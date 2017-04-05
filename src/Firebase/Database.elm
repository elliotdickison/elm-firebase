effect module Firebase.Database
    where { subscription = MySub }
    exposing
        ( Error(..)
        , Query(..)
        , QueryFilter(..)
        , QueryLimit(..)
        , attempt
        , set
        , push
        , remove
        , map
        , get
        , getList
        , changes
        , listChanges
        , listItemAdditions
        , listItemChanges
        , listItemMoves
        , listItemRemovals
        )

import Firebase exposing (App)
import Firebase.Database.Snapshot as Snapshot exposing (Snapshot)
import Firebase.Database.Decode as Decode
import Task exposing (Task)
import Json.Encode as Encode exposing (Value)
import Task.Extra exposing ((&>))


-- TODO: wrap up the list APIs into a single listChanges function that
-- implements the listItem functions under the hood (which basically creates a
-- streaming API w/ much better performance)
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


set : String -> Value -> App -> Task Error ()
set path value app =
    Native.Firebase.set app path value


push : String -> Maybe Value -> App -> Task Error String
push path value app =
    Native.Firebase.push app path value


remove : String -> App -> Task Error ()
remove path app =
    Native.Firebase.remove app path


map :
    String
    -> (Maybe a -> Maybe a)
    -> (Value -> Result String a)
    -> (a -> Value)
    -> App
    -> Task Error (Maybe a)
map path func decode encode app =
    (Decode.value decode >> Result.map (func >> (Maybe.map encode)))
        |> Native.Firebase.map app path
        |> Task.map Snapshot.toValue
        |> Task.Extra.andThenDecodeMaybe decode
        |> Task.mapError UnexpectedValue


get : String -> (Value -> Result String a) -> App -> Task Error (Maybe a)
get path decode app =
    Native.Firebase.get app path Nothing
        |> Task.map Snapshot.toValue
        |> Task.Extra.andThenDecodeMaybe decode
        |> Task.mapError UnexpectedValue


getList :
    String
    -> Query
    -> (String -> Value -> Result String a)
    -> App
    -> Task Error (List a)
getList path query decode app =
    Native.Firebase.get app path (Just query)
        |> Task.map (Snapshot.toKeyValueList >> Decode.keyValueList decode)
        |> Task.andThen Task.Extra.fromResult
        |> Task.mapError UnexpectedValue


attempt : App -> (Result x a -> msg) -> (App -> Task x a) -> Cmd msg
attempt app toMsg toTask =
    Task.attempt toMsg (toTask app)


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
listItemAdditions =
    childAndPrevKeySub ChildAdded


listItemChanges :
    String
    -> Query
    -> (String -> Value -> Result String a)
    -> App
    -> (Result Error ( a, Maybe String ) -> msg)
    -> Sub msg
listItemChanges =
    childAndPrevKeySub ChildChanged


listItemMoves :
    String
    -> Query
    -> (String -> Value -> Result String a)
    -> App
    -> (Result Error ( a, Maybe String ) -> msg)
    -> Sub msg
listItemMoves =
    childAndPrevKeySub ChildMoved


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


childAndPrevKeySub :
    Event
    -> String
    -> Query
    -> (String -> Value -> Result String a)
    -> App
    -> (Result Error ( a, Maybe String ) -> msg)
    -> Sub msg
childAndPrevKeySub event path query decode app toMsg =
    let
        toDecodedMsg keyValue prevKey =
            keyValue
                |> Decode.keyValue decode
                |> Result.map (\value -> ( value, prevKey ))
                |> Result.mapError UnexpectedValue
                |> toMsg
    in
        subscription <|
            ChildAndPrevKeySub ( app, path, Just query, event ) toDecodedMsg


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
