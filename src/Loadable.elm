module Loadable exposing
    ( Loadable, Value(..)
    , notAsked, loading, succeed, fail
    , map, andMap, andThen, combineMap, fromMaybe, fromResult, toLoading, toNotLoading, andMapWith, combineMapWith
    , withDefault, toMaybe, toMaybeError, isLoading, unwrap, value
    )

{-| Loadable and reloadable data. `Loadable` is an extension of `RemoteData` to
include a loading state in the success and failure cases.


## Types

@docs Loadable, Value


## Constructors

@docs notAsked, loading, succeed, fail


## Combinators

@docs map, andMap, andThen, combineMap, fromMaybe, fromResult, toLoading, toNotLoading, andMapWith, combineMapWith


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

    fromResult (Ok 1) --> succeed 1

    fromResult (Err "error") --> fail "error"

-}
fromResult : Result e a -> Loadable e a
fromResult result =
    case result of
        Ok a ->
            succeed a

        Err error ->
            fail error


{-| Convert a `Maybe` into a `Loadable`

    fromMaybe (Just 1) --> succeed 1

    fromMaybe Nothing --> notAsked

-}
fromMaybe : Maybe a -> Loadable e a
fromMaybe maybe =
    case maybe of
        Just a ->
            succeed a

        Nothing ->
            notAsked



-- COMBINATORS


mapLoading : (Bool -> Bool) -> Loadable e a -> Loadable e a
mapLoading f (Loadable internals) =
    Loadable { internals | isLoading = f internals.isLoading }


{-| Set loading to `True`

    toLoading loading --> loading

    toLoading notAsked --> loading

-}
toLoading : Loadable e a -> Loadable e a
toLoading =
    mapLoading (\_ -> True)


{-| Set loading to `False`

    toNotLoading loading --> notAsked

    toNotLoading notAsked --> notAsked

-}
toNotLoading : Loadable e a -> Loadable e a
toNotLoading =
    mapLoading (\_ -> False)


{-| Map the value of a `Loadable`

    map (\a -> a + 1) (succeed 1) --> succeed 2

    map (\_ -> 0) (fail "error") --> fail "error"

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

    succeed 1 |> andThen (\a -> succeed (a + 100)) --> succeed 101

    succeed 1 |> andThen (\_ -> fail "error") --> fail "error"

    fail "error" |> andThen (\_ -> loading) --> fail "error"

    notAsked |> andThen (\_ -> loading) --> notAsked

    loading |> andThen (\_ -> notAsked) --> loading

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
            Loadable { value = Empty, isLoading = data.isLoading }


{-| Apply a function to the value of a `Loadable`

    succeed (\a -> a + 1) |> andMap (succeed 1) --> succeed 2

-}
andMap : Loadable e a -> Loadable e (a -> b) -> Loadable e b
andMap ma mf =
    mf |> andThen (\f -> map f ma)


{-| Combine a list of `Loadable` values

    combineMap succeed [ 1, 2, 3 ]
    --> succeed [ 1, 2, 3 ]

    let
        odd n =
            modBy 2 n == 1
        failIfOdd n =
            if odd n then
                fail (String.fromInt n)
            else
                succeed n
    in
    combineMap failIfOdd [ 1, 2, 3 ]
    --> fail "1"

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
        --> succeed "ab"

    fail "a"
        |> andMapWith (++) (fail "b")
        --> fail "ab"

-}
andMapWith : (e -> e -> e) -> Loadable e a -> Loadable e (a -> b) -> Loadable e b
andMapWith onError ma mf =
    case ( value mf, value ma ) of
        ( Failure e1, Failure e2 ) ->
            Loadable { value = Failure (onError e1 e2), isLoading = isLoading mf }

        _ ->
            andMap ma mf


{-| Combine a list of `Loadable` values with a function that combines the errors

    combineMapWith (\x _ -> x) == combineMap

    let
        odd n =
            modBy 2 n == 1
        failIfOdd n =
            if odd n then
                fail (String.fromInt n)
            else
                succeed n
    in
    combineMapWith (++) failIfOdd [ 1, 2, 3 ] --> fail "13"

-}
combineMapWith : (e -> e -> e) -> (a -> Loadable e b) -> List a -> Loadable e (List b)
combineMapWith onError f =
    List.foldr
        (\a acc -> map (::) (f a) |> andMapWith onError acc)
        (succeed [])



-- DESTRUCTORS


{-| Get the success value out of `Loadable` or a fallback if it's not the success case

    withDefault 0 (succeed 1) --> 1

    withDefault 0 notAsked --> 0

-}
withDefault : a -> Loadable e a -> a
withDefault default (Loadable internals) =
    case internals.value of
        Success a ->
            a

        _ ->
            default


{-| Convert a `Loadable` to a `Maybe`

    toMaybe (succeed 1) --> Just 1

    toMaybe notAsked --> Nothing

-}
toMaybe : Loadable e a -> Maybe a
toMaybe (Loadable internals) =
    case internals.value of
        Success a ->
            Just a

        _ ->
            Nothing


{-| Get the value of a `Loadable`

    value (succeed 1) --> Success 1

    value notAsked --> Empty

-}
value : Loadable e a -> Value e a
value (Loadable internals) =
    internals.value


{-| Check if the `Loadable` is loading

    isLoading loading --> True

    isLoading notAsked --> False

-}
isLoading : Loadable e a -> Bool
isLoading (Loadable internals) =
    internals.isLoading


{-| Unwrap a `Loadable`

    unwrap (succeed 1) --> { value = Success 1, isLoading = False }

    unwrap notAsked --> { value = Empty, isLoading = False }

-}
unwrap : Loadable e a -> { value : Value e a, isLoading : Bool }
unwrap (Loadable data) =
    data


{-| Convert a `Loadable` to a `Maybe` of the error type

    toMaybeError (fail "error") --> Just "error"

    toMaybeError notAsked --> Nothing

-}
toMaybeError : Loadable e a -> Maybe e
toMaybeError (Loadable internals) =
    case internals.value of
        Failure error ->
            Just error

        _ ->
            Nothing
