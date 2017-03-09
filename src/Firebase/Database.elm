effect module Firebase.Database
    where { command = MyCmd, subscription = MySub }
    exposing
        ( set
        , get
        , changes
        )

import Firebase exposing (Config, Path, Error, Event(..))
import Firebase.Database.LowLevel as LowLevel
import Json.Encode as Encode
import Task exposing (Task)


type alias EventSignature =
    ( Config, Path, Event )


type MyCmd msg
    = Set Config Path (Result Error Encode.Value -> msg) Encode.Value
    | Get Config Path (Result Error Encode.Value -> msg)


type MySub msg
    = MySubValue EventSignature (Encode.Value -> msg)
    | MySubValueAndPrevKey EventSignature (Encode.Value -> Maybe String -> msg)


type alias State msg =
    List (MySub msg)


type Msg
    = SubResponse EventSignature Encode.Value (Maybe String)



-- API


set : Config -> Path -> (Result Error Encode.Value -> msg) -> Encode.Value -> Cmd msg
set config path toMsg value =
    command (Set config path toMsg value)


get : Config -> Path -> (Result Error Encode.Value -> msg) -> Cmd msg
get config path toMsg =
    command (Get config path toMsg)


changes : Config -> Path -> (Encode.Value -> msg) -> Sub msg
changes config path toMsg =
    subscription (MySubValue ( config, path, Change ) toMsg)


newChildren : Config -> Path -> (Encode.Value -> Maybe String -> msg) -> Sub msg
newChildren config path toMsg =
    subscription (MySubValueAndPrevKey ( config, path, ChildAdd ) toMsg)



-- HELPERS


getEventSignature : MySub msg -> EventSignature
getEventSignature sub =
    case sub of
        MySubValue signature _ ->
            signature

        MySubValueAndPrevKey signature _ ->
            signature


diffEventSignatures :
    List EventSignature
    -> List EventSignature
    -> List EventSignature
diffEventSignatures a b =
    List.foldl
        (\signature uniqueList ->
            let
                notIn =
                    List.member signature >> not
            in
                if notIn a && notIn uniqueList then
                    signature :: uniqueList
                else
                    uniqueList
        )
        []
        b


listen : Platform.Router msg Msg -> EventSignature -> Task Never ()
listen router ( config, path, event ) =
    let
        toMsg =
            SubResponse ( config, path, event )

        handler value prevKey =
            Platform.sendToSelf router (toMsg value prevKey)
    in
        LowLevel.listen config path event handler


stopListening : EventSignature -> Task Never ()
stopListening ( config, path, event ) =
    LowLevel.stopListening config path event


handleSubResponse :
    Platform.Router msg Msg
    -> Encode.Value
    -> Maybe String
    -> MySub msg
    -> Task Never ()
handleSubResponse router value prevKey sub =
    case sub of
        MySubValue _ toMsg ->
            Platform.sendToApp router (toMsg value)

        MySubValueAndPrevKey _ toMsg ->
            Platform.sendToApp router (toMsg value prevKey)


runCmd : Platform.Router msg Msg -> MyCmd msg -> Task Never ()
runCmd router cmd =
    case cmd of
        Set config path toMsg value ->
            LowLevel.set config path value
                |> Task.andThen (\value -> Platform.sendToApp router (toMsg (Ok value)))
                |> Task.onError (\error -> Platform.sendToApp router (toMsg (Err error)))

        Get config path toMsg ->
            LowLevel.get config path
                |> Task.andThen (\value -> Platform.sendToApp router (toMsg (Ok value)))
                |> Task.onError (\error -> Platform.sendToApp router (toMsg (Err error)))



-- EFFECT MANAGER


(&>) : Task x a -> Task x b -> Task x b
(&>) t1 t2 =
    Task.andThen (\_ -> t2) t1


init : Task Never (State msg)
init =
    Task.succeed []


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
        MySubValue signature toMsg ->
            MySubValue signature (toMsg >> f)

        MySubValueAndPrevKey signature toMsg ->
            MySubValueAndPrevKey signature (\c -> toMsg c >> f)


onEffects :
    Platform.Router msg Msg
    -> List (MyCmd msg)
    -> List (MySub msg)
    -> State msg
    -> Task Never (State msg)
onEffects router cmds subs state =
    let
        signatures =
            List.map getEventSignature state

        nextSignatures =
            List.map getEventSignature subs

        startListeners =
            diffEventSignatures signatures nextSignatures
                |> List.map (listen router)
                |> Task.sequence

        stopListeners =
            diffEventSignatures nextSignatures signatures
                |> List.map stopListening
                |> Task.sequence

        runCmds =
            cmds
                |> List.map (runCmd router)
                |> Task.sequence
    in
        startListeners
            &> stopListeners
            &> runCmds
            &> Task.succeed subs


onSelfMsg : Platform.Router msg Msg -> Msg -> State msg -> Task Never (State msg)
onSelfMsg router selfMsg state =
    case selfMsg of
        SubResponse signature value prevKey ->
            state
                |> List.filter (getEventSignature >> (==) signature)
                |> List.map (handleSubResponse router value prevKey)
                |> Task.sequence
                |> Task.andThen (\_ -> Task.succeed state)
