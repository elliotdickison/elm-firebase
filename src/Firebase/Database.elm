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
    = Set Config Path (Error -> msg) Encode.Value
    | Get Config Path (Result Error Encode.Value -> msg)


type MySub msg
    = MySubValue EventSignature (Encode.Value -> msg)
    | MySubValueAndPrevKey EventSignature (Encode.Value -> Maybe String -> msg)


type alias State msg =
    { subs : List (MySub msg)
    , listenAttempted : Bool
    , latestValue : Maybe Encode.Value
    }


type Msg
    = StartListener EventSignature
    | StopListener EventSignature
    | HandleListenerValue EventSignature Encode.Value (Maybe String)



-- API


set : Config -> Path -> (Error -> msg) -> Encode.Value -> Cmd msg
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
                memberOfA =
                    List.member signature a

                memberOfB =
                    List.member signature uniqueList
            in
                case ( memberOfA, memberOfB ) of
                    ( False, False ) ->
                        signature :: uniqueList

                    _ ->
                        uniqueList
        )
        []
        b



-- EFFECT MANAGER


init : Task Never (State msg)
init =
    Task.succeed
        { subs = []
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
    case cmds of
        [] ->
            let
                signatures =
                    List.map getEventSignature state.subs

                nextSignatures =
                    List.map getEventSignature subs

                startListeners =
                    diffEventSignatures signatures nextSignatures
                        |> List.map (StartListener >> Platform.sendToSelf router)
                        |> Task.sequence

                stopListeners =
                    diffEventSignatures nextSignatures signatures
                        |> List.map (StopListener >> Platform.sendToSelf router)
                        |> Task.sequence
            in
                startListeners
                    |> Task.andThen (\_ -> stopListeners)
                    |> Task.andThen (\_ -> Task.succeed { state | subs = subs })

        (Set config path toMsg value) :: otherCmds ->
            LowLevel.set config path value
                |> Task.onError (\error -> Platform.sendToApp router (toMsg error))
                |> Task.andThen (\_ -> onEffects router otherCmds subs state)

        (Get config path toMsg) :: otherCmds ->
            LowLevel.get config path
                |> Task.andThen (\value -> Platform.sendToApp router (toMsg (Ok value)))
                |> Task.onError (\error -> Platform.sendToApp router (toMsg (Err error)))
                |> Task.andThen (\_ -> onEffects router otherCmds subs state)


onSelfMsg : Platform.Router msg Msg -> Msg -> State msg -> Task Never (State msg)
onSelfMsg router selfMsg state =
    case selfMsg of
        StartListener ( config, path, event ) ->
            let
                handler value prevKey =
                    Platform.sendToSelf router (HandleListenerValue ( config, path, event ) value prevKey)
            in
                LowLevel.listen config path event handler
                    |> Task.andThen (\_ -> Task.succeed state)

        StopListener ( config, path, event ) ->
            LowLevel.stop config path event
                |> Task.andThen (\_ -> Task.succeed state)

        HandleListenerValue signature value prevKey ->
            state.subs
                |> List.filter (\sub -> getEventSignature sub == signature)
                |> List.map
                    (\sub ->
                        case sub of
                            MySubValue _ toMsg ->
                                Platform.sendToApp router (toMsg value)

                            MySubValueAndPrevKey _ toMsg ->
                                Platform.sendToApp router (toMsg value prevKey)
                    )
                |> Task.sequence
                |> Task.andThen
                    (\_ ->
                        Task.succeed
                            { state | latestValue = value |> Debug.log "heard" |> Just }
                    )
