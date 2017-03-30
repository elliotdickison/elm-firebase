module Firebase.Database.LowLevel
    exposing
        ( Event(..)
        , set
        , map
        , get
        , listen
        , stopListening
        )

import Firebase
    exposing
        ( Config
        , Path
        , Query
        , Key
        , KeyValue
        , Error
        )
import Firebase.Database.Snapshot exposing (Snapshot)
import Native.Firebase
import Task exposing (Task)
import Json.Encode as Encode exposing (Value)


type Event
    = Change
    | ChildAdd
    | ChildChange
    | ChildRemove
    | ChildMove



-- WRITING DATA


set : Config -> Path -> Value -> Task Error ()
set =
    Native.Firebase.set


map : Config -> Path -> (Maybe Value -> Maybe Value) -> Task Error Snapshot
map =
    Native.Firebase.map



-- READING DATA


get : Config -> Path -> Maybe Query -> Task Error Snapshot
get =
    Native.Firebase.get



-- SUBSCRIBING TO DATA


listen :
    Config
    -> Path
    -> Maybe Query
    -> Event
    -> (Snapshot -> Maybe Key -> Task Never ())
    -> Task Never ()
listen =
    Native.Firebase.listen


stopListening : Config -> Path -> Event -> Maybe Query -> Task Never ()
stopListening =
    Native.Firebase.stopListening
