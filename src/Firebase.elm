effect module Firebase where { command = MyCmd } exposing (Error(..), initialize, set)

import Firebase.App as App exposing (App)
import Firebase.Database as Database
import Json.Encode as Json
import Task exposing (Task)
import Dict exposing (Dict)


-- Types


type Error
    = AppInitializeError
    | DatabasePermissionError
    | DatabaseConfigError String
    | DatabaseOtherError String


type MyCmd msg
    = Set Database.Path (Error -> msg) Json.Value
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


set : Database.Path -> (Error -> msg) -> Json.Value -> Cmd msg
set path errorToMsg value =
    command (Set path errorToMsg value)



-- Database


convertDatabaseError : Database.Error -> Error
convertDatabaseError error =
    case error of
        Database.PermissionError ->
            DatabasePermissionError

        Database.ConfigError message ->
            DatabaseConfigError message

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
                        |> Task.mapError convertDatabaseError
                        |> Task.onError (\error -> Platform.sendToApp router (errorToMsg error))
                        |> Task.andThen (\_ -> onEffects router cmdListTail state)

                Nothing ->
                    Platform.sendToApp router (errorToMsg AppInitializeError)
                        |> Task.andThen (\_ -> onEffects router cmdListTail state)

        (Initialize config) :: cmdListTail ->
            App.initialize config
                |> Task.andThen (\app -> onEffects router cmdListTail { state | app = Just app })


onSelfMsg : Platform.Router msg Msg -> Msg -> State msg -> Task Never (State msg)
onSelfMsg router selfMsg state =
    case selfMsg of
        NoOp ->
            Task.succeed state
