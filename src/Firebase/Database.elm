effect module Firebase.Database
    where { subscription = MySub }
    exposing
        ( Error(..)
        , Query(..)
        , QueryFilter(..)
        , QueryLimit(..)
        , attempt
        , set
        , get
        , getList
        , value
        , list
        )

import Firebase exposing (App)
import Firebase.Database.Snapshot as Snapshot exposing (Snapshot)
import Task exposing (Task)
import Json.Encode as Encode exposing (Value)
import Result.Extra


resultToTask : Result x a -> Task x a
resultToTask result =
    case result of
        Ok a ->
            Task.succeed a

        Err x ->
            Task.fail x



--andThenDecode : (a -> Result x b) -> Task x a -> Task x b
--andThenDecode decode =
--    Task.andThen (decode >> Result.Extra.toTask)
--andThenDecodeMaybe : (a -> Result x b) -> Task x a -> Task x b
--andThenDecodeMaybe decode =
--    Task.andThen (decode >> Result.Extra.toTask)
-- TODO: Consider including encoders/decoders in the API to simplify boilerplate
-- on the user end. Also, use the Encoder/Decoder types
-- TODO: wrap up the list APIs into a single listChanges function that
-- implements the listItem functions under the hood (which basically creates a
-- streaming API w/ much better performance)
-- set : App -> String -> (Result Error () -> msg) -> Value -> Cmd msg
-- map : App -> String -> (Result Error (Maybe Value) -> msg) -> (Maybe Value -> Maybe Value) -> Cmd msg
-- merge : App -> String -> (Result Error Value -> msg) -> Value -> Cmd msg
-- remove : App -> String -> (Result Error () -> msg) -> Cmd msg
-- push : App -> String -> (Result Error Key -> msg) -> Maybe Value -> Cmd msg
-- get : App -> String -> (Result Error (Maybe Value) -> msg) -> Cmd msg
-- getList : App -> String -> (Result Error (List (String, Value)) -> msg) -> Query -> Cmd msg
-- value : App -> String -> (Value -> msg) -> Sub msg
-- list : App -> String -> (List (String, Value) -> msg) -> Query -> Sub msg
-- stream : App -> String -> (List (String, Value) -> msg) -> Query -> Sub msg
-- listItemChanges : App -> String -> ((String, Value) -> Maybe Key -> msg) -> Query -> Sub msg
-- listItemAdditions : App -> String -> ((String, Value) -> Maybe Key -> msg) -> Query -> Sub msg
-- listItemMoves : App -> String -> ((String, Value) -> Maybe Key -> msg) -> Query -> Sub msg
-- listItemRemovals : App -> String -> ((String, Value) -> msg) -> Query -> Sub msg


type Event
    = Change
    | ChildAdd
    | ChildChange
    | ChildRemove
    | ChildMove



-- TODO: Replace "OtherError" w/ actual possible errors


type Error
    = PermissionDenied
    | UnexpectedValue String
    | OtherError String


type Query
    = OrderByKey QueryFilter QueryLimit
    | OrderByValue QueryFilter QueryLimit
    | OrderByChild String QueryFilter QueryLimit


type QueryFilter
    = NoFilter
    | Matching Value
    | StartingAt Value
    | EndingAt Value
    | Between Value Value


type QueryLimit
    = NoLimit
    | First Int
    | Last Int


type alias SubSignature =
    ( App, String, Maybe Query, Event )


type MySub msg
    = ValueSub SubSignature (Maybe Value -> msg)
    | ListSub SubSignature (List ( String, Value ) -> msg)
    | ListItemSub SubSignature (( String, Value ) -> msg)
    | ListItemAndPrevKeySub SubSignature (( String, Value ) -> Maybe String -> msg)


type alias State msg =
    List (MySub msg)


type Msg
    = SubResponse SubSignature Snapshot (Maybe String)



-- API


attempt : App -> (Result x a -> msg) -> (App -> Task x a) -> Cmd msg
attempt app toMsg toTask =
    Task.attempt toMsg (toTask app)


set : String -> Value -> App -> Task Error ()
set path value app =
    Native.Firebase.set app path value


push : String -> Maybe Value -> App -> Task Error String
push path value app =
    Native.Firebase.push app path value


map : (Value -> Result String a) -> (a -> Value) -> String -> (Maybe a -> Maybe a) -> App -> Task Error (Maybe a)
map decode encode path func app =
    Native.Firebase.map app path (mapValue decode encode func)
        |> Task.map Snapshot.toValue
        |> Task.andThen
            (\value ->
                case value of
                    Just value ->
                        value
                            |> decode
                            |> Result.mapError UnexpectedValue
                            |> Result.map Just
                            |> resultToTask

                    Nothing ->
                        Task.succeed Nothing
            )


mapValue : (Value -> Result String a) -> (a -> Value) -> (Maybe a -> Maybe a) -> Maybe Value -> Result String (Maybe Value)
mapValue decode encode func value =
    case value of
        Just value ->
            decode value
                |> Result.map (Just >> func >> Maybe.map encode)

        Nothing ->
            Nothing |> func |> Maybe.map encode |> Ok


get : (Value -> Result String a) -> String -> App -> Task Error (Maybe a)
get decode path app =
    Native.Firebase.get app path Nothing
        |> Task.map Snapshot.toValue
        |> Task.andThen
            (\value ->
                case value of
                    Just value ->
                        value
                            |> decode
                            |> Result.mapError UnexpectedValue
                            |> Result.map Just
                            |> resultToTask

                    Nothing ->
                        Task.succeed Nothing
            )


getList : (String -> Value -> Result String a) -> String -> Query -> App -> Task Error (List a)
getList decode path query app =
    Native.Firebase.get app path (Just query)
        |> Task.andThen (Snapshot.toKeyValueList >> (List.map (\( key, value ) -> decode key value)) >> Result.Extra.combine >> Result.mapError UnexpectedValue >> resultToTask)


value : App -> String -> (Maybe Value -> msg) -> Sub msg
value app path toMsg =
    subscription (ValueSub ( app, path, Nothing, Change ) toMsg)


list : App -> String -> Query -> (List ( String, Value ) -> msg) -> Sub msg
list app path query toMsg =
    subscription (ListSub ( app, path, Just query, Change ) toMsg)



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

        ( app, path, query, event ) =
            signature
    in
        Native.Firebase.listen app path query event handler


stopListening : SubSignature -> Task Never ()
stopListening ( app, path, query, event ) =
    Native.Firebase.stopListening app path query event


handleSub :
    Platform.Router msg Msg
    -> Snapshot
    -> Maybe String
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
