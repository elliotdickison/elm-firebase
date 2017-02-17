module Main exposing (..)

import Html exposing (Html, div, text, button)
import Html.Events exposing (onClick)
import Json.Encode as Encode
import Json.Decode as Decode
import Firebase


type alias Model =
    { error : Maybe String
    , user : Maybe String
    }


type Msg
    = RequestSet
    | RequestGet
    | RequestGetComplete (Result Firebase.Error Encode.Value)
    | SetFailed Firebase.Error


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
    }
        ! [ Firebase.initialize
                { apiKey = "AIzaSyC6D2bQwHU61AaGabDTVQ531kyoiZ-aKZo"
                , authDomain = "elm-firebase.firebaseapp.com"
                , databaseUrl = "https://elm-firebase.firebaseio.com"
                , storageBucket = "elm-firebase.appspot.com"
                , messagingSenderId = "488262915403"
                }
          ]


view : Model -> Html Msg
view model =
    div []
        [ div [] [ text "error", model.error |> Maybe.withDefault "" |> text ]
        , div [] [ text "user", model.user |> Maybe.withDefault "" |> text ]
        , button [ onClick RequestSet ] [ text "Set!" ]
        , button [ onClick RequestGet ] [ text "Get!" ]
        ]


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        RequestSet ->
            { model | error = Nothing }
                ! [ Firebase.set "users/1" SetFailed (Encode.string "bob") ]

        RequestGet ->
            model ! [ Firebase.get "users/2" RequestGetComplete ]

        RequestGetComplete result ->
            case result of
                Ok value ->
                    case Decode.decodeValue Decode.string value of
                        Ok string ->
                            { model | error = Nothing, user = Just string } ! []

                        Err error ->
                            { model | error = Just error, user = Nothing } ! []

                Err error ->
                    { model | error = Just (toString error), user = Nothing } ! []

        SetFailed error ->
            { model | error = Just (toString error) }
                ! []


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none
