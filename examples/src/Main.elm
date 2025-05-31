module Main exposing (main)

import Browser
import Html exposing (Html)
import Html.Attributes as Attributes
import Html.Events as Events
import Http
import Json.Decode exposing (Decoder)
import Loadable exposing (Loadable)


type alias Todo =
    { userId : Int
    , id : Int
    , title : String
    , body : String
    }


decoderTodo : Decoder Todo
decoderTodo =
    Json.Decode.map4 Todo
        (Json.Decode.field "userId" Json.Decode.int)
        (Json.Decode.field "id" Json.Decode.int)
        (Json.Decode.field "title" Json.Decode.string)
        (Json.Decode.field "body" Json.Decode.string)


fetchTodos : Cmd Msg
fetchTodos =
    Http.get
        { url = "https://jsonplaceholder.typicode.com/todos"
        , expect = Http.expectJson BackendRespondedWithTodos (Json.Decode.list decoderTodo)
        }


type alias Model =
    { todos : Loadable Http.Error (List Todo) }


initialModel : Model
initialModel =
    { todos = Loadable.notAsked }


type Msg
    = UserClickedFetchTodos
    | BackendRespondedWithTodos (Result Http.Error (List Todo))


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        UserClickedFetchTodos ->
            ( { model | todos = Loadable.toLoading model.todos }, fetchTodos )

        BackendRespondedWithTodos result ->
            ( { model | todos = Loadable.fromResult result }, Cmd.none )


view : Model -> Html Msg
view model =
    Html.div []
        [ Html.h1 [] [ Html.text "Todos" ]
        , Html.button [ Events.onClick UserClickedFetchTodos ] [ Html.text "Fetch Todos" ]
        , Html.div [ Attributes.classList [ ( "loading", Loadable.isLoading model.todos ) ] ]
            [ case Loadable.value model.todos of
                Loadable.Empty ->
                    Html.text "Loading..."

                Loadable.Success todos ->
                    Html.ul [] (List.map viewTodo todos)

                Loadable.Failure _ ->
                    Html.text "Something went wrong"
            ]
        ]


viewTodo : Todo -> Html Msg
viewTodo todo =
    Html.li []
        [ Html.h2 [] [ Html.text todo.title ]
        , Html.p [] [ Html.text ("User ID: " ++ String.fromInt todo.userId) ]
        ]


main : Program () Model Msg
main =
    Browser.element
        { init = \_ -> ( initialModel, fetchTodos )
        , view = view
        , update = update
        , subscriptions = \_ -> Sub.none
        }
