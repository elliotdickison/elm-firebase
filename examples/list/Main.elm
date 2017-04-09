module Main exposing (..)

import Html exposing (Html, h1, p, div, text, button, input)
import Html.Events exposing (onClick, onInput)
import Html.Attributes exposing (value)
import Json.Encode as Encode exposing (Value)
import Json.Decode as Decode
import Firebase
import Firebase.Database as Database
    exposing
        ( Query(..)
        , Filter(..)
        , Limit(..)
        )


type alias Todo =
    { id : String
    , description : String
    }


type alias Model =
    { error : Maybe Database.Error
    , todos : List Todo
    , form : String
    }


type Msg
    = TodosUpdated (Result Database.Error (List Todo))
    | AddTodo
    | AddTodoComplete (Result Database.Error String)
    | RemoveTodo String
    | RemoveTodoComplete (Result Database.Error ())
    | UpdateForm String


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
    Model Nothing [] "" ! []


view : Model -> Html Msg
view model =
    div []
        (List.append
            [ h1 [] [ text "List" ]
            , p [] [ text "This example shows the basics of adding, removing, and fetching list items." ]
            , div [] (List.map viewTodo model.todos)
            , input [ value model.form, onInput UpdateForm ] []
            , button [ onClick AddTodo ] [ text "Add" ]
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


viewTodo : Todo -> Html Msg
viewTodo todo =
    div []
        [ text todo.description
        , button [ onClick (RemoveTodo todo.id) ] [ text "Remove" ]
        ]


decodeTodo : String -> Value -> Result String Todo
decodeTodo id value =
    value
        |> Decode.decodeValue Decode.string
        |> Result.map (Todo id)


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        TodosUpdated result ->
            case result of
                Ok todos ->
                    { model | error = Nothing, todos = todos } ! []

                Err error ->
                    { model | error = Just error } ! []

        AddTodo ->
            { model | form = "" }
                ! [ Database.push "todos" (model.form |> Encode.string |> Just)
                        |> Database.attempt firebase AddTodoComplete
                  ]

        AddTodoComplete _ ->
            model ! []

        RemoveTodo id ->
            model
                ! [ Database.remove ("todos/" ++ id)
                        |> Database.attempt firebase RemoveTodoComplete
                  ]

        RemoveTodoComplete _ ->
            model ! []

        UpdateForm value ->
            { model | form = value } ! []


subscriptions : Model -> Sub Msg
subscriptions model =
    Database.listChanges "todos" (OrderByKey NoFilter NoLimit) decodeTodo
        |> Database.subscribe firebase TodosUpdated
