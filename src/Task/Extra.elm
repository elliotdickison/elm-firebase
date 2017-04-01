module Task.Extra exposing (fromResult, andThenDecode, andThenDecodeMaybe)

import Task exposing (Task)


fromResult : Result x a -> Task x a
fromResult result =
    case result of
        Ok a ->
            Task.succeed a

        Err x ->
            Task.fail x


andThenDecode : (a -> Result x b) -> Task x a -> Task x b
andThenDecode decode =
    Task.andThen (decode >> fromResult)


andThenDecodeMaybe : (a -> Result x b) -> Task x (Maybe a) -> Task x (Maybe b)
andThenDecodeMaybe decode =
    Task.andThen ((Maybe.map (decode >> fromResult >> Task.map Just)) >> (Maybe.withDefault (Task.succeed Nothing)))
