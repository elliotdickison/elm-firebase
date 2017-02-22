effect module Firebase where { command = MyCmd } exposing (Error(..), initialize, set, get)

import Firebase.App as App exposing (App)
import Firebase.Database as Database
import Json.Encode as Encode
import Task exposing (Task)
import Dict exposing (Dict)


-- Types


type Error
    = NotInitialized
    | DatabasePermissionDenied
    | DatabaseOtherError String


type MyCmd msg
    = Set Database.Path (Error -> msg) Encode.Value
    | Get Database.Path (Result Error Encode.Value -> msg)
    | Initialize App.Config


type alias SubsDict msg =
    Dict String (List (String -> msg))


type alias State msg =
    { app : Maybe App
    , subs : SubsDict msg
    }


type Msg
    = NoOp



-- API


initialize : App.Config -> Cmd msg
initialize config =
    command (Initialize config)


set : Database.Path -> (Error -> msg) -> Encode.Value -> Cmd msg
set path errorToMsg value =
    command (Set path errorToMsg value)


get : Database.Path -> (Result Error Encode.Value -> msg) -> Cmd msg
get path resultToMsg =
    command (Get path resultToMsg)



-- Database


mapDatabaseError : Database.Error -> Error
mapDatabaseError error =
    case error of
        Database.PermissionDenied ->
            DatabasePermissionDenied

        Database.OtherError message ->
            DatabaseOtherError message



-- Effect manager magic


init : Task Never (State msg)
init =
    Task.succeed (State Nothing Dict.empty)


cmdMap : (a -> b) -> MyCmd a -> MyCmd b
cmdMap f cmd =
    case cmd of
        Set path errorToMsg value ->
            Set path (errorToMsg >> f) value

        Get path resultToMsg ->
            Get path (resultToMsg >> f)

        Initialize config ->
            Initialize config


onEffects : Platform.Router msg Msg -> List (MyCmd msg) -> State msg -> Task Never (State msg)
onEffects router cmdList state =
    case cmdList of
        [] ->
            Task.succeed state

        (Set path errorToMsg value) :: cmdListTail ->
            case state.app of
                Just app ->
                    Database.set app path value
                        |> Task.mapError mapDatabaseError
                        |> Task.onError (\error -> Platform.sendToApp router (errorToMsg error))
                        |> Task.andThen (\_ -> onEffects router cmdListTail state)

                Nothing ->
                    Platform.sendToApp router (errorToMsg NotInitialized)
                        |> Task.andThen (\_ -> onEffects router cmdListTail state)

        (Get path resultToMsg) :: cmdListTail ->
            case state.app of
                Just app ->
                    Database.get app path
                        |> Task.mapError mapDatabaseError
                        |> Task.andThen (\value -> Platform.sendToApp router (resultToMsg (Ok value)))
                        |> Task.onError (\error -> Platform.sendToApp router (resultToMsg (Err error)))
                        |> Task.andThen (\_ -> onEffects router cmdListTail state)

                Nothing ->
                    Platform.sendToApp router (resultToMsg (Err NotInitialized))
                        |> Task.andThen (\_ -> onEffects router cmdListTail state)

        (Initialize config) :: cmdListTail ->
            App.initialize config
                |> Task.andThen (\app -> onEffects router cmdListTail { state | app = Just app })


onSelfMsg : Platform.Router msg Msg -> Msg -> State msg -> Task Never (State msg)
onSelfMsg router selfMsg state =
    case selfMsg of
        NoOp ->
            Task.succeed state
