module Loadable.Dict exposing (get, toLoading)

{-| Utility functions for working with `Dict`s of `Loadable` values

@docs get, toLoading

-}

import Dict exposing (Dict)
import Loadable exposing (Loadable)


{-| Get the value from a `Dict` of `Loadable` values, defaulting to `notAsked`
if the key is not found
-}
get : comparable -> Dict comparable (Loadable e a) -> Loadable e a
get key dict =
    Dict.get key dict
        |> Maybe.withDefault Loadable.notAsked


{-| Transition an entry in a `Dict` of `Loadable` values to loading,
inserting `loading` at the key if it's not already present
-}
toLoading : comparable -> Dict comparable (Loadable e a) -> Dict comparable (Loadable e a)
toLoading key =
    Dict.update key
        (\maybeLoadable ->
            case maybeLoadable of
                Just loadable ->
                    Just (Loadable.toLoading loadable)

                Nothing ->
                    Just Loadable.loading
        )
