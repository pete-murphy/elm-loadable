module LoadableTests exposing (..)

import Expect exposing (Expectation)
import Fuzz exposing (Fuzzer)
import Loadable exposing (Loadable)
import Test exposing (Test)


suite : Test
suite =
    Test.describe "Loadable"
        [ Test.describe "map"
            [ Test.test "should map a function over a Loadable" <|
                \_ ->
                    Expect.equal (Loadable.map (\a -> a + 1) (Loadable.succeed 1))
                        (Loadable.succeed 2)
            ]
        , Test.describe "combineMap"
            [ Test.test "should combine a list of Loadables" <|
                \_ ->
                    Expect.equal (Loadable.combineMap (\a -> Loadable.succeed a) [ 1, 2, 3 ])
                        (Loadable.succeed [ 1, 2, 3 ])
            ]
        , Test.describe "andThen"
            [ let
                fuzzF =
                    Fuzz.oneOfValues
                        [ \_ -> Loadable.succeed 1
                        , \_ -> Loadable.fail "oop"
                        , Loadable.succeed
                        , \_ -> Loadable.loading
                        , \_ -> Loadable.notAsked
                        , \_ -> Loadable.succeed 2 |> Loadable.toLoading
                        , \_ -> Loadable.fail "oop" |> Loadable.toLoading
                        , Loadable.succeed >> Loadable.toLoading
                        ]
              in
              Test.fuzz2 fuzzF Fuzz.int "left identity" <|
                \f x ->
                    Expect.equal (Loadable.succeed x |> Loadable.andThen f)
                        (f x)
            , let
                fuzzMa =
                    Fuzz.oneOfValues
                        [ Loadable.succeed 1
                        , Loadable.fail "oop"
                        , Loadable.loading
                        , Loadable.notAsked
                        , Loadable.succeed 2 |> Loadable.toLoading
                        , Loadable.fail "ah" |> Loadable.toLoading
                        ]
              in
              Test.fuzz fuzzMa "right identity" <|
                \ma ->
                    Expect.equal (ma |> Loadable.andThen Loadable.succeed)
                        ma
            , let
                fuzzF =
                    Fuzz.oneOfValues
                        [ \_ -> Loadable.succeed 1
                        , \_ -> Loadable.fail "oop"
                        , Loadable.succeed
                        , \_ -> Loadable.loading
                        , \_ -> Loadable.notAsked
                        , \_ -> Loadable.succeed 2 |> Loadable.toLoading
                        , \_ -> Loadable.fail "oop" |> Loadable.toLoading
                        , Loadable.succeed >> Loadable.toLoading
                        ]

                fuzzMa =
                    Fuzz.oneOfValues
                        [ Loadable.succeed 1
                        , Loadable.fail "oop"
                        , Loadable.loading
                        , Loadable.notAsked
                        , Loadable.succeed 2 |> Loadable.toLoading
                        , Loadable.fail "ah" |> Loadable.toLoading
                        ]
              in
              Test.fuzz3 fuzzF fuzzF fuzzMa "associativity" <|
                \f g ma ->
                    Expect.equal (ma |> Loadable.andThen (\x -> f x |> Loadable.andThen g))
                        ((ma |> Loadable.andThen f) |> Loadable.andThen g)
            ]
        , Test.describe "andMap"
            [ Test.test "should apply a function to the value of a Loadable" <|
                \_ ->
                    Expect.equal (Loadable.succeed (\a -> a + 1) |> Loadable.andMap (Loadable.succeed 1))
                        (Loadable.succeed 2)
            ]
        , Test.describe "andMapWith"
            [ Test.test "should apply a function to the value of a Loadable, combining the errors" <|
                \_ ->
                    Expect.equal (Loadable.succeed (\a -> a ++ "b") |> Loadable.andMapWith (++) (Loadable.succeed "a"))
                        (Loadable.succeed "ab")
            , Test.test "should combine the errors of the two Loadables" <|
                \_ ->
                    Expect.equal (Loadable.fail "a" |> Loadable.andMapWith (++) (Loadable.fail "b"))
                        (Loadable.fail "ab")
            , let
                fuzzMa =
                    Fuzz.oneOfValues
                        [ Loadable.succeed 1
                        , Loadable.fail "oop"
                        , Loadable.loading
                        , Loadable.notAsked
                        , Loadable.succeed 2 |> Loadable.toLoading
                        , Loadable.fail "ah" |> Loadable.toLoading
                        ]
              in
              Test.fuzzWith { runs = 1000, distribution = Test.noDistribution } (Fuzz.pair fuzzMa fuzzMa) "andMapWith always is same as andMap" <|
                \( ma, mb ) ->
                    Expect.equal
                        (Loadable.succeed (+)
                            |> Loadable.andMapWith Basics.always ma
                            |> Loadable.andMapWith Basics.always mb
                        )
                        (Loadable.succeed (+)
                            |> Loadable.andMap ma
                            |> Loadable.andMap mb
                        )
            , Test.test "combineMapWith" <|
                \_ ->
                    let
                        odd n =
                            modBy 2 n == 1

                        failIfOdd n =
                            if odd n then
                                Loadable.fail (String.fromInt n)

                            else
                                Loadable.succeed n
                    in
                    Expect.equal
                        (Loadable.combineMapWith (++) failIfOdd [ 1, 2, 3 ])
                        (Loadable.fail "13")
            ]
        ]
