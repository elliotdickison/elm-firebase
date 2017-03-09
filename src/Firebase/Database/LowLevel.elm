module Firebase.Database.LowLevel exposing (set, get, listen, stopListening)

import Json.Encode as Encode
import Task exposing (Task)
import Firebase exposing (Config, Path, Error, Event)
import Native.Firebase


set : Config -> Path -> Encode.Value -> Task Error Encode.Value
set =
    Native.Firebase.set


get : Config -> Path -> Task Error Encode.Value
get =
    Native.Firebase.get


listen : Config -> Path -> Event -> (Encode.Value -> Maybe String -> Task Never ()) -> Task Never ()
listen config path event handler =
    Native.Firebase.listen config path event handler


stopListening : Config -> Path -> Event -> Task Never ()
stopListening config path event =
    Native.Firebase.stopListening config path event
