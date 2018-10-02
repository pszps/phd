{-# LANGUAGE Arrows #-}
module SIRYampa 
  ( runSIRYampa
  , defaultSIRYampaCtx

  , SIRState (..)
  , SIRYampaSimCtx (..)

  -- expose agents behaviour functions as well 
  , susceptibleAgent
  , infectedAgent
  , recoveredAgent

  , initAgents
  ) where

import Control.Monad.Random
import FRP.Yampa

data SIRState = Susceptible | Infected | Recovered deriving (Show, Eq)
type SIRAgent = SF [SIRState] SIRState

data SIRYampaSimCtx g = SIRYampaSimCtx
  { syCtxTimeLimit   :: !Double
  , syCtxTimeDelta   :: !Double

  , syCtxRng         :: g

  , syCtxAgentCount  :: !Int
  , syCtxInfected    :: !Int

  , syCtxContactRate :: !Double
  , syCtxInfectivity :: !Double
  , syCtxIllnessDur  :: !Double
  }

defaultSIRYampaCtx :: RandomGen g 
                   => g
                   -> SIRYampaSimCtx g 
defaultSIRYampaCtx g = SIRYampaSimCtx {
    syCtxTimeLimit   = 10
  , syCtxTimeDelta   = 0.1

  , syCtxRng         = g

  , syCtxAgentCount  = 10
  , syCtxInfected    = 1

  , syCtxContactRate = 5
  , syCtxInfectivity = 0.05
  , syCtxIllnessDur  = 15
  }

runSIRYampa :: RandomGen g 
            => SIRYampaSimCtx g
            -> [[SIRState]]
runSIRYampa simCtx
    = runSimulationUntil g t dt as cr inf dur
  where
    t  = syCtxTimeLimit simCtx
    dt = syCtxTimeDelta simCtx
    g  = syCtxRng simCtx
      
    agentCount = syCtxAgentCount simCtx
    infected   = syCtxInfected simCtx

    cr  = syCtxContactRate simCtx
    inf = syCtxInfectivity simCtx
    dur = syCtxIllnessDur simCtx

    as = initAgents agentCount infected

runSimulationUntil :: RandomGen g 
                   => g 
                   -> Time 
                   -> DTime 
                   -> [SIRState]
                   -> Double
                   -> Double
                   -> Double
                   -> [[SIRState]]
runSimulationUntil g0 t dt as cr inf dur 
    = embed (stepSimulation sfs as) ((), dts)
  where
    steps = floor $ t / dt
    dts   = replicate steps (dt, Nothing)

    (rngs, _) = rngSplits g0 (length as) []
    sfs       = zipWith (sirAgent cr inf dur) rngs as

rngSplits :: RandomGen g => g -> Int -> [g] -> ([g], g)
rngSplits g 0 acc = (acc, g)
rngSplits g n acc = rngSplits g'' (n - 1) (g' : acc)
  where
    (g', g'') = split g

stepSimulation :: [SIRAgent] 
               -> [SIRState] 
               -> SF () [SIRState]
stepSimulation sfs as =
    dpSwitch
      (\_ sfs' -> (map (\sf -> (as, sf)) sfs'))
      sfs
      -- if we switch immediately we end up in endless switching, so always wait for 'next'
      (switchingEvt >>> notYet) 
      stepSimulation

  where
    switchingEvt :: SF ((), [SIRState]) (Event [SIRState])
    switchingEvt = arr (\(_, newAs) -> Event newAs)

sirAgent :: RandomGen g 
         => Double
         -> Double
         -> Double
         -> g 
         -> SIRState 
         -> SIRAgent
sirAgent cr inf dur g Susceptible = susceptibleAgent cr inf dur g
sirAgent _  _   dur g Infected    = infectedAgent dur g
sirAgent _  _   _   _ Recovered   = recoveredAgent

susceptibleAgent :: RandomGen g
                 => Double
                 -> Double
                 -> Double
                 -> g
                 -> SIRAgent
susceptibleAgent contactRate infectivity illnessDuration g0 = 
    switch 
      -- delay the switching by 1 step, otherwise could
      -- make the transition from Susceptible to Recovered within time-step
      (susceptible g0 >>> iPre (Susceptible, NoEvent))
      (const $ infectedAgent illnessDuration g0)
  where
    susceptible :: RandomGen g => g -> SF [SIRState] (SIRState, Event ())
    susceptible g = proc as -> do
      makeContact <- occasionally g (1 / contactRate) () -< ()

      -- NOTE: strangely if we are not splitting all if-then-else into
      -- separate but only a single one, then it seems not to work,
      -- dunno why
      if isEvent makeContact
        then (do
          a <- drawRandomElemSFSafe g -< as
          case a of
            Just Infected -> do
              i <- randomBoolSF g infectivity -< ()
              if i
                then returnA -< (Infected, Event ())
                else returnA -< (Susceptible, NoEvent)
            _       -> returnA -< (Susceptible, NoEvent))
        else returnA -< (Susceptible, NoEvent)

infectedAgent :: RandomGen g 
              => Double
              -> g 
              -> SIRAgent
infectedAgent illnessDuration g = 
    switch 
      -- delay the switching by 1 step, otherwise could
      -- make the transition from Susceptible to Recovered within time-step
      --(infected >>> iPre (Infected, NoEvent))
      infected
      (const recoveredAgent)
  where
    infected :: SF [SIRState] (SIRState, Event ())
    infected = proc _ -> do
      recEvt <- occasionally g illnessDuration () -< ()
      let a = event Infected (const Recovered) recEvt
      returnA -< (a, recEvt)

recoveredAgent :: SIRAgent
recoveredAgent = arr (const Recovered)

randomBoolSF :: RandomGen g => g -> Double -> SF () Bool
randomBoolSF g p = proc _ -> do
  r <- noiseR ((0, 1) :: (Double, Double)) g -< ()
  returnA -< (r <= p)

drawRandomElemSF :: RandomGen g => g -> SF [a] a
drawRandomElemSF g = proc as -> do
  r <- noiseR ((0, 1) :: (Double, Double)) g -< ()
  let len = length as
  let idx = fromIntegral len * r
  let a =  as !! floor idx
  returnA -< a

drawRandomElemSFSafe :: RandomGen g => g -> SF [a] (Maybe a)
drawRandomElemSFSafe g = proc as -> do
  r <- noiseR ((0, 1) :: (Double, Double)) g -< ()
  if null as
    then returnA -< Nothing
    else do
      let len = length as
      let idx = fromIntegral len * r
      let a =  as !! floor idx
      returnA -< Just a

initAgents :: Int -> Int -> [SIRState]
initAgents s i = sus ++ inf
  where
    sus = replicate s Susceptible
    inf = replicate i Infected