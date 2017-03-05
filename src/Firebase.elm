effect module Firebase
    where { command = MyCmd, subscription = MySub }
    exposing
        ( Error(..)
        , set
        , get
        , changes
        )

import Firebase.App as App
import Firebase.Database as Database
import Json.Encode as Encode
import Task exposing (Task)


-- TYPES


type Error
    = DatabasePermissionDenied
    | DatabaseOtherError String


type MyCmd msg
    = Set App.Config Database.Path (Error -> msg) Encode.Value
    | Get App.Config Database.Path (Result Error Encode.Value -> msg)


type MySub msg
    = MySubValue App.Config Database.Path Database.Event (Encode.Value -> msg)
    | MySubValueAndPrevKey App.Config Database.Path Database.Event (Encode.Value (Maybe String) -> msg)


type alias State msg =
    { listeners : List Database.Listener
    , subs : List (MySub msg)
    , listenAttempted : Bool
    , latestValue : Maybe Encode.Value
    }


type Msg
    = DataReceived Encode.Value (Maybe String)



-- API


set : App.Config -> Database.Path -> (Error -> msg) -> Encode.Value -> Cmd msg
set config path toMsg value =
    command (Set config path toMsg value)


get : App.Config -> Database.Path -> (Result Error Encode.Value -> msg) -> Cmd msg
get config path toMsg =
    command (Get config path toMsg)


changes : App.Config -> Database.Path -> (Encode.Value -> msg) -> Sub msg
changes config path toMsg =
    subscription (MySubValue config path Database.Change toMsg)


newChildren : App.Config -> Database.Path -> (Encode.Value (Maybe String) -> msg) -> Sub msg
newChildren config path toMsg =
    subscription (MySubValueAndPrevKey config path Database.ChildAdd toMsg)



-- DATABASE


mapDatabaseError : Database.Error -> Error
mapDatabaseError error =
    case error of
        Database.PermissionDenied ->
            DatabasePermissionDenied

        Database.OtherError message ->
            DatabaseOtherError message


listen : Platform.Router msg Msg -> App.Config -> Database.Path -> Database.Event -> Task Never Database.Listener
listen router config path event =
    let
        handler value prevKey =
            Platform.sendToSelf router (DataReceived value prevKey)
    in
        Database.listen config path event handler



-- MANAGER


init : Task Never (State msg)
init =
    Task.succeed
        { listeners = []
        , subs = []
        , listenAttempted = False
        , latestValue = Nothing
        }


cmdMap : (a -> b) -> MyCmd a -> MyCmd b
cmdMap f cmd =
    case cmd of
        Set config path toMsg value ->
            Set config path (toMsg >> f) value

        Get config path toMsg ->
            Get config path (toMsg >> f)


subMap : (a -> b) -> MySub a -> MySub b
subMap f sub =
    case sub of
        MySubValue config path event toMsg ->
            MySubValue config path event (toMsg >> f)

        MySubValueAndPrevKey config path event toMsg ->
            MySubValueAndPrevKey config path event (toMsg >> f)


onEffects :
    Platform.Router msg Msg
    -> List (MyCmd msg)
    -> List (MySub msg)
    -> State msg
    -> Task Never (State msg)
onEffects router cmdList subList state =
    let
        nextSubList =
            subList
    in
        case cmdList of
            [] ->
                --case ( state.listenAttempted, state.app ) of
                --    ( False, Just app ) ->
                --        listen router app "user" Database.Change
                --            |> Task.andThen (\pid -> onEffects router cmdList subList { state | listenAttempted = True })
                --    _ ->
                Task.succeed state

            (Set config path toMsg value) :: cmdListTail ->
                Database.set config path value
                    |> Task.mapError mapDatabaseError
                    |> Task.onError (\error -> Platform.sendToApp router (toMsg error))
                    |> Task.andThen (\_ -> onEffects router cmdListTail subList state)

            (Get config path toMsg) :: cmdListTail ->
                Database.get config path
                    |> Task.mapError mapDatabaseError
                    |> Task.andThen (\value -> Platform.sendToApp router (toMsg (Ok value)))
                    |> Task.onError (\error -> Platform.sendToApp router (toMsg (Err error)))
                    |> Task.andThen (\_ -> onEffects router cmdListTail subList state)


onSelfMsg : Platform.Router msg Msg -> Msg -> State msg -> Task Never (State msg)
onSelfMsg router selfMsg state =
    case selfMsg of
        DataReceived value prevKey ->
            Task.succeed { state | latestValue = value |> Debug.log "heard" |> Just }
