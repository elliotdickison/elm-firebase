module Main exposing (..)

import Html exposing (Html, h1, p, div, text, button, input, form)
import Html.Events exposing (onClick, onSubmit, onInput)
import Html.Attributes exposing (value, type_)
import Json.Encode as Encode exposing (Value)
import Json.Decode as Decode
import Firebase
import Firebase.Database as Database
    exposing
        ( Query(..)
        , Filter(..)
        , Limit(..)
        )


type alias Item =
    { id : String
    , description : String
    }


type alias Model =
    { error : Maybe Database.Error
    , items : List Item
    , form : String
    }


type Msg
    = ItemsUpdated (Result Database.Error (List Item))
    | AddItem
    | AddItemComplete (Result Database.Error String)
    | RemoveItem String
    | RemoveItemComplete (Result Database.Error ())
    | UpdateForm String


firebase : Firebase.App
firebase =
    Firebase.getApp
        { apiKey = ""
        , authDomain = ""
        , databaseUrl = ""
        , storageBucket = ""
        , messagingSenderId = ""
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
    Model Nothing [] "" ! []


view : Model -> Html Msg
view model =
    div []
        (List.append
            [ h1 [] [ text "List" ]
            , p [] [ text "This example shows the basics of adding, removing, and fetching list items." ]
            , div [] (List.map viewItem model.items)
            , form [ onSubmit AddItem ]
                [ input [ value model.form, onInput UpdateForm ] []
                , button [ type_ "submit" ] [ text "Add" ]
                ]
            ]
            (viewError model.error)
        )


viewError : Maybe Database.Error -> List (Html Msg)
viewError error =
    case error of
        Just error ->
            [ div [] [ text "error: ", error |> toString |> text ] ]

        Nothing ->
            []


viewItem : Item -> Html Msg
viewItem todo =
    div []
        [ text todo.description
        , button [ onClick (RemoveItem todo.id) ] [ text "Remove" ]
        ]


decodeItem : String -> Value -> Result String Item
decodeItem id value =
    value
        |> Decode.decodeValue Decode.string
        |> Result.map (Item id)


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        ItemsUpdated result ->
            case result of
                Ok items ->
                    { model | items = items } ! []

                Err error ->
                    { model | error = Just error } ! []

        AddItem ->
            { model | form = "" }
                ! [ Database.push "items" (model.form |> Encode.string |> Just)
                        |> Database.attempt firebase AddItemComplete
                  ]

        AddItemComplete result ->
            case result of
                Err error ->
                    { model | error = Just error } ! []

                _ ->
                    model ! []

        RemoveItem id ->
            model
                ! [ Database.remove ("items/" ++ id)
                        |> Database.attempt firebase RemoveItemComplete
                  ]

        RemoveItemComplete result ->
            case result of
                Err error ->
                    { model | error = Just error } ! []

                _ ->
                    model ! []

        UpdateForm value ->
            { model | form = value } ! []


subscriptions : Model -> Sub Msg
subscriptions model =
    Database.listChanges "items" (OrderByKey NoFilter NoLimit) decodeItem
        |> Database.subscribe firebase ItemsUpdated
