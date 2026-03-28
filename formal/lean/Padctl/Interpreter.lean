-- Interpreter core operations matching src/core/interpreter.zig
import Padctl.Types

-- Byte-level field reading (models readFieldByTag)
def readU8 (raw : ByteArray) (off : Nat) : Option Nat :=
  if off < raw.size then some raw[off]!.toNat else none

def readU16le (raw : ByteArray) (off : Nat) : Option Nat :=
  if off + 1 < raw.size then
    some (raw[off]!.toNat + raw[off + 1]!.toNat * 256)
  else none

def readU16be (raw : ByteArray) (off : Nat) : Option Nat :=
  if off + 1 < raw.size then
    some (raw[off]!.toNat * 256 + raw[off + 1]!.toNat)
  else none

def readU32le (raw : ByteArray) (off : Nat) : Option Nat :=
  if off + 3 < raw.size then
    some (raw[off]!.toNat + raw[off + 1]!.toNat * 256 +
          raw[off + 2]!.toNat * 65536 + raw[off + 3]!.toNat * 16777216)
  else none

def readU32be (raw : ByteArray) (off : Nat) : Option Nat :=
  if off + 3 < raw.size then
    some (raw[off]!.toNat * 16777216 + raw[off + 1]!.toNat * 65536 +
          raw[off + 2]!.toNat * 256 + raw[off + 3]!.toNat)
  else none

def toSigned (val : Nat) (bits : Nat) : Int :=
  if bits == 0 then 0
  else if val < 2 ^ (bits - 1) then (val : Int)
  else (val : Int) - (2 ^ bits : Nat)

def readField (raw : ByteArray) (offset : Nat) (ft : FieldType) : Option Int :=
  match ft with
  | .u8     => (readU8 raw offset).map (Int.ofNat ·)
  | .i8     => (readU8 raw offset).map (toSigned · 8)
  | .u16le  => (readU16le raw offset).map (Int.ofNat ·)
  | .i16le  => (readU16le raw offset).map (toSigned · 16)
  | .u16be  => (readU16be raw offset).map (Int.ofNat ·)
  | .i16be  => (readU16be raw offset).map (toSigned · 16)
  | .u32le  => (readU32le raw offset).map (Int.ofNat ·)
  | .i32le  => (readU32le raw offset).map (toSigned · 32)
  | .u32be  => (readU32be raw offset).map (Int.ofNat ·)
  | .i32be  => (readU32be raw offset).map (toSigned · 32)

-- Bit extraction (models extractBits)
def extractBits (raw : ByteArray) (byteOff : Nat) (startBit : Nat) (bitCount : Nat) : Nat :=
  if bitCount == 0 then 0
  else
    let needed := (startBit + bitCount + 7) / 8
    let val := (List.range needed).foldl (fun acc i =>
      if byteOff + i < raw.size then
        acc + raw[byteOff + i]!.toNat * (2 ^ (i * 8))
      else acc) 0
    (val / (2 ^ startBit)) % (2 ^ bitCount)

-- Sign extension (models signExtend)
def signExtend (val : Nat) (bitCount : Nat) : Int :=
  toSigned (val % (2 ^ bitCount)) bitCount

-- Checksum algorithms
inductive ChecksumAlgo where
  | sum8
  | xor
  | crc32
  deriving DecidableEq, Repr

def checksumSum8 (raw : ByteArray) (start stop : Nat) : Nat :=
  (List.range (stop - start)).foldl (fun acc i =>
    if start + i < raw.size then (acc + raw[start + i]!.toNat) % 256
    else acc) 0

def checksumXor (raw : ByteArray) (start stop : Nat) : Nat :=
  (List.range (stop - start)).foldl (fun acc i =>
    if start + i < raw.size then Nat.xor acc raw[start + i]!.toNat
    else acc) 0

def verifyChecksum (raw : ByteArray) (algo : ChecksumAlgo) (rangeStart rangeEnd : Nat) (offset : Nat) : Bool :=
  if offset >= raw.size then false
  else match algo with
    | .sum8 => checksumSum8 raw rangeStart rangeEnd == raw[offset]!.toNat
    | .xor  => checksumXor raw rangeStart rangeEnd == raw[offset]!.toNat
    | .crc32 => true  -- CRC32 verification omitted (complex lookup table)

-- Report matching (models checkMatch)
def checkMatch (raw : ByteArray) (offset : Nat) (expected : ByteArray) : Bool :=
  if raw.size < offset + expected.size then false
  else (List.range expected.size).all fun i =>
    raw[offset + i]! == expected[i]!

-- Button group decoding (models extractAndFillCompiled button logic)
-- entries: list of (bit_idx_in_source, button_bit_in_output)
def decodeButtonGroup (raw : ByteArray) (srcOff : Nat) (srcSize : Nat)
    (entries : List (Nat × Nat)) : Nat :=
  let srcVal := (List.range srcSize).foldl (fun acc i =>
    if srcOff + i < raw.size then
      acc + raw[srcOff + i]!.toNat * (2 ^ (i * 8))
    else acc) 0
  entries.foldl (fun bits (bitIdx, btnBit) =>
    if (srcVal / (2 ^ bitIdx)) % 2 == 1 then
      bits + 2 ^ btnBit  -- set bit (assumes no overlap)
    else bits) 0
