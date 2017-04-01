module Firebase.Database.Snapshot
    exposing
        ( Snapshot
        , toKey
        , toValue
        , toKeyValue
        , toList
        , toKeyValueList
        )

import Native.Firebase
import Json.Encode as Encode exposing (Value)


type Snapshot
    = Snapshot


toKey : Snapshot -> String
toKey =
    Native.Firebase.snapshotToKey


toValue : Snapshot -> Maybe Value
toValue =
    Native.Firebase.snapshotToValue


toList : Snapshot -> List Snapshot
toList =
    Native.Firebase.snapshotToList


toKeyValue : Snapshot -> Maybe ( String, Value )
toKeyValue snapshot =
    snapshot
        |> toValue
        |> Maybe.map (\value -> ( toKey snapshot, value ))


toKeyValueList : Snapshot -> List ( String, Value )
toKeyValueList snapshot =
    snapshot
        |> toList
        |> List.filterMap toKeyValue
