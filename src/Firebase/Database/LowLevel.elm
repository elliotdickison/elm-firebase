module Firebase.Database.LowLevel exposing (set, get, getList, listen, stopListening)

import Json.Encode as Encode
import Task exposing (Task)
import Firebase exposing (Config, Path, Query, Key, Error, Event)
import Native.Firebase


-- WRITING DATA


set : Config -> Path -> Encode.Value -> Task Error Encode.Value
set =
    Native.Firebase.set



-- READING DATA


get : Config -> Path -> Task Error Encode.Value
get =
    Native.Firebase.get


getList : Config -> Path -> Query -> Task Error (List ( Key, Encode.Value ))
getList =
    Native.Firebase.getList



-- SUBSCRIBING TO DATA


listen : Config -> Path -> Event -> (Encode.Value -> Maybe Key -> Task Never ()) -> Task Never ()
listen =
    Native.Firebase.listen


stopListening : Config -> Path -> Event -> Task Never ()
stopListening =
    Native.Firebase.stopListening
