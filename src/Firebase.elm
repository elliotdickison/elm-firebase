module Firebase
    exposing
        ( Error(..)
        , Query(..)
        , QueryFilter(..)
        , QueryLimit(..)
        , Config
        , Path
        , Key
        , KeyValue
        )

import Json.Encode as Encode exposing (Value)


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


type alias KeyValue =
    ( Key, Value )


type Query
    = OrderByKey QueryFilter QueryLimit
    | OrderByValue QueryFilter QueryLimit
    | OrderByChild Path QueryFilter QueryLimit


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
