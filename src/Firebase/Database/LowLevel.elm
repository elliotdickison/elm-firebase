module Firebase.Database.LowLevel exposing (set, get, listen, stop)

import Json.Encode as Encode
import Task exposing (Task)
import Firebase exposing (Config, Path, Error, Event)
import Native.Firebase


set : Config -> Path -> Encode.Value -> Task Error ()
set =
    Native.Firebase.set


get : Config -> Path -> Task Error Encode.Value
get =
    Native.Firebase.get


listen : Config -> Path -> Event -> (Encode.Value -> Maybe String -> Task Never ()) -> Task Never ()
listen =
    Native.Firebase.listen


stop : Config -> Path -> Event -> Task Never ()
stop =
    Native.Firebase.stop
