-- Properties — formal proofs for padctl transforms, interpreter, and state
import Padctl.Transform
import Padctl.Interpreter
import Padctl.State

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

-- P12: applyDelta(s, diff(t, s)) = t (round-trip)
theorem apply_diff_roundtrip (s t : GamepadState) :
    applyDelta s (diff t s) = t := by
  cases s; cases t
  simp only [applyDelta, diff, Option.getD]
  congr 1 <;> (split <;> simp_all)

-- P13: diff(s, s) has all fields = none (self-diff is empty)
theorem diff_self_empty (s : GamepadState) :
    diff s s = emptyDelta := by
  cases s
  simp [diff, emptyDelta]

-- P14: extractBits bounds — returns 0 when bitCount = 0
theorem extractBits_zero_count (raw : ByteArray) (byteOff startBit : Nat) :
    extractBits raw byteOff startBit 0 = 0 := by
  simp [extractBits]

-- P14b: extractBits result is bounded by 2^bitCount
private theorem two_pow_pos (n : Nat) : 0 < 2 ^ n := by
  induction n with
  | zero => simp
  | succ n ih =>
    have : 2 ^ n ≤ 2 ^ n + 2 ^ n := Nat.le_add_right _ _
    simp [Nat.pow_succ, Nat.mul_comm]
    omega

theorem extractBits_bounded (raw : ByteArray) (byteOff startBit bitCount : Nat) :
    extractBits raw byteOff startBit bitCount < 2 ^ bitCount := by
  unfold extractBits
  split
  · exact two_pow_pos bitCount
  · exact Nat.mod_lt _ (two_pow_pos bitCount)

-- P15: signExtend round-trip — signExtend on a value already in range
-- For val < 2^(bitCount-1), signExtend returns val as-is
theorem signExtend_positive (val : Nat) (bitCount : Nat) (hbc : 0 < bitCount)
    (hval : val < 2 ^ (bitCount - 1)) (hval2 : val < 2 ^ bitCount) :
    signExtend val bitCount = (val : Int) := by
  simp only [signExtend, toSigned, Nat.mod_eq_of_lt hval2]
  have : ¬(bitCount = 0) := by omega
  simp [this]
  intro h
  omega

-- P16: synthesizeDpadAxes — opposing directions cancel
-- up + down pressed → dy = 0; left + right pressed → dx = 0
theorem dpad_opposing_cancel_x (buttons : Nat)
    (hleft : testBit buttons dpadLeftBit = true)
    (hright : testBit buttons dpadRightBit = true) :
    (synthesizeDpadAxes buttons).1 = 0 := by
  simp only [synthesizeDpadAxes, hleft, hright]
  omega

theorem dpad_opposing_cancel_y (buttons : Nat)
    (hup : testBit buttons dpadUpBit = true)
    (hdown : testBit buttons dpadDownBit = true) :
    (synthesizeDpadAxes buttons).2 = 0 := by
  simp only [synthesizeDpadAxes, hup, hdown]
  omega

-- P16b: no dpad buttons → (0, 0)
theorem dpad_no_buttons (buttons : Nat)
    (hu : testBit buttons dpadUpBit = false)
    (hd : testBit buttons dpadDownBit = false)
    (hl : testBit buttons dpadLeftBit = false)
    (hr : testBit buttons dpadRightBit = false) :
    synthesizeDpadAxes buttons = (0, 0) := by
  simp only [synthesizeDpadAxes, hu, hd, hl, hr]
  decide

-- P17: checkMatch with empty expected succeeds when offset in bounds
theorem checkMatch_empty (raw : ByteArray) (offset : Nat)
    (h : offset ≤ raw.size) :
    checkMatch raw offset ByteArray.empty = true := by
  unfold checkMatch
  have : ByteArray.empty.size = 0 := by native_decide
  simp [this, Nat.not_lt_of_le h]

-- P17b: checkMatch fails when buffer too small
theorem checkMatch_oob (raw expected : ByteArray) (offset : Nat)
    (h : raw.size < offset + expected.size) :
    checkMatch raw offset expected = false := by
  unfold checkMatch
  simp [h]

-- P12b: applyDelta with emptyDelta is identity
theorem applyDelta_empty (s : GamepadState) :
    applyDelta s emptyDelta = s := by
  cases s
  simp [applyDelta, emptyDelta]
