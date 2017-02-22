module Firebase.Database exposing (Path, Error(..), set, get)

import Json.Encode as Encode
import Task exposing (Task)
import Firebase.App exposing (App)
import Native.Firebase


type alias Path =
    String


type Error
    = PermissionDenied
    | OtherError String


type Event
    = Change
    | ChildAdd
    | ChildChange
    | ChildRemove
    | ChildMove


set : App -> Path -> Encode.Value -> Task Error ()
set =
    Native.Firebase.set


get : App -> Path -> Task Error Encode.Value
get =
    Native.Firebase.get


on : App -> Path -> Event -> Task Never ()
on =
    Native.Firebase.on
