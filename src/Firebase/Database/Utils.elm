module Firebase.Database.Utils exposing (decodeKeyValueList, mapValue)

import Result.Extra
import Json.Encode exposing (Value)


decodeKeyValueList :
    (String -> Value -> Result String a)
    -> List ( String, Value )
    -> Result String (List a)
decodeKeyValueList decode list =
    list
        |> List.map (\( key, value ) -> decode key value)
        |> Result.Extra.combine


mapValue :
    (Value -> Result String a)
    -> (a -> Value)
    -> (Maybe a -> Maybe a)
    -> Maybe Value
    -> Result String (Maybe Value)
mapValue decode encode func value =
    case value of
        Just value ->
            decode value
                |> Result.map (Just >> func >> Maybe.map encode)

        Nothing ->
            Nothing |> func |> Maybe.map encode |> Ok
