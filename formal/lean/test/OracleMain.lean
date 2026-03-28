-- Lean oracle: generates exhaustive test vectors for DRT consumption
-- Output format: CSV lines grouped by section headers
-- Zig DRT reads these and asserts production output matches.
import Padctl.Types
import Padctl.Transform
import Padctl.Interpreter
import Padctl.State
import Padctl.Mapper

open IO

/-! ## Helpers -/

private def intToString (v : Int) : String :=
  if v < 0 then s!"-{v.natAbs}" else s!"{v.natAbs}"

private def boolToString (b : Bool) : String :=
  if b then "1" else "0"

/-! ## Transform vectors -/

-- For each transform op, generate boundary test cases:
-- op_name,input,tMax,expected
private def transformVectors : List (String × Int × Nat × Int) :=
  let neg := "negate"
  let abs_ := "abs"
  let clamp := "clamp"
  let dz := "deadzone"
  let scale := "scale"
  -- negate: normal, zero, maxInt boundary, minInt guard
  [ (neg,    0,   255,   0),
    (neg,    1,   255,  -1),
    (neg,  127,   127,-127),
    (neg, -127,   127, 127),
    (neg,    1,   127,  -1),
    (neg, -128,   127, 127),  -- minInt guard: Int.negSucc 127 = -128
    (neg, -256,   255, 255),  -- minInt guard: Int.negSucc 255 = -256
    (neg,  100,   255,-100),
    -- abs: normal cases + minInt guard
    (abs_,   0,  255,   0),
    (abs_,  50,  255,  50),
    (abs_, -50,  255,  50),
    (abs_, 127,  127, 127),
    (abs_,-127,  127, 127),
    (abs_,-128,  127, 127),  -- minInt guard
    (abs_,-256,  255, 255),  -- minInt guard
    -- clamp: below, in-range, above
    (clamp,  -200, 0, -100),  -- lo=-100, hi=100 encoded in op
    (clamp,  -100, 0, -100),
    (clamp,     0, 0,    0),
    (clamp,   100, 0,  100),
    (clamp,   200, 0,  100),
    -- deadzone: below threshold, at threshold, above
    (dz, 0, 0, 0),       -- threshold encoded as tMax field for simplicity
    (dz, 5, 0, 0),
    (dz, 9, 0, 0),
    (dz, 10, 0, 10),
    (dz, -5, 0, 0),
    (dz, -10, 0, -10),
    (dz, -11, 0, -11),
    -- scale: x=0→a, x=tMax→b, midpoints
    (scale,   0, 255,  -100),  -- a=-100, b=100
    (scale, 255, 255,   100),
    (scale, 127, 255,    -1),  -- 127*200/255 + (-100) = 99.6.. → truncated
    (scale, 128, 255,     0) ] -- 128*200/255 + (-100) = 0.39.. → truncated

private def emitTransformVectors : IO Unit := do
  println "# TRANSFORM"
  println "# op,input,tMax,expected"
  -- negate vectors
  for (op, input, tMax, expected) in transformVectors do
    match op with
    | "negate" =>
      let result := applyTransform .negate input tMax
      println s!"{op},{intToString input},{tMax},{intToString result}"
      if result != expected then
        throw (IO.userError s!"SELF-CHECK FAILED: negate({intToString input}, {tMax}) = {intToString result}, expected {intToString expected}")
    | "abs" =>
      let result := applyTransform .abs input tMax
      println s!"{op},{intToString input},{tMax},{intToString result}"
      if result != expected then
        throw (IO.userError s!"SELF-CHECK FAILED: abs({intToString input}, {tMax}) = {intToString result}, expected {intToString expected}")
    | _ => pure ()
  -- clamp vectors: lo=-100, hi=100
  let clampLo : Int := -100
  let clampHi : Int := 100
  for (op, input, _, expected) in transformVectors do
    if op == "clamp" then
      let result := applyTransform (.clamp clampLo clampHi) input 0
      println s!"{op},{intToString input},{intToString clampLo},{intToString clampHi},{intToString result}"
      if result != expected then
        throw (IO.userError s!"SELF-CHECK FAILED: clamp({intToString input}) = {intToString result}, expected {intToString expected}")
  -- deadzone vectors: threshold=10
  let dzThresh : Nat := 10
  for (op, input, _, expected) in transformVectors do
    if op == "deadzone" then
      let result := applyTransform (.deadzone dzThresh) input 0
      println s!"{op},{intToString input},{dzThresh},{intToString result}"
      if result != expected then
        throw (IO.userError s!"SELF-CHECK FAILED: deadzone({intToString input}) = {intToString result}, expected {intToString expected}")
  -- scale vectors: a=-100, b=100, tMax=255
  let scaleA : Int := -100
  let scaleB : Int := 100
  for (op, input, tMax, expected) in transformVectors do
    if op == "scale" then
      let result := applyTransform (.scale scaleA scaleB) input tMax
      println s!"{op},{intToString input},{tMax},{intToString scaleA},{intToString scaleB},{intToString result}"
      if result != expected then
        throw (IO.userError s!"SELF-CHECK FAILED: scale({intToString input}) = {intToString result}, expected {intToString expected}")
  -- Negative scale inputs (ediv vs tdiv divergence cases): a=0, b=100, tMax=127
  let nsA : Int := 0
  let nsB : Int := 100
  for (input, tMax, expected) in [
    ((-7 : Int),  (127 : Nat), (-5 : Int)),   -- tdiv(-700, 127) + 0
    (-128,         127,        -100)            -- tdiv(-12800, 127) + 0
  ] do
    let result := applyTransform (.scale nsA nsB) input tMax
    println s!"scale,{intToString input},{tMax},{intToString nsA},{intToString nsB},{intToString result}"
    if result != expected then
      throw (IO.userError s!"SELF-CHECK FAILED: scale({intToString input}, tMax={tMax}, a={nsA}, b={nsB}) = {intToString result}, expected {intToString expected}")

/-! ## Transform chain vectors -/

private def emitChainVectors : IO Unit := do
  println "# CHAIN"
  println "# input,tMax,op1,op2,...,expected"
  -- chain: negate then clamp
  let v1 := runTransformChain 50 [.negate, .clamp (-100) 100] 255
  println s!"50,255,negate,clamp:-100:100,{intToString v1}"
  -- chain: scale then deadzone
  let v2 := runTransformChain 5 [.scale (-100) 100, .deadzone 10] 255
  println s!"5,255,scale:-100:100,deadzone:10,{intToString v2}"
  -- chain: abs then clamp
  let v3 := runTransformChain (-80) [.abs, .clamp 0 50] 255
  println s!"-80,255,abs,clamp:0:50,{intToString v3}"
  -- chain: negate then scale (creates negative input to scale — ediv vs tdiv)
  let v4 := runTransformChain 7 [.negate, .scale 0 100] 127
  println s!"7,127,negate,scale:0:100,{intToString v4}"
  if v4 != -5 then
    throw (IO.userError s!"SELF-CHECK FAILED: chain negate,scale(0,100) of 7 = {intToString v4}, expected -5")
  -- empty chain
  let v5 := runTransformChain 42 [] 255
  println s!"42,255,,{intToString v5}"

/-! ## Field read vectors -/

private def emitReadFieldVectors : IO Unit := do
  println "# READFIELD"
  println "# field_type,offset,hex_bytes,expected"
  -- u8
  let raw1 := ByteArray.mk #[0x00, 0x7F, 0x80, 0xFF]
  for (off, ft, expected) in [
    (0, FieldType.u8,    (0 : Int)),
    (1, FieldType.u8,    127),
    (2, FieldType.u8,    128),
    (3, FieldType.u8,    255),
    (0, FieldType.i8,    0),
    (1, FieldType.i8,    127),
    (2, FieldType.i8,   -128),
    (3, FieldType.i8,   -1)
  ] do
    match readField raw1 off ft with
    | some v =>
      println s!"{repr ft},{off},{intToString v}"
      if v != expected then
        throw (IO.userError s!"readField mismatch: {repr ft} at {off} got {intToString v}, expected {intToString expected}")
    | none   => throw (IO.userError s!"readField returned none for {repr ft} at offset {off}")

  -- u16le / i16le
  let raw2 := ByteArray.mk #[0x00, 0x00, 0xFF, 0x7F, 0x00, 0x80, 0xFF, 0xFF]
  for (off, ft, expected) in [
    (0, FieldType.u16le,     (0 : Int)),
    (2, FieldType.u16le, 32767),
    (4, FieldType.u16le, 32768),
    (6, FieldType.u16le, 65535),
    (0, FieldType.i16le,     0),
    (2, FieldType.i16le, 32767),
    (4, FieldType.i16le,-32768),
    (6, FieldType.i16le,    -1)
  ] do
    match readField raw2 off ft with
    | some v =>
      println s!"{repr ft},{off},{intToString v}"
      if v != expected then
        throw (IO.userError s!"readField mismatch: {repr ft} at {off} got {intToString v}, expected {intToString expected}")
    | none => throw (IO.userError s!"readField none: {repr ft} at {off}")

  -- u16be / i16be
  let raw3 := ByteArray.mk #[0x00, 0x00, 0x7F, 0xFF, 0x80, 0x00, 0xFF, 0xFF]
  for (off, ft, expected) in [
    (0, FieldType.u16be,     (0 : Int)),
    (2, FieldType.u16be, 32767),
    (4, FieldType.u16be, 32768),
    (6, FieldType.u16be, 65535),
    (0, FieldType.i16be,     0),
    (2, FieldType.i16be, 32767),
    (4, FieldType.i16be,-32768),
    (6, FieldType.i16be,    -1)
  ] do
    match readField raw3 off ft with
    | some v =>
      println s!"{repr ft},{off},{intToString v}"
      if v != expected then
        throw (IO.userError s!"readField mismatch: {repr ft} at {off} got {intToString v}, expected {intToString expected}")
    | none => throw (IO.userError s!"readField none: {repr ft} at {off}")

  -- u32le / i32le
  let raw4 := ByteArray.mk #[0x00, 0x00, 0x00, 0x00,
                              0xFF, 0xFF, 0xFF, 0x7F,
                              0x00, 0x00, 0x00, 0x80,
                              0xFF, 0xFF, 0xFF, 0xFF]
  for (off, ft, expected) in [
    (0,  FieldType.u32le,          (0 : Int)),
    (4,  FieldType.u32le,  2147483647),       -- 0x7FFFFFFF
    (8,  FieldType.u32le,  2147483648),       -- 0x80000000
    (12, FieldType.u32le,  4294967295),       -- 0xFFFFFFFF
    (0,  FieldType.i32le,          0),
    (4,  FieldType.i32le,  2147483647),       -- INT32_MAX
    (8,  FieldType.i32le, -2147483648),       -- INT32_MIN
    (12, FieldType.i32le,         -1)
  ] do
    match readField raw4 off ft with
    | some v =>
      println s!"{repr ft},{off},{intToString v}"
      if v != expected then
        throw (IO.userError s!"readField mismatch: {repr ft} at {off} got {intToString v}, expected {intToString expected}")
    | none => throw (IO.userError s!"readField none: {repr ft} at {off}")

  -- u32be / i32be
  let raw5 := ByteArray.mk #[0x00, 0x00, 0x00, 0x00,
                              0x7F, 0xFF, 0xFF, 0xFF,
                              0x80, 0x00, 0x00, 0x00,
                              0xFF, 0xFF, 0xFF, 0xFF]
  for (off, ft, expected) in [
    (0,  FieldType.u32be,          (0 : Int)),
    (4,  FieldType.u32be,  2147483647),
    (8,  FieldType.u32be,  2147483648),
    (12, FieldType.u32be,  4294967295),
    (0,  FieldType.i32be,          0),
    (4,  FieldType.i32be,  2147483647),
    (8,  FieldType.i32be, -2147483648),
    (12, FieldType.i32be,         -1)
  ] do
    match readField raw5 off ft with
    | some v =>
      println s!"{repr ft},{off},{intToString v}"
      if v != expected then
        throw (IO.userError s!"readField mismatch: {repr ft} at {off} got {intToString v}, expected {intToString expected}")
    | none => throw (IO.userError s!"readField none: {repr ft} at {off}")

/-! ## ExtractBits vectors -/

private def emitExtractBitsVectors : IO Unit := do
  println "# EXTRACTBITS"
  println "# byteOff,startBit,bitCount,hex_bytes,expected"
  let raw := ByteArray.mk #[0b10110100, 0b11001010, 0xFF, 0x00]
  -- bitCount=0 → 0
  println s!"0,0,0,{extractBits raw 0 0 0}"
  -- 1 bit at bit 0 of byte 0: 0b10110100 bit0 = 0
  println s!"0,0,1,{extractBits raw 0 0 1}"
  -- 1 bit at bit 2 of byte 0: 0b10110100 bit2 = 1
  println s!"0,2,1,{extractBits raw 0 2 1}"
  -- 4 bits at bit 0 of byte 0: 0b0100 = 4
  println s!"0,0,4,{extractBits raw 0 0 4}"
  -- 8 bits at bit 0 of byte 0: full byte = 0xB4 = 180
  println s!"0,0,8,{extractBits raw 0 0 8}"
  -- cross-byte: 4 bits starting at bit 6 of byte 0
  -- byte0 = 0b10110100, byte1 = 0b11001010
  -- combined LE = 0b11001010_10110100, shift right 6 = 0b0000_11001010_10 → mask 4 bits
  println s!"0,6,4,{extractBits raw 0 6 4}"
  -- 8 bits from byte 2: 0xFF = 255
  println s!"2,0,8,{extractBits raw 2 0 8}"
  -- 8 bits from byte 3: 0x00 = 0
  println s!"3,0,8,{extractBits raw 3 0 8}"

/-! ## SignExtend vectors -/

private def emitSignExtendVectors : IO Unit := do
  println "# SIGNEXTEND"
  println "# value,bitCount,expected"
  for (val, bits, expected) in [
    ((0 : Nat), (8 : Nat), (0 : Int)),
    (127, 8, 127),
    (128, 8, -128),
    (255, 8, -1),
    (0, 16, 0),
    (32767, 16, 32767),
    (32768, 16, -32768),
    (65535, 16, -1),
    (0, 1, 0),
    (1, 1, -1)
  ] do
    let result := signExtend val bits
    println s!"{val},{bits},{intToString result}"
    if result != expected then
      throw (IO.userError s!"signExtend mismatch: signExtend({val}, {bits}) = {intToString result}, expected {intToString expected}")

/-! ## Button assembly vectors -/

private def emitAssembleVectors : IO Unit := do
  println "# ASSEMBLE"
  println "# raw,suppress,inject,expected"
  for (raw, suppress, inject) in [
    ((0b1111 : Nat), (0b0101 : Nat), (0b0000 : Nat)),  -- suppress bits 0,2
    (0b1111, 0b0000, 0b10000),  -- inject bit 4
    (0b1010, 0b1111, 0b0101),   -- suppress all, inject 0,2
    (0b0000, 0b0000, 0b0000),   -- all zero
    (0b1111, 0b1111, 0b1111),   -- suppress all, inject all
    (0b1111, 0b0000, 0b0000),   -- no-op
    (0xFF, 0x0F, 0xF0)          -- byte-level
  ] do
    let result := assembleButtons raw suppress inject
    println s!"{raw},{suppress},{inject},{result}"

/-! ## Dpad synthesis vectors -/

private def emitDpadVectors : IO Unit := do
  println "# DPAD_SYNTH"
  println "# buttons,expected_dx,expected_dy"
  -- no buttons
  let b0 : Nat := 0
  let (dx0, dy0) := synthesizeDpadAxes b0
  println s!"{b0},{intToString dx0},{intToString dy0}"
  -- up only (bit 14)
  let bUp := 1 <<< 14
  let (dxU, dyU) := synthesizeDpadAxes bUp
  println s!"{bUp},{intToString dxU},{intToString dyU}"
  -- down only (bit 15)
  let bDown := 1 <<< 15
  let (dxD, dyD) := synthesizeDpadAxes bDown
  println s!"{bDown},{intToString dxD},{intToString dyD}"
  -- left only (bit 16)
  let bLeft := 1 <<< 16
  let (dxL, dyL) := synthesizeDpadAxes bLeft
  println s!"{bLeft},{intToString dxL},{intToString dyL}"
  -- right only (bit 17)
  let bRight := 1 <<< 17
  let (dxR, dyR) := synthesizeDpadAxes bRight
  println s!"{bRight},{intToString dxR},{intToString dyR}"
  -- up + down cancel
  let bUD := (1 <<< 14) ||| (1 <<< 15)
  let (dxUD, dyUD) := synthesizeDpadAxes bUD
  println s!"{bUD},{intToString dxUD},{intToString dyUD}"
  -- left + right cancel
  let bLR := (1 <<< 16) ||| (1 <<< 17)
  let (dxLR, dyLR) := synthesizeDpadAxes bLR
  println s!"{bLR},{intToString dxLR},{intToString dyLR}"
  -- up + right
  let bUR := (1 <<< 14) ||| (1 <<< 17)
  let (dxUR, dyUR) := synthesizeDpadAxes bUR
  println s!"{bUR},{intToString dxUR},{intToString dyUR}"

/-! ## Checksum vectors -/

private def emitChecksumVectors : IO Unit := do
  println "# CHECKSUM"
  println "# algo,start,stop,offset,hex_bytes,expected_bool"
  -- sum8: 1+2+3 = 6 mod 256 = 6; byte at offset 3 = 6 → true
  let raw1 := ByteArray.mk #[1, 2, 3, 6]
  println s!"sum8,0,3,3,{boolToString (verifyChecksum raw1 .sum8 0 3 3)}"
  -- sum8 fail: expected 7 but sum=6
  let raw2 := ByteArray.mk #[1, 2, 3, 7]
  println s!"sum8,0,3,3,{boolToString (verifyChecksum raw2 .sum8 0 3 3)}"
  -- xor: 0xAA ^ 0x55 = 0xFF
  let raw3 := ByteArray.mk #[0xAA, 0x55, 0xFF]
  println s!"xor,0,2,2,{boolToString (verifyChecksum raw3 .xor 0 2 2)}"
  -- xor fail
  let raw4 := ByteArray.mk #[0xAA, 0x55, 0x00]
  println s!"xor,0,2,2,{boolToString (verifyChecksum raw4 .xor 0 2 2)}"
  -- crc32: "123456789" → 0xCBF43926
  let crcData := ByteArray.mk #[0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39]
  let crcExpected : UInt32 := 0xCBF43926
  let crcResult := crc32 crcData 0 9
  println s!"crc32,0,9,computed={crcResult.toNat},expected={crcExpected.toNat},{boolToString (crcResult == crcExpected)}"
  if crcResult != crcExpected then
    throw (IO.userError s!"CRC32 check vector failed: got {crcResult.toNat}, expected {crcExpected.toNat}")
  -- crc32 verify via verifyChecksum: append LE bytes of CRC to data
  let crcLE := ByteArray.mk #[0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39,
                               0x26, 0x39, 0xF4, 0xCB]
  let crcVerify := verifyChecksum crcLE .crc32 0 9 9
  println s!"crc32_verify,0,9,9,{boolToString crcVerify}"
  if !crcVerify then
    throw (IO.userError "CRC32 verifyChecksum failed for known-good data")

/-! ## Hat switch decode vectors -/

private def emitHatDecodeVectors : IO Unit := do
  println "# HAT_DECODE"
  println "# hatValue,expected_dx,expected_dy"
  let expected : List (Nat × Int × Int) :=
    [(0, 0, -1), (1, 1, -1), (2, 1, 0), (3, 1, 1),
     (4, 0, 1), (5, -1, 1), (6, -1, 0), (7, -1, -1),
     (8, 0, 0), (15, 0, 0)]
  for (hat, edx, edy) in expected do
    let (dx, dy) := decodeDpadHat hat
    println s!"{hat},{intToString dx},{intToString dy}"
    if dx != edx || dy != edy then
      throw (IO.userError s!"decodeDpadHat({hat}) = ({intToString dx},{intToString dy}), expected ({intToString edx},{intToString edy})")

/-! ## Button decode vectors -/

private def emitButtonDecodeVectors : IO Unit := do
  println "# BUTTON_DECODE"
  println "# srcOff,srcSize,entries,hex_bytes,expected"
  -- byte 0x05 = 0b00000101, entries: bit0→btn0, bit2→btn4
  let raw := ByteArray.mk #[0x05]
  let entries := [(0, 0), (2, 4)]
  let result := decodeButtonGroup raw 0 1 entries
  println s!"0,1,0:0|2:4,{result}"
  -- byte 0xFF, entries: bit0→btn0, bit7→btn7
  let raw2 := ByteArray.mk #[0xFF]
  let entries2 := [(0, 0), (7, 7)]
  let result2 := decodeButtonGroup raw2 0 1 entries2
  println s!"0,1,0:0|7:7,{result2}"
  -- byte 0x00, entries: bit0→btn0
  let raw3 := ByteArray.mk #[0x00]
  let result3 := decodeButtonGroup raw3 0 1 [(0, 0)]
  println s!"0,1,0:0,{result3}"

/-! ## Mapper: layer FSM vectors -/

private def emitLayerFSMVectors : IO Unit := do
  println "# LAYER_FSM"
  println "# action,description,tapHold_before,tapHold_after"
  -- idle → press trigger → pending
  let s0 : MapperState := {}
  let s1 := onTriggerPress s0 0
  println s!"press,idle_to_pending,{repr s0.tapHold},{repr s1.tapHold}"
  -- pending → timer expired → active
  let s2 := onTimerExpired s1
  println s!"timer,pending_to_active,{repr s1.tapHold},{repr s2.tapHold}"
  -- active → release → idle
  let s3 := onTriggerRelease s2
  println s!"release,active_to_idle,{repr s2.tapHold},{repr s3.tapHold}"
  -- press while already pending → no-op
  let s4 := onTriggerPress s1 1
  println s!"press,pending_noop,{repr s1.tapHold},{repr s4.tapHold}"

/-! ## Mapper: remap vectors -/

private def emitRemapVectors : IO Unit := do
  println "# REMAP"
  println "# buttons,prevButtons,entries,suppress,inject,aux_count"
  -- remap button 0 → gamepad button 4; button 0 pressed
  let buttons : Nat := 1  -- bit 0 set
  let prev : Nat := 0
  let remaps : List RemapEntry := [{ source := 0, target := .gamepadButton 4 }]
  let result := applyRemaps buttons prev remaps
  println s!"{buttons},{prev},0>g4,{result.suppressMask},{result.injectMask},{result.auxEvents.length}"
  -- remap button 0 → disabled; button 0 pressed
  let remaps2 : List RemapEntry := [{ source := 0, target := .disabled }]
  let result2 := applyRemaps buttons prev remaps2
  println s!"{buttons},{prev},0>disabled,{result2.suppressMask},{result2.injectMask},{result2.auxEvents.length}"
  -- remap button 0 → key 30; button 0 newly pressed
  let remaps3 : List RemapEntry := [{ source := 0, target := .key 30 }]
  let result3 := applyRemaps buttons prev remaps3
  println s!"{buttons},{prev},0>k30,{result3.suppressMask},{result3.injectMask},{result3.auxEvents.length}"

/-! ## Main -/

def main : IO Unit := do
  emitTransformVectors
  emitChainVectors
  emitReadFieldVectors
  emitExtractBitsVectors
  emitSignExtendVectors
  emitAssembleVectors
  emitDpadVectors
  emitChecksumVectors
  emitHatDecodeVectors
  emitButtonDecodeVectors
  emitLayerFSMVectors
  emitRemapVectors
  IO.eprintln "oracle: all self-checks passed"
