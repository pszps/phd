{-# LANGUAGE Arrows           #-}
{-# LANGUAGE FlexibleContexts #-}
module SugarScape.Agent 
  ( agentMsf
  ) where

import Control.Monad.Random
import Control.Monad.Trans.MSF.State
import Data.MonadicStreamFunction

import SugarScape.Agent.Ageing
import SugarScape.Agent.Common
import SugarScape.Agent.Culture
import SugarScape.Agent.Dying
import SugarScape.Agent.Interface
import SugarScape.Agent.Mating
import SugarScape.Agent.Metabolism
import SugarScape.Agent.Move
import SugarScape.Agent.Polution
import SugarScape.Agent.Utils
import SugarScape.Model
import SugarScape.Utils

--import Debug.Trace as DBG

------------------------------------------------------------------------------------------------------------------------
agentMsf :: RandomGen g => SugarScapeAgent g
agentMsf params aid s0 = feedback s0 (proc (evt, s) -> do
  (s', ao) <- runStateS (generalEventHandler params aid) -< (s, evt)
  returnA -< (ao, s'))

-- SugAgentMonad g  = StateT SugEnvironment (Rand g)
-- SugAgentMonadT g = StateT ABSState (StateT SugEnvironment (Rand g))
-- AgentMSF m e o =  MSF (AgentT m) (ABSEvent e) (AgentOut m e o)
-- SugAgentMSF g  = AgentMSF (SugAgentMonad g) SugEvent SugAgentObservable
-- MSF (AgentT m) (ABSEvent e) (AgentOut m e o)

generalEventHandler :: RandomGen g 
                    => SugarScapeParams
                    -> AgentId 
                    -> EventHandler g
generalEventHandler params myId =
  -- optionally switching the top event handler 
  continueWithAfter 
    (proc evt -> 
      case evt of 
        TimeStep -> 
          constM (handleTimeStep params myId) -< ()
        (DomainEvent (sender, MatingRequest otherGender)) -> do
          ao <- arrM (uncurry (handleMatingRequest myId)) -< (sender, otherGender)
          returnA -< (ao, Nothing)
        (DomainEvent (sender, MatingTx childId)) -> do
          ao <- arrM (uncurry (handleMatingTx myId)) -< (sender, childId)
          returnA -< (ao, Nothing)
        (DomainEvent (sender, Inherit share)) -> do
          ao <- arrM (uncurry (handleInheritance myId)) -< (sender, share)
          returnA -< (ao, Nothing)
        (DomainEvent (sender, CulturalProcess tag)) -> do
          ao <- arrM (uncurry (handleCulturalProcess myId)) -< (sender, tag)
          returnA -< (ao, Nothing)
        (DomainEvent (sender, KilledInCombat)) -> do
          ao <- arrM (handleKilledInCombat myId) -< sender
          returnA -< (ao, Nothing)
        _        -> 
          returnA -< error $ "Agent " ++ show myId ++ ": undefined event " ++ show evt ++ " in agent, terminating!")

handleTimeStep :: RandomGen g 
               => SugarScapeParams
               -> AgentId
               -> AgentAction g (SugAgentOut g, Maybe (EventHandler g))
handleTimeStep params myId = do
  --DBG.trace ("Agent " ++ show myId ++ ": handleTimeStep") 
  agentAgeing
  
  (harvestAmount, maoCombat) <- agentMove params myId
  metabAmount                <- agentMetabolism params
  agentPolute params harvestAmount (fromIntegral metabAmount)

  -- NOTE: ordering is important to replicate the dynamics
  -- after having aged, moved and applied metabolism, the 
  -- agent could have died already, thus not able to mate
  ifThenElseM
    (starvedToDeath params `orM` dieOfAge)
    (do
      aoDie <- agentDies params myId agentMsf
      let ao = maybe aoDie (`agentOutMergeRightObs` aoDie) maoCombat
      return (ao, Nothing))
    (do 
      let cont = agentContAfterMating params myId

      ret <- agentMating 
              params 
              myId 
              agentMsf
              (generalEventHandler params myId) 
              cont

      case ret of
        Nothing -> do
          aoCont <- cont
          let ao = maybe aoCont (`agentOutMergeRightObs` aoCont) maoCombat
          return (ao, Nothing)
        Just (aoMating, mhdl) -> do
          let ao = maybe aoMating (`agentOutMergeRightObs` aoMating) maoCombat
          return (ao, mhdl))

agentContAfterMating :: RandomGen g 
                     => SugarScapeParams
                     -> AgentId
                     -> AgentAction g (SugAgentOut g)
agentContAfterMating params myId = do
  --DBG.trace ("Agent " ++ show myId ++ ": agentContAfterMating") 
  -- NOTE: perform cultural process here, does not matter if it is before or after mating (or is this wrong?)
  mao <- agentCultureProcess params myId
  case mao of
    Nothing -> agentOutObservableM
    Just ao -> return ao