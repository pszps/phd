module NewAgents.Run (
runNewAgentsSteps,

runNewAgentsDebug
) where

import FRP.Yampa

import NewAgents.Model
import NewAgents.Init

import FRP.FrABS

import System.IO

rngSeed :: Int
rngSeed = 42

dt :: DTime
dt = 1.0

agentCount :: Int
agentCount = 1

t :: Time
t = 11

updateStrat :: UpdateStrategy
updateStrat = Parallel

shuffleAgents :: Bool
shuffleAgents = False

runNewAgentsSteps :: IO ()
runNewAgentsSteps = do
  hSetBuffering stdout NoBuffering

  params <- initSimulation updateStrat Nothing Nothing shuffleAgents (Just rngSeed)
  (initAdefs, initEnv) <- initNewAgents agentCount

  let asenv = simulateTime initAdefs initEnv params dt t

  -- let (t, asFinal, _) = last asenv
  -- mapM_ printNewAgent asFinal
  -- print t
  mapM_ printStep asenv

runNewAgentsDebug :: IO ()
runNewAgentsDebug = do
    hSetBuffering stdout NoBuffering

    params <- initSimulation updateStrat Nothing Nothing shuffleAgents (Just rngSeed)
    (initAdefs, initEnv) <- initNewAgents agentCount
    
    simulateDebug initAdefs initEnv params dt renderFunc
  where
    renderFunc :: Bool -> (Time, [NewAgentObservable], NewAgentEnvironment) -> IO Bool
    renderFunc _ (_, aobs, _) = mapM_ printNewAgent aobs >> (return False)

printStep :: (Time, [NewAgentObservable], NewAgentEnvironment) -> IO ()
printStep (t, as, e) = do
  putStr $ "t = " ++ show t ++ "\n   " 
  mapM_ printNewAgent as

printNewAgent :: NewAgentObservable -> IO ()
printNewAgent (aid, s) = putStrLn $ "Agent " ++ show aid ++ ": state = " ++ show s