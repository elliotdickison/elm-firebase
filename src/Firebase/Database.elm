module Firebase.Database exposing (Path, Error(..), set, get)

import Json.Encode as Encode
import Task exposing (Task)
import Firebase.App exposing (App)
import Native.Firebase


type alias Path =
    String


type Error
    = PermissionError
    | ConfigError String
    | OtherError String


set : App -> Path -> Encode.Value -> Task Error ()
set =
    Native.Firebase.set


get : App -> Path -> Task Error Encode.Value
get =
    Native.Firebase.get
