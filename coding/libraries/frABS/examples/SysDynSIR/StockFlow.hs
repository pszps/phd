{-# LANGUAGE Arrows #-}
module SysDynSIR.StockFlow (
    susceptibleStock,
    infectiousStock,
    recoveredStock,

    infectionRateFlow,
    recoveryRateFlow
  ) where

import SysDynSIR.Model

import FRP.Yampa

import FRP.FrABS

------------------------------------------------------------------------------------------------------------------------
-- STOCKS
-- NOTE: stocks state depends only on its initial value and the integral over incoming and outgoing rates
------------------------------------------------------------------------------------------------------------------------
susceptibleStock :: Stock
susceptibleStock initValue = proc ain ->
    do
        let infectionRate = flowInFrom infectionRateFlowId ain

        stockValue <- (initValue+) ^<< integral -< (-infectionRate)
        
        let ao = agentOutFromIn ain
        let ao0 = setDomainState stockValue ao
        let ao1 = stockOutTo stockValue infectionRateFlowId ao0

        returnA -< ao1

infectiousStock :: Stock
infectiousStock initValue = proc ain ->
    do
        let infectionRate = flowInFrom infectionRateFlowId ain
        let recoveryRate = flowInFrom recoveryRateFlowId ain

        stockValue <- (initValue+) ^<< integral -< (infectionRate - recoveryRate)
        
        let ao = agentOutFromIn ain
        let ao0 = setDomainState stockValue ao
        let ao1 = stockOutTo stockValue infectionRateFlowId ao0 
        let ao2 = stockOutTo stockValue recoveryRateFlowId ao1
        
        returnA -< ao2

recoveredStock :: Stock
recoveredStock initValue = proc ain ->
    do
        let recoveryRate = flowInFrom recoveryRateFlowId ain

        stockValue <- (initValue+) ^<< integral -< recoveryRate
        
        let ao = agentOutFromIn ain
        let ao' = setDomainState stockValue ao

        returnA -< ao'
------------------------------------------------------------------------------------------------------------------------

------------------------------------------------------------------------------------------------------------------------
-- FLOWS
-- NOTE: flows are inherently stateless
------------------------------------------------------------------------------------------------------------------------
infectionRateFlow :: Flow
infectionRateFlow = proc ain ->
    do
        let susceptible = stockInFrom susceptibleStockId ain 
        let infectious = stockInFrom infectiousStockId ain

        let flowValue = (infectious * contactRate * susceptible * infectivity) / totalPopulation
        
        let ao = agentOutFromIn ain
        let ao' = flowOutTo flowValue susceptibleStockId ao
        let ao'' = flowOutTo flowValue infectiousStockId ao'

        returnA -< ao''

-- NOTE: flows are inherently stateless
recoveryRateFlow :: Flow
recoveryRateFlow = proc ain ->
    do
        let infectious = stockInFrom infectiousStockId ain

        let flowValue = infectious / avgIllnessDuration
        
        let ao = agentOutFromIn ain
        let ao' = flowOutTo flowValue infectiousStockId ao
        let ao'' = flowOutTo flowValue recoveredStockId ao'

        returnA -< ao''
------------------------------------------------------------------------------------------------------------------------