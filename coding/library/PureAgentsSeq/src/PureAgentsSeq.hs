module PureAgentsSeq (
    module Data.Maybe,
    Agent(..),
    SimHandle(..),
    AgentId,
    AgentTransformer,
    AgentMessage,
    Msg(..),
    kill,
    newAgent,
    sendMsg,
    sendMsgToRandomNeighbour,
    broadcastMsgToNeighbours,
    updateState,
    writeState,
    addNeighbours,
    stepSimulation,
    initStepSimulation,
    advanceSimulation,
    runSimulation,
    createAgent,
    extractHdlEnv,
    extractHdlAgents
  ) where

import Data.Maybe
import System.Random

import qualified Data.Map as Map

------------------------------------------------------------------------------------------------------------------------
-- PUBLIC, exported
------------------------------------------------------------------------------------------------------------------------
-- The super-set of all Agent-Messages
data Msg m = Dt Double | Domain m
-- An agent-message is always a tuple of a message with the sender-id
type AgentMessage m = (AgentId, Msg m)

-- NOTE: the central agent-behaviour-function: transforms an agent using a message and an environment to a new agent
type AgentTransformer m s e = ((Agent m s e, e) -> AgentMessage m -> (Agent m s e, e))
type OutFunc m s e = (([Agent m s e], e) -> IO (Bool, Double))

{- NOTE:    m is the type of messages the agent understands
            s is the type of a generic state of the agent e.g. any data
            e is the type of a generic environment the agent can act upon
-}
type AgentId = Int

data Agent m s e = Agent {
    agentId :: AgentId,
    killFlag :: Bool,
    outBox :: [(AgentId, AgentId, m)],              -- NOTE: 1st AgentId contains the senderId, 2nd AgentId contains the targetId (redundancy saves us processing time)
    inBox :: [(AgentId, m)],                        -- NOTE: AgentId contains the senderId
    neighbours :: Map.Map AgentId AgentId,
    trans :: AgentTransformer m s e,
    state :: s,
    newAgents :: [Agent m s e]
}

data SimHandle m s e = SimHandle {
    simHdlAgents :: [Agent m s e],
    simHdlEnv :: e
}

newAgent :: Agent m s e -> Agent m s e -> Agent m s e
newAgent aParent aNew = aParent { newAgents = nas ++ [aNew] }
    where
        nas = newAgents aParent

kill :: Agent m s e -> Agent m s e
kill a = a { killFlag = True }

sendMsg :: Agent m s e -> m -> AgentId -> Agent m s e
sendMsg a m targetId
    | targetNotFound = a                                     -- NOTE: receiver not found in the neighbours
    | otherwise = a { outBox = newOutBox }
    where
        senderId = agentId a
        targetNotFound = isNothing (Map.lookup targetId (neighbours a))       -- NOTE: do we really need to look-up the neighbours?
        newOutBox = (senderId, targetId, m) : (outBox a) -- TODO: is order irrelevant? could use ++ as well but more expensive (or not?)

broadcastMsgToNeighbours :: Agent m s e -> m -> Agent m s e
broadcastMsgToNeighbours a m = foldl (\a' nId -> sendMsg a' m nId ) a nsIds
    where
        nsIds = Map.elems (neighbours a)

sendMsgToRandomNeighbour :: (RandomGen g) => Agent m s e -> m -> g -> (Agent m s e, g)
sendMsgToRandomNeighbour a m g = (a', g')
    where
        ns = (neighbours a)
        nsCount = Map.size ns
        (randIdx, g') = randomR(0, nsCount-1) g
        randAgentId = (Map.elems ns) !! randIdx     -- TODO: do we really need to map to elements?
        a' = sendMsg a m randAgentId

updateState :: Agent m s e -> (s -> s) -> Agent m s e
updateState a sf = a { state = s' }
    where
        s = state a
        s' = sf s

writeState :: Agent m s e -> s -> Agent m s e
writeState a s = updateState a (\_ -> s)

createAgent :: AgentId -> s -> AgentTransformer m s e -> Agent m s e
createAgent i s t = Agent{ agentId = i,
                                    state = s,
                                    outBox = [],
                                    inBox = [],
                                    killFlag = False,
                                    neighbours = Map.empty,
                                    newAgents = [],
                                    trans = t }

addNeighbours :: Agent m s e -> [Agent m s e] -> Agent m s e
addNeighbours a ns = a { neighbours = newNeighbours }
    where
        newNeighbours = foldl (\acc a -> Map.insert (agentId a) (agentId a) acc) (neighbours a) ns

extractHdlEnv :: SimHandle m s e -> e
extractHdlEnv = simHdlEnv

extractHdlAgents :: SimHandle m s e -> [Agent m s e]
extractHdlAgents = simHdlAgents

-- TODO: return all steps of agents and environment
stepSimulation :: [Agent m s e] -> e -> Double -> Int -> ([Agent m s e], e)
stepSimulation as e dt 0 = (as, e)
stepSimulation as e dt n = stepSimulation as' e' dt (n-1)
    where
        (as', e') = stepAllAgents as dt e

initStepSimulation :: [Agent m s e] -> e -> ([Agent m s e], SimHandle m s e)
initStepSimulation as e = (as, hdl)
    where
        hdl = SimHandle { simHdlAgents = as, simHdlEnv = e }

advanceSimulation :: SimHandle m s e -> Double -> ([Agent m s e], e, SimHandle m s e)
advanceSimulation hdl dt = (as', e', hdl')
    where
        e = extractHdlEnv hdl
        as = extractHdlAgents hdl
        (as', e') = stepAllAgents as dt e
        hdl' = hdl { simHdlAgents = as', simHdlEnv = e' }

runSimulation :: [Agent m s e] -> e -> OutFunc m s e -> IO ()
runSimulation as e out = runSimulation' as 0.0 e out
    where
        runSimulation' :: [Agent m s e] -> Double -> e -> OutFunc m s e -> IO ()
        runSimulation' as dt e out = do
                                        let (as', e') = stepAllAgents as dt e
                                        (cont, dt') <- out (as', e')
                                        if cont == True then
                                            runSimulation' as' dt' e' out
                                            else
                                                return ()

------------------------------------------------------------------------------------------------------------------------
-- PRIVATE, non exports
------------------------------------------------------------------------------------------------------------------------
-- TODO: does the map change the order? if yes, does it make a difference?
stepAllAgents :: [Agent m s e] -> Double -> e -> ([Agent m s e], e)
stepAllAgents as dt e = (Map.elems am', e')
    where
        am = insertAgents Map.empty as
        (am', e') = foldl (stepAllAgentsFold dt) (am, e) (Map.keys am)

        -- NOTE: we will iterate only over the keys, this allows us to update the whole map
        stepAllAgentsFold :: Double -> (Map.Map AgentId (Agent m s e), e) -> AgentId -> (Map.Map AgentId (Agent m s e), e)
        stepAllAgentsFold dt (am, e) aid = (amFinal, e')
            where
                a = fromJust (Map.lookup aid am)  -- NOTE: it is guaranteed that this key is in the map
                (a', e') = stepAgent dt (a, e)
                am' = deliverOutMsgs a' (insertAgents am (newAgents a'))
                aFinal = a' { newAgents = [], outBox = [] }
                amFinal = case (killFlag aFinal) of
                                    True -> Map.delete (agentId aFinal) am'
                                    otherwise -> Map.insert (agentId aFinal) aFinal am'

insertAgents :: Map.Map AgentId (Agent m s e) -> [Agent m s e] -> Map.Map AgentId (Agent m s e)
insertAgents am as = foldl (\accMap a -> Map.insert (agentId a) a accMap ) am as

-- NOTE: this places the messages in the out-box of of the first argument agent at their corresponding receivers in the map
deliverOutMsgs :: Agent m s e -> Map.Map AgentId (Agent m s e) -> Map.Map AgentId (Agent m s e)
deliverOutMsgs a am = am'
    where
        (allOutMsgs, _) = collectOutMsgs [a]
        am' = foldl (\agentMap' outMsgTup -> deliverMsg agentMap' outMsgTup ) am allOutMsgs

-- NOTE: could be the case that the receiver is no more in the map because it has been killed
deliverMsg :: Map.Map AgentId (Agent m s e) -> (AgentId, AgentId, m) -> Map.Map AgentId (Agent m s e)
deliverMsg am (senderId, receiverId, m)
    | receiverNotFound = am
    | otherwise = Map.insert receiverId a' am
    where
        mayReceiver = Map.lookup receiverId am
        receiverNotFound = isNothing mayReceiver
        a = (fromJust mayReceiver)
        ib = inBox a
        ibM = (senderId, m)
        a' = a { inBox = ib ++ [ibM] }

-- NOTE: first AgentId: senderId, second AgentId: receiverId
collectOutMsgs :: [Agent m s e] -> ([(AgentId, AgentId, m)], [Agent m s e])
collectOutMsgs as = foldl (\(accMsgs, accAs) a -> ((outBox a) ++ accMsgs, (a { outBox = [] }) : accAs) ) ([], []) as

stepAgent :: Double -> (Agent m s e, e) -> (Agent m s e, e)
stepAgent dt (a, e) = (aAfterUpdt, eAfterUpdt)
    where
        (aAfterMsgProc, eAfterMsgProc) = processAllMessages (a, e)
        agentTransformer = trans aAfterMsgProc
        (aAfterUpdt, eAfterUpdt) = agentTransformer (aAfterMsgProc, eAfterMsgProc) (-1, Dt dt)

processMsg :: (Agent m s e, e) -> (AgentId, m) -> (Agent m s e, e)
processMsg (a, e) (senderId, m) = agentTransformer (a, e) (senderId, Domain m)
    where
        agentTransformer = trans a

processAllMessages :: (Agent m s e, e) -> (Agent m s e, e)
processAllMessages (a, e) = (aAfterMsgs', eAfterMsgs)
    where
        msgs = inBox a
        (aAfterMsgs, eAfterMsgs) = foldl (\(a', e') senderMsgPair -> processMsg (a', e') senderMsgPair) (a, e) msgs
        aAfterMsgs' = aAfterMsgs { inBox = [] }

------------------------------------------------------------------------------------------------------------------------
