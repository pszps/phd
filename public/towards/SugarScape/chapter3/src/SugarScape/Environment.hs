{-# LANGUAGE Arrows           #-}
{-# LANGUAGE FlexibleContexts #-}
module SugarScape.Environment 
  ( SugEnvironmentSF
  , sugEnvironmentSf
  ) where

import Control.Monad.Identity
import Control.Monad.State.Strict
import FRP.BearRiver

import SugarScape.Discrete
import SugarScape.Model

type SugEnvironmentSF = SF Identity SugEnvironment SugEnvironment

------------------------------------------------------------------------------------------------------------------------
-- ENVIRONMENT-BEHAVIOUR
------------------------------------------------------------------------------------------------------------------------
sugEnvironmentSf :: SugarScapeParams -> SugEnvironmentSF
sugEnvironmentSf params = proc env -> do
  t <- time -< ()
  env' <- arrM (\(t, env) -> lift $ execStateT (envBehaviour params t) env) -< (t, env)
  returnA -< env'

envBehaviour :: SugarScapeParams 
             -> Time
             -> State SugEnvironment ()
envBehaviour params t = do
  regrowSugar (spSugarRegrow params) t
  polutionDiffusion (spPolutionDiffusion params) t

polutionDiffusion :: Maybe Int
                  -> Time
                  -> State SugEnvironment ()
polutionDiffusion Nothing _  = return ()
polutionDiffusion (Just d) t 
    | not doDiffusion = return ()
    | otherwise = do
      cs <- allCellsWithCoordsM
      fs <- mapM (\(coord, c) -> do
        ncs <- neighbourCellsM coord True
        let flux = sum (map sugEnvSitePolutionLevel ncs) / fromIntegral (length ncs)
        return flux) cs

      zipWithM_ (\(coord, c) flux -> do
        let c' = c { sugEnvSitePolutionLevel = flux }
        changeCellAtM coord c') cs fs
  where
    doDiffusion = 0 == mod (floor t) d

regrowSugar :: SugarRegrow 
            -> Time
            -> State SugEnvironment ()
regrowSugar Immediate   _ = regrowSugarToMax
regrowSugar (Rate rate) _ = regrowSugarByRate rate
regrowSugar (Season summerRate winterRate seasonDuration) t
                          = regrowSugarBySeason t summerRate winterRate seasonDuration

regrowSugarToMax :: State SugEnvironment ()
regrowSugarToMax = updateCellsM (\c -> c { sugEnvSiteSugarLevel = sugEnvSiteSugarCapacity c})

regrowSugarByRate :: Double -> State SugEnvironment ()
regrowSugarByRate rate = updateCellsM $ regrowSugarInSiteWithRate rate

regrowSugarBySeason :: Time
                    -> Double
                    -> Double
                    -> Int
                    -> State SugEnvironment ()
regrowSugarBySeason t summerRate winterRate seasonDuration 
    = updateCellsWithCoordsM (\((_, y), c) -> 
        if y <= half
          then regrowSugarInSiteWithRate topate c
          else regrowSugarInSiteWithRate bottomRate c)
  where
    half       = floor (fromIntegral (snd sugarscapeDimensions) / 2 :: Double)

    isSummer   = even (floor ((t / fromIntegral seasonDuration) :: Double) :: Integer)
    topate     = if isSummer then summerRate     else 1 / winterRate
    bottomRate = if isSummer then 1 / winterRate else summerRate

regrowSugarInSiteWithRate :: Double 
                          -> SugEnvSite
                          -> SugEnvSite
regrowSugarInSiteWithRate rate c 
  = c { sugEnvSiteSugarLevel = 
          min
              (sugEnvSiteSugarCapacity c)
              ((sugEnvSiteSugarLevel c) + rate)} -- if this bracket is omited it leads to a bug: all environment cells have +1 level