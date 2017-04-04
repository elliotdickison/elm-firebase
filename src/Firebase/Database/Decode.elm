module Firebase.Database.Decode
    exposing
        ( value
        , keyValue
        , keyValueList
        )

import Json.Encode as Encode exposing (Value)
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
