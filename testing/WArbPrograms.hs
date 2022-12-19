-- | Arbitrary instances for different complexities/validities of programs
module WArbPrograms where

import Control.Applicative (Applicative (liftA2))
import Control.Monad (guard)
import Control.Monad.State.Lazy (MonadState (..), State, evalState)
import NonNeg (NonNeg)
import Test.QuickCheck (Arbitrary (..), Property)
import Test.QuickCheck qualified as QC
import Test.QuickCheck.Arbitrary (Arbitrary)
import Test.QuickCheck.Gen (Gen)
import WSyntax (WBop (..), WInstruction (..))

-- | Quickcheck tests
numPops :: WInstruction l -> Int
numPops InputChar = 1
numPops InputNum = 1
numPops OutputChar = 1
numPops OutputNum = 1
numPops (Push _) = 0
numPops Dup = 1
numPops Swap = 2
numPops Discard = 1
numPops (Copy n) = fromEnum n + 1
numPops (Slide n) = fromEnum n + 1
numPops (Arith _) = 2
numPops (Label _) = 0
numPops (Call _) = 0
numPops (Jump _) = 0
numPops (Branch _ _) = 0
numPops Return = 0
numPops End = 0
numPops Store = 2
numPops Retrieve = 1

numPushes :: WInstruction l -> Int
numPushes InputChar = 0
numPushes InputNum = 0
numPushes OutputChar = 0
numPushes OutputNum = 0
numPushes (Push _) = 1
numPushes Dup = 2
numPushes Swap = 2
numPushes Discard = 0
numPushes (Copy n) = fromEnum n + 2
numPushes (Slide n) = 1
numPushes (Arith _) = 1
numPushes (Label _) = 0
numPushes (Call _) = 0
numPushes (Jump _) = 0
numPushes (Branch _ _) = 0
numPushes Return = 0
numPushes End = 0
numPushes Store = 0
numPushes Retrieve = 1

class InstructionSet a where
  unpack :: a -> WInstruction Int

arbStackInstr :: Gen (WInstruction l)
arbStackInstr =
  QC.oneof
    [ Push <$> arbitrary,
      pure Dup,
      pure Swap,
      pure Discard,
      Copy <$> arbitrary,
      Slide <$> arbitrary,
      Arith <$> arbitrary
    ]

smallStackInstr :: Gen (WInstruction l)
smallStackInstr = do
  instr <- arbStackInstr
  case instr of
    Copy n -> return (Copy $ toEnum (fromEnum n `mod` 5))
    Slide n -> return (Slide $ toEnum (fromEnum n `mod` 5))
    _ -> return instr

programOf :: Gen (WInstruction l) -> Gen [WInstruction l]
programOf gen = do
  size <- QC.getSize
  instrs <- QC.resize (size * 5) $ QC.listOf gen
  return (instrs ++ [End])

stackProgram :: Gen [WInstruction l]
stackProgram = programOf smallStackInstr

stackVerify :: [WInstruction l] -> Maybe Int
stackVerify = aux 0
  where
    aux :: Int -> [WInstruction l] -> Maybe Int
    aux stackHeight [] = return stackHeight
    aux stackHeight (x : xs) = do
      let stackHeight' = stackHeight - numPops x
      guard (stackHeight' >= 0)
      aux (stackHeight' + numPushes x) xs

stackValidate :: [WInstruction l] -> [WInstruction l]
stackValidate l = evalState (mStackValidate l) 0
  where
    mStackValidate :: [WInstruction l] -> State Int [WInstruction l]
    mStackValidate (x : xs) = do
      stackHeight <- get
      if numPops x <= stackHeight
        then do
          put (stackHeight - numPops x + numPushes x)
          (x :) <$> mStackValidate xs
        else mStackValidate xs
    mStackValidate [] = return []

validStackProgram :: Gen [WInstruction l]
validStackProgram =
  stackValidate
    <$> programOf (QC.oneof [smallStackInstr, Push <$> arbitrary])

outputInstr :: Gen (WInstruction l)
outputInstr = QC.elements [OutputNum]

validOutputProgram :: Gen [WInstruction l]
validOutputProgram =
  stackValidate
    <$> programOf
      ( QC.frequency
          [ (5, Push <$> arbitrary),
            (1, smallStackInstr),
            (2, outputInstr)
          ]
      )

inputInstr :: Gen (WInstruction l)
inputInstr = QC.elements [InputChar, InputNum]

validInputProgram :: Gen [WInstruction l]
validInputProgram =
  stackValidate
    <$> programOf
      ( QC.frequency
          [ (5, Push <$> arbitrary),
            (1, smallStackInstr),
            (3, inputInstr)
          ]
      )

sprinkleHeap :: Gen (WInstruction l) -> Gen [WInstruction l]
sprinkleHeap gen = do
  begin <- QC.listOf gen
  (addr :: Int) <- arbitrary
  (val :: Int) <- arbitrary
  let storeInstrs = [Push addr, Push val, Store]
  middle <- QC.listOf gen
  let loadInstrs = [Push addr, Retrieve]
  end <- QC.listOf gen
  return $ begin <> storeInstrs <> middle <> loadInstrs <> end

heapInstr :: Gen (WInstruction l)
heapInstr = QC.elements [Store, Retrieve]

-- posInstr :: Gen (WInstruction l)
-- posInstr = QC.frequency [

-- ]

validHeapAndOutputProgram :: Gen [WInstruction l]
validHeapAndOutputProgram = (<> [End]) . stackValidate <$> sprinkleHeap gen
  where
    gen :: Gen (WInstruction l)
    gen =
      QC.frequency
        [ (5, Push . (`mod` 10) <$> arbitrary),
          (1, smallPosStackInstr),
          (2, pure OutputNum),
          (1, heapInstr)
        ]

    smallPosStackInstr :: Gen (WInstruction l)
    smallPosStackInstr = do
      instr <- smallStackInstr
      return $ case instr of
        Push n -> Push (n `mod` 10)
        Arith e | e `elem` [Sub, Div, Mod] -> Arith Add
        _ -> instr

checkProp :: (Show l, Arbitrary l) => Gen [WInstruction l] -> ([WInstruction l] -> Property) -> Property
checkProp gen prop =
  QC.withMaxSuccess
    150
    (QC.forAllShrink gen (map (\l' -> l' <> [End]) . shrink . init) prop)
