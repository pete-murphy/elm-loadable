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
