module Firebase
    exposing
        ( Error(..)
        , Event(..)
        , Query(..)
        , QueryFilter(..)
        , QueryLimit(..)
        , Config
        , Path
        , Key
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


type alias Key =
    String


type Event
    = Change
    | ChildAdd
    | ChildChange
    | ChildRemove
    | ChildMove


type Query
    = OrderByKey QueryFilter QueryLimit
    | OrderByValue QueryFilter QueryLimit
    | OrderByChild Path QueryFilter QueryLimit


type QueryFilter
    = NoFilter
    | Matching Encode.Value
    | StartingAt Encode.Value
    | EndingAt Encode.Value
    | Between Encode.Value Encode.Value


type QueryLimit
    = NoLimit
    | First Int
    | Last Int
