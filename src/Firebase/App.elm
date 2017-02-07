module Firebase.App exposing (App, Config, initialize)

import Task exposing (Task)
import Native.Firebase


type App
    = App


type alias Config =
    { apiKey : String
    , authDomain : String
    , databaseUrl : String
    , storageBucket : String
    , messagingSenderId : String
    }


initialize : Config -> Task Never App
initialize =
    Native.Firebase.initialize
