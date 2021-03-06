-----------------------------------------------------------------------------
-- |
-- Module     : Driver
-- Copyright  : Copyright (c) , Patrick Perry <patperry@stanford.edu>
-- License    : BSD3
-- Maintainer : Patrick Perry <patperry@stanford.edu>
-- Stability  : experimental
--

module Driver (
    Natural(..),
    Index(..),
    ListChoose(..),    
    ListPermute(..),
    SwapsPermute(..),
    CyclesPermute(..),
    Sort(..),
    SortBy(..),
    Swap(..),
    
    mytest,
    mycheck,
    mytests,
    done,

    ) where

import Control.Monad
import Data.List
import Data.Ord
import System.IO
import System.Random
import Test.QuickCheck
import Text.Printf
import Text.Show.Functions


newtype Natural = Nat Int deriving (Eq,Show)
instance Arbitrary Natural where
    arbitrary = do
        n <- arbitrary
        return $ Nat (abs n)
    
    coarbitrary = undefined

data Index = Index Int Int deriving (Eq,Show)
instance Arbitrary Index where
    arbitrary = do
        (Nat n) <- arbitrary
        i <- choose (0, n)
        return $ Index (n + 1) i

    coarbitrary = undefined

data ListChoose = ListChoose Int Int [Int] deriving (Eq,Show)
instance Arbitrary ListChoose where
    arbitrary = do
        (Nat n) <- arbitrary
        k <- choose (0,n)
        
        xs <- vector n :: Gen [Int]
        return . ListChoose n k $ 
            sort $ take k $ (snd . unzip) $ sortBy (comparing fst) $ zip xs [0..]

    coarbitrary = undefined


data ListPermute = ListPermute Int [Int] deriving (Eq,Show)
instance Arbitrary ListPermute where
    arbitrary = do
        (Nat n) <- arbitrary
        xs <- vector n :: Gen [Int]
        return . ListPermute n $ 
            (snd . unzip) $ sortBy (comparing fst) $ zip xs [0..]

    coarbitrary = undefined

data SwapsPermute = SwapsPermute Int [(Int,Int)] deriving (Eq,Show)
instance Arbitrary SwapsPermute where
    arbitrary = do
        (Nat n) <- arbitrary
        let n' = n + 1
        (Nat k) <- arbitrary
        ss <- replicateM k (swap n')
        return $ SwapsPermute n' ss

    coarbitrary = undefined

swap n = do
    i <- choose (0,n-1)
    j <- choose (0,n-1)
    return (i,j)

data CyclesPermute = CyclesPermute Int [[Int]] deriving (Eq,Show)
instance Arbitrary CyclesPermute where
    arbitrary = do
        (Nat n) <- arbitrary
        cs <- exhaust randomCycle null [0..n]
        cs' <- cutSomeSingletons cs
        return $ CyclesPermute (n+1) cs'

    coarbitrary = undefined

exhaust :: Monad m => (a -> m (b, a)) -> (a -> Bool) -> a -> m [b]
exhaust _ p x | p x = return []
exhaust f p x = do
    (r, y) <- f x
    rs <- exhaust f p y
    return (r:rs)

cutSomeSingletons [] = return []
cutSomeSingletons ([x]:xs) = do
    is <- elements [True, False]
    if is
        then liftM ([x]:) $ cutSomeSingletons xs
        else cutSomeSingletons xs
cutSomeSingletons (x:xs) = liftM (x:) $ cutSomeSingletons xs

randomCycle xs = do
    first <- elements xs
    complete first (xs \\ [first])
  where
    complete first rest = do
        next <- elements (first:rest)
        if next == first
            then return ([first], rest)
            else do
                (more, leftover) <- complete first (rest \\ [next])
                return ((next:more), leftover)


data Swap = Swap Int Int Int deriving (Eq,Show)
instance Arbitrary Swap where
    arbitrary = do
        (Index n i) <- arbitrary
        j <- choose (0,n-1)
        return $ Swap n i j

    coarbitrary = undefined

instance Arbitrary Ordering where
    arbitrary   = elements [ LT, GT, EQ ]
    coarbitrary = coarbitrary . fromEnum

data Sort = Sort Int [Int] deriving (Eq,Show)
instance Arbitrary Sort where
    arbitrary = do
        (Index n i) <- arbitrary
        xs <- vector n
        return $ Sort i xs
        
    coarbitrary = undefined

data SortBy = SortBy (Int -> Int -> Ordering) Int [Int] deriving (Show)
instance Arbitrary SortBy where
    arbitrary = do
        cmp <- arbitrary
        (Sort n xs) <- arbitrary
        return $ SortBy cmp n xs
    
    coarbitrary = undefined


------------------------------------------------------------------------
--
-- QC driver ( taken from xmonad-0.6 )
--

debug = False

mytest :: Testable a => a -> Int -> IO (Bool, Int)
mytest a n = mycheck defaultConfig
    { configMaxTest=n
    , configEvery   = \n args -> let s = show n in s ++ [ '\b' | _ <- s ] } a
 -- , configEvery= \n args -> if debug then show n ++ ":\n" ++ unlines args else [] } a

mycheck :: Testable a => Config -> a -> IO (Bool, Int)
mycheck config a = do
    rnd <- newStdGen
    mytests config (evaluate a) rnd 0 0 []

mytests :: Config -> Gen Result -> StdGen -> Int -> Int -> [[String]] -> IO (Bool, Int)
mytests config gen rnd0 ntest nfail stamps
    | ntest == configMaxTest config = done "OK," ntest stamps >> return (True, ntest)
    | nfail == configMaxFail config = done "Arguments exhausted after" ntest stamps >> return (True, ntest)
    | otherwise               =
      do putStr (configEvery config ntest (arguments result)) >> hFlush stdout
         case ok result of
           Nothing    ->
             mytests config gen rnd1 ntest (nfail+1) stamps
           Just True  ->
             mytests config gen rnd1 (ntest+1) nfail (stamp result:stamps)
           Just False ->
             putStr ( "Falsifiable after "
                   ++ show ntest
                   ++ " tests:\n"
                   ++ unlines (arguments result)
                    ) >> hFlush stdout >> return (False, ntest)
     where
      result      = generate (configSize config ntest) rnd2 gen
      (rnd1,rnd2) = split rnd0

done :: String -> Int -> [[String]] -> IO ()
done mesg ntest stamps = putStr ( mesg ++ " " ++ show ntest ++ " tests" ++ table )
  where
    table = display
            . map entry
            . reverse
            . sort
            . map pairLength
            . group
            . sort
            . filter (not . null)
            $ stamps

    display []  = ".\n"
    display [x] = " (" ++ x ++ ").\n"
    display xs  = ".\n" ++ unlines (map (++ ".") xs)

    pairLength xss@(xs:_) = (length xss, xs)
    entry (n, xs)         = percentage n ntest
                       ++ " "
                       ++ concat (intersperse ", " xs)

    percentage n m        = show ((100 * n) `div` m) ++ "%"

------------------------------------------------------------------------

