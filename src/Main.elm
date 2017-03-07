module Main exposing (..)

import Html exposing (Html, div, text, button)
import Html.Events exposing (onClick)
import Json.Encode as Encode
import Json.Decode as Decode
import Firebase
import Firebase.Database as Database


type alias Model =
    { error : Maybe String
    , user : Maybe String
    , config : Firebase.Config
    }


type Msg
    = RequestSet
    | RequestGet
    | GetComplete (Result Firebase.Error Encode.Value)
    | SetFailed Firebase.Error
    | OnChange Encode.Value
    | OnChange2 Encode.Value


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
    , user = Nothing
    , config =
        { name = "example-app"
        , apiKey = "AIzaSyC6D2bQwHU61AaGabDTVQ531kyoiZ-aKZo"
        , authDomain = "elm-firebase.firebaseapp.com"
        , databaseUrl = "https://elm-firebase.firebaseio.com"
        , storageBucket = "elm-firebase.appspot.com"
        , messagingSenderId = "488262915403"
        }
    }
        ! []


view : Model -> Html Msg
view model =
    div []
        [ div [] [ text "error: ", model.error |> Maybe.withDefault "" |> text ]
        , div [] [ text "user: ", model.user |> Maybe.withDefault "" |> text ]
        , button [ onClick RequestSet ] [ text "Set!" ]
        , button [ onClick RequestGet ] [ text "Get!" ]
        ]


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        RequestSet ->
            { model | error = Nothing }
                ! [ Database.set model.config "user" SetFailed (Encode.string "bob4") ]

        SetFailed error ->
            { model | error = Just (toString error) } ! []

        RequestGet ->
            model ! [ Database.get model.config "user" GetComplete ]

        GetComplete result ->
            let
                decoded =
                    result
                        |> Result.mapError toString
                        |> Result.andThen (Decode.decodeValue Decode.string)
            in
                case decoded of
                    Ok value ->
                        { model | error = Nothing, user = Just value } ! []

                    Err error ->
                        { model | error = Just error, user = Nothing } ! []

        OnChange data ->
            case Decode.decodeValue Decode.string data of
                Ok string ->
                    { model | error = Nothing, user = Just string } ! []

                Err error ->
                    { model | error = Just error, user = Nothing } ! []

        OnChange2 data ->
            case Decode.decodeValue Decode.string data of
                Ok string ->
                    { model | error = Nothing, user = Just string } ! []

                Err error ->
                    { model | error = Just error, user = Nothing } ! []


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch
        [ Database.changes model.config "user" OnChange
        , Database.changes model.config "user" OnChange2
        ]
