module Firebase.Database.Snapshot
    exposing
        ( Snapshot
        , toKey
        , toValue
        , toKeyValue
        , toList
        , toKeyValueList
        )

import Native.Firebase.Database.Snapshot
import Json.Encode as Encode exposing (Value)


type Snapshot
    = Snapshot


toKey : Snapshot -> String
toKey =
    Native.Firebase.Database.Snapshot.toKey


toValue : Snapshot -> Maybe Value
toValue =
    Native.Firebase.Database.Snapshot.toValue


toList : Snapshot -> List Snapshot
toList =
    Native.Firebase.Database.Snapshot.toList


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
