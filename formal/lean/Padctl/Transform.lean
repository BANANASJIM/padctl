-- Transform chain matching src/core/interpreter.zig runTransformChain
import Padctl.Types

-- Zig: val * (b - a) / t_max + a  (divTrunc semantics)
-- Int.div in Lean 4 is tdiv (truncation toward zero), matching Zig @divTrunc.
def applyTransform (op : TransformOp) (val : Int) (tMax : Nat) : Int :=
  match op with
  | .negate =>
    if val == Int.negSucc tMax then tMax  -- minInt guard: -(tMax+1) → tMax
    else -val
  | .abs =>
    if val == Int.negSucc tMax then tMax
    else val.natAbs
  | .scale a b =>
    if tMax == 0 then val
    else val * (b - a) / tMax + a
  | .clamp lo hi => max lo (min hi val)
  | .deadzone threshold =>
    if val.natAbs < threshold then 0 else val

def runTransformChain (val : Int) (chain : List TransformOp) (tMax : Nat) : Int :=
  chain.foldl (fun v op => applyTransform op v tMax) val
