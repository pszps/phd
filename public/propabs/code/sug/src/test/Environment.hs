{-# LANGUAGE FlexibleInstances #-}
module Environment
  ( envTests
  ) where

import Control.Monad.Random

import Test.Tasty
import Test.Tasty.QuickCheck as QC

import SugarScape.AgentMonad
import SugarScape.Discrete
import SugarScape.Environment
import SugarScape.Model

import Utils

import Debug.Trace

instance Arbitrary SugEnvCell where
  -- arbitrary :: Gen SugEnvCell
  arbitrary = do
    cap <- choose sugarCapacityRange
    lvl <- choose (0, cap)

    return SugEnvCell {
      sugEnvSugarCapacity = cap
    , sugEnvSugarLevel    = lvl
    , sugEnvOccupier      = Nothing
    }

instance Arbitrary (Discrete2d SugEnvCell) where
  -- arbitrary :: Gen SugEnvCell
  arbitrary = do
    --dimX <- choose (1, 100)
    --dimY <- choose (1, 100)
  
    let dimX = 100
        dimY = 100

        dim = (dimX, dimY)
        n   = moore
        w   = WrapBoth

    cs <- vector (dimX * dimY)

    let coords  = [(x, y) | x <- [0..dimX - 1], y <- [0..dimY - 1]]
        csCoord = zip coords cs

    return $ createDiscrete2d dim n w csCoord

envTests :: RandomGen g 
         => g
         -> TestTree 
envTests g = testGroup "Environment Tests"
            [ QC.testProperty "Regrow By Rate" $ prop_env_regrow_rate g
            , QC.testProperty "Regrow By Max" $ prop_env_regrow_full g
            , QC.testProperty "Regrow To Full" $ prop_env_regrow_rate_full g  ]

-- test that after max level / rate steps the difference between level and capacity in all cells is 0
prop_env_regrow_rate :: RandomGen g 
                     => g
                     -> Positive Double
                     -> Discrete2d SugEnvCell
                     -> Bool
prop_env_regrow_rate g (Positive rate) env0 
    = all posSugarLevel cs'    &&
      all levelLTESugarMax cs' &&
      diffWithinRate
  where
    (_, env', _, _, _) = runAgentSF (sugEnvironment rate) defaultAbsState env0 g

    cs0 = allCells env0
    cs'       = allCells env'

    diffWithinRate = all (\(c0, c') -> sugarLevelDiffEps c' c0 rate 0.01) (zip cs0 cs')

prop_env_regrow_rate_full :: RandomGen g 
                          => g
                          -> Positive Double
                          -> Discrete2d SugEnvCell
                          -> Bool
prop_env_regrow_rate_full g (Positive rate) env0 
    = all posSugarLevel cs' && all fullSugarLevel cs'
  where
    maxCap = snd sugarCapacityRange
    steps  = ceiling $ maxCap / rate
    (outs, _, _, _) = runAgentSFSteps steps (sugEnvironment rate) defaultAbsState env0 g
    (_, env') = last outs
    cs' = allCells env'

-- test growback after 1 step
-- test that after 1 step the difference between level and capacity in all cells is 0
prop_env_regrow_full :: RandomGen g 
                     => g
                     -> Discrete2d SugEnvCell
                     -> Bool
prop_env_regrow_full g env0 
    = all fullSugarLevel cs && all posSugarLevel cs 
  where
    -- with a regrow-rate < 0 the sugar regrows to max within 1 step
    fullRegrowRate = -1
    (_, env', _, _, _) = runAgentSF (sugEnvironment fullRegrowRate) defaultAbsState env0 g

    cs = allCells env'

sugarLevelDiffEps :: SugEnvCell
                  -> SugEnvCell
                  -> Double
                  -> Double
                  -> Bool
sugarLevelDiffEps c0 c1 ref eps
    = trace ("\n diff = " ++ show diff ++ " diffRef = " ++ show diffRef ++ " ref = " ++ show ref) diffRef >= 0
  where
    diff    = sugEnvSugarLevel c0 - sugEnvSugarLevel c1
    diffRef = ref - diff

fullSugarLevel :: SugEnvCell -> Bool
fullSugarLevel c = sugEnvSugarLevel c == sugEnvSugarCapacity c

posSugarLevel :: SugEnvCell -> Bool
posSugarLevel c = sugEnvSugarLevel c > 0

levelLTESugarMax :: SugEnvCell -> Bool
levelLTESugarMax c = sugEnvSugarLevel c <= sugEnvSugarCapacity c