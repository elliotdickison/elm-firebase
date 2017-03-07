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
    | MySubValueAndPrevKey EventSignature (Encode.Value (Maybe String) -> msg)


type alias State msg =
    { subs : List (MySub msg)
    , listenAttempted : Bool
    , latestValue : Maybe Encode.Value
    }


type Msg
    = StartListeners (List EventSignature)
    | StopListeners (List EventSignature)
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


newChildren : Config -> Path -> (Encode.Value (Maybe String) -> msg) -> Sub msg
newChildren config path toMsg =
    subscription (MySubValueAndPrevKey ( config, path, ChildAdd ) toMsg)



-- HELPERS


listen : Platform.Router msg Msg -> Config -> Path -> Event -> Task Never ()
listen router config path event =
    let
        handler value prevKey =
            Platform.sendToSelf router (HandleListenerValue ( config, path, event ) value prevKey)
    in
        LowLevel.listen config path event handler


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
            MySubValueAndPrevKey signature (toMsg >> f)


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

                addedSignatures =
                    diffEventSignatures signatures nextSignatures
                        |> Debug.log "added signatures"

                removedSignatures =
                    diffEventSignatures nextSignatures signatures
                        |> Debug.log "removed signatures"
            in
                case ( List.isEmpty addedSignatures, List.isEmpty removedSignatures ) of
                    ( False, False ) ->
                        Platform.sendToSelf router (StartListeners addedSignatures)
                            |> Task.andThen (\_ -> Platform.sendToSelf router (StopListeners removedSignatures))
                            |> Task.andThen (\_ -> Task.succeed { state | subs = subs })

                    ( False, True ) ->
                        Platform.sendToSelf router (StartListeners addedSignatures)
                            |> Task.andThen (\_ -> Task.succeed { state | subs = subs })

                    ( True, False ) ->
                        Platform.sendToSelf router (StopListeners removedSignatures)
                            |> Task.andThen (\_ -> Task.succeed { state | subs = subs })

                    ( True, True ) ->
                        Task.succeed { state | subs = subs }

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
        StartListeners (( config, path, event ) :: otherSignatures) ->
            listen router config path event
                |> Task.andThen (\_ -> onSelfMsg router (StartListeners otherSignatures) state)

        StopListeners (( config, path, event ) :: otherSignatures) ->
            LowLevel.stop config path event
                |> Task.andThen (\_ -> onSelfMsg router (StopListeners otherSignatures) state)

        HandleListenerValue signature value prevKey ->
            Task.succeed
                { state | latestValue = value |> Debug.log "heard" |> Just }

        _ ->
            Task.succeed state
