module Main exposing (..)

import Html exposing (Html, div, text, button)
import Html.Events exposing (onClick)
import Firebase


type alias Model =
    { int : Int
    , app : Firebase.App
    }


type Msg
    = RequestInt
    | ReceiveInt Int


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
    { int = 1
    , app =
        Firebase.initializeApp
            { apiKey = "AIzaSyC6D2bQwHU61AaGabDTVQ531kyoiZ-aKZo"
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
        [ model.int |> toString |> text
        , button [ onClick RequestInt ] [ text "Generate!" ]
        ]


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        RequestInt ->
            ( model, Firebase.generateInt ReceiveInt )

        ReceiveInt int ->
            ( { model | int = int }, Cmd.none )


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none
