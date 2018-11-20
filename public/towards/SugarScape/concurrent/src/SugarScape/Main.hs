module Main where

import Data.Char
import Data.List
--import System.IO

import Options.Applicative

import SugarScape.Export.ExportRunner
import SugarScape.Visual.GlossRunner
import SugarScape.Visual.Renderer
import SugarScape.Core.Scenario
import SugarScape.Core.Simulation

data Output = File Int String  -- steps, filename
            | Visual Int AgentColoring SiteColoring  -- render-freq, agent vis, site-vis

instance Show Output where
  show (File steps file)   = "FILE " ++ show steps ++ " " ++ show file ++ 
                              " (write output of " ++ show steps ++ " steps to file " ++ show file ++ ")"
  show (Visual 0 ac sc) = "VISUAL MAX " ++ show ac ++ " " ++ show sc ++
                              " (render as many steps per second possible, Agent-Coloring: " ++ show ac ++ 
                              ", Site-Coloring: " ++ show sc ++ ")"
  show (Visual freq ac sc) = "VISUAL "  ++ show freq ++ " " ++ show ac ++ " " ++ show sc ++
                              " (render " ++ show freq ++ 
                              " steps per second, Agent-Coloring: " ++ show ac ++ 
                              ", Site-Coloring: " ++ show sc ++ ")"

data Options = Options 
  { optScenario :: String
  , optOutput   :: Output
  , optRngSeed  :: Maybe Int
  }

-- clear & stack exec -- sugarscape-concurrent -s "Animation II-1" -f 1000 -o export/dynamics.m -r 42
-- clear & stack exec -- sugarscape-concurrent -s "Animation II-1" -v 0 --ac Disease --sc Resource -r 42

-- TODO
-- check if self-messaging works: does it result in a retry if a thread enqueues a message to the tqueue it has read before?
-- fix bug with continuations
-- remove unsafePerformIO for reading Environment in Renderer and Tests
-- fix space leak 
-- remove busy waiting in main-thread with cleverer technique, results in loads of retries

main :: IO ()
main = do
    --hSetBuffering stdout NoBuffering
    o <- execParser opts
    runSugarscape o
  where
    opts = info (parseOptions <**> helper)
      ( fullDesc
     <> progDesc "Full implementation of the famous SugarScape model by J. Epstein and R. Axtell.")

runSugarscape :: Options -> IO ()
runSugarscape opts = do
  let scenarioName = optScenario opts
      ms           = findScenario scenarioName sugarScapeScenarios

  case ms of
    Nothing -> putStrLn $ "Couldn't find scenario " ++ show scenarioName ++ ", exit."
    Just scenario -> do
      let output    = optOutput opts
          rngSeed   = optRngSeed opts

      (initSimState, initOut, scenario') <- initSimulationOpt rngSeed scenario

      putStrLn "Running Sugarscape with... " 
      putStrLn "--------------------------------------------------"
      print scenario'
      putStrLn "--------------------------------------------------"

      putStrLn $ "RNG Seed: \t\t\t" ++ maybe "N/A - using default global random number initialisation" show rngSeed
      putStrLn $ "Output Type: \t\t\t" ++ show output
      putStrLn "--------------------------------------------------"

      case output of 
        File steps file   -> writeSimulationUntil file steps initSimState
        Visual freq av cv -> runGloss scenario' initSimState initOut freq av cv

      putStrLn "\n--------------------------------------------------\n"

findScenario :: String 
             -> [SugarScapeScenario]
             -> Maybe SugarScapeScenario
findScenario name0 
    = find (\s -> strToLower (sgScenarioName s) == name)
  where
    strToLower = map toLower
    name       = strToLower name0

parseOptions :: Parser Options
parseOptions 
  = Options 
    <$> strOption
      (  long "scenario"
      <> short 's'
      <> metavar "String"
      <> help "SugarScape scenario to run e.g. \"Animation II-2\"")
    <*> parseOutput
    <*> optional (option auto  
      ( long "rng" 
      <> short 'r'
      <> help "Fixing rng seed" 
      <> metavar "Int"))

parseOutput :: Parser Output
parseOutput = fileOut    <|> 
              visualOut

fileOut :: Parser Output
fileOut = File 
        <$> option auto
          (  long "fileout"
          <> short 'f'
          <> help "Write each step to output file"
          <> value 1000
          <> metavar "Int" )
        <*> strOption
          (  long "output"
          <> short 'o'
          <> value "export/dynamics.m"
          <> metavar "String"
          <> help "Output file")
      
visualOut :: Parser Output
visualOut = Visual 
         <$> option auto
           (  long "visual"
           <> short 'v'
           <> help "Visual steps calculated per second without upper limit of steps calculated in total (infinitely running)"
           <> value 0
           <> metavar "Int" )
        <*> option auto
           (  long "ac"
           <> help "Coloring of agents"
           <> value Default
           <> metavar "Default | Gender | Culture | Tribe | Welfare | Disease")
        <*> option auto
           (  long "sc"
           <> help "Coloring of sites"
           <> value Resource
           <> metavar "Resource | Polution")