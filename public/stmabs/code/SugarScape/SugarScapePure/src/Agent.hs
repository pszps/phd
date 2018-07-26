{-# LANGUAGE Arrows #-}
module Agent 
  (
    sugAgent
  ) where

import Control.Monad.Random
import Control.Monad.State.Strict
import FRP.BearRiver

import AgentMonad
import Common
import Environment
import Discrete
import Model
import Random
import Utils

------------------------------------------------------------------------------------------------------------------------
sugAgent :: RandomGen g 
         => Bool
         -> AgentId
         -> SugAgentState
         -> SugAgent g
sugAgent rebirthFlag aid s0 = feedback s0 (proc (ain, s) -> do
  age      <- time -< ()
  (ao, s') <- arrM (\(age, ain, s) -> lift $ runStateT (chapterII rebirthFlag aid ain age) s) -< (age, ain, s)
  returnA -< (ao, s'))

updateAgentState :: RandomGen g
                 => (SugAgentState -> SugAgentState)
                 -> StateT SugAgentState (SugAgentMonadT g) ()
updateAgentState = modify

observable :: RandomGen g
           => StateT SugAgentState (SugAgentMonadT g) (SugAgentOut g)
observable 
  = get >>= \s -> return $ agentOutObservable $ sugObservableFromState s 

------------------------------------------------------------------------------------------------------------------------
-- Chapter II: Life And Death On The Sugarscape
------------------------------------------------------------------------------------------------------------------------
chapterII :: RandomGen g 
          => Bool
          -> AgentId
          -> SugAgentIn
          -> Time
          -> StateT SugAgentState (SugAgentMonadT g) (SugAgentOut g)
chapterII rebirthFlag aid _ain age = do
  ao <- agentMetabolism
  ifThenElse
    (isDead ao)
    (if rebirthFlag
      then do
        (_, newA) <- birthNewAgent rebirthFlag
        return $ newAgent newA ao
      else return ao)
    (do
      agentMove aid
      ao' <- observable 
      return $ ao <°> ao')

birthNewAgent :: RandomGen g
              => Bool
              -> StateT SugAgentState (SugAgentMonadT g) (AgentId, SugAgentDef g)
birthNewAgent rebirthFlag = do
      newAid    <- lift nextAgentId
      newCoord  <- findUnoccpiedRandomPosition
      (newA, _) <- lift $ lift $ lift $ randomAgent (newAid, newCoord) (sugAgent rebirthFlag) id
      return (newAid, newA)
  where
    findUnoccpiedRandomPosition :: RandomGen g
                                => StateT SugAgentState (SugAgentMonadT g) Discrete2dCoord
    findUnoccpiedRandomPosition = do
      e <- lift $ lift get
      (c, coord) <- lift $ lift $ lift $ randomCell e
      ifThenElse
        (cellOccupied c) 
        findUnoccpiedRandomPosition
        (return coord)

agentDies :: RandomGen g
          => StateT SugAgentState (SugAgentMonadT g) (SugAgentOut g)
agentDies = do
  unoccupyPosition
  return $ kill agentOut

unoccupyPosition :: RandomGen g
                 => StateT SugAgentState (SugAgentMonadT g) ()
unoccupyPosition = do
  (coord, cell) <- agentCellOnCoord
  let cell' = cell { sugEnvOccupier = Nothing }
  lift $ lift $ changeCellAtM coord cell'

agentCellOnCoord :: RandomGen g
                 => StateT SugAgentState (SugAgentMonadT g) (Discrete2dCoord, SugEnvCell)
agentCellOnCoord = do
  coord <- gets sugAgCoord
  cell  <- lift $ lift $ cellAtM coord
  return (coord, cell)

agentMetabolism :: RandomGen g
                => StateT SugAgentState (SugAgentMonadT g) (SugAgentOut g)
agentMetabolism = do
  s <- get
  let sugarMetab = sugAgSugarMetab s

  sugarLevel <- gets sugAgSugarLevel

  let newSugarLevel = max 0 (sugarLevel - sugarMetab)
  
  updateAgentState (\s' -> s' { sugAgSugarLevel = newSugarLevel })

  ifThenElseM
    starvedToDeath
    agentDies
    (return agentOut)

starvedToDeath :: RandomGen g
               => StateT SugAgentState (SugAgentMonadT g) Bool
starvedToDeath = do
  sugar <- gets sugAgSugarLevel
  return $ sugar <= 0

agentMove :: RandomGen g
          => AgentId
          -> StateT SugAgentState (SugAgentMonadT g) ()
agentMove aid = do
  cellsInSight <- agentLookout
  coord <- gets sugAgCoord

  let unoccupiedCells = filter (cellUnoccupied . snd) cellsInSight

  ifThenElse 
    (null unoccupiedCells)
    agentStayAndHarvest
    (do
        -- NOTE included self but this will be always kicked out because self is occupied by self, need to somehow add this
        --       what we want is that in case of same sugar on all fields (including self), the agent does not move because staying is the lowest distance (=0)
        selfCell <- lift $ lift $ cellAtM coord
        let unoccupiedCells' = (coord, selfCell) : unoccupiedCells

        let bf = bestCellFunc
        let bestCells = selectBestCells bf coord unoccupiedCells'
        (cellCoord, _) <- lift $ lift $ lift $ randomElemM bestCells
        agentMoveAndHarvestCell aid cellCoord)

agentLookout :: RandomGen g
             => StateT SugAgentState (SugAgentMonadT g) [(Discrete2dCoord, SugEnvCell)]
agentLookout = do
  vis <- gets sugAgVision
  coord <- gets sugAgCoord
  lift $ lift $ neighboursInNeumannDistanceM coord vis False

agentStayAndHarvest :: RandomGen g
                    => StateT SugAgentState (SugAgentMonadT g) ()
agentStayAndHarvest = gets sugAgCoord >>= agentHarvestCell

agentMoveAndHarvestCell :: RandomGen g
                        => AgentId
                        -> Discrete2dCoord 
                        -> StateT SugAgentState (SugAgentMonadT g) ()
agentMoveAndHarvestCell aid cellCoord = do
  agentHarvestCell cellCoord 
  agentMoveTo aid cellCoord

agentMoveTo :: RandomGen g
             => AgentId
             -> Discrete2dCoord 
             -> StateT SugAgentState (SugAgentMonadT g) ()
agentMoveTo aid cellCoord = do
  unoccupyPosition

  updateAgentState (\s -> s { sugAgCoord = cellCoord })

  s <- get

  cell <- lift $ lift $ cellAtM cellCoord
  let co = cell { sugEnvOccupier = Just (cellOccupier aid s) }
  lift $ lift $ changeCellAtM cellCoord co 

agentHarvestCell :: RandomGen g
                 => Discrete2dCoord 
                 -> StateT SugAgentState (SugAgentMonadT g) ()
agentHarvestCell cellCoord = do
  cell <- lift $ lift $ cellAtM cellCoord

  sugarLevelAgent <- gets sugAgSugarLevel

  let sugarLevelCell     = sugEnvSugarLevel cell
  let newSugarLevelAgent = sugarLevelCell + sugarLevelAgent

  updateAgentState (\s -> s { sugAgSugarLevel = newSugarLevelAgent })

  let cellHarvested = cell { sugEnvSugarLevel = 0.0 }
  lift $ lift $ changeCellAtM cellCoord cellHarvested