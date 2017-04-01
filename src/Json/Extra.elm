module Json.Extra exposing (mapMaybe)

import Json.Encode exposing (Value)


mapMaybe :
    (Value -> Result String a)
    -> (a -> Value)
    -> (Maybe a -> Maybe a)
    -> Maybe Value
    -> Result String (Maybe Value)
mapMaybe decode encode func value =
    case value of
        Just value ->
            decode value
                |> Result.map (Just >> func >> Maybe.map encode)

        Nothing ->
            Nothing |> func |> Maybe.map encode |> Ok
