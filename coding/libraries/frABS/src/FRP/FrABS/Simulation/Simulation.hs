{-# LANGUAGE Arrows #-}
module FRP.FrABS.Simulation.Simulation (
    UpdateStrategy (..),
    EnvironmentCollapsing,
    SimulationParams (..),

    processIOInit,
    processSteps
  ) where

import FRP.FrABS.Env.Environment
import FRP.FrABS.Simulation.SeqIteration
import FRP.FrABS.Simulation.ParIteration
import FRP.FrABS.Agent.Agent
import FRP.FrABS.Simulation.Internal

import FRP.Yampa
import FRP.Yampa.InternalCore

import Data.Maybe
import Data.List
import System.Random
import qualified Data.Map as Map
import Control.Concurrent.STM.TVar

data UpdateStrategy = Sequential | Parallel deriving (Eq)
type EnvironmentCollapsing ec l = ([Environment ec l] -> Environment ec l)

data SimulationParams ec l = SimulationParams {
    simStrategy :: UpdateStrategy,
    simEnvCollapse :: Maybe (EnvironmentCollapsing ec l),
    simShuffleAgents :: Bool,
    simRng :: StdGen,
    simIdGen :: TVar Int
}

------------------------------------------------------------------------------------------------------------------------
-- RUNNING SIMULATION FROM AN OUTER LOOP
------------------------------------------------------------------------------------------------------------------------
-- NOTE: don't care about a, we don't use it anyway
processIOInit :: [AgentDef s m ec l]
                    -> Environment ec l
                    -> SimulationParams ec l
                    -> (ReactHandle ([AgentIn s m ec l], Environment ec l) ([AgentOut s m ec l], Environment ec l)
                            -> Bool
                            -> ([AgentOut s m ec l], Environment ec l)
                            -> IO Bool)
                    -> IO (ReactHandle ([AgentIn s m ec l], Environment ec l) ([AgentOut s m ec l], Environment ec l))
processIOInit as env params iterFunc = reactInit
                                                (return (ains, env))
                                                iterFunc
                                                (process as params)
    where
        idGen = simIdGen params
        ains = createStartingAgentIn as env idGen
------------------------------------------------------------------------------------------------------------------------

------------------------------------------------------------------------------------------------------------------------
-- CALCULATING A FIXED NUMBER OF STEPS OF THE SIMULATION
------------------------------------------------------------------------------------------------------------------------
{- NOTE: to run Yampa in a pure-functional way use embed -}
processSteps :: [AgentDef s m ec l]
                    -> Environment ec l
                    -> SimulationParams ec l
                    -> Double
                    -> Int
                    -> [([AgentOut s m ec l], Environment ec l)]
processSteps as env params dt steps = embed
                                            (process as params)
                                            ((ains, env), sts)
    where
        -- NOTE: again haskells laziness put to use: take steps items from the infinite list of sampling-times
        sts = replicate steps (dt, Nothing)
        idGen = simIdGen params
        ains = createStartingAgentIn as env idGen
----------------------------------------------------------------------------------------------------------------------


----------------------------------------------------------------------------------------------------------------------
process :: [AgentDef s m ec l]
                -> SimulationParams ec l
                -> SF ([AgentIn s m ec l], Environment ec l) ([AgentOut s m ec l], Environment ec l)
process as params = iterationStrategy asfs params
    where
        asfs = map adBeh as

iterationStrategy :: [SF (AgentIn s m ec l) (AgentOut s m ec l)]
                        -> SimulationParams ec l
                        -> SF ([AgentIn s m ec l], Environment ec l) ([AgentOut s m ec l], Environment ec l)
iterationStrategy asfs params 
    | Sequential == strategy = simulateSeq asfs params
    | Parallel == strategy = simulatePar asfs params
    where
        strategy = simStrategy params

simulate :: ([AgentIn s m ec l], Environment ec l)
                  -> [SF (AgentIn s m ec l) (AgentOut s m ec l)]
                  -> SimulationParams ec l
                  -> Double
                  -> Int
                  -> [([AgentOut s m ec l], Environment ec l)]
simulate ains asfs params dt steps = embed
                                                  sfStrat
                                                  (ains, sts)
    where
        sts = replicate steps (dt, Nothing)
        sfStrat = iterationStrategy asfs params
----------------------------------------------------------------------------------------------------------------------

----------------------------------------------------------------------------------------------------------------------
-- SEQUENTIAL STRATEGY
----------------------------------------------------------------------------------------------------------------------
simulateSeq :: [SF (AgentIn s m ec l) (AgentOut s m ec l)]
                -> (SimulationParams ec l)
                -> SF ([AgentIn s m ec l], Environment ec l) ([AgentOut s m ec l], Environment ec l)
simulateSeq initSfs initParams = SF {sfTF = tf0}
    where
        tf0 (initInputs, initEnv) = (tfCont, (initOuts, initEnv))
            where
                -- NOTE: to prevent undefined outputs we create outputs based on the initials
                initOuts = map agentOutFromIn initInputs
                --(nextSfs, initOs, nextIns) = runSeqInternal initSfs initInput clbk 0.0
                -- NOTE: in SEQ we need already to know the dt for the NEXT step because we are iterating in sequence => ommit first output => need 1 step more
                tfCont = simulateSeqAux initParams initSfs initInputs initEnv

        -- NOTE: here we create recursively a new continuation
        -- ins are the old inputs from which outs resulted, together with their sfs
        simulateSeqAux params sfs ins env = SF' tf
            where
                -- NOTE: this is a function definition
                -- tf :: DTime -> [i] -> Transition [i] [o]
                tf dt _ = (tf', (outs, env''))
                    where
                        -- run the next step with the new sfs and inputs to get the sf-contintuations and their outputs
                        (sfs', ins', outs) = runSeqInternal 
                            sfs 
                            ins 
                            (seqCallback params) 
                            (seqCallbackIteration $ simIdGen initParams)
                            dt

                        -- NOTE: the 'last' environment is in the first of outs because runSeqInternal reverses the outputs
                        env' = if null outs then env else aoEnv $ head outs
                        env'' = runEnv env' dt

                        insWithNewEnv = map (\ain -> ain { aiEnv = env'' }) ins'

                        (params', sfsShuffled, insShuffled) = shuffleAgents params sfs' insWithNewEnv

                        -- create a continuation of this SF
                        tf' = simulateSeqAux params' sfsShuffled insShuffled env''



seqCallbackIteration :: TVar Int -> [AgentOut s m ec l] -> ([AgentBehaviour s m ec l], [AgentIn s m ec l])
seqCallbackIteration idGen aouts = (newSfs, newSfsIns')
    where
        -- NOTE: messages of this agent are ALWAYS distributed, whether it is killed or not
        (newSfs, newSfsIns) = foldr (handleCreateAgents idGen) ([], []) aouts
        -- NOTE: distribute messages to newly created agents as well
        newSfsIns' = distributeMessages newSfsIns aouts

seqCallback :: SimulationParams ec l
                -> ([AgentIn s m ec l], [AgentBehaviour s m ec l])
                -> (AgentBehaviour s m ec l)
                -> (AgentBehaviour s m ec l, AgentIn s m ec l, AgentOut s m ec l)
                -> ([AgentIn s m ec l],
                    Maybe (AgentBehaviour s m ec l, AgentIn s m ec l, AgentOut s m ec l))
seqCallback params (otherIns, otherSfs) oldSf (sf, oldIn, newOut)
    | doRecursion = seqCallbackRec params otherIns otherSfs oldSf (sf, recIn, newOut)
    | otherwise = handleAgent otherIns (sf, unRecIn, newOut)
    where
        -- NOTE: first layer of recursion: calling simulate within a simulation
        -- NOTE: at this level we are determining how many levels of recursion we run: at the moment, we stop after the first level
        doRecursion = if (isEvent (aiRec oldIn)) then
                        False   -- this is recursion-level 1 (0 is the initial level), stop here, can be replaced by counter in the future
                        else
                            isEvent $ aoRec newOut      -- this is recursion-level 0 (initial level), do recursion only if the agent requests to do so

        -- NOTE: need to handle inputs different based upon whether we are doing
        recIn = if (isEvent $ aiRec oldIn) then
                    oldIn -- this is recursion level 1 => will do normal agent-handling and feed past outputs to the agent so it can select the best
                    else
                        oldIn { aiRec = Event [] } -- this is recursion level 0 => start with empty past outputs

        -- NOTE: need to stop recursion
        unRecIn = oldIn { aiRec = NoEvent }

        -- NOTE: second layer of recursion: this allows the agent to simulate an arbitrary number of AgentOuts
        seqCallbackRec :: SimulationParams ec l
                           -> [AgentIn s m ec l]
                           -> [AgentBehaviour s m ec l]
                           -> (AgentBehaviour s m ec l)
                           -> (AgentBehaviour s m ec l, AgentIn s m ec l, AgentOut s m ec l)
                           -> ([AgentIn s m ec l],
                               Maybe (AgentBehaviour s m ec l, AgentIn s m ec l, AgentOut s m ec l))
        seqCallbackRec params otherIns otherSfs oldSf (sf, recIn, newOut)
            | isEvent $ aoRec newOut = handleRecursion params otherIns otherSfs oldSf (sf, recIn', newOut)     -- the last output requested recursion, perform it
            | otherwise = handleAgent otherIns (sf, unRecIn, newOut)                                                     -- no more recursion request, just handle agent as it is and return it, this will transport it back to the outer level
            where
                pastOutputs = fromEvent $ aiRec recIn                           -- at this point we can be sure that there MUST be an aiRec - Event otherwise would make no sense: having an aiRec - Event with a list means, that we are inside a recursion level (either 0 or 1)
                recIn' = recIn { aiRec = Event (newOut : pastOutputs) }         -- append the new output to the past ones

                -- NOTE: need to stop recursion
                unRecIn = recIn { aiRec = NoEvent }

        -- this initiates the recursive simulation call
        handleRecursion :: SimulationParams ec l
                             -> [AgentIn s m ec l]     -- the inputs to the 'other' agents
                             -> [AgentBehaviour s m ec l] -- the signal functions of the 'other' agents
                             -> (AgentBehaviour s m ec l)     -- the OLD signal function of the current agent: it is the SF BEFORE having initiated the recursion
                             -> (AgentBehaviour s m ec l, AgentIn s m ec l, AgentOut s m ec l)
                             -> ([AgentIn s m ec l],
                                    Maybe (AgentBehaviour s m ec l, AgentIn s m ec l, AgentOut s m ec l))
        handleRecursion params otherIns otherSfs oldSf a@(sf, oldIn, newOut)
            | isJust mayAgent = retAfterRec
            | otherwise = retSelfKilled       -- the agent killed itself, terminate recursion
            where
                -- NOTE: collect self-messages for agent, distribute its messages and environment to others
                retSelfKilled@(otherIns', mayAgent) = handleAgent otherIns a

                (_, newIn, _) = fromJust mayAgent

                otherIns'' = if allowsRecOthers newOut then otherIns' else forbidRecursion otherIns'

                -- TODO: to prevent an endless creation of recursions when running a recursion for more than 1 step one needs to let the recursive agent let know it is inside its own recursion with the same mechanism as letting others now they are inside another recursion.

                -- NOTE: need to add agent, because not included
                -- TODO: does it really have to be added at the end?
                allAsfs = otherSfs ++ [oldSf]       -- NOTE: use the old sf, no time
                allAins = otherIns'' ++ [newIn]

                env = aoEnv newOut

                -- TODO: does it make sense to run multiple steps? what is the meaning of it?
                -- TODO: when running for multiple steps it makes sense to specify WHEN the agent of oldSF runs
                -- NOTE: when setting steps to > 1 we end up in an infinite loop
                -- TODO: only running in sequential for now
                allStepsRecOuts = (simulate (allAins, env) allAsfs params 1.0 1) 

                (lastStepRecOuts, _) = (last allStepsRecOuts)
                mayRecOut = Data.List.find (\ao -> (aoId ao) == (aiId oldIn)) lastStepRecOuts

                -- TODO: what happens to the environment? it could have changed by the other agents but we need to re-set it to before
                
                -- TODO: the agent died in the recursive simulation, what should we do?
                retAfterRec = if isJust mayRecOut then
                                seqCallbackRec params otherIns otherSfs oldSf (sf, newIn, fromJust mayRecOut)
                                else
                                    retSelfKilled

        forbidRecursion :: [AgentIn s m ec l] -> [AgentIn s m ec l]
        forbidRecursion ains = map (\ai -> ai { aiRecInitAllowed = False } ) ains

        handleAgent :: [AgentIn s m ec l]
                                -> (AgentBehaviour s m ec l, AgentIn s m ec l, AgentOut s m ec l)
                                -> ([AgentIn s m ec l],
                                     Maybe (AgentBehaviour s m ec l, AgentIn s m ec l, AgentOut s m ec l))
        handleAgent otherIns a@(sf, oldIn, newOut) = (otherIns'', mayAgent)
            where
                (otherIns', newOut') = handleConversation otherIns newOut
                mayAgent = handleKillOrLiveAgent (sf, oldIn, newOut')
                otherIns'' = distributeActions otherIns' newOut'

        handleConversation :: [AgentIn s m ec l]
                                -> AgentOut s m ec l
                                -> ([AgentIn s m ec l], AgentOut s m ec l)
        handleConversation otherIns newOut
            | hasConversation newOut = handleConversation otherIns' newOut'
            | otherwise = (otherIns, newOut)
            where
                conv@(_, senderReplyFunc) = fromEvent $ aoConversation newOut

                -- NOTE: it is possible that agents which are just newly created are already target of a conversation because
                --       their position in the environment was occupied using their id which exposes them to potential messages
                --       and conversations. These newly created agents are not yet available in the current iteration and can
                --       only fully participate in the next one. Thus we ignore conversation-requests

                mayRepl = conversationReply otherIns newOut conv
                (otherIns', newOut') = maybe (otherIns, senderReplyFunc newOut Nothing) id mayRepl

                conversationReply :: [AgentIn s m ec l] 
                                        -> AgentOut s m ec l
                                        -> (AgentMessage m, AgentConversationSender s m ec l)
                                        -> Maybe ([AgentIn s m ec l], AgentOut s m ec l) 
                conversationReply otherIns newOut ((receiverId, receiverMsg), senderReplyFunc) =
                    do
                        receivingIdx <- findIndex ((==receiverId) . aiId) otherIns
                        let receivingIn = otherIns !! receivingIdx 
                        convHandler <- aiConversation receivingIn
                        (replyM, receivingIn') <- convHandler receivingIn (aoId newOut, receiverMsg)
                        let otherIns' = replace receivingIdx otherIns receivingIn'
                        let newOut' = senderReplyFunc newOut (Just (receiverId, replyM))
                        return (otherIns', newOut')

        replace :: Int -> [a] -> a -> [a]
        replace idx as a = front ++ (a : backNoElem)
            where
                (front, back) = splitAt idx as  -- NOTE: back includes the element with the index
                backNoElem = tail back

        handleKillOrLiveAgent :: (AgentBehaviour s m ec l, AgentIn s m ec l, AgentOut s m ec l)
                                    -> Maybe (AgentBehaviour s m ec l, AgentIn s m ec l, AgentOut s m ec l)
        handleKillOrLiveAgent (sf, oldIn, newOut)
            | killAgent = Nothing
            | otherwise = Just (sf, newIn', newOut)
            where
                killAgent = isEvent $ aoKill newOut
                newIn = newAgentIn oldIn newOut

                -- NOTE: need to handle sending messages to itself because the input of this agent is not in the list of all inputs because it will be replaced anyway by newIn
                newIn' = collectMessagesFor [newOut] newIn

        distributeActions :: [AgentIn s m ec l] -> AgentOut s m ec l -> [AgentIn s m ec l]
        distributeActions otherIns newOut = otherIns1
            where
                 -- NOTE: distribute messages to all other agents
                otherIns0 = distributeMessages otherIns [newOut]
                -- NOTE: passing the changed environment to the next agents
                otherIns1 = passEnvForward newOut otherIns0

        passEnvForward :: AgentOut s m ec l -> [AgentIn s m ec l] -> [AgentIn s m ec l]
        passEnvForward out allIns = map (\ain -> ain { aiEnv = env }) allIns
            where
                env = aoEnv out
----------------------------------------------------------------------------------------------------------------------

----------------------------------------------------------------------------------------------------------------------
-- PARALLEL STRATEGY
----------------------------------------------------------------------------------------------------------------------
simulatePar :: [SF (AgentIn s m ec l) (AgentOut s m ec l)]
                -> SimulationParams ec l
                -> SF ([AgentIn s m ec l], Environment ec l) ([AgentOut s m ec l], Environment ec l)
simulatePar initSfs initParams = SF {sfTF = tf0}
    where
        tf0 (initInputs, initEnv) = (tfCont, (initOuts, initEnv))
            where
                -- NOTE: to prevent undefined outputs we create outputs based on the initials
                initOuts = map agentOutFromIn initInputs
                tfCont = simulateParAux initParams initSfs initInputs initEnv

        -- NOTE: here we create recursively a new continuation
        -- ins are the old inputs from which outs resulted, together with their sfs
        simulateParAux params sfs ins env = SF' tf
            where
                -- NOTE: this is a function defition
                -- tf :: DTime -> [i] -> Transition [i] [o]
                tf dt _ =  (tf', (outs', env'))
                    where
                         -- run the next step with the new sfs and inputs to get the sf-contintuations and their outputs
                        (sfs', outs') = runParInternal sfs ins

                        -- freezing the collection of SF' to 'promote' them back to SF
                        frozenSfs = freezeCol sfs' dt

                        -- using the callback to create the next inputs and allow changing of the SF-collection
                        (sfs'', ins') = parCallback ins outs' frozenSfs

                        env' = collapseEnvironments params env dt outs'
                        insWithEnv = distributeEnvironment params ins' env'

                        -- NOTE: although the agents make the move at the same time, when shuffling them, 
                        --          the order of collecting and distributing the messages makes a difference 
                        --          if model-semantics are relying on randomized message-ordering, then shuffling is required and has to be turned on in the params
                        (params', sfsShuffled, insShuffled) = shuffleAgents params sfs'' insWithEnv

                        -- create a continuation of this SF
                        tf' = simulateParAux params' sfsShuffled insShuffled env'


        collapseEnvironments :: SimulationParams ec l -> Environment ec l -> Double -> [AgentOut s m ec l] -> Environment ec l
        collapseEnvironments params initEnv dt outs 
            | isCollapsingEnv = runEnv collapsedEnv dt
            | otherwise = initEnv
            where
                isCollapsingEnv = isJust $ mayEnvCollapFun

                mayEnvCollapFun = simEnvCollapse params
                envCollapFun = fromJust mayEnvCollapFun

                allEnvs = map aoEnv outs
                collapsedEnv = envCollapFun allEnvs 

        distributeEnvironment :: SimulationParams ec l -> [AgentIn s m ec l] -> Environment ec l -> [AgentIn s m ec l]
        distributeEnvironment params ins env 
            | isCollapsingEnv = map (\i -> i {aiEnv = env}) ins
            | otherwise = ins
            where
                isCollapsingEnv = isJust $ simEnvCollapse params

parCallback :: [AgentIn s m ec l]
                -> [AgentOut s m ec l]
                -> [AgentBehaviour s m ec l]
                -> ([AgentBehaviour s m ec l], [AgentIn s m ec l])
parCallback oldAgentIns newAgentOuts asfs = (asfs', newAgentIns')
    where
        (asfs', newAgentIns) = processAgents asfs oldAgentIns newAgentOuts
        newAgentIns' = distributeMessages newAgentIns newAgentOuts

        processAgents :: [AgentBehaviour s m ec l]
                            -> [AgentIn s m ec l]
                            -> [AgentOut s m ec l]
                            -> ([AgentBehaviour s m ec l], [AgentIn s m ec l])
        processAgents asfs oldIs newOs = foldr handleAgent ([], []) asfsIsOs
            where
                asfsIsOs = zip3 asfs oldIs newOs

                handleAgent :: (AgentBehaviour s m ec l, AgentIn s m ec l, AgentOut s m ec l)
                                -> ([AgentBehaviour s m ec l], [AgentIn s m ec l])
                                -> ([AgentBehaviour s m ec l], [AgentIn s m ec l])
                handleAgent  a@(_, oldIn, newOut) acc = handleKillOrLiveAgent acc' a
                    where
                        idGen = aiIdGen oldIn
                        acc' = handleCreateAgents idGen newOut acc 

                handleKillOrLiveAgent :: ([AgentBehaviour s m ec l], [AgentIn s m ec l])
                                            -> (AgentBehaviour s m ec l, AgentIn s m ec l, AgentOut s m ec l)
                                            -> ([AgentBehaviour s m ec l], [AgentIn s m ec l])
                handleKillOrLiveAgent acc@(asfsAcc, ainsAcc) (sf, oldIn, newOut)
                    | killAgent = acc
                    | otherwise = (sf : asfsAcc, newIn : ainsAcc) 
                    where
                        killAgent = isEvent $ aoKill newOut
                        newIn = newAgentIn oldIn newOut
----------------------------------------------------------------------------------------------------------------------


----------------------------------------------------------------------------------------------------------------------
-- utils
----------------------------------------------------------------------------------------------------------------------
newAgentIn :: AgentIn s m ec l -> AgentOut s m ec l -> AgentIn s m ec l
newAgentIn oldIn newOut = oldIn { aiStart = NoEvent,
                                aiState = (aoState newOut),
                                aiMessages = NoEvent,
                                aiEnvPos = (aoEnvPos newOut),
                                aiEnv = (aoEnv newOut),
                                aiRng = aoRng newOut }


shuffleAgents :: SimulationParams ec l 
                    -> [AgentBehaviour s m ec l] 
                    -> [AgentIn s m ec l] 
                    -> (SimulationParams ec l, [AgentBehaviour s m ec l], [AgentIn s m ec l])
shuffleAgents params sfs ins 
    | doShuffle = (params', sfs', ins')
    | otherwise = (params, sfs, ins)
    where
        doShuffle = simShuffleAgents params
        g = simRng params 

        sfsIns = zip sfs ins
        (shuffledSfsIns, g') = fisherYatesShuffle g sfsIns

        params' = params { simRng = g' }
        (sfs', ins') = foldr (\(sf, i) (sfAcc, insAcc) -> (sf : sfAcc, i : insAcc)) ([], []) shuffledSfsIns

-- Taken from https://wiki.haskell.org/Random_shuffle
-- | Randomly shuffle a list without the IO Monad
--   /O(N)/
fisherYatesShuffle :: RandomGen g => g -> [a] -> ([a], g)
fisherYatesShuffle gen [] = ([], gen)
fisherYatesShuffle gen l = 
  toElems $ foldl fisherYatesStep (initial (head l) gen) (numerate (tail l))
  where
    toElems (x, y) = (Map.elems x, y)
    numerate = zip [1..]
    initial x gen = (Map.singleton 0 x, gen)

    fisherYatesStep :: RandomGen g => (Map.Map Int a, g) -> (Int, a) -> (Map.Map Int a, g)
    fisherYatesStep (m, gen) (i, x) = ((Map.insert j x . Map.insert i (m Map.! j)) m, gen')
      where
        (j, gen') = randomR (0, i) gen
-----------------------------------------------------------------------------------

runEnv :: Environment c l -> DTime -> Environment c l
runEnv env dt
    | isNothing mayEnvBeh = env
    | otherwise = env' { envBehaviour = Just envSF' }
    where
        mayEnvBeh = envBehaviour env

        envSF = fromJust mayEnvBeh
        (envSF', env') = runAndFreezeSF envSF env dt

handleCreateAgents :: TVar Int
                        -> AgentOut s m ec l
                        -> ([AgentBehaviour s m ec l], [AgentIn s m ec l])
                        -> ([AgentBehaviour s m ec l], [AgentIn s m ec l])
handleCreateAgents idGen o acc@(asfsAcc, ainsAcc) 
    | hasCreateAgents = (asfsAcc ++ newSfs, ainsAcc ++ newAis)
    | otherwise = acc
    where
        newAgentInheritedEnvironment = aoEnv o
        newAgentDefsEvt = aoCreate o
        hasCreateAgents = isEvent newAgentDefsEvt
        newAgentDefs = fromEvent newAgentDefsEvt
        newSfs = map adBeh newAgentDefs
        newAis = map (startingAgentInFromAgentDef newAgentInheritedEnvironment idGen) newAgentDefs


collectMessagesFor :: [AgentOut s m ec l] -> AgentIn s m ec l -> AgentIn s m ec l
collectMessagesFor aouts ai = ai { aiMessages = msgsEvt }
    where
        aid = aiId ai
        aiMsgs = aiMessages ai
        msgsEvt = foldr (\ao accMsgs -> mergeMessages (collectMessagesFrom aid ao) accMsgs) aiMsgs aouts

collectMessagesFrom :: AgentId -> AgentOut s m ec l -> Event [AgentMessage m]
collectMessagesFrom aid ao = foldr (\(receiverId, m) accMsgs-> if receiverId == aid then
                                                                mergeMessages (Event [(senderId, m)]) accMsgs
                                                                else
                                                                    accMsgs) NoEvent msgs
    where
        senderId = aoId ao
        msgsEvt = aoMessages ao
        msgs = if isEvent msgsEvt then
                    fromEvent msgsEvt
                    else
                        []


distributeMessages = distributeMessagesFast

distributeMessagesSlow :: [AgentIn s m ec l] -> [AgentOut s m ec l] -> [AgentIn s m ec l]
distributeMessagesSlow ains aouts = map (collectMessagesFor aouts) ains

distributeMessagesFast :: [AgentIn s m ec l] -> [AgentOut s m ec l] -> [AgentIn s m ec l]
distributeMessagesFast ains aouts = map (distributeMessagesAux allMsgs) ains
    where
        allMsgs = collectAllMessages aouts

        distributeMessagesAux :: Map.Map AgentId [AgentMessage m]
                                    -> AgentIn s m ec l
                                    -> AgentIn s m ec l
        distributeMessagesAux allMsgs ain = ain { aiMessages = msgsEvt }
            where
                receiverId = aiId ain
                mayReceiverMsgs = Map.lookup receiverId allMsgs
                msgsEvt = maybe NoEvent (\receiverMsgs -> Event receiverMsgs) mayReceiverMsgs

collectAllMessages :: [AgentOut s m ec l] -> Map.Map AgentId [AgentMessage m]
collectAllMessages aos = foldr collectAllMessagesAux Map.empty aos
    where
        collectAllMessagesAux :: AgentOut s m ec l 
                                    -> Map.Map AgentId [AgentMessage m]
                                    -> Map.Map AgentId [AgentMessage m]
        collectAllMessagesAux ao accMsgs 
            | isEvent msgsEvt = foldr collectAllMessagesAuxAux accMsgs (fromEvent msgsEvt)
            | otherwise = accMsgs
            where
                senderId = aoId ao
                msgsEvt = aoMessages ao

                collectAllMessagesAuxAux :: AgentMessage m
                                            -> Map.Map AgentId [AgentMessage m]
                                            -> Map.Map AgentId [AgentMessage m]
                collectAllMessagesAuxAux (receiverId, m) accMsgs = Map.insert receiverId newMsgs accMsgs
                    where
                        mayReceiverMsgs = Map.lookup receiverId accMsgs
                        msg = (senderId, m)

                        newMsgs = maybe [msg] (\receiverMsgs -> (msg : receiverMsgs)) mayReceiverMsgs
----------------------------------------------------------------------------------------------------------------------