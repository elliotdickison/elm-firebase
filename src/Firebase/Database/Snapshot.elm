module Firebase.Database.Snapshot
    exposing
        ( Snapshot
        , toKey
        , toValue
        , toKeyValue
        , toList
        , toKeyValueList
        )

import Firebase exposing (Key, KeyValue)
import Json.Encode as Encode exposing (Value)


type Snapshot
    = Snapshot


toKey : Snapshot -> Key
toKey =
    Native.Firebase.snapshotToKey


toValue : Snapshot -> Maybe Value
toValue =
    Native.Firebase.snapshotToValue


toList : Snapshot -> List Snapshot
toList =
    Native.Firebase.snapshotToList


toKeyValue : Snapshot -> Maybe KeyValue
toKeyValue snapshot =
    snapshot
        |> toValue
        |> Maybe.map (\value -> ( toKey snapshot, value ))


toKeyValueList : Snapshot -> List KeyValue
toKeyValueList snapshot =
    snapshot
        |> toList
        |> List.filterMap toKeyValue
