module Main exposing (..)

import Html exposing (Html, div, text, button)
import Html.Events exposing (onClick)
import Json.Encode as Encode exposing (Value)
import Json.Decode as Decode
import Firebase
import Firebase.Database as Database
    exposing
        ( Query(..)
        , QueryFilter(..)
        , QueryLimit(..)
        )


type alias Model =
    { error : Maybe String
    , users : List String
    }


type Msg
    = RequestUsers
    | UserRequestCompleted (Result Database.Error (List String))
    | UsersChanged (List ( String, Value ))


firebase : Firebase.App
firebase =
    Firebase.getApp
        { apiKey = "AIzaSyC6D2bQwHU61AaGabDTVQ531kyoiZ-aKZo"
        , authDomain = "elm-firebase.firebaseapp.com"
        , databaseUrl = "https://elm-firebase.firebaseio.com"
        , storageBucket = "elm-firebase.appspot.com"
        , messagingSenderId = "488262915403"
        }


decodeUser : String -> Value -> Result String String
decodeUser key value =
    Decode.decodeValue Decode.string value


decodeUsers : Value -> Result String (List String)
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
            model
                ! [ Database.getList decodeUser "users" (OrderByValue NoFilter NoLimit)
                        |> Database.attempt firebase UserRequestCompleted
                  ]

        UserRequestCompleted result ->
            case result of
                Ok value ->
                    { model | error = Nothing, users = value } ! []

                Err error ->
                    { model | error = Just (toString error), users = [] } ! []

        UsersChanged value ->
            { model | error = Nothing, users = value |> List.map toString } ! []


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch [ Database.list firebase "users" (OrderByValue NoFilter NoLimit) UsersChanged ]
