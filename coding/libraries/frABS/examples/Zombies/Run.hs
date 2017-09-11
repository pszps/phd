module Zombies.Run (
    runZombiesWithRendering,
    runZombiesStepsAndWriteToFile
  ) where

import Zombies.Environment
import Zombies.Init
import Zombies.Renderer 
import Zombies.Model

import FRP.FrABS

import System.IO

winSize = (800, 800)
winTitle = "Zombies"
updateStrat = Sequential
shuffleAgents = False
rngSeed = 42
samplingTimeDelta = 1.0  -- NOTE: this model has no time-semantics (it does not matter if it is 1.0 or 0.1)
frequency = 0
steps = 200

runZombiesWithRendering :: IO ()
runZombiesWithRendering =
    do
        params <- initSimulation updateStrat Nothing Nothing shuffleAgents (Just rngSeed)
        (initAdefs, initEnv) <- initZombies

        simulateAndRender initAdefs
                            initEnv
                            params
                            samplingTimeDelta
                            frequency
                            winTitle
                            winSize
                            renderZombiesFrame
                            (Just printDynamics)

runZombiesStepsAndWriteToFile :: IO ()
runZombiesStepsAndWriteToFile =
    do
        params <- initSimulation updateStrat Nothing Nothing shuffleAgents (Just rngSeed)
        (initAdefs, initEnv) <- initZombies

        let asenv = processSteps initAdefs initEnv params samplingTimeDelta steps

        writeDynamics asenv

writeDynamics :: [([ZombiesAgentOut], ZombiesEnvironment)] -> IO ()
writeDynamics dynamics =
    do
        let fileName = "zombies_dynamics.m"

        fileHdl <- openFile fileName WriteMode
        
        hPutStrLn fileHdl "dynamics = ["
        mapM_ (hPutStrLn fileHdl . writeDynamicsAux) dynamics
        hPutStrLn fileHdl "];"

        hPutStrLn fileHdl "humanCount = dynamics (:, 1);"
        hPutStrLn fileHdl "zombieCount = dynamics (:, 2);"
        hPutStrLn fileHdl "figure"
        hPutStrLn fileHdl "plot (humanCount.', 'color', 'blue');"
        hPutStrLn fileHdl "hold on"
        hPutStrLn fileHdl "plot (zombieCount.', 'color', 'red');"
        hPutStrLn fileHdl "xlabel ('Steps');"
        hPutStrLn fileHdl "ylabel ('Agents');"
        hPutStrLn fileHdl "legend('Humans','Zombies');"
        hPutStrLn fileHdl ("title ('Zombie Dynamics');")

        hClose fileHdl

    where
        writeDynamicsAux :: ([ZombiesAgentOut], ZombiesEnvironment) -> String
        writeDynamicsAux (aos, _) = show humanCount ++ "," ++ show zombieCount ++ ";"
            where
                humanCount = length $ filter (\ao -> isHuman $ aoState ao) aos
                zombieCount = length $ filter (\ao -> isZombie $ aoState ao) aos

printDynamics :: ([(AgentId, ZombiesAgentState)], ZombiesEnvironment)
                    ->([(AgentId, ZombiesAgentState)], ZombiesEnvironment)
                    -> IO ()
printDynamics (aoutsPrev, _) (aoutsCurr, _) = 
    do
        let humanCount = length $ filter (\(_, s) -> isHuman s) aoutsCurr
        let zombieCount = length $ filter (\(_, s) -> isZombie s) aoutsCurr
        putStrLn (show humanCount ++ "," ++ show zombieCount ++ ";")
