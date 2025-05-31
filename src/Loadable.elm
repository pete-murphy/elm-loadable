module Loadable exposing
    ( Loadable, Value(..)
    , notAsked, loading, succeed, fail
    , map, andMap, andThen, combineMap, fromMaybe, fromResult, toLoading, toNotLoading
    , withDefault, toMaybe, toMaybeError, isLoading, unwrap, value
    , andMapWith, combineMapWith
    )

{-| Loadable and reloadable data


## Types

@docs Loadable, Value


## Constructors

@docs notAsked, loading, succeed, fail


## Combinators

@docs map, andMap, andThen, combineMap, fromMaybe, fromResult, toLoading, toNotLoading


## Destructors

@docs withDefault, toMaybe, toMaybeError, isLoading, unwrap, value

-}

-- TYPES


{-| A `Loadable` value is either empty, failed, or succeeded, and may be loading
or not
-}
type Loadable e a
    = Loadable (Internals e a)


type alias Internals e a =
    { value : Value e a
    , isLoading : Bool
    }


{-| The value of a `Loadable`, aside from its loading state
-}
type Value e a
    = Empty
    | Failure e
    | Success a



-- CONSTRUCTORS


{-| An empty value that is not loading
-}
notAsked : Loadable e a
notAsked =
    Loadable { value = Empty, isLoading = False }


{-| An empty value that is loading
-}
loading : Loadable e a
loading =
    Loadable { value = Empty, isLoading = True }


{-| A successful value that is not loading
-}
succeed : a -> Loadable e a
succeed a =
    Loadable { value = Success a, isLoading = False }


{-| A failed value that is not loading
-}
fail : e -> Loadable e a
fail error =
    Loadable { value = Failure error, isLoading = False }


{-| Convert a `Result` into a `Loadable`

    fromResult (Ok a) == succeed a

    fromResult (Err e) == fail e

-}
fromResult : Result e a -> Loadable e a
fromResult result =
    case result of
        Ok a ->
            succeed a

        Err error ->
            fail error


{-| Convert a `Maybe` into a `Loadable`

    fromMaybe (Just a) == succeed a

    fromMaybe Nothing == notAsked

-}
fromMaybe : Maybe a -> Loadable e a
fromMaybe maybe =
    case maybe of
        Just a ->
            succeed a

        Nothing ->
            notAsked



-- COMBINATORS


{-| Map the loading state of a `Loadable`

    mapLoading (\_ -> True) loading == loading

    mapLoading (\_ -> False) loading == notAsked

-}
mapLoading : (Bool -> Bool) -> Loadable e a -> Loadable e a
mapLoading f (Loadable internals) =
    Loadable { internals | isLoading = f internals.isLoading }


{-| Set loading to `True`

    toLoading loading == loading

    toLoading notAsked == notAsked

-}
toLoading : Loadable e a -> Loadable e a
toLoading =
    mapLoading (\_ -> True)


{-| Set loading to `False`

    toNotLoading loading == notAsked

    toNotLoading notAsked == notAsked

-}
toNotLoading : Loadable e a -> Loadable e a
toNotLoading =
    mapLoading (\_ -> False)


{-| Map the value of a `Loadable`

    map (\a -> a + 1) (succeed 1) == succeed 2

    map (\_ -> 0) (fail "error") == fail "error"

-}
map : (a -> b) -> Loadable e a -> Loadable e b
map f (Loadable internals) =
    Loadable
        (case internals.value of
            Empty ->
                { value = Empty, isLoading = internals.isLoading }

            Failure error ->
                { value = Failure error, isLoading = internals.isLoading }

            Success a ->
                { value = Success (f a), isLoading = internals.isLoading }
        )


{-| Should match the semantics of the Monad instance for

```haskell
ExceptT e (MaybeT (Writer Any))
```

    andThen (\a -> map f a) (succeed a) == map f (succeed a)

    andThen (\_ -> fail "error") (succeed a) == fail "error"

    andThen (\_ -> loading) (fail "error") == loading

    andThen (\_ -> notAsked) notAsked == notAsked

-}
andThen : (a -> Loadable e b) -> Loadable e a -> Loadable e b
andThen f (Loadable data) =
    case data.value of
        Success a ->
            let
                next =
                    unwrap (f a)
            in
            Loadable { value = next.value, isLoading = data.isLoading || next.isLoading }

        Failure err ->
            Loadable { value = Failure err, isLoading = data.isLoading }

        Empty ->
            -- Int.is
            Loadable { value = Empty, isLoading = data.isLoading }


{-| Apply a function to the value of a `Loadable`

    succeed (\a -> a + 1) |> andMap (succeed 1) == succeed 2

-}
andMap : Loadable e a -> Loadable e (a -> b) -> Loadable e b
andMap ma mf =
    mf |> andThen (\f -> map f ma)


{-| Combine a list of `Loadable` values

    combineMap (\a -> succeed a) [ 1, 2, 3 ] == succeed [ 1, 2, 3 ]

    let
        odd n =
            modBy 2 n == 1

        failIfOdd n =
            if odd n then
                fail (String.fromInt n)

            else
                succeed n
    in
    combineMap failIfOdd [ 1, 2, 3 ] == fail "1"

-}
combineMap : (a -> Loadable e b) -> List a -> Loadable e (List b)
combineMap f =
    List.foldr
        (\a acc -> map (::) (f a) |> andMap acc)
        (succeed [])


{-| Apply a function to the value of a `Loadable`, combining the errors.

NOTE: This is intended to be used in a pipeline, with errors accumulating left
to right _in the pipeline_ not in the order of arguments to the function. See
the examples.

    succeed (\a -> a ++ "b")
        |> andMapWith (++) (succeed "a")
        == succeed "ab"

    fail "a"
        |> andMapWith (++) (fail "b")
        == fail "ab"

-}
andMapWith : (e -> e -> e) -> Loadable e a -> Loadable e (a -> b) -> Loadable e b
andMapWith onError ma mf =
    let
        v =
            case ( value mf, value ma ) of
                ( Success f, Success a ) ->
                    Success (f a)

                ( Failure e1, Failure e2 ) ->
                    Failure (onError e1 e2)

                ( Failure e, Success _ ) ->
                    Failure e

                ( Success _, Failure e ) ->
                    Failure e

                ( Empty, _ ) ->
                    Empty

                ( _, Empty ) ->
                    Empty
    in
    Loadable { value = v, isLoading = isLoading ma || isLoading mf }


{-| Combine a list of `Loadable` values with a function that combines the errors

    combineMapWith (++) (succeed [ "a" ]) (succeed [ "b" ]) == succeed [ "ab" ]

    combineMapWith (++) (fail "a") (fail "b") == fail "ab"

-}
combineMapWith : (e -> e -> e) -> (a -> Loadable e b) -> List a -> Loadable e (List b)
combineMapWith onError f =
    List.foldr
        (\a acc -> map (::) (f a) |> andMapWith onError acc)
        (succeed [])



-- DESTRUCTORS


{-| Get the default value if the `Loadable` is not loading

    withDefault 0 (succeed 1) == 1

    withDefault 0 notAsked == 0

-}
withDefault : a -> Loadable e a -> a
withDefault default (Loadable internals) =
    case internals.value of
        Success a ->
            a

        _ ->
            default


{-| Convert a `Loadable` to a `Maybe`

    toMaybe (succeed 1) == Just 1

    toMaybe notAsked == Nothing

-}
toMaybe : Loadable e a -> Maybe a
toMaybe (Loadable internals) =
    case internals.value of
        Success a ->
            Just a

        _ ->
            Nothing


{-| Get the value of a `Loadable`

    value (succeed 1) == Success 1

    value notAsked == Empty

-}
value : Loadable e a -> Value e a
value (Loadable internals) =
    internals.value


{-| Check if the `Loadable` is loading

    isLoading loading == True

    isLoading notAsked == False

-}
isLoading : Loadable e a -> Bool
isLoading (Loadable internals) =
    internals.isLoading


{-| Unwrap a `Loadable`

    unwrap (succeed 1) == { value = Success 1, isLoading = False }

    unwrap notAsked == { value = Empty, isLoading = False }

-}
unwrap : Loadable e a -> Internals e a
unwrap (Loadable data) =
    data


{-| Convert a `Loadable` to a `Maybe` of the error type

    toMaybeError (fail "error") == Just "error"

    toMaybeError notAsked == Nothing

-}
toMaybeError : Loadable e a -> Maybe e
toMaybeError (Loadable internals) =
    case internals.value of
        Failure error ->
            Just error

        _ ->
            Nothing
