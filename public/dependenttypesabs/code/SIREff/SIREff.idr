module SIREff

import Debug.Trace
import Data.Vect

import Effects
import Effect.Random
import Effect.State
import Effect.StdIO

import Export

data SIRState 
  = Susceptible 
  | Infected 
  | Recovered

-- we want the dimensions in the environment, something
-- only possible with dependent types. Also we parameterise
-- over the type of the elements, basically its a matrix
Disc2dEnv : (w : Nat) -> (h : Nat) -> (e : Type) -> Type
Disc2dEnv w h e = Vect w (Vect h e)

contactRate : Double
contactRate = 5.0

infectivity : Double
infectivity = 0.05

illnessDuration : Double
illnessDuration = 15.0

Eq SIRState where
  (==) Susceptible Susceptible = True
  (==) Infected Infected = True
  (==) Recovered Recovered = True
  (==) _ _ = False

randomDouble : Eff Double [RND]
randomDouble = do
  ri <- rndInt 1 100000
  let r = cast ri / 100000
  pure r

randomExp : Double -> Eff Double [RND]
randomExp lambda = do
  r <- randomDouble
  pure $ ((-log r) / lambda)

randomBool : Double -> Eff Bool [RND]
randomBool p = do
  r <- randomDouble
  pure (p >= r)

SIRAgent : Type
SIRAgent = (SIRState, Double)

mkSusceptible : SIRAgent
mkSusceptible = (Susceptible, 0)

mkInfected : Double -> SIRAgent
mkInfected rt = (Infected, rt)

mkRecovered : SIRAgent
mkRecovered = (Recovered, 0)

recovered : Eff SIRAgent [RND]
recovered = pure mkRecovered

infected : Double -> Double -> Eff SIRAgent [RND]
infected recoveryTime dt
  = if recoveryTime - dt > 0
      then pure $ mkInfected (recoveryTime - dt)
      else pure mkRecovered

susceptible : Double -> Eff SIRAgent [RND]
susceptible infFract = do
    numContacts <- randomExp (1 / contactRate)
    infFlag     <- makeContact (fromIntegerNat $ cast numContacts) infFract
    if infFlag
      then do
        dur <- randomExp (1 / illnessDuration)
        pure $ mkInfected dur
      else pure mkSusceptible
  where
    makeContact :  Nat 
                -> Double
                -> Eff Bool [RND] -- TODO: avoid boolean blindness, produce a proof that the agent was infected 
    makeContact Z _ = pure False
    makeContact (S n) infFract = do
      flag <- randomBool (infFract * infectivity)
      if flag
        then pure True
        else makeContact n infFract

-------------------------------------------------------------------------------
createAgents :  Nat
             -> Nat
             -> Nat
             -> Eff (List SIRAgent) [RND]
createAgents susCount infCount recCount = do
    let sus = replicate susCount mkSusceptible
    let rec = replicate recCount mkRecovered
    inf <- createInfs infCount
    pure (sus ++ inf ++ rec)
  where
    createInfs : Nat -> Eff (List SIRAgent) [RND]
    createInfs Z = pure []
    createInfs (S k) = do
      dur <- randomExp (1 / illnessDuration) 
      infs' <- createInfs k
      pure $ (mkInfected dur) :: infs'

isSus : SIRAgent -> Bool
isSus (Susceptible, _) = True
isSus _ = False

isInf : SIRAgent -> Bool
isInf (Infected, _) = True
isInf _ = False

isRec : SIRAgent -> Bool
isRec (Recovered, _) = True
isRec _ = False

runAgents :  Double
          -> List SIRAgent 
          -> Eff (List (Nat, Nat, Nat)) [RND]
runAgents dt as = runAgentsAcc as []
  where
    runAgent : Double -> SIRAgent -> Eff SIRAgent [RND]
    runAgent infFract (Susceptible, _) = susceptible infFract
    runAgent _ (Infected, rt) = infected rt dt
    runAgent _ (Recovered, _) = recovered

    runAllAgents :  Double
                 -> List SIRAgent 
                 -> List SIRAgent 
                 -> Eff (List SIRAgent) [RND]
    runAllAgents _ [] acc = pure acc 
    runAllAgents infFract (a :: as) acc = do
      a' <- runAgent infFract a
      runAllAgents infFract as (a' :: acc)

    runAgentsAcc :  List SIRAgent 
                 -> List (Nat, Nat, Nat) 
                 -> Eff (List (Nat, Nat, Nat)) [RND]
    runAgentsAcc as acc = do
      let nSus = length $ filter isSus as
      let nInf = length $ filter isInf as
      let nRec = length $ filter isRec as
      
      let step = (nSus, nInf, nRec)

      if nInf == 0
        then pure (reverse (step :: acc))
        else do
          let nSum = cast {to=Double} (nSus + nRec + nInf)
          let infFract = cast {to=Double} nInf / nSum

          -- TODO: why is mapE (runAgent infFract) as not working????
          as' <- runAllAgents infFract as []
          runAgentsAcc as' (step :: acc)

runSIR : Eff (List (Nat, Nat, Nat)) [RND]
runSIR = do
  as <- createAgents 99 1 0
  runAgents 1.0 as

main : IO ()
main = do
  let dyns = runPureInit [42] runSIR
  writeMatlabFile "sirEff.m" dyns
