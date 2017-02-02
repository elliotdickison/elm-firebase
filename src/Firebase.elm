effect module Firebase where { command = MyCmd } exposing (App, initializeApp, generateInt)

--import Firebase.Reference as Reference exposing (Reference)

import Native.Firebase
import Task exposing (Task)
import Dict exposing (Dict)


-- Types


type App
    = App


type alias Config =
    { apiKey : String
    , authDomain : String
    , databaseUrl : String
    , storageBucket : String
    , messagingSenderId : String
    }


type MyCmd msg
    = GenerateInt (Int -> msg)


type alias SubsDict msg =
    Dict String (List (String -> msg))


type alias State msg =
    { int : Int
    , subs : SubsDict msg
    }


type Msg
    = NoOp



-- API


initializeApp : Config -> App
initializeApp config =
    Native.Firebase.initializeApp config


generateInt : (Int -> msg) -> Cmd msg
generateInt msg =
    command (GenerateInt msg)



-- Effect manager magic


init : Task Never (State msg)
init =
    Task.succeed (State 0 Dict.empty)


cmdMap : (a -> b) -> MyCmd a -> MyCmd b
cmdMap f (GenerateInt msg) =
    GenerateInt (msg >> f)


onEffects : Platform.Router msg Msg -> List (MyCmd msg) -> State msg -> Task Never (State msg)
onEffects router cmdList state =
    case cmdList of
        [] ->
            Task.succeed state

        (GenerateInt msg) :: cmdListTail ->
            Platform.sendToApp router (msg state.int)
                |> Task.andThen (\_ -> Task.succeed { state | int = state.int + 1 })


onSelfMsg : Platform.Router msg Msg -> Msg -> State msg -> Task Never (State msg)
onSelfMsg router selfMsg state =
    case selfMsg of
        NoOp ->
            Task.succeed state
