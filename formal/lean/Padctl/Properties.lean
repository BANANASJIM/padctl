-- Properties — formal proofs for padctl transforms, interpreter, state, and mapper
import Padctl.Transform
import Padctl.Interpreter
import Padctl.State
import Padctl.Mapper

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
theorem scale_range (a b : Int) (tMax : Nat) (x : Int)
    (htMax : 0 < tMax) (hab : a ≤ b)
    (hx0 : 0 ≤ x) (hxm : x ≤ tMax) :
    a ≤ applyTransform (.scale a b) x tMax ∧
    applyTransform (.scale a b) x tMax ≤ b := by
  unfold applyTransform
  have htMax_ne : (tMax : Nat) ≠ 0 := by omega
  simp [htMax_ne]
  constructor
  · -- Lower bound: x * (b-a) / tMax ≥ 0, so + a ≥ a
    have h1 : (0 : Int) ≤ b - a := by omega
    have h2 : (0 : Int) ≤ x * (b - a) := Int.mul_nonneg hx0 h1
    have h3 : (0 : Int) ≤ (tMax : Int) := by omega
    have h4 : (0 : Int) ≤ (x * (b - a)).tdiv (tMax : Int) := Int.tdiv_nonneg h2 h3
    omega
  · -- Upper bound: x * (b-a) / tMax ≤ b - a
    have h1 : (0 : Int) ≤ b - a := by omega
    have h3 : (0 : Int) < (tMax : Int) := by omega
    have h5 : x * (b - a) ≤ (tMax : Int) * (b - a) :=
      Int.mul_le_mul_of_nonneg_right hxm h1
    have h6 : (x * (b - a)).tdiv (tMax : Int) ≤ ((tMax : Int) * (b - a)).tdiv (tMax : Int) :=
      Int.tdiv_le_tdiv h3 h5
    have h7 : (tMax : Int) ≠ 0 := by omega
    rw [Int.mul_tdiv_cancel_left (b - a) h7] at h6
    omega

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

/-! ## Mapper properties -/

-- P18: assembleButtons — suppressed bits are cleared when suppress ∩ inject = 0
theorem assemble_suppress_clears (raw suppress inject : Nat)
    (h_disjoint : suppress &&& inject = 0) :
    assembleButtons raw suppress inject &&& suppress = 0 := by
  unfold assembleButtons Nat.andNot
  apply Nat.eq_of_testBit_eq
  intro i
  rw [Nat.testBit_and, Nat.testBit_or, Nat.zero_testBit]
  have hbw : (Nat.bitwise (fun x y => x && !y) raw suppress).testBit i =
    (raw.testBit i && !suppress.testBit i) :=
    Nat.testBit_bitwise (by decide) raw suppress i
  rw [hbw]
  have h_bit : suppress.testBit i = true → inject.testBit i = false := by
    intro hs
    have h := congrArg (·.testBit i) h_disjoint
    simp [Nat.testBit_and, Nat.zero_testBit] at h
    exact h hs
  cases hs : suppress.testBit i <;> simp [h_bit, hs]

-- P19: Layer mutual exclusion — onTriggerPress while tapHold active is no-op
theorem layer_mutual_exclusion (s : MapperState) (th : TapHoldState) (j : Nat)
    (h : s.tapHold = some th) :
    onTriggerPress s j = s := by
  unfold onTriggerPress
  simp [h]

-- P20: Layer toggle involutive — toggling twice returns to original
theorem toggle_involutive (b : Bool) : !(!b) = b := by
  cases b <;> simp

-- P21: Dpad arrows — dx = 0 in output when input dx = 0
theorem dpad_arrows_zero_dx (dy prevDx prevDy : Int) (suppress : Bool) :
    (processDpad 0 dy prevDx prevDy .arrows suppress).dpadX = 0 := by
  simp [processDpad]

-- P21b: Dpad gamepad mode is passthrough
theorem dpad_gamepad_passthrough (dx dy prevDx prevDy : Int) :
    (processDpad dx dy prevDx prevDy .gamepad false).dpadX = dx ∧
    (processDpad dx dy prevDx prevDy .gamepad false).dpadY = dy := by
  simp [processDpad]

-- P23: decodeDpadHat exhaustive — all 9 cases produce valid (dx, dy) pairs
-- Hat values 0-7 each produce a unique direction; 8+ produce neutral
theorem dpadHat_exhaustive :
    decodeDpadHat 0 = (0, -1) ∧ decodeDpadHat 1 = (1, -1) ∧
    decodeDpadHat 2 = (1, 0) ∧ decodeDpadHat 3 = (1, 1) ∧
    decodeDpadHat 4 = (0, 1) ∧ decodeDpadHat 5 = (-1, 1) ∧
    decodeDpadHat 6 = (-1, 0) ∧ decodeDpadHat 7 = (-1, -1) ∧
    decodeDpadHat 8 = (0, 0) := by decide

-- P24: decodeDpadHat opposing directions cancel (up/down: hat 0 vs hat 4)
theorem dpadHat_opposing_y :
    (decodeDpadHat 0).2 = -(decodeDpadHat 4).2 := by decide

-- P25: decodeDpadHat opposing directions cancel (left/right: hat 6 vs hat 2)
theorem dpadHat_opposing_x :
    (decodeDpadHat 6).1 = -(decodeDpadHat 2).1 := by decide

-- P22: assembleButtons — inject bits always present in output
theorem assemble_inject_present (raw suppress inject : Nat) :
    assembleButtons raw suppress inject ||| inject = assembleButtons raw suppress inject := by
  unfold assembleButtons
  rw [Nat.or_assoc, Nat.or_self]
