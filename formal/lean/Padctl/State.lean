-- GamepadState operations matching src/core/state.zig
import Padctl.Types

structure GamepadState where
  ax : Int := 0
  ay : Int := 0
  rx : Int := 0
  ry : Int := 0
  lt : Nat := 0
  rt : Nat := 0
  buttons : Nat := 0
  dpad_x : Int := 0
  dpad_y : Int := 0
  gyro_x : Int := 0
  gyro_y : Int := 0
  gyro_z : Int := 0
  accel_x : Int := 0
  accel_y : Int := 0
  accel_z : Int := 0
  touch0_x : Int := 0
  touch0_y : Int := 0
  touch1_x : Int := 0
  touch1_y : Int := 0
  touch0_active : Bool := false
  touch1_active : Bool := false
  battery_level : Nat := 0
  deriving DecidableEq, Repr

structure GamepadStateDelta where
  ax : Option Int := none
  ay : Option Int := none
  rx : Option Int := none
  ry : Option Int := none
  lt : Option Nat := none
  rt : Option Nat := none
  buttons : Option Nat := none
  dpad_x : Option Int := none
  dpad_y : Option Int := none
  gyro_x : Option Int := none
  gyro_y : Option Int := none
  gyro_z : Option Int := none
  accel_x : Option Int := none
  accel_y : Option Int := none
  accel_z : Option Int := none
  touch0_x : Option Int := none
  touch0_y : Option Int := none
  touch1_x : Option Int := none
  touch1_y : Option Int := none
  touch0_active : Option Bool := none
  touch1_active : Option Bool := none
  battery_level : Option Nat := none
  deriving DecidableEq, Repr

def applyDelta (s : GamepadState) (d : GamepadStateDelta) : GamepadState :=
  { ax := d.ax.getD s.ax
    ay := d.ay.getD s.ay
    rx := d.rx.getD s.rx
    ry := d.ry.getD s.ry
    lt := d.lt.getD s.lt
    rt := d.rt.getD s.rt
    buttons := d.buttons.getD s.buttons
    dpad_x := d.dpad_x.getD s.dpad_x
    dpad_y := d.dpad_y.getD s.dpad_y
    gyro_x := d.gyro_x.getD s.gyro_x
    gyro_y := d.gyro_y.getD s.gyro_y
    gyro_z := d.gyro_z.getD s.gyro_z
    accel_x := d.accel_x.getD s.accel_x
    accel_y := d.accel_y.getD s.accel_y
    accel_z := d.accel_z.getD s.accel_z
    touch0_x := d.touch0_x.getD s.touch0_x
    touch0_y := d.touch0_y.getD s.touch0_y
    touch1_x := d.touch1_x.getD s.touch1_x
    touch1_y := d.touch1_y.getD s.touch1_y
    touch0_active := d.touch0_active.getD s.touch0_active
    touch1_active := d.touch1_active.getD s.touch1_active
    battery_level := d.battery_level.getD s.battery_level }

def emptyDelta : GamepadStateDelta := {}

def diff (a b : GamepadState) : GamepadStateDelta :=
  { ax := if a.ax ≠ b.ax then some a.ax else none
    ay := if a.ay ≠ b.ay then some a.ay else none
    rx := if a.rx ≠ b.rx then some a.rx else none
    ry := if a.ry ≠ b.ry then some a.ry else none
    lt := if a.lt ≠ b.lt then some a.lt else none
    rt := if a.rt ≠ b.rt then some a.rt else none
    buttons := if a.buttons ≠ b.buttons then some a.buttons else none
    dpad_x := if a.dpad_x ≠ b.dpad_x then some a.dpad_x else none
    dpad_y := if a.dpad_y ≠ b.dpad_y then some a.dpad_y else none
    gyro_x := if a.gyro_x ≠ b.gyro_x then some a.gyro_x else none
    gyro_y := if a.gyro_y ≠ b.gyro_y then some a.gyro_y else none
    gyro_z := if a.gyro_z ≠ b.gyro_z then some a.gyro_z else none
    accel_x := if a.accel_x ≠ b.accel_x then some a.accel_x else none
    accel_y := if a.accel_y ≠ b.accel_y then some a.accel_y else none
    accel_z := if a.accel_z ≠ b.accel_z then some a.accel_z else none
    touch0_x := if a.touch0_x ≠ b.touch0_x then some a.touch0_x else none
    touch0_y := if a.touch0_y ≠ b.touch0_y then some a.touch0_y else none
    touch1_x := if a.touch1_x ≠ b.touch1_x then some a.touch1_x else none
    touch1_y := if a.touch1_y ≠ b.touch1_y then some a.touch1_y else none
    touch0_active := if a.touch0_active ≠ b.touch0_active then some a.touch0_active else none
    touch1_active := if a.touch1_active ≠ b.touch1_active then some a.touch1_active else none
    battery_level := if a.battery_level ≠ b.battery_level then some a.battery_level else none }

-- ButtonId matching Zig ButtonId enum (all 33 members)
inductive ButtonId where
  | south | east | north | west
  | lsb | rsb | back | start | guide | misc
  | lt | rt | lb | rb
  | dpadUp | dpadDown | dpadLeft | dpadRight
  | lt2 | rt2
  | paddle1 | paddle2 | paddle3 | paddle4
  | touchpadButton
  | misc2 | misc3 | misc4 | misc5 | misc6
  | misc7 | misc8 | misc9
  deriving DecidableEq, Repr

def ButtonId.toNat : ButtonId → Nat
  | .south => 0 | .east => 1 | .north => 2 | .west => 3
  | .lsb => 4 | .rsb => 5 | .back => 6 | .start => 7
  | .guide => 8 | .misc => 9
  | .lt => 10 | .rt => 11 | .lb => 12 | .rb => 13
  | .dpadUp => 14 | .dpadDown => 15 | .dpadLeft => 16 | .dpadRight => 17
  | .lt2 => 18 | .rt2 => 19
  | .paddle1 => 20 | .paddle2 => 21 | .paddle3 => 22 | .paddle4 => 23
  | .touchpadButton => 24
  | .misc2 => 25 | .misc3 => 26 | .misc4 => 27 | .misc5 => 28 | .misc6 => 29
  | .misc7 => 30 | .misc8 => 31 | .misc9 => 32

-- Dpad button bit positions matching Zig ButtonId enum
def dpadUpBit : Nat := ButtonId.toNat .dpadUp
def dpadDownBit : Nat := ButtonId.toNat .dpadDown
def dpadLeftBit : Nat := ButtonId.toNat .dpadLeft
def dpadRightBit : Nat := ButtonId.toNat .dpadRight

def testBit (n : Nat) (bit : Nat) : Bool := (n / (2 ^ bit)) % 2 == 1

def synthesizeDpadAxes (buttons : Nat) : Int × Int :=
  let right := testBit buttons dpadRightBit
  let left  := testBit buttons dpadLeftBit
  let down  := testBit buttons dpadDownBit
  let up    := testBit buttons dpadUpBit
  let dx : Int := (if right then 1 else 0) - (if left then 1 else 0)
  let dy : Int := (if down then 1 else 0) - (if up then 1 else 0)
  (dx, dy)
