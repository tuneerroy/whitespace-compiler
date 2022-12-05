module ASyntax where
import Data.Word (Word8, Word16, Word32)

data Reg8 = AH | AL | BH | BL

data Reg16 = AX | BX | CX | DX

data Reg32 = EAX | EBX | ECX | EDX | ESI | EDI | ESP | EBP

data DataDirective = DB Word8 | DW Word16 | DD Word32

data AInstruction l =
    DataInstruction
    | Label l
    deriving (Functor, Foldable, Traversable)

{-
mov
push (push stack)
pop (pop stack)
lea
add
sub
inc
dec
imul
idiv
and
or
xor
not
neg
shl
shr
jmp
jcondition (conditional jump)
cmp
call
ret
-}
