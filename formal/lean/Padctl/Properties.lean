-- Transform properties (Tier 1) — formal proofs for padctl transforms
import Padctl.Transform

-- P1: negate is involutive (except minInt)
-- If v != -(tMax+1) and -v != -(tMax+1), then negate(negate(v)) = v
theorem negate_involutive (v : Int) (tMax : Nat)
    (h : v ≠ Int.negSucc tMax) (h2 : -v ≠ Int.negSucc tMax) :
    applyTransform .negate (applyTransform .negate v tMax) tMax = v := by
  unfold applyTransform
  simp [h, h2]

-- P2: clamp output is in range
theorem clamp_in_range (lo hi v : Int) (h : lo ≤ hi) :
    lo ≤ applyTransform (.clamp lo hi) v 0 ∧ applyTransform (.clamp lo hi) v 0 ≤ hi := by
  simp only [applyTransform]
  constructor <;> omega

-- P3: deadzone produces zero for small inputs
theorem deadzone_zero (threshold : Nat) (v : Int) (h : v.natAbs < threshold) :
    applyTransform (.deadzone threshold) v 0 = 0 := by
  simp only [applyTransform, h, ite_true]

-- P4: abs is non-negative (except minInt)
theorem abs_nonneg (v : Int) (tMax : Nat) (h : v ≠ Int.negSucc tMax) :
    0 ≤ applyTransform .abs v tMax := by
  unfold applyTransform
  simp [h]

-- P5: scale output range (unsigned input x ∈ [0, tMax], a ≤ b)
-- sorry: requires Int.tdiv monotonicity auxiliary lemma
theorem scale_range (a b : Int) (tMax : Nat) (x : Int)
    (htMax : 0 < tMax) (hab : a ≤ b)
    (hx0 : 0 ≤ x) (hxm : x ≤ tMax) :
    a ≤ applyTransform (.scale a b) x tMax ∧
    applyTransform (.scale a b) x tMax ≤ b := by
  sorry -- Int.tdiv monotonicity: x*(b-a)/tMax ∈ [0, b-a] when x ∈ [0, tMax]

-- P6: deadzone preserves large values
theorem deadzone_preserves (threshold : Nat) (v : Int) (h : ¬(v.natAbs < threshold)) :
    applyTransform (.deadzone threshold) v 0 = v := by
  simp only [applyTransform, h, ite_false]

-- P7: clamp is idempotent
theorem clamp_idempotent (lo hi v : Int) (h : lo ≤ hi) :
    applyTransform (.clamp lo hi) (applyTransform (.clamp lo hi) v 0) 0 =
    applyTransform (.clamp lo hi) v 0 := by
  simp only [applyTransform]
  omega

-- P8: negate at minInt returns tMax
theorem negate_minint_guard (tMax : Nat) :
    applyTransform .negate (Int.negSucc tMax) tMax = tMax := by
  simp [applyTransform]

-- P9: abs at minInt returns tMax
theorem abs_minint_guard (tMax : Nat) :
    applyTransform .abs (Int.negSucc tMax) tMax = tMax := by
  simp [applyTransform]

-- P10: empty transform chain is identity
theorem chain_empty (v : Int) (tMax : Nat) :
    runTransformChain v [] tMax = v := by
  simp [runTransformChain]

-- P11: single-element chain equals single application
theorem chain_singleton (v : Int) (op : TransformOp) (tMax : Nat) :
    runTransformChain v [op] tMax = applyTransform op v tMax := by
  simp [runTransformChain]
