module Model.Tests 
  ( modelTests
  ) where

import Control.Monad.Random
import Test.Tasty
import Test.Tasty.HUnit as Unit
import Test.Tasty.QuickCheck as QC

import Model.Model

repls :: Int
repls = 5

confidence :: Double
confidence = 0.95

modelTests :: RandomGen g 
           => g
           -> TestTree 
modelTests g 
  = testGroup "Model Tests" 
      [ QC.testProperty "Inheritance Gini" $ prop_inheritance_gini repls confidence
      , QC.testProperty "Wealth Distribution" $ prop_wealth_dist repls confidence

      , QC.testProperty "Terracing" $ prop_terracing repls confidence
      , QC.testProperty "Trading Dynamics" prop_trading_dynamics
      , QC.testProperty "Disease Dynamics All Recover" prop_disease_dynamics_allrecover 
      , QC.testProperty "Disease Dynamics Minority Recover" prop_disease_dynamics_minorityrecover      
      , QC.testProperty "Cultural Dynamics" prop_culture_dynamics

      , Unit.testCase "Carrying Capacity" $ prop_carrying_cap g repls confidence

      ]