module Firebase.Database exposing (Path, Error(..), set)

import Json.Encode as Json
import Task exposing (Task)
import Firebase.App exposing (App)
import Native.Firebase


type alias Path =
    String


type Error
    = PermissionError
    | ConfigError String
    | OtherError String


set : App -> Path -> Json.Value -> Task Error ()
set =
    Native.Firebase.set
