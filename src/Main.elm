module Main exposing (..)

import Html exposing (Html, div, text, button)
import Html.Events exposing (onClick)
import Json.Encode as Json
import Firebase


type alias Model =
    { error : Maybe String }


type Msg
    = RequestSet
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
    { error = Nothing }
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
        [ model.error |> Maybe.withDefault "" |> text
        , button [ onClick RequestSet ] [ text "Set!" ]
        ]


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        RequestSet ->
            { model | error = Nothing }
                ! [ Firebase.set "users/1" SetFailed (Json.string "bob") ]

        SetFailed error ->
            { model | error = Just (toString error) }
                ! []


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none
