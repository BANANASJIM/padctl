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

-- CRC32 ISO-HDLC (polynomial 0xEDB88320, init 0xFFFFFFFF, XOR output)
-- Bit-by-bit implementation: for each byte, XOR into crc, then 8 rounds of
-- if (crc & 1) then (crc >>> 1) XOR poly else (crc >>> 1).
private def crc32Byte (crc : UInt32) (b : UInt8) : UInt32 :=
  let c0 := crc ^^^ b.toUInt32
  let step (c : UInt32) : UInt32 :=
    if c &&& 1 == 1 then (c >>> 1) ^^^ 0xEDB88320 else c >>> 1
  step (step (step (step (step (step (step (step c0)))))))

def crc32 (raw : ByteArray) (start stop : Nat) : UInt32 :=
  let init : UInt32 := 0xFFFFFFFF
  let result := (List.range (stop - start)).foldl (fun acc i =>
    if start + i < raw.size then crc32Byte acc raw[start + i]!
    else acc) init
  result ^^^ 0xFFFFFFFF

def verifyChecksum (raw : ByteArray) (algo : ChecksumAlgo) (rangeStart rangeEnd : Nat) (offset : Nat) : Bool :=
  if offset + 3 >= raw.size then
    match algo with
    | .crc32 => false
    | _ => if offset >= raw.size then false
           else match algo with
                | .sum8 => checksumSum8 raw rangeStart rangeEnd == raw[offset]!.toNat
                | .xor  => checksumXor raw rangeStart rangeEnd == raw[offset]!.toNat
                | .crc32 => false  -- unreachable
  else match algo with
    | .sum8 => checksumSum8 raw rangeStart rangeEnd == raw[offset]!.toNat
    | .xor  => checksumXor raw rangeStart rangeEnd == raw[offset]!.toNat
    | .crc32 =>
      let expected := raw[offset]!.toNat + raw[offset + 1]!.toNat * 256 +
                      raw[offset + 2]!.toNat * 65536 + raw[offset + 3]!.toNat * 16777216
      (crc32 raw rangeStart rangeEnd).toNat == expected

-- Report matching (models checkMatch)
def checkMatch (raw : ByteArray) (offset : Nat) (expected : ByteArray) : Bool :=
  if raw.size < offset + expected.size then false
  else (List.range expected.size).all fun i =>
    raw[offset + i]! == expected[i]!

-- HID hat switch decode (models applyFieldTag .dpad branch)
-- 0=N, 1=NE, 2=E, 3=SE, 4=S, 5=SW, 6=W, 7=NW, 8+=neutral
def decodeDpadHat (hatValue : Nat) : Int × Int :=
  match hatValue with
  | 0 => (0, -1)    -- Up
  | 1 => (1, -1)    -- Up-Right
  | 2 => (1, 0)     -- Right
  | 3 => (1, 1)     -- Down-Right
  | 4 => (0, 1)     -- Down
  | 5 => (-1, 1)    -- Down-Left
  | 6 => (-1, 0)    -- Left
  | 7 => (-1, -1)   -- Up-Left
  | _ => (0, 0)     -- Neutral (8 or any other value)

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
