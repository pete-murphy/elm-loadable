<!-- {{REPLACE ALL THE SECTIONS SURROUNDED BY DOUBLE `{}`'s }}

{{Set the description of your github project to the following format

{{TAGLINE}} {{LINK-TO-PACKAGE}}

Example:

Create styles that don't mysteriously break! http://package.elm-lang.org/packages/mdgriffith/stylish-elephants/latest

}} -->

# `pete-murphy/elm-loadable`

<!-- {{Copy Paste badge from Travis here.

See the [elm-test Github page](https://github.com/elm-community/elm-test) for instructions on how to set up Travis with an Elm project.
}}

{{
Example:
[![Build Status](https://travis-ci.org/dillonkearns/graphqelm.svg?branch=master)](https://travis-ci.org/dillonkearns/graphqelm) }} -->

A data type for tracking loadable (and reloadable) data, like data fetched from a backend server.

<!-- {{Replace link below with the simplest meaningful demo of your Elm package on https://ellie-app.com/ }}

See an [example in action on Ellie]({{YOUR LINK HERE}}). -->

<!-- See more end-to-end example code in the `examples/` folder. -->

## Installation

```
elm install pete-murphy/elm-loadable
```

## Design Goals

This package is centered around the `Loadable` type, which is a minimal extension of `RemoteData` from [`krisajenkins/remotedata`](https://package.elm-lang.org/packages/krisajenkins/remotedata/latest) that adds a "reloading" state to the error and success cases. See [this discussion on alternative solutions to this problem](https://github.com/krisajenkins/remotedata/issues/9) for background.

<details><summary>Differences from <code>RemoteData</code></summary>

`RemoteData e a` is a sum type defined as

```elm
type RemoteData e a
    = NotAsked
    | Loading
    | Failure e
    | Success a
```

As the "sum type" name implies, we can think of this type as having $$2 + e + a$$ inhabitants (see [_The algebra (and calculus!) of algebraic data types_](https://codewords.recurse.com/issues/three/algebra-and-calculus-of-algebraic-data-types)). Under this lens, `Loadable e a` is a _product of sums_ represented internally as

```elm
type Value e a
    = Empty
    | Failure e
    | Success a
```

with a `loading : Boolean` added to all cases. Expressed algebraically, `Value` is $$1 + e + a$$ (very similar to `RemoteData`) and `Loadable` is the product of that sum _and_ `Bool`'s 2 inhabitants: $$2 \times (1 + e + a)$$ or $$2 + 2e + 2a$$ (compare to `RemoteData`'s $$2 + e + a$$).

You can losslessly convert from `RemoteData` to `Loadable`

```elm
remoteDataToLoadable : RemoteData e a -> Loadable e a
remoteDataToLoadable remoteData =
    case remoteData of
        RemoteData.NotAsked ->
            Loadable.notAsked

        RemoteData.Loading ->
            Loadable.loading

        RemoteData.Success a ->
            Loadable.succeed a

        RemoteData.Failure e ->
            Loadable.fail e
```

Going the other direction just means discarding the loading state in the success & error cases.

```elm
loadableToRemoteData : Loadable e a -> RemoteData e a
loadableToRemoteData loadable =
    case ( Loadable.value loadable, Loadable.isLoading loadable ) of
        ( Loadable.Empty, False ) ->
            RemoteData.NotAsked

        ( Loadable.Empty, True ) ->
            RemoteData.Loading

        ( Loadable.Success a, _ ) ->
            RemoteData.Success a

        ( Loadable.Failure e, _ ) ->
            RemoteData.Failure e
```

</details>

## Overview

### Example usage

```elm
type alias Model =
    { todos : Loadable Http.Error (List Todo) }


init : ( Model, Cmd Msg )
init =
    ({ todos = Loadable.notAsked }, fetchTodos )


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
```

<!-- - Link to a live [Ellie](https://ellie-app.com/) Demo -->

<!-- ## Usage -->

<!-- {{Any setup instructions like how to hook the package code into the user's `update`/`init` functions. Or any scripts to run to do code generation, etc.}} -->

<!-- ## Learning Resources -->

<!-- Ask for help on the [Elm Slack](https://elm-lang.org/community/slack) in the #{{relevant-channel-name}}. {{It's nice to add a friendly word of encouragement to make users feel welcome to ask questions here.}}

{{Link to FAQ section or markdown file}}

{{Any other relevant blog posts, youtube videos, gitbooks, etc.
Here's a [nice example from the style-elements package](https://github.com/mdgriffith/style-elements/#resources-to-get-you-started)
}} -->
