module Main exposing (..)

import Html exposing (Html, h1, p, div, text, button)
import Html.Events exposing (onClick)
import Json.Encode as Encode exposing (Value)
import Json.Decode as Decode
import Firebase
import Firebase.Database as Database


type alias Model =
    { error : Maybe Database.Error
    , counter : Maybe Int
    }


type Msg
    = Add Int
    | AddComplete (Result Database.Error (Maybe Int))
    | Reset
    | ResetComplete (Result Database.Error ())
    | CounterUpdated (Result Database.Error (Maybe Int))


firebase : Firebase.App
firebase =
    Firebase.getApp
        { apiKey = "AIzaSyC6D2bQwHU61AaGabDTVQ531kyoiZ-aKZo"
        , authDomain = "elm-firebase.firebaseapp.com"
        , databaseUrl = "https://elm-firebase.firebaseio.com"
        , storageBucket = "elm-firebase.appspot.com"
        , messagingSenderId = "488262915403"
        }


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
    Model Nothing Nothing ! []


view : Model -> Html Msg
view model =
    div []
        [ h1 [] [ text "Counter" ]
        , p [] [ text "This example uses the `Database.update` function, which allows safe updates of remote data using Firebase's transaction feature. The update is applied to the existing value in the remote database, not the local model, so concurrent updates from different clients can be syncronized correctly." ]
        , viewCounter model
        , button [ onClick (Add 1) ] [ text "Increment" ]
        , button [ onClick (Add -1) ] [ text "Decrement" ]
        , button [ onClick Reset ] [ text "Reset" ]
        ]


viewCounter : Model -> Html Msg
viewCounter model =
    case model.error of
        Just error ->
            div [] [ text "error: ", error |> toString |> text ]

        Nothing ->
            div [] [ text "counter: ", model.counter |> Maybe.map toString |> Maybe.withDefault "loading..." |> text ]


decodeCounter : Value -> Result String Int
decodeCounter =
    Decode.decodeValue Decode.int


encodeCounter : Int -> Value
encodeCounter =
    Encode.int


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        Add amount ->
            model
                ! [ Database.update "counter" (updateCounter amount) decodeCounter encodeCounter
                        |> Database.attempt firebase AddComplete
                  ]

        AddComplete _ ->
            model ! []

        Reset ->
            model ! [ encodeCounter 0 |> Database.set "counter" |> Database.attempt firebase ResetComplete ]

        ResetComplete _ ->
            model ! []

        CounterUpdated result ->
            case result of
                Ok counter ->
                    { model | error = Nothing, counter = counter } ! []

                Err error ->
                    { model | error = Just error, counter = Nothing } ! []


updateCounter : Int -> Maybe Int -> Maybe Int
updateCounter amount currentValue =
    case currentValue of
        Just value ->
            Just (value + amount)

        Nothing ->
            Just amount


subscriptions : Model -> Sub Msg
subscriptions model =
    Database.changes "counter" decodeCounter
        |> Database.subscribe firebase CounterUpdated
