module Firebase
    exposing
        ( App
        , Config
        , getApp
        )

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


getApp : Config -> App
getApp =
    Native.Firebase.getApp
