effect module Firebase.Database
    where { subscription = MySub }
    exposing
        ( Error(..)
        , Query(..)
        , Filter(..)
        , Limit(..)
        , attempt
        , subscribe
        , set
        , push
        , remove
        , update
        , get
        , getList
        , changes
        , listChanges
        , listItemAdditions
        , listItemChanges
        , listItemMoves
        , listItemRemovals
        )

import Native.Firebase.Database
import Firebase exposing (App)
import Firebase.Database.Snapshot as Snapshot exposing (Snapshot)
import Firebase.Database.Decode as Decode
import Firebase.Utils.Task as TaskUtils exposing ((&>))
import Task exposing (Task)
import Json.Encode as Encode exposing (Value)


type Error
    = PermissionDenied
    | UnexpectedValue String
    | OtherError String


type Query
    = OrderByKey Filter Limit
    | OrderByValue Filter Limit
    | OrderByChild String Filter Limit


type Filter
    = NoFilter
    | Matching Value
    | StartingAt Value
    | EndingAt Value
    | Between Value Value


type Limit
    = NoLimit
    | First Int
    | Last Int


type Event
    = ValueChanged
    | ChildAdded
    | ChildChanged
    | ChildRemoved
    | ChildMoved


type alias SubSignature =
    ( App, String, Maybe Query, Event )


type MySub msg
    = ValueSub SubSignature (Maybe Value -> msg)
    | ListSub SubSignature (List ( String, Value ) -> msg)
    | ChildSub SubSignature (( String, Value ) -> msg)
    | ChildAndPrevKeySub SubSignature (( String, Value ) -> Maybe String -> msg)


type alias State msg =
    List (MySub msg)


type Msg
    = SubResponse SubSignature Snapshot (Maybe String)



-- API


attempt : App -> (Result x a -> msg) -> (App -> Task x a) -> Cmd msg
attempt app toMsg toTask =
    Task.attempt toMsg (toTask app)


subscribe : App -> (a -> msg) -> (App -> (a -> msg) -> Sub msg) -> Sub msg
subscribe app toMsg toSub =
    toSub app toMsg


set : String -> Value -> App -> Task Error ()
set path value app =
    Native.Firebase.Database.set app path value


push : String -> Maybe Value -> App -> Task Error String
push path value app =
    Native.Firebase.Database.push app path value


remove : String -> App -> Task Error ()
remove path app =
    Native.Firebase.Database.remove app path


update :
    String
    -> (Maybe a -> Maybe a)
    -> (Value -> Result String a)
    -> (a -> Value)
    -> App
    -> Task Error (Maybe a)
update path func decode encode app =
    (Decode.value decode >> Result.map (func >> (Maybe.map encode)))
        |> Native.Firebase.Database.update app path
        |> Task.map Snapshot.toValue
        |> Decode.andThenDecodeMaybe decode
        |> Task.mapError UnexpectedValue


get : String -> (Value -> Result String a) -> App -> Task Error (Maybe a)
get path decode app =
    Native.Firebase.Database.get app path Nothing
        |> Task.map Snapshot.toValue
        |> Decode.andThenDecodeMaybe decode
        |> Task.mapError UnexpectedValue


getList :
    String
    -> Query
    -> (String -> Value -> Result String a)
    -> App
    -> Task Error (List a)
getList path query decode app =
    Native.Firebase.Database.get app path (Just query)
        |> Task.map (Snapshot.toKeyValueList >> Decode.keyValueList decode)
        |> Task.andThen TaskUtils.fromResult
        |> Task.mapError UnexpectedValue


changes :
    String
    -> (Value -> Result String a)
    -> App
    -> (Result Error (Maybe a) -> msg)
    -> Sub msg
changes path decode app toMsg =
    subscription <|
        ValueSub
            ( app, path, Nothing, ValueChanged )
            (Decode.value decode >> Result.mapError UnexpectedValue >> toMsg)


listChanges :
    String
    -> Query
    -> (String -> Value -> Result String a)
    -> App
    -> (Result Error (List a) -> msg)
    -> Sub msg
listChanges path query decode app toMsg =
    subscription <|
        ListSub
            ( app, path, Just query, ValueChanged )
            (Decode.keyValueList decode >> Result.mapError UnexpectedValue >> toMsg)


listItemAdditions :
    String
    -> Query
    -> (String -> Value -> Result String a)
    -> App
    -> (Result Error ( a, Maybe String ) -> msg)
    -> Sub msg
listItemAdditions path query decode app toMsg =
    subscription <|
        ChildAndPrevKeySub
            ( app, path, Just query, ChildAdded )
            (keyValueAndPrevKeyToMsg decode toMsg)


listItemChanges :
    String
    -> Query
    -> (String -> Value -> Result String a)
    -> App
    -> (Result Error ( a, Maybe String ) -> msg)
    -> Sub msg
listItemChanges path query decode app toMsg =
    subscription <|
        ChildAndPrevKeySub
            ( app, path, Just query, ChildChanged )
            (keyValueAndPrevKeyToMsg decode toMsg)


listItemMoves :
    String
    -> Query
    -> (String -> Value -> Result String a)
    -> App
    -> (Result Error ( a, Maybe String ) -> msg)
    -> Sub msg
listItemMoves path query decode app toMsg =
    subscription <|
        ChildAndPrevKeySub
            ( app, path, Just query, ChildMoved )
            (keyValueAndPrevKeyToMsg decode toMsg)


listItemRemovals :
    String
    -> Query
    -> (String -> Value -> Result String a)
    -> App
    -> (Result Error a -> msg)
    -> Sub msg
listItemRemovals path query decode app toMsg =
    subscription <|
        ChildSub
            ( app, path, Just query, ChildRemoved )
            (Decode.keyValue decode >> Result.mapError UnexpectedValue >> toMsg)



-- HELPERS


keyValueAndPrevKeyToMsg :
    (String -> Value -> Result String a)
    -> (Result Error ( a, Maybe String ) -> msg)
    -> ( String, Value )
    -> Maybe String
    -> msg
keyValueAndPrevKeyToMsg decode toMsg keyValue prevKey =
    keyValue
        |> Decode.keyValue decode
        |> Result.map (\value -> ( value, prevKey ))
        |> Result.mapError UnexpectedValue
        |> toMsg


getSubSignature : MySub msg -> SubSignature
getSubSignature sub =
    case sub of
        ValueSub signature _ ->
            signature

        ListSub signature _ ->
            signature

        ChildSub signature _ ->
            signature

        ChildAndPrevKeySub signature _ ->
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


startListening : Platform.Router msg Msg -> SubSignature -> Task Never ()
startListening router signature =
    let
        handler snapshot prevKey =
            Platform.sendToSelf router (SubResponse signature snapshot prevKey)

        ( app, path, query, event ) =
            signature
    in
        Native.Firebase.Database.startListening app path query event handler


stopListening : SubSignature -> Task Never ()
stopListening ( app, path, query, event ) =
    Native.Firebase.Database.stopListening app path query event


handleSub :
    Platform.Router msg Msg
    -> Snapshot
    -> Maybe String
    -> MySub msg
    -> Task Never ()
handleSub router snapshot prevKey sub =
    case sub of
        ValueSub _ toMsg ->
            snapshot |> Snapshot.toValue |> toMsg |> Platform.sendToApp router

        ListSub _ toMsg ->
            snapshot
                |> Snapshot.toKeyValueList
                |> toMsg
                |> Platform.sendToApp router

        ChildSub _ toMsg ->
            case Snapshot.toKeyValue snapshot of
                Just keyValue ->
                    keyValue |> toMsg |> Platform.sendToApp router

                Nothing ->
                    Task.succeed ()

        ChildAndPrevKeySub _ toMsg ->
            case Snapshot.toKeyValue snapshot of
                Just keyValue ->
                    toMsg keyValue prevKey |> Platform.sendToApp router

                Nothing ->
                    Task.succeed ()



-- EFFECT MANAGER


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

        ChildSub signature toMsg ->
            ChildSub signature (toMsg >> f)

        ChildAndPrevKeySub signature toMsg ->
            ChildAndPrevKeySub signature (\a -> toMsg a >> f)


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
                |> List.map (startListening router)
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
