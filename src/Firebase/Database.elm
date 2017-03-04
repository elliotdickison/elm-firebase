module Firebase.Database exposing (Path, Listener, Event(..), Error(..), set, get, listen, stop)

import Json.Encode as Encode
import Task exposing (Task)
import Firebase.App exposing (App)
import Native.Firebase


type alias Path =
    String


type Listener
    = Listener


type Event
    = Change
    | ChildAdd
    | ChildChange
    | ChildRemove
    | ChildMove



-- TODO: Get rid of "OtherError" and replace with explicit values


type Error
    = PermissionDenied
    | OtherError String


set : App -> Path -> Encode.Value -> Task Error ()
set =
    Native.Firebase.set


get : App -> Path -> Task Error Encode.Value
get =
    Native.Firebase.get


listen : App -> Path -> Event -> (Encode.Value -> Maybe String -> Task Never ()) -> Task Never Listener
listen =
    Native.Firebase.listen


stop : Listener -> Task Never ()
stop =
    Native.Firebase.stop
