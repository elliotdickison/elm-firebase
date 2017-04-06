module Firebase.Database.Decode
    exposing
        ( value
        , keyValue
        , keyValueList
        , andThenDecode
        , andThenDecodeMaybe
        )

import Task exposing (Task)
import Firebase.Utils.Task as TaskUtils
import Json.Encode exposing (Value)
import Result.Extra
import Maybe.Extra


value :
    (Value -> Result String a)
    -> Maybe Value
    -> Result String (Maybe a)
value decode =
    Maybe.Extra.unwrap (Ok Nothing) (decode >> Result.map Just)


keyValue :
    (String -> Value -> Result String a)
    -> ( String, Value )
    -> Result String a
keyValue decode ( key, value ) =
    decode key value


keyValueList :
    (String -> Value -> Result String a)
    -> List ( String, Value )
    -> Result String (List a)
keyValueList decode =
    List.map (keyValue decode) >> Result.Extra.combine


andThenDecode : (a -> Result x b) -> Task x a -> Task x b
andThenDecode decode =
    Task.andThen (decode >> TaskUtils.fromResult)


andThenDecodeMaybe : (a -> Result x b) -> Task x (Maybe a) -> Task x (Maybe b)
andThenDecodeMaybe decode =
    Task.andThen (Maybe.Extra.unwrap (Task.succeed Nothing) (decode >> TaskUtils.fromResult >> Task.map Just))
