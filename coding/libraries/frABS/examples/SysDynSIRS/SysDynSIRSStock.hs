{-# LANGUAGE Arrows #-}
module SysDynSIRS.SysDynSIRSStock (
    susceptibleStock,
    infectiousStock,
    recoveredStock,

    infectionRateFlow,
    recoveryRateFlow
  ) where

import SysDynSIRS.SysDynSIRSModel

import FRP.Yampa

import FrABS.Agent.Agent
import FrABS.Agent.AgentUtils

------------------------------------------------------------------------------------------------------------------------
-- STOCKS
-- NOTE: stocks state depends only on its initial value and the integral over incoming and outgoing rates
------------------------------------------------------------------------------------------------------------------------
susceptibleStock :: SysDynSIRSStockBehaviour
susceptibleStock initValue = proc ain ->
    do
        let infectious = flowInFrom infectionRateFlowId ain

        stockValue <- (initValue+) ^<< integral -< (-infectious)
        
        let ao = agentOutFromIn ain
        let ao0 = setDomainState ao stockValue
        let ao1 = stockOutTo stockValue infectionRateFlowId ao0

        returnA -< ao1

infectiousStock :: SysDynSIRSStockBehaviour
infectiousStock initValue = proc ain ->
    do
        let infectionRate = flowInFrom infectionRateFlowId ain
        let recoveryRate = flowInFrom recoveryRateFlowId ain

        stockValue <- (initValue+) ^<< integral -< (infectionRate - recoveryRate)
        
        let ao = agentOutFromIn ain
        let ao0 = setDomainState ao stockValue
        let ao1 = stockOutTo stockValue infectionRateFlowId ao0 
        let ao2 = stockOutTo stockValue recoveryRateFlowId ao1
        
        returnA -< ao2

recoveredStock :: SysDynSIRSStockBehaviour
recoveredStock initValue = proc ain ->
    do
        let recoveryRate = flowInFrom recoveryRateFlowId ain

        stockValue <- (initValue+) ^<< integral -< recoveryRate
        
        let ao = agentOutFromIn ain
        let ao' = setDomainState ao stockValue

        returnA -< ao'
------------------------------------------------------------------------------------------------------------------------

------------------------------------------------------------------------------------------------------------------------
-- FLOWS
-- NOTE: flows are inherently stateless
------------------------------------------------------------------------------------------------------------------------
infectionRateFlow :: SysDynSIRSFlowBehaviour
infectionRateFlow = proc ain ->
    do
        let susceptible = stockInFrom susceptibleStockId ain 
        let infectious = stockInFrom infectiousStockId ain

        let flowValue = infectious * contactRate * (susceptible / totalPopulation) * infectivity
        
        let ao = agentOutFromIn ain
        let ao' = flowOutTo flowValue susceptibleStockId ao
        let ao'' = flowOutTo flowValue infectiousStockId ao'

        returnA -< ao''

-- NOTE: flows are inherently stateless
recoveryRateFlow :: SysDynSIRSFlowBehaviour
recoveryRateFlow = proc ain ->
    do
        let infectious = stockInFrom infectiousStockId ain

        let flowValue = infectious / avgIllnessDuration
        
        let ao = agentOutFromIn ain
        let ao' = flowOutTo flowValue infectiousStockId ao
        let ao'' = flowOutTo flowValue recoveredStockId ao'

        returnA -< ao''
------------------------------------------------------------------------------------------------------------------------


------------------------------------------------------------------------------------------------------------------------
-- UTILS
------------------------------------------------------------------------------------------------------------------------
filterMessageValue :: Double -> (AgentMessage SysDynSIRSMsg) -> Double
filterMessageValue initValue (_, Value v) = v

valueInFrom :: AgentId -> SysDynSIRSIn -> Double
valueInFrom senderId ain = onMessageFrom senderId ain filterMessageValue 0.0 

valueOutTo :: Double -> AgentId -> SysDynSIRSOut -> SysDynSIRSOut
valueOutTo value receiverId ao = sendMessage ao (receiverId, Value value)

flowInFrom = valueInFrom
stockInFrom = valueInFrom

flowOutTo = valueOutTo
stockOutTo = valueOutTo
------------------------------------------------------------------------------------------------------------------------