module Firebase.Database exposing (Path, Listener, Event(..), Error(..), set, get, listen, stop)

import Json.Encode as Encode
import Task exposing (Task)
import Firebase.App exposing (Config)
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


set : Config -> Path -> Encode.Value -> Task Error ()
set =
    Native.Firebase.set


get : Config -> Path -> Task Error Encode.Value
get =
    Native.Firebase.get


listen : Config -> Path -> Event -> (Encode.Value -> Maybe String -> Task Never ()) -> Task Never Listener
listen =
    Native.Firebase.listen


stop : Listener -> Task Never ()
stop =
    Native.Firebase.stop
