module RemoteDataConversion exposing (..)

import Loadable exposing (Loadable)
import RemoteData exposing (RemoteData)


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
