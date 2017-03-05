module Firebase exposing (Error(..), Event(..), Config, Path)

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
