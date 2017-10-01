module Test.Signal
  ( expect
  , expectFn
  , incAff
  , incEff
  , tick
  ) where

import Prelude
import Control.Monad.Aff (Aff, Canceler, makeAff, nonCanceler)
import Control.Monad.Aff.AVar (AVAR)
import Control.Monad.Eff (Eff)
import Control.Monad.Eff.Exception (Error, error)
import Control.Monad.Eff.Ref (REF, writeRef, readRef, newRef)
import Control.Monad.Eff.Timer (TIMER)
import Data.Either (Either(..))
import Data.Function.Uncurried (Fn4, runFn4)
import Data.List (List(..), fromFoldable, toUnfoldable)
import Signal (Signal, constant, (~>), runSignal)
import Test.Unit (Test, timeout)

expectFn :: forall e a. Eq a => Show a => Signal a -> Array a -> Test (ref :: REF | e)
expectFn sig vals = makeAff \resolve -> do
  remaining <- newRef vals
  let getNext val = do
        nextValArray <- readRef remaining
        let nextVals = fromFoldable nextValArray
        case nextVals of
          Cons x xs -> do
            if x /= val then resolve $ Left $ error $ "expected " <> show x <> " but got " <> show val
              else case xs of
                Nil -> resolve $ Right unit
                _ -> writeRef remaining (toUnfoldable xs)
          Nil -> resolve $ Left $ error "unexpected emptiness"
  runSignal $ sig ~> getNext
  pure nonCanceler

expect :: forall e a. Eq a => Show a => Int -> Signal a -> Array a -> Test (ref :: REF, timer :: TIMER, avar :: AVAR | e)
expect time sig vals = timeout time $ expectFn sig vals

foreign import tickP :: forall a c. Fn4 (c -> Signal c) Int Int (Array a) (Signal a)

tick :: forall a. Int -> Int -> Array a -> Signal a
tick = runFn4 tickP constant

foreign import incEff :: forall e. Int -> Eff e Int

foreign import incAffP :: forall e. (Int -> Either Error Int) -> Int -> (Either Error Int -> Eff e Unit) -> Eff e (Canceler e)

incAff :: forall e. Int -> Aff e Int
incAff val = makeAff (incAffP Right val)
