effect module Firebase.Database
    where { subscription = MySub }
    exposing
        ( attempt
        , set
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
import Firebase.Database.Snapshot as Snapshot exposing (Snapshot)
import Task exposing (Task)
import Json.Encode as Encode exposing (Value)


-- TODO: get rid of "name" in the config and update the native "getDatabase"
-- function to diff apps based on the database URL
-- TODO: Consider including encoders/decoders in the API to simplify boilerplate
-- on the user end
-- TODO: wrap up the list APIs into a single listChanges function that
-- implements the listItem functions under the hood (which basically creates a
-- streaming API w/ much better performance)
-- set : Config -> Path -> (Result Error Value -> msg) -> Value -> Cmd msg
-- map : Config -> Path -> (Result Error (Maybe Value) -> msg) -> (Maybe Value -> Maybe Value) -> Cmd msg
-- merge : Config -> Path -> (Result Error Value -> msg) -> Value -> Cmd msg
-- remove : Config -> Path -> (Result Error () -> msg) -> Cmd msg
-- create : Config -> Path -> (Result Error Key -> msg) -> Maybe Value -> Cmd msg
-- get : Config -> Path -> (Result Error (Maybe Value) -> msg) -> Cmd msg
-- getList : Config -> Path -> (Result Error (List KeyValue) -> msg) -> Query -> Cmd msg
-- changes : Config -> Path -> (Value -> msg) -> Sub msg
-- listChanges : Config -> Path -> (List KeyValue -> msg) -> Query -> Sub msg
-- listItemChanges : Config -> Path -> (KeyValue -> Maybe Key -> msg) -> Query -> Sub msg
-- listItemAdditions : Config -> Path -> (KeyValue -> Maybe Key -> msg) -> Query -> Sub msg
-- listItemMoves : Config -> Path -> (KeyValue -> Maybe Key -> msg) -> Query -> Sub msg
-- listItemRemovals : Config -> Path -> (KeyValue -> msg) -> Query -> Sub msg


type alias SubSignature =
    ( Config, Path, Maybe Query, LowLevel.Event )


type MySub msg
    = ValueSub SubSignature (Maybe Value -> msg)
    | ListSub SubSignature (List KeyValue -> msg)
    | ListItemSub SubSignature (KeyValue -> msg)
    | ListItemAndPrevKeySub SubSignature (KeyValue -> Maybe Key -> msg)


type alias State msg =
    List (MySub msg)


type Msg
    = SubResponse SubSignature Snapshot (Maybe Key)



-- API


attempt : Config -> (Result x a -> msg) -> (Config -> Task x a) -> Cmd msg
attempt config toMsg toTask =
    Task.attempt toMsg (toTask config)


set : Path -> Value -> Config -> Task Error Value
set path value config =
    LowLevel.set config path value
        |> Task.map (\_ -> value)


map : Path -> (Maybe Value -> Maybe Value) -> Config -> Task Error (Maybe Value)
map path func config =
    LowLevel.map config path func
        |> Task.map Snapshot.toValue


get : Path -> Config -> Task Error (Maybe Value)
get path config =
    LowLevel.get config path Nothing
        |> Task.map Snapshot.toValue


getList : Path -> Query -> Config -> Task Error (List KeyValue)
getList path query config =
    LowLevel.get config path (Just query)
        |> Task.map Snapshot.toKeyValueList


changes : Config -> Path -> (Maybe Value -> msg) -> Sub msg
changes config path toMsg =
    subscription (ValueSub ( config, path, Nothing, LowLevel.Change ) toMsg)


listChanges : Config -> Path -> Query -> (List KeyValue -> msg) -> Sub msg
listChanges config path query toMsg =
    subscription (ListSub ( config, path, Just query, LowLevel.Change ) toMsg)



-- HELPERS


getSubSignature : MySub msg -> SubSignature
getSubSignature sub =
    case sub of
        ValueSub signature _ ->
            signature

        ListSub signature _ ->
            signature

        ListItemSub signature _ ->
            signature

        ListItemAndPrevKeySub signature _ ->
            signature


diffSubSignatures :
    List SubSignature
    -> List SubSignature
    -> List SubSignature
diffSubSignatures a b =
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


listen : Platform.Router msg Msg -> SubSignature -> Task Never ()
listen router signature =
    let
        handler snapshot prevKey =
            Platform.sendToSelf router (SubResponse signature snapshot prevKey)

        ( config, path, query, event ) =
            signature
    in
        LowLevel.listen config path query event handler


stopListening : SubSignature -> Task Never ()
stopListening ( config, path, query, event ) =
    LowLevel.stopListening config path event query


handleSub :
    Platform.Router msg Msg
    -> Snapshot
    -> Maybe Key
    -> MySub msg
    -> Task Never ()
handleSub router snapshot prevKey sub =
    case sub of
        ValueSub _ toMsg ->
            Platform.sendToApp router (snapshot |> Snapshot.toValue |> toMsg)

        ListSub _ toMsg ->
            Platform.sendToApp router (snapshot |> Snapshot.toKeyValueList |> toMsg)

        ListItemSub _ toMsg ->
            case Snapshot.toKeyValue snapshot of
                Just keyValue ->
                    Platform.sendToApp router (toMsg keyValue)

                Nothing ->
                    Task.succeed ()

        ListItemAndPrevKeySub _ toMsg ->
            case Snapshot.toKeyValue snapshot of
                Just keyValue ->
                    Platform.sendToApp router (toMsg keyValue prevKey)

                Nothing ->
                    Task.succeed ()



-- EFFECT MANAGER


(&>) : Task x a -> Task x b -> Task x b
(&>) t1 t2 =
    Task.andThen (\_ -> t2) t1


init : Task Never (State msg)
init =
    Task.succeed []


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
    -> List (MySub msg)
    -> State msg
    -> Task Never (State msg)
onEffects router subs state =
    let
        signatures =
            List.map getSubSignature state

        nextSignatures =
            List.map getSubSignature subs

        stopListeners =
            diffSubSignatures nextSignatures signatures
                |> List.map stopListening
                |> Task.sequence

        startListeners =
            diffSubSignatures signatures nextSignatures
                |> List.map (listen router)
                |> Task.sequence
    in
        stopListeners
            &> startListeners
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
                |> List.filter (getSubSignature >> (==) signature)
                |> List.map (handleSub router snapshot prevKey)
                |> Task.sequence
                |> Task.andThen (\_ -> Task.succeed state)
