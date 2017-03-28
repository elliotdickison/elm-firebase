module Main exposing (..)

import Html exposing (Html, div, text, button)
import Html.Events exposing (onClick)
import Json.Encode as Encode
import Json.Decode as Decode
import Firebase
import Firebase.Database as Database


type alias Model =
    { error : Maybe String
    , users : List String
    }


type Msg
    = RequestUsers
    | UserRequestSucceeded (Result Firebase.Error (List Firebase.KeyValue))
    | UsersChanged (Maybe Encode.Value)


config : Firebase.Config
config =
    { name = "example-app"
    , apiKey = "AIzaSyC6D2bQwHU61AaGabDTVQ531kyoiZ-aKZo"
    , authDomain = "elm-firebase.firebaseapp.com"
    , databaseUrl = "https://elm-firebase.firebaseio.com"
    , storageBucket = "elm-firebase.appspot.com"
    , messagingSenderId = "488262915403"
    }


decodeUsers : Encode.Value -> Result String (List String)
decodeUsers =
    Decode.decodeValue (Decode.list Decode.string)


main : Program Never Model Msg
main =
    Html.program
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        }


init : ( Model, Cmd Msg )
init =
    { error = Nothing
    , users = []
    }
        ! []


view : Model -> Html Msg
view model =
    div []
        [ div [] [ text "error: ", model.error |> Maybe.withDefault "" |> text ]
        , div [] [ text "users: ", model.users |> String.join ", " |> text ]
        , button [ onClick RequestUsers ] [ text "Get users!" ]
        ]


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        RequestUsers ->
            model ! [ Database.getList config UserRequestSucceeded "users" (Firebase.OrderByValue Firebase.NoFilter Firebase.NoLimit) ]

        UserRequestSucceeded result ->
            let
                decoded =
                    result
                        |> Result.mapError toString
                        |> Result.map (List.map toString)
            in
                case decoded of
                    Ok value ->
                        { model | error = Nothing, users = value } ! []

                    Err error ->
                        { model | error = Just error, users = [] } ! []

        UsersChanged value ->
            case value of
                Just value ->
                    case (decodeUsers value) of
                        Ok value ->
                            { model | error = Nothing, users = value } ! []

                        Err error ->
                            { model | error = Just error, users = [] } ! []

                Nothing ->
                    { model | error = Nothing, users = [] } ! []


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch [ Database.changes config UsersChanged "users" ]
