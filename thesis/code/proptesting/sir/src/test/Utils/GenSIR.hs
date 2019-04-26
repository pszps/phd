module Utils.GenSIR where

import Control.Monad.Random
import Test.Tasty.QuickCheck

import SIR.Model

newtype UnitRange = UnitRange Double deriving Show

newtype TimeRange = TimeRange Double deriving Show

instance Arbitrary UnitRange where
  arbitrary = UnitRange <$> choose (0, 1)

instance Arbitrary TimeRange where
  arbitrary = TimeRange <$> choose (0, 10)

genStdGen :: Gen StdGen
genStdGen = do
  seed <- choose (minBound, maxBound)
  return $ mkStdGen seed

genSIRState :: Gen SIRState
genSIRState = elements [Susceptible, Infected, Recovered]