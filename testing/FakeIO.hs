module FakeIO (outputOf, finalStateOf, FakeState (..), FakeIO) where

import Control.Monad (ap, liftM)
import Data.Sequence (Seq, (|>))
import Data.Sequence qualified as Seq
import MonadReadWrite (MonadReadWrite (..))

-- A copy of the state monad to prevent typeclass interference
newtype State' s a = S (s -> (a, s))

runState' :: State' s a -> s -> (a, s)
runState' (S f) = f

evalState' :: State' s a -> s -> a
evalState' (S f) x = fst $ f x

execState' :: State' s a -> s -> s
execState' (S f) x = snd $ f x

instance Monad (State' s) where
  return :: a -> State' s a
  return x = S (x,)

  (>>=) :: State' s a -> (a -> State' s b) -> State' s b
  (S st) >>= f = S (\x -> case st x of (a, s) -> runState' (f a) s)

instance Functor (State' s) where
  fmap = liftM

instance Applicative (State' s) where
  pure = return
  (<*>) = ap

-- | The actual fake state
data FakeState = FakeState
  { input :: String,
    output :: String -> String
  }

type FakeIO = State' FakeState

get' :: State' s s
get' = S $ \s -> (s, s)

put' :: s -> State' s ()
put' s' = S $ const ((), s')

instance MonadReadWrite FakeIO where
  readChar = do
    state <- get'
    let (x : xs) = input state
    put' $ state {input = xs}
    return x
  writeString s = do
    state <- get'
    put' $ state {output = output state . (s <>)}

ofInput :: String -> FakeState
ofInput = flip FakeState id

outputOf :: Monad m => FakeIO (m s) -> String -> m String
outputOf fakeIO input = e >> return (output state [])
  where
    (e, state) = runState' fakeIO (ofInput input)

finalStateOf :: Monad m => FakeIO (m s) -> String -> m s
finalStateOf fakeIO input = e
  where
    (e, state) = runState' fakeIO (ofInput input)