effect module Firebase.Database
    where { command = MyCmd, subscription = MySub }
    exposing
        ( set
        , get
        , getList
        , changes
        , listChanges
        )

import Firebase
    exposing
        ( Config
        , Path
        , Key
        , KeyValue
        , Query
        , Error
        )
import Firebase.Database.LowLevel as LowLevel
import Task exposing (Task)
import Json.Encode as Encode exposing (Value)


-- TODO: get rid of "name" in the config and update the native "getDatabase"
-- function to diff apps based on the database URL
-- TODO: Think more about argument order... may make sense to have path go
-- first (or second, after config)
-- TODO: Consider including encoders/decoders in the API to simplify boilerplate
-- on the user end
-- TODO: wrap up the list APIs into a single listChanges function that
-- implements the listItem functions under the hood (which basically creates a
-- streaming API w/ much better performance)
-- set : Config -> (Result Error Value -> msg) -> Path -> Value -> Cmd msg
-- map : Config -> (Result Error (Maybe Value) -> msg) -> Path -> (Maybe Value -> Maybe Value) -> Cmd msg
-- merge : Config -> (Result Error Value -> msg) -> Path -> Value -> Cmd msg
-- remove : Config -> (Result Error () -> msg) -> Path -> Cmd msg
-- create : Config -> (Result Error Key -> msg) -> Path -> Maybe Value -> Cmd msg
-- get : Config -> (Result Error (Maybe Value) -> msg) -> Path -> Cmd msg
-- getList : Config -> (Result Error (List KeyValue) -> msg) -> Path -> Query -> Cmd msg
-- changes : Config -> (Value -> msg) -> Path -> Sub msg
-- listChanges : Config -> (List KeyValue -> msg) -> Path -> Query -> Sub msg
-- listItemChanges : Config -> (KeyValue -> Maybe Key -> msg) -> Path -> Query -> Sub msg
-- listItemAdditions : Config -> (KeyValue -> Maybe Key -> msg) -> Path -> Query -> Sub msg
-- listItemMoves : Config -> (KeyValue -> Maybe Key -> msg) -> Path -> Query -> Sub msg
-- listItemRemovals : Config -> (KeyValue -> msg) -> Path -> Query -> Sub msg


type alias EventSignature =
    ( Config, Path, Maybe Query, LowLevel.Event )


type MyCmd msg
    = Set Config (Result Error Value -> msg) Path Value
    | Map Config (Result Error (Maybe Value) -> msg) Path (Maybe Value -> Maybe Value)
    | Get Config (Result Error (Maybe Value) -> msg) Path
    | GetList Config (Result Error (List KeyValue) -> msg) Path Query


type MySub msg
    = ValueSub EventSignature (Maybe Value -> msg)
    | ListSub EventSignature (List KeyValue -> msg)
    | ListItemSub EventSignature (KeyValue -> msg)
    | ListItemAndPrevKeySub EventSignature (KeyValue -> Maybe Key -> msg)


type alias State msg =
    List (MySub msg)


type Msg
    = SubResponse EventSignature LowLevel.Snapshot (Maybe Key)
    | NoOp



-- API


set :
    Config
    -> (Result Error Value -> msg)
    -> Path
    -> Value
    -> Cmd msg
set config toMsg path value =
    command (Set config toMsg path value)


map :
    Config
    -> (Result Error (Maybe Value) -> msg)
    -> Path
    -> (Maybe Value -> Maybe Value)
    -> Cmd msg
map config toMsg path func =
    command (Map config toMsg path func)


get : Config -> (Result Error (Maybe Value) -> msg) -> Path -> Cmd msg
get config toMsg path =
    command (Get config toMsg path)


getList :
    Config
    -> (Result Error (List KeyValue) -> msg)
    -> Path
    -> Query
    -> Cmd msg
getList config toMsg path query =
    command (GetList config toMsg path query)


changes : Config -> (Maybe Value -> msg) -> Path -> Sub msg
changes config toMsg path =
    subscription (ValueSub ( config, path, Nothing, LowLevel.Change ) toMsg)


listChanges : Config -> (List KeyValue -> msg) -> Path -> Query -> Sub msg
listChanges config toMsg path query =
    subscription (ListSub ( config, path, Just query, LowLevel.Change ) toMsg)



-- HELPERS


getEventSignature : MySub msg -> EventSignature
getEventSignature sub =
    case sub of
        ValueSub signature _ ->
            signature

        ListSub signature _ ->
            signature

        ListItemSub signature _ ->
            signature

        ListItemAndPrevKeySub signature _ ->
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
listen router signature =
    let
        handler snapshot prevKey =
            Platform.sendToSelf router (SubResponse signature snapshot prevKey)

        ( config, path, query, event ) =
            signature
    in
        LowLevel.listen config path query event handler


stopListening : EventSignature -> Task Never ()
stopListening ( config, path, query, event ) =
    LowLevel.stopListening config path event query


snapshotToKeyValue : LowLevel.Snapshot -> Maybe KeyValue
snapshotToKeyValue snapshot =
    snapshot
        |> LowLevel.snapshotToValue
        |> Maybe.map (\value -> ( LowLevel.snapshotToKey snapshot, value ))


snapshotToKeyValueList : LowLevel.Snapshot -> List KeyValue
snapshotToKeyValueList snapshot =
    snapshot
        |> LowLevel.snapshotToList
        |> List.filterMap snapshotToKeyValue


handleSubResponse :
    Platform.Router msg Msg
    -> LowLevel.Snapshot
    -> Maybe Key
    -> MySub msg
    -> Task Never ()
handleSubResponse router snapshot prevKey sub =
    case sub of
        ValueSub _ toMsg ->
            Platform.sendToApp router (snapshot |> LowLevel.snapshotToValue |> toMsg)

        ListSub _ toMsg ->
            Platform.sendToApp router (snapshot |> snapshotToKeyValueList |> toMsg)

        ListItemSub _ toMsg ->
            case snapshotToKeyValue snapshot of
                Just keyValue ->
                    Platform.sendToApp router (toMsg keyValue)

                Nothing ->
                    Platform.sendToSelf router NoOp

        ListItemAndPrevKeySub _ toMsg ->
            case snapshotToKeyValue snapshot of
                Just keyValue ->
                    Platform.sendToApp router (toMsg keyValue prevKey)

                Nothing ->
                    Platform.sendToSelf router NoOp


runCmd : Platform.Router msg Msg -> MyCmd msg -> Task Never ()
runCmd router cmd =
    case cmd of
        Set config toMsg path value ->
            LowLevel.set config path value
                |> Task.andThen (\_ -> value |> Ok |> toMsg |> Platform.sendToApp router)
                |> Task.onError (Err >> toMsg >> Platform.sendToApp router)

        Map config toMsg path func ->
            LowLevel.map config path func
                |> Task.map LowLevel.snapshotToValue
                |> Task.andThen (Ok >> toMsg >> Platform.sendToApp router)
                |> Task.onError (Err >> toMsg >> Platform.sendToApp router)

        Get config toMsg path ->
            LowLevel.get config path Nothing
                |> Task.map LowLevel.snapshotToValue
                |> Task.andThen (Ok >> toMsg >> Platform.sendToApp router)
                |> Task.onError (Err >> toMsg >> Platform.sendToApp router)

        GetList config toMsg path query ->
            LowLevel.get config path (Just query)
                |> Task.map snapshotToKeyValueList
                |> Task.andThen (Ok >> toMsg >> Platform.sendToApp router)
                |> Task.onError (Err >> toMsg >> Platform.sendToApp router)



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
        Set config toMsg path value ->
            Set config (toMsg >> f) path value

        Map config toMsg path func ->
            Map config (toMsg >> f) path func

        Get config toMsg path ->
            Get config (toMsg >> f) path

        GetList config toMsg path query ->
            GetList config (toMsg >> f) path query


subMap : (a -> b) -> MySub a -> MySub b
subMap f sub =
    case sub of
        ValueSub signature toMsg ->
            ValueSub signature (toMsg >> f)

        ListSub signature toMsg ->
            ListSub signature (toMsg >> f)

        ListItemSub signature toMsg ->
            ListItemSub signature (toMsg >> f)

        ListItemAndPrevKeySub signature toMsg ->
            ListItemAndPrevKeySub signature (\c -> toMsg c >> f)


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

        stopListeners =
            diffEventSignatures nextSignatures signatures
                |> List.map stopListening
                |> Task.sequence

        startListeners =
            diffEventSignatures signatures nextSignatures
                |> List.map (listen router)
                |> Task.sequence

        runCmds =
            cmds
                |> List.map (runCmd router)
                |> Task.sequence
    in
        stopListeners
            &> startListeners
            &> runCmds
            &> Task.succeed subs


onSelfMsg :
    Platform.Router msg Msg
    -> Msg
    -> State msg
    -> Task Never (State msg)
onSelfMsg router selfMsg state =
    case selfMsg of
        SubResponse signature snapshot prevKey ->
            state
                |> List.filter (getEventSignature >> (==) signature)
                |> List.map (handleSubResponse router snapshot prevKey)
                |> Task.sequence
                |> Task.andThen (\_ -> Task.succeed state)

        NoOp ->
            Task.succeed state
