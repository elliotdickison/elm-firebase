module Firebase
    exposing
        ( Error(..)
        , Event(..)
        , Order(..)
        , OrderFilter(..)
        , OrderLimit(..)
        , Config
        , Path
        )

import Json.Encode as Encode


-- TYPES


type alias Config =
    { name : String
    , apiKey : String
    , authDomain : String
    , databaseUrl : String
    , storageBucket : String
    , messagingSenderId : String
    }



-- TODO: Replace "OtherError" w/ actual possible errors


type Error
    = PermissionDenied
    | OtherError String


type alias Path =
    String


type Event
    = Change
    | ChildAdd
    | ChildChange
    | ChildRemove
    | ChildMove


type Order
    = DefaultOrder OrderLimit
    | OrderByKey OrderFilter OrderLimit
    | OrderByValue OrderFilter OrderLimit
    | OrderByChild Path OrderFilter OrderLimit


type OrderFilter
    = NoFilter
    | Matching Encode.Value
    | StartingAt Encode.Value
    | EndingAt Encode.Value
    | Between Encode.Value Encode.Value


type OrderLimit
    = NoLimit
    | First Int
    | Last Int
