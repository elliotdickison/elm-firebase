effect module Firebase
    where { command = MyCmd, subscription = MySub }
    exposing
        ( Error(..)
        , initialize
        , set
        , get
        , changes
        )

import Firebase.App as App exposing (App)
import Firebase.Database as Database
import Json.Encode as Encode
import Task exposing (Task)


-- TYPES


type Error
    = NotInitialized
    | DatabasePermissionDenied
    | DatabaseOtherError String


type MyCmd msg
    = Set Database.Path (Error -> msg) Encode.Value
    | Get Database.Path (Result Error Encode.Value -> msg)
    | Initialize App.Config


type MySub msg
    = MySubValue Database.Path Database.Event (Encode.Value -> msg)
    | MySubValueAndPrevKey Database.Path Database.Event (Encode.Value (Maybe String) -> msg)


type alias State msg =
    { app : Maybe App
    , listeners : List ( Database.Path, Database.Event, Database.Listener )
    , subs : List ( Database.Path, Database.Event, Encode.Value -> msg )
    , listenAttempted : Bool
    , latestValue : Maybe Encode.Value
    }


type Msg
    = DataReceived Encode.Value (Maybe String)



-- API


initialize : App.Config -> Cmd msg
initialize config =
    command (Initialize config)


set : Database.Path -> (Error -> msg) -> Encode.Value -> Cmd msg
set path toMsg value =
    command (Set path toMsg value)


get : Database.Path -> (Result Error Encode.Value -> msg) -> Cmd msg
get path toMsg =
    command (Get path toMsg)


changes : Database.Path -> (Encode.Value -> msg) -> Sub msg
changes path toMsg =
    subscription (MySubValue path Database.Change toMsg)


newChildren : Database.Path -> (Encode.Value (Maybe String) -> msg) -> Sub msg
newChildren path toMsg =
    subscription (MySubValueAndPrevKey path Database.ChildAdd toMsg)



-- DATABASE


mapDatabaseError : Database.Error -> Error
mapDatabaseError error =
    case error of
        Database.PermissionDenied ->
            DatabasePermissionDenied

        Database.OtherError message ->
            DatabaseOtherError message


listen : Platform.Router msg Msg -> App -> Database.Path -> Database.Event -> Task Never Database.Listener
listen router app path event =
    let
        handler value prevKey =
            Platform.sendToSelf router (DataReceived value prevKey)
    in
        Database.listen app path event handler



-- MANAGER


init : Task Never (State msg)
init =
    Task.succeed
        { app = Nothing
        , listeners = []
        , subs = []
        , listenAttempted = False
        , latestValue = Nothing
        }


cmdMap : (a -> b) -> MyCmd a -> MyCmd b
cmdMap f cmd =
    case cmd of
        Set path toMsg value ->
            Set path (toMsg >> f) value

        Get path toMsg ->
            Get path (toMsg >> f)

        Initialize config ->
            Initialize config


subMap : (a -> b) -> MySub a -> MySub b
subMap f sub =
    case sub of
        MySubValue path event toMsg ->
            MySubValue path event (toMsg >> f)

        MySubValueAndPrevKey path event toMsg ->
            MySubValueAndPrevKey path event (toMsg >> f)


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
                case ( state.listenAttempted, state.app ) of
                    ( False, Just app ) ->
                        listen router app "user" Database.Change
                            |> Task.andThen (\pid -> onEffects router cmdList subList { state | listenAttempted = True })

                    _ ->
                        Task.succeed state

            (Set path toMsg value) :: cmdListTail ->
                case state.app of
                    Just app ->
                        Database.set app path value
                            |> Task.mapError mapDatabaseError
                            |> Task.onError (\error -> Platform.sendToApp router (toMsg error))
                            |> Task.andThen (\_ -> onEffects router cmdListTail subList state)

                    Nothing ->
                        Platform.sendToApp router (toMsg NotInitialized)
                            |> Task.andThen (\_ -> onEffects router cmdListTail subList state)

            (Get path toMsg) :: cmdListTail ->
                case state.app of
                    Just app ->
                        Database.get app path
                            |> Task.mapError mapDatabaseError
                            |> Task.andThen (\value -> Platform.sendToApp router (toMsg (Ok value)))
                            |> Task.onError (\error -> Platform.sendToApp router (toMsg (Err error)))
                            |> Task.andThen (\_ -> onEffects router cmdListTail subList state)

                    Nothing ->
                        Platform.sendToApp router (toMsg (Err NotInitialized))
                            |> Task.andThen (\_ -> onEffects router cmdListTail subList state)

            (Initialize config) :: cmdListTail ->
                App.initialize config
                    |> Task.andThen (\app -> onEffects router cmdListTail subList { state | app = Just app })


onSelfMsg : Platform.Router msg Msg -> Msg -> State msg -> Task Never (State msg)
onSelfMsg router selfMsg state =
    case selfMsg of
        DataReceived value prevKey ->
            Task.succeed { state | latestValue = value |> Debug.log "heard" |> Just }
