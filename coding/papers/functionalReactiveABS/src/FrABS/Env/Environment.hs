{-# LANGUAGE Arrows #-}
module FrABS.Env.Environment where

import Data.Array.IArray
import System.Random

{-
an Environment is a container which contains Agents and allows them to move arround
    => assigns an agent a position within a space
    => allows an agent to query its neighbourhood within this space
    => allows an agent to change its location
    => has a signal-function which is invoked once per iteration to allow the environment to behave e.g. regrow ressources which were harvested by the agents
-}

-- TODO: continuous environment: instead of Int, use Double -> can we do this by params?
    -- or use type-classes?
-- TODO: can we generalize to higher dimensions?
-- TODO: graph environment: no geometrical space => no position but only neighbours

data (Num d) => EnvCoordGeneric d = EnvCoordGeneric (d, d)
type EnvironmentBehaviour c = (Environment c -> Environment c)
type EnvCoord = (Int, Int)
type EnvLimits = (Int, Int)
type EnvNeighbourhood = [(Int, Int)]
data EnvWrapping = ClipToMax | WrapHorizontal | WrapVertical | WrapBoth

-- TODO: mapping of agent -> coordinate
data Environment c = Environment {
    envBehaviour :: Maybe (EnvironmentBehaviour c),
    envLimits :: EnvLimits,
    envNeighbourhood :: EnvNeighbourhood,
    envWrapping :: EnvWrapping,
    envCells :: Array EnvCoord c
}

createEnvironment :: Maybe (EnvironmentBehaviour c) ->
                        EnvLimits ->
                        EnvNeighbourhood ->
                        EnvWrapping ->
                        [(EnvCoord, c)] ->
                        Environment c
createEnvironment beh
                    l@(xLimit, yLimit)
                    n
                    w
                    cs = Environment {
                             envBehaviour = beh,
                             envLimits = l,
                             envNeighbourhood = n,
                             envWrapping = w,
                             envCells = arr
                         }
    where
        arr = array ((0, 0), (xLimit - 1, yLimit - 1)) cs

updateEnvironmentCells :: Environment c -> (c -> c) -> Environment c
updateEnvironmentCells env mecf = env { envCells = ec' }
    where
        ec = envCells env
        ec' = amap mecf ec

changeCellAt :: Environment c -> EnvCoord -> c -> Environment c
changeCellAt env coord c = env { envCells = arr' }
    where
        arr = envCells env
        arr' = arr // [(coord, c)]

cellsAt :: Environment c -> [EnvCoord] -> [c]
cellsAt env cs = map (arr !) cs
    where
        arr = envCells env

cellAt :: Environment c -> EnvCoord -> c
cellAt env coord = arr ! coord
    where
        arr = envCells env

randomCell :: (RandomGen g) => g -> Environment c -> (c, EnvCoord, g)
randomCell g env = (randCell, randCoord, g'')
    where
        (maxX, maxY) = envLimits env
        (randX, g') = randomR (0, maxX - 1) g
        (randY, g'') = randomR (0, maxY - 1) g'
        randCoord = (randX, randY)
        randCell = cellAt env randCoord

randomCellWithRadius :: (RandomGen g) => g -> Environment c -> EnvCoord -> Int -> (c, EnvCoord, g)
randomCellWithRadius g env (x, y) r = (randCell, randCoord', g'')
    where
        (randX, g') = randomR (-r, r) g
        (randY, g'') = randomR (-r, r) g'
        randCoord = (x + randX, y + randY)
        randCoord' = wrap (envLimits env) (envWrapping env) randCoord
        randCell = cellAt env randCoord'

-- TODO: use wrap-settings, this discharges coords outside
neighbours :: Environment c -> EnvCoord -> [c]
neighbours env coord@(x, y) = cellsAt env clippedCoords
    where
        n = (envNeighbourhood env)
        l = (envLimits env)
        unclippedCoords = neighbourhoodOf coord n
        clippedCoords = filter (\c -> validCoord c l ) unclippedCoords

        validCoord :: EnvCoord -> EnvLimits -> Bool
        validCoord (x, y) (xMax, yMax)
            | x < 0 = False
            | y < 0 = False
            | x >= xMax = False
            | y >= yMax = False
            | otherwise = True


------------------------------------------------------------------------------------------------------------------------
-- GENERAL SPATIAL
------------------------------------------------------------------------------------------------------------------------
wrapNeighbourhood :: EnvLimits -> EnvWrapping -> EnvNeighbourhood -> EnvNeighbourhood
wrapNeighbourhood l w ns = map (wrap l w) ns

------------------------------------------------------------------------------------------------------------------------
-- 2D DISCRETE SPATIAL
------------------------------------------------------------------------------------------------------------------------
-- TODO: is not yet correct
wrap :: EnvLimits -> EnvWrapping -> EnvCoord -> EnvCoord
wrap (maxX, maxY) ClipToMax (x, y) = (max 0 (min x (maxX - 1)), max 0 (min y (maxY - 1)))
wrap (maxX, maxY) WrapHorizontal (x, y) = (min x (x - maxX - 1), y)
wrap (maxX, maxY) WrapVertical (x, y) = (x, min y (y - maxY - 1))
wrap (maxX, maxY) WrapBoth (x, y) = (min x (x - maxX - 1), min y (y - maxY - 1))

neighbourhoodOf :: EnvCoord -> EnvNeighbourhood -> EnvNeighbourhood
neighbourhoodOf (x,y) ns = map (\(x', y') -> (x + x', y + y')) ns

-- NOTE: neumann-neighbourhood only exists in discrete spatial environments
neumann :: EnvNeighbourhood
neumann = [topDelta, leftDelta, rightDelta, bottomDelta]
neumannSelf :: EnvNeighbourhood
neumannSelf = [topDelta, leftDelta, centerDelta, rightDelta, bottomDelta]

-- NOTE: moore-neighbourhood only exists in discrete spatial environments
moore :: EnvNeighbourhood
moore = [topLeftDelta, topDelta, topRightDelta,
         leftDelta, rightDelta,
         bottomLeftDelta, bottomDelta, bottomRightDelta]
mooreSelf :: EnvNeighbourhood
mooreSelf = [topLeftDelta, topDelta, topRightDelta,
             leftDelta, centerDelta, rightDelta,
             bottomLeftDelta, bottomDelta, bottomRightDelta]

topLeftDelta =       (-1, -1)
topDelta =           ( 0, -1)
topRightDelta =      ( 1, -1)
leftDelta =          (-1,  0)
centerDelta =        ( 0,  0)
rightDelta =         ( 1,  0)
bottomLeftDelta =    (-1,  1)
bottomDelta =        ( 0,  1)
bottomRightDelta =   ( 1,  1)
------------------------------------------------------------------------------------------------------------------------

