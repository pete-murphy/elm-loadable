# `pete-murphy/elm-loadable`

A data type for tracking loadable (and reloadable) data, like data fetched from a backend server.

## Installation

```
elm install pete-murphy/elm-loadable
```

## Design Goals

This package is centered around the `Loadable` type, which is a minimal extension of `RemoteData` from [`krisajenkins/remotedata`](https://package.elm-lang.org/packages/krisajenkins/remotedata/latest) that adds a "reloading" state to the error and success cases. See [this discussion on alternative solutions to this problem](https://github.com/krisajenkins/remotedata/issues/9) for background.

There are many other use cases for extensions on top of `RemoteData`—you might want to track how many times a request has been attempted, or you might want to attach metadata about when the data was last successfully loaded. The motivation for this package is simply to allow _showing stale data while refetching_.

`Loadable e a` is essentially the same as `( Bool, Maybe (Result e a) )`. This could be encoded many different ways, for example as the sum type

```elm
type Loadable e a
    = NotAsked
    | Loading
    | Failure e
    | FailureReloading e
    | Success a
    | SuccessReloading a
```

The encoding in this package is intended to make pattern-matching as simple as possible. Using `Loadable.value` this will often look like

```elm
case Loadable.value model of
    Loadable.Empty ->
        -- ...

    Loadable.Success success ->
        -- ...

    Loadable.Failure failure ->
        -- ...
```

with the option of matching on `Loadable.isLoading model` in any of the three branches as needed. See [usage](#usage).

## Overview

### Usage

#### `init`

Typically you will use `Loadable.notAsked` or `Loadable.loading` in your `init` function.

```elm
type alias Model =
    { todos : Loadable Http.Error (List Todo) }


init : ( Model, Cmd Msg )
init =
    ({ todos = Loadable.loading }, fetchTodos )

```

#### `update`

In `update`, you can transition `Loadable` to loading using `Loadable.toLoading`.

```elm
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

```

#### `view`

In `view` you can match on empty, success, and failure cases with `Loadable.value`, and separately match on `Loadable.isLoading` as needed.

```elm
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
```

[See this example on Ellie](https://ellie-app.com/vBQPV95Fbdba1)
