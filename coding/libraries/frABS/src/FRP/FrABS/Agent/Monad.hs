{-# LANGUAGE Arrows #-}
module FRP.FrABS.Agent.Monad (
    agentIdM,
    environmentM,
    -- environmentPositionM,
    -- changeEnvironmentPositionM,

    createAgentM,
    killM,
    isDeadM,

    sendMessageM,
    sendMessagesM,
    broadcastMessageM,
    onMessageM,
    onMessageMState,

    conversationM,
    conversationEndM,
    conversationReplyMonadicRunner,
    conversationIgnoreReplyMonadicRunner,

    updateDomainStateM,
    getDomainStateM,
    setDomainStateM,
    domainStateFieldM,

    runEnvironmentM,

    agentMonadic,

    ifThenElse,
    ifThenElseM
  ) where

import FRP.FrABS.Agent.Agent

import FRP.Yampa

import Control.Monad
import Control.Monad.Trans.State

------------------------------------------------------------------------------------------------------------------------
-- Monadic Agent Functions
------------------------------------------------------------------------------------------------------------------------
agentIdM :: State (AgentOut s m e) AgentId
agentIdM = state (\ao -> (aoId ao, ao))

environmentM :: State (AgentOut s m e) e
environmentM = state (\ao -> (aoEnv ao, ao))

{-
environmentPositionM :: State (AgentOut s m e) EnvCoord
environmentPositionM = state (\ao -> (aoEnvPos ao, ao))

changeEnvironmentPositionM :: EnvCoord -> State (AgentOut s m e) ()
changeEnvironmentPositionM pos = state (\ao -> ((), ao { aoEnvPos = pos }))
-}

sendMessageM :: AgentMessage m -> State (AgentOut s m e) ()
sendMessageM msg = state (\ao -> ((), sendMessage msg ao))

conversationM :: AgentMessage m
                -> AgentConversationSender s m e
                -> State (AgentOut s m e) ()
conversationM msg replyHdl = state (\ao -> ((), conversation msg replyHdl ao))

conversationEndM :: State (AgentOut s m e) ()
conversationEndM = state (\ao -> ((), conversationEnd ao))

sendMessagesM :: [AgentMessage m] -> State (AgentOut s m e) ()
sendMessagesM msgs = state (\ao -> ((), sendMessages msgs ao))

broadcastMessageM :: m -> [AgentId] -> State (AgentOut s m e) ()
broadcastMessageM m receiverIds = state (broadcastMessageMAux m)
    where
        broadcastMessageMAux :: m -> AgentOut s m e -> ((), AgentOut s m e)
        broadcastMessageMAux m ao = ((), sendMessages msgs ao)
            where
                n = length receiverIds
                ms = replicate n m
                msgs = zip receiverIds ms

createAgentM :: AgentDef s m e -> State (AgentOut s m e) ()
createAgentM newDef = state (\ao -> ((),createAgent newDef ao))

conversationReplyMonadicRunner :: (Maybe (AgentMessage m) -> State (AgentOut s m e) ()) 
                                    -> AgentConversationSender s m e
conversationReplyMonadicRunner replyAction ao mayReply = execState (replyAction mayReply) ao

conversationIgnoreReplyMonadicRunner :: State (AgentOut s m e) () -> AgentConversationSender s m e
conversationIgnoreReplyMonadicRunner replyAction ao _ = execState replyAction ao

killM :: State (AgentOut s m e) ()
killM = state (\ao -> ((), ao { aoKill = Event () }))

isDeadM :: State (AgentOut s m e) Bool
isDeadM = state (\ao -> (isDead ao, ao))
   
onMessageMState :: (AgentMessage m -> State acc ()) -> AgentIn s m e -> State acc ()
onMessageMState msgHdl ai = onMessageM (\_ msg -> msgHdl msg) ai ()

onMessageM :: (Monad mon) => (acc -> AgentMessage m -> mon acc) -> AgentIn s m e -> acc -> mon acc
onMessageM msgHdl ai acc
    | not hasMessages = return acc
    -- | otherwise = foldM (\acc msg -> msgHdl acc msg) acc msgs
    | otherwise = foldM msgHdl acc msgs
    where
        msgsEvt = aiMessages ai
        hasMessages = isEvent msgsEvt
        msgs = fromEvent msgsEvt
    
updateDomainStateM :: (s -> s) -> State (AgentOut s m e) ()
updateDomainStateM f = state (updateDomainStateMAux f)
    where
        updateDomainStateMAux :: (s -> s) 
                            -> AgentOut s m e 
                            -> ((), AgentOut s m e)
        updateDomainStateMAux f ao = ((), updateDomainState f ao)

setDomainStateM :: s -> State (AgentOut s m e) ()
setDomainStateM s = state (\ao -> ((), setDomainState s ao))

domainStateFieldM :: (s -> t) -> State (AgentOut s m e) t
domainStateFieldM f = state (domainStateFieldMAux f)
    where
        domainStateFieldMAux :: (s -> t) 
                            -> AgentOut s m e
                            -> (t, AgentOut s m e)
        domainStateFieldMAux f ao = (f s, ao)
            where
                s = aoState ao

runEnvironmentM :: State e a -> State (AgentOut s m e) a
runEnvironmentM envStateTrans =
    do
        env <- environmentM 
        let (a, env') = runState envStateTrans env
        setEnvironmentM env'
        return a

setEnvironmentM :: e -> State (AgentOut s m e) ()
setEnvironmentM env =
    do
        ao <- get 
        put $ ao { aoEnv = env }

getDomainStateM :: State (AgentOut s m e) s
getDomainStateM = 
    do
        ao <- get
        let domainState = aoState ao 
        return domainState

agentMonadic :: (Double -> AgentIn s m e -> State (AgentOut s m e) ()) -> AgentBehaviour s m e
agentMonadic f = proc ain ->
    do
        age <- time -< 0

        let ao = agentOutFromIn ain
        let ao' = execState (f age ain) ao
        
        returnA -< ao'

------------------------------------------------------------------------------------------------------------------------
-- Monadic Utility Functions
------------------------------------------------------------------------------------------------------------------------
ifThenElse :: Monad m => Bool -> m a -> m a -> m a
ifThenElse p trueAction falseAction = if p then trueAction else falseAction

ifThenElseM :: Monad m => m Bool -> m a -> m a -> m a
ifThenElseM test trueAction falseAction = test >>= \t -> if t then trueAction else falseAction
------------------------------------------------------------------------------------------------------------------------