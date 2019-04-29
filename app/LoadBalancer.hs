{-# LANGUAGE ScopedTypeVariables #-}

module Main where

import Control.Monad (replicateM, forM_, forever)
import Control.Monad.Random.Class (getRandomR)
import Data.Random.Source.PureMT (newPureMT)
import Deli (Channel, Deli, JobTiming(..))
import Deli.Printer (printResults)
import System.Random
import qualified Deli
import qualified Deli.Random

createWorker
    :: Deli JobTiming (Channel JobTiming)
createWorker = do
    workerChannel <- Deli.newChannel Nothing
    Deli.fork $ forever $ do
        job <- Deli.readChannel workerChannel
        Deli.runJob job
    return workerChannel

roundRobinWorkers
    :: Int
    -> Channel JobTiming
    -> Deli JobTiming ()
roundRobinWorkers num jobChannel = do
    chans :: [Channel JobTiming] <- replicateM num createWorker
    -- create an infinite list of all channels, repeated,
    -- then for each one, read from main queue, and write
    -- to the worker's queue
    let roundRobinList = cycle chans
    forM_ roundRobinList $ \worker -> do
        job <- Deli.readChannel jobChannel
        Deli.writeChannel worker job

randomWorkers
    :: Int
    -> Channel JobTiming
    -> Deli JobTiming ()
randomWorkers num jobChannel = do
    chans :: [Channel JobTiming] <- replicateM num createWorker
    forever $ do
        randomWorkerIndex <- getRandomR (0, length chans - 1)
        let workerQueue = chans !! randomWorkerIndex
        job <- Deli.readChannel jobChannel
        Deli.writeChannel workerQueue job

loadBalancerExample :: IO ()
loadBalancerExample = do
    simulationGen <- newStdGen
    inputGen <- newPureMT
    -- Generate a poisson process of arrivals, with a mean of 650 arrivals
    -- per second
    let arrivals = Deli.Random.arrivalTimePoissonDistribution 31000
    -- Generate a Pareto distribution of service times, with a mean service
    -- time of 3 milliseconds (0.03 seconds) (alpha is set to 1.16 inside this
    -- function)
        serviceTimes = Deli.Random.durationParetoDistribution 0.5
        jobs = take 1000000 $ Deli.Random.distributionToJobs arrivals serviceTimes inputGen
        roundRobinRes = Deli.simulate simulationGen jobs (roundRobinWorkers (1018 * 8))
        randomRes = Deli.simulate simulationGen jobs (randomWorkers (1018 * 8))

    putStrLn "## Round Robin ##"
    printResults roundRobinRes
    putStrLn "## Random ##"
    printResults randomRes
    newline

    where newline = putStrLn "\n"

main :: IO ()
main = do
    loadBalancerExample
    newline

    where newline = putStrLn "\n"
