{-# LANGUAGE Arrows                #-}

module Main where 

-- first import: base
import           Data.Maybe
import           Text.Printf
import           System.IO

-- second import: 3rd party libraries
import           Control.Monad.Random
import           Control.Monad.State.Strict
import           Data.MonadicStreamFunction
import qualified Data.Map as Map
import qualified Data.PQueue.Min as PQ
-- import           Debug.Trace

-- third import: project local
-- none

type EventId      = Integer
type Time         = Double
type AgentId      = Int
newtype Event e   = Event e deriving Show
data QueueItem e  = QueueItem AgentId (Event e) Time deriving Show
type EventQueue e = PQ.MinQueue (QueueItem e)

instance Eq (QueueItem e) where
  (==) (QueueItem _ _ t1) (QueueItem _ _ t2) = t1 == t2

instance Ord (QueueItem e) where
  compare (QueueItem _ _ t1) (QueueItem _ _ t2) = compare t1 t2

data ABSState e s = ABSState
  { absEvtQueue    :: EventQueue e
  , absTime        :: Time
  , absAgents      :: Map.Map AgentId (AgentCont e s)
  , absAgentIds    :: [AgentId]
  , absEvtCount    :: Integer

  , absDomainState :: s
  }

<<<<<<< HEAD:public/purefunctionalepidemics/code/Step7_EventDriven/src/Main.hs
-- TODO: use StateT
=======
>>>>>>> 9a2e606ae003ee48a1900211808bac9e465c6aa2:public/dependenttypesabs/code/Step1_HaskellDESABS/src/Main.hs
type ABSMonad e s  = State (ABSState e s)
type AgentCont e s = MSF (ABSMonad e s) e ()
type Agent e s     = AgentId -> State (ABSState e s) (AgentCont e s)

type SIRDomainState = (Int, Int, Int)

data SIRState 
  = Susceptible
  | Infected
  | Recovered
  deriving (Show, Eq)

data SIREvent 
  = MakeContact
  | Contact AgentId SIRState
  | Recover 
  deriving Show

-- TODO: add Rand Monad into stack
type SIRAgent     = Agent SIREvent SIRDomainState
type SIRAgentCont = AgentCont SIREvent SIRDomainState

rngSeed :: Int
rngSeed = 42

agentCount :: Int
agentCount = 1000

infectedCount :: Int
infectedCount = 10

-- use negative number for unlimited number of events
maxEvents :: Integer
maxEvents = -1 

-- use 1 / 0 for unrestricted time
maxTime :: Double
maxTime = 160.0

makeContactInterval :: Double
makeContactInterval = 1.0

contactRate :: Int
contactRate = 5

infectivity :: Double
infectivity = 0.05

illnessDuration :: Double
illnessDuration = 15.0

main :: IO ()
main = do
  let g = mkStdGen rngSeed
  let (as, _g') = runRand (initAgents agentCount infectedCount) g

  let (t, evtCount, ss) = runABS as (0, 0, 0) maxEvents maxTime 1.0

  print $ "Finished at t = " ++ show t ++ 
          ", after " ++ show evtCount ++ 
          " events"
          
  let ss' = map (\(s, i, r) -> (fromIntegral s, fromIntegral i, fromIntegral r)) ss
  writeDynamicsToFile ("ABS_DES_" ++ show agentCount ++ "agents.m") ss'

initAgents :: RandomGen g => Int -> Int -> Rand g [SIRAgent]
initAgents n nInf = do
    susAs <- forM [1..n - nInf] (const $ createAgent Susceptible)
    infAs <- forM [1..nInf] (const $ createAgent Infected)
    return $ susAs ++ infAs
  where
    createAgent :: RandomGen g => SIRState -> Rand g SIRAgent
    createAgent s = getSplit >>= \g -> return $ sirAgent s g

-- | A sir agent which is in one of three states
sirAgent :: RandomGen g 
         => SIRState    -- ^ the initial state of the agent
         -> g           -- ^ the initial random-number generator
         -> SIRAgent    -- ^ the continuation
sirAgent Susceptible g0 aid = do
    -- on start
    modifyDomainState incSus
    scheduleEvent aid MakeContact makeContactInterval
    return $ susceptibleAgent aid g0
sirAgent Infected g0 aid = do
    -- on start
    modifyDomainState incInf
    let (dt, _) = runRand (randomExpM (1 / illnessDuration)) g0
    scheduleEvent aid Recover dt
    return $ infectedAgent aid
sirAgent Recovered _ _ = modifyDomainState incRec >> return recoveredAgent

susceptibleAgent :: RandomGen g => AgentId -> g -> SIRAgentCont
susceptibleAgent aid g0 = 
    switch
      susceptibleAgentInfected
      (const $ infectedAgent aid)
  where
    susceptibleAgentInfected :: MSF
                                (ABSMonad SIREvent SIRDomainState) 
                                SIREvent
                                ((), Maybe ()) 
    susceptibleAgentInfected = feedback g0 (proc (e, g) ->
      case e of
        (Contact _ s) -> 
          if Infected == s
            then do
              let (r, g') = runRand (randomBoolM infectivity) g
              if r 
                then do
                  arrM_ $ modifyDomainState decSus -< ()
                  arrM_ $ modifyDomainState incInf -< ()
                  let (dt, g'') = runRand (randomExpM (1 / illnessDuration)) g'
                  arrM (scheduleEvent aid Recover) -< dt
                  returnA -< (((), Just ()), g'')
                else returnA -< (((), Nothing), g')
            else returnA -< (((), Nothing), g)

        MakeContact -> do
          ais <- arrM_ allAgentIds -< ()
          let (receivers, g') = runRand (forM [1..contactRate] (const $ randomElem ais)) g
          arrM (mapM_ makeContact) -< receivers
          arrM_ (scheduleEvent aid MakeContact makeContactInterval) -< ()
          returnA -< (((), Nothing), g')

        -- this will never occur for a susceptible
        Recover -> returnA -< (((), Nothing), g)) 

    makeContact :: AgentId -> State (ABSState SIREvent SIRDomainState) ()
    makeContact receiver = 
      scheduleEvent 
        receiver 
        (Contact aid Susceptible)
        0.0 -- immediate schedule

infectedAgent :: AgentId -> SIRAgentCont
infectedAgent aid = 
    switch 
      infectedAgentRecovered 
      (const recoveredAgent)
  where
    infectedAgentRecovered :: MSF 
                              (ABSMonad SIREvent SIRDomainState) 
                              SIREvent 
                              ((), Maybe ()) 
    infectedAgentRecovered = proc e ->
      case e of
        (Contact sender s) ->
          -- can we somehow replace it with 'when'?
          if Susceptible == s
            then do
              arrM replyContact -< sender
              returnA -< ((), Nothing)
            else returnA -< ((), Nothing)
        -- this will never occur for an infected agent
        MakeContact  -> returnA -< ((), Nothing) 
        Recover      -> do
          arrM_ $ modifyDomainState decInf -< ()
          arrM_ $ modifyDomainState incRec -< ()
          returnA -< ((), Just ())

    replyContact :: AgentId -> State (ABSState SIREvent SIRDomainState) ()
    replyContact receiver =
      scheduleEvent 
        receiver 
        (Contact aid Infected)
        0.0 -- immediate schedule

recoveredAgent :: SIRAgentCont
recoveredAgent = proc _e -> returnA -< ()

incSus :: (Int, Int, Int) -> (Int, Int, Int)
incSus (s, i, r) = (s+1, i, r)

decSus :: (Int, Int, Int) -> (Int, Int, Int)
decSus (s, i, r) = (s-1, i, r)

incInf :: (Int, Int, Int) -> (Int, Int, Int)
incInf (s, i, r) = (s, i+1, r)

decInf :: (Int, Int, Int) -> (Int, Int, Int)
decInf (s, i, r) = (s, i-1, r)

incRec :: (Int, Int, Int) -> (Int, Int, Int)
incRec (s, i, r) = (s, i, r+1)

runABS :: [Agent e s] 
       -> s
       -> Integer 
       -> Double
       -> Double
       -> (Time, Integer, [s])
runABS as0 s0 steps tLimit tSampling = (finalTime, finalEvtCnt, reverse domStateSamples)
  where
    abs0 = ABSState {
      absEvtQueue    = PQ.empty
    , absTime        = 0
    , absAgents      = Map.empty
    , absAgentIds    = []
    , absEvtCount    = 0
    , absDomainState = s0
    }

    asWIds = Prelude.zipWith (\a aid -> a aid) as0 [0..]

    (as0', abs') = runState (sequence asWIds) abs0
    asMap = Prelude.foldr (\(aid, a) acc -> Map.insert aid a acc) Map.empty (Prelude.zip [0..] as0')

    abs'' = abs' { 
      absAgents   = asMap
    , absAgentIds = Map.keys asMap 
    }

    (domStateSamples, finalState) = runState (stepClock steps 0 []) abs''
    finalTime   = absTime finalState
    finalEvtCnt = absEvtCount finalState

    stepClock :: Integer 
              -> Double
              -> [s]
              -> State (ABSState e s) [s]
    stepClock 0 _ acc = return acc
    stepClock n ts acc = do 
      q <- gets absEvtQueue

      -- TODO: use MaybeT 

      let mayHead = PQ.getMin q
      if isNothing mayHead 
        then return acc
        else do
          ec <- gets absEvtCount
          t <- gets absTime

          let (QueueItem aid (Event e) t') = fromJust mayHead
          let q' = PQ.drop 1 q

          -- modify time and changed queue before running the process
          -- because the process might change the queue 
          modify (\s -> s { 
            absEvtQueue = q' 
          , absTime     = t'
          , absEvtCount = ec + 1
          })

          as <- gets absAgents
          let a = fromJust $ Map.lookup aid as
          (_, a') <- unMSF a e
          let as' = Map.insert aid a' as

          modify (\s -> s { absAgents = as' })

          s <- gets absDomainState
          let (acc', ts') = if ts >= tSampling
              then (s : acc, 0)
              else (acc, ts + (t' - t))

          if t' < tLimit
            then stepClock (n-1) ts' acc'
            else return acc'
        
allAgentIds :: State (ABSState e s) [AgentId]
allAgentIds = gets absAgentIds

modifyDomainState :: (s -> s) -> State (ABSState e s) ()
modifyDomainState f = 
  modify (\s -> s { absDomainState = f $ absDomainState s })

scheduleEvent :: AgentId 
              -> e
              -> Double
              -> State (ABSState e s) ()
scheduleEvent aid e dt = do
  q <- gets absEvtQueue
  t <- gets absTime

  let qe = QueueItem aid (Event e) (t + dt)
  let q' = PQ.insert qe q

  modify (\s -> s { absEvtQueue = q' })

randomElem :: RandomGen g => [e] -> Rand g e
randomElem es = do
  let len = length es
  idx <- getRandomR (0, len - 1)
  return $ es !! idx

randomBoolM :: RandomGen g => Double -> Rand g Bool
randomBoolM p = getRandomR (0, 1) >>= (\r -> return $ r <= p)

randomExpM :: RandomGen g => Double -> Rand g Double
randomExpM lambda = avoid 0 >>= (\r -> return ((-log r) / lambda))
  where
    avoid :: (Random a, Eq a, RandomGen g) => a -> Rand g a
    avoid x = do
      r <- getRandom
      if r == x
        then avoid x
        else return r

writeDynamicsToFile :: String -> [(Double, Double, Double)] -> IO ()
writeDynamicsToFile fileName dynamics = do
  fileHdl <- openFile fileName WriteMode
  hPutStrLn fileHdl "dynamics = ["
  mapM_ (hPutStrLn fileHdl . sirDynamicToString) dynamics
  hPutStrLn fileHdl "];"

  hPutStrLn fileHdl "susceptible = dynamics (:, 1);"
  hPutStrLn fileHdl "infected = dynamics (:, 2);"
  hPutStrLn fileHdl "recovered = dynamics (:, 3);"
  hPutStrLn fileHdl "totalPopulation = susceptible(1) + infected(1) + recovered(1);"

  hPutStrLn fileHdl "susceptibleRatio = susceptible ./ totalPopulation;"
  hPutStrLn fileHdl "infectedRatio = infected ./ totalPopulation;"
  hPutStrLn fileHdl "recoveredRatio = recovered ./ totalPopulation;"

  hPutStrLn fileHdl "steps = length (susceptible);"
  hPutStrLn fileHdl "indices = 0 : steps - 1;"

  hPutStrLn fileHdl "figure"
  hPutStrLn fileHdl "plot (indices, susceptibleRatio.', 'color', 'blue', 'linewidth', 2);"
  hPutStrLn fileHdl "hold on"
  hPutStrLn fileHdl "plot (indices, infectedRatio.', 'color', 'red', 'linewidth', 2);"
  hPutStrLn fileHdl "hold on"
  hPutStrLn fileHdl "plot (indices, recoveredRatio.', 'color', 'green', 'linewidth', 2);"

  hPutStrLn fileHdl "set(gca,'YTick',0:0.05:1.0);"
  
  hPutStrLn fileHdl "xlabel ('Time');"
  hPutStrLn fileHdl "ylabel ('Population Ratio');"
  hPutStrLn fileHdl "legend('Susceptible','Infected', 'Recovered');"

  hClose fileHdl

sirDynamicToString :: (Double, Double, Double) -> String
sirDynamicToString (s, i, r) =
  printf "%f" s
  ++ "," ++ printf "%f" i
  ++ "," ++ printf "%f" r
  ++ ";"