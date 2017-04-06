module Firebase.Utils.Task exposing ((&>), fromResult)

import Task exposing (Task)


(&>) : Task x a -> Task x b -> Task x b
(&>) t1 t2 =
    Task.andThen (\_ -> t2) t1


fromResult : Result x a -> Task x a
fromResult result =
    case result of
        Ok a ->
            Task.succeed a

        Err x ->
            Task.fail x
