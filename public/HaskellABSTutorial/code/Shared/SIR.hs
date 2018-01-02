module SIR
  (
    SIRState (..)

  , contactRate
  , infectivity
  , illnessDuration
  
  , aggregateAllStates
  , aggregateStates
  , writeAggregatesToFile
  ) where

import System.IO
import Text.Printf

data SIRState = Susceptible | Infected | Recovered deriving (Show, Eq)

contactRate :: Double
contactRate = 5.0

infectivity :: Double
infectivity = 0.05

illnessDuration :: Double
illnessDuration = 15.0

aggregateAllStates :: [[SIRState]] -> [(Int, Int, Int)]
aggregateAllStates = map aggregateStates

aggregateStates :: [SIRState] -> (Int, Int, Int)
aggregateStates as = (susceptibleCount, infectedCount, recoveredCount)
  where
    susceptibleCount = length $ filter (Susceptible==) as
    infectedCount = length $ filter (Infected==) as
    recoveredCount = length $ filter (Recovered==) as

writeAggregatesToFile :: String -> [(Int, Int, Int)] -> IO ()
writeAggregatesToFile fileName dynamics = do
  fileHdl <- openFile fileName WriteMode
  hPutStrLn fileHdl "dynamics = ["
  mapM_ (hPutStrLn fileHdl . sirAggregateToString) dynamics
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

sirAggregateToString :: (Int, Int, Int) -> String
sirAggregateToString (susceptibleCount, infectedCount, recoveredCount) =
  printf "%d" susceptibleCount
  ++ "," ++ printf "%d" infectedCount
  ++ "," ++ printf "%d" recoveredCount
  ++ ";"