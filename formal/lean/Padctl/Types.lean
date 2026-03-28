-- Padctl core types matching src/core/interpreter.zig and src/core/state.zig

inductive FieldType where
  | u8 | i8 | u16le | i16le | u16be | i16be | u32le | i32le | u32be | i32be
  deriving DecidableEq, Repr

inductive TransformOp where
  | negate | abs | scale (a b : Int) | clamp (lo hi : Int) | deadzone (threshold : Nat)
  deriving Repr

inductive FieldTag where
  | ax | ay | rx | ry | lt | rt
  | gyro_x | gyro_y | gyro_z | accel_x | accel_y | accel_z
  | touch0_x | touch0_y | touch1_x | touch1_y
  | touch0_active | touch1_active
  | battery_level | dpad
  | unknown
  deriving DecidableEq, Repr

-- typeMaxByTag matching Zig: returns the positive maximum for the type.
-- Zig uses i64, we use Int (superset).
def FieldType.typeMax : FieldType → Nat
  | .u8              => 255
  | .i8              => 127
  | .u16le | .u16be  => 65535
  | .i16le | .i16be  => 32767
  | .u32le | .u32be  => 4294967295
  | .i32le | .i32be  => 2147483647

def FieldType.isSigned : FieldType → Bool
  | .i8 | .i16le | .i16be | .i32le | .i32be => true
  | _ => false

def FieldType.byteSize : FieldType → Nat
  | .u8 | .i8                                => 1
  | .u16le | .i16le | .u16be | .i16be        => 2
  | .u32le | .i32le | .u32be | .i32be        => 4
