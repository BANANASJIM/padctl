-- Mapper — deterministic core of src/core/mapper.zig
-- Models: layer FSM, button remap, dpad modes, button assembly, full apply pipeline
import Padctl.State

/-! ## Bit operations -/

-- Bitwise complement for Nat is not available in Lean 4 stdlib.
-- We define assembleButtons directly using Nat.bitwise operations.

def setBit (n : Nat) (bit : Nat) : Nat := n ||| (1 <<< bit)

/-! ## Aux events -/

inductive AuxEvent where
  | key (code : Nat) (pressed : Bool)
  | mouseButton (code : Nat) (pressed : Bool)
  | rel (code : Nat) (value : Int)
  deriving DecidableEq, Repr

/-! ## Layer FSM — matching src/core/layer.zig -/

inductive TapHoldPhase where | pending | active
  deriving DecidableEq, Repr

inductive LayerMode where | hold | toggle
  deriving DecidableEq, Repr

structure LayerConfig where
  trigger : Nat       -- ButtonId as bit position
  mode : LayerMode
  holdTimeout : Nat := 200
  deriving DecidableEq, Repr

structure TapHoldState where
  layerIdx : Nat
  phase : TapHoldPhase := .pending
  layerActivated : Bool := false
  deriving DecidableEq, Repr

structure MapperState where
  buttons : Nat := 0
  prevButtons : Nat := 0
  tapHold : Option TapHoldState := none
  toggled : List Bool := []  -- per-layer toggle state, indexed by layer config position
  deriving DecidableEq, Repr

/-! ### Tap-hold state machine -/

def onTriggerPress (s : MapperState) (layerIdx : Nat) : MapperState :=
  match s.tapHold with
  | some _ => s  -- already PENDING or ACTIVE: ignore
  | none => { s with tapHold := some { layerIdx, phase := .pending } }

def onTimerExpired (s : MapperState) : MapperState :=
  match s.tapHold with
  | some th =>
    if th.phase == .pending then
      { s with tapHold := some { th with phase := .active, layerActivated := true } }
    else s
  | none => s

def onTriggerRelease (s : MapperState) : MapperState :=
  { s with tapHold := none }

/-! ### Layer active resolution -/

private def firstToggled : List Bool → Nat → Option Nat
  | [], _ => none
  | true :: _, i => some i
  | false :: rest, i => firstToggled rest (i + 1)

-- Returns index of active layer: hold-active first, then first toggled
def getActiveLayer (s : MapperState) (layers : List LayerConfig) : Option Nat :=
  match s.tapHold with
  | some th =>
    if th.layerActivated && th.layerIdx < layers.length then some th.layerIdx
    else firstToggled s.toggled 0
  | none => firstToggled s.toggled 0

/-! ### processLayerTriggers — per-frame dispatch -/

private def processLayerTriggersAux (layers : List LayerConfig) (acc : MapperState) (idx : Nat)
    : MapperState :=
  match layers with
  | [] => acc
  | cfg :: rest =>
    let pressed := testBit acc.buttons cfg.trigger
    let wasPressed := testBit acc.prevButtons cfg.trigger
    let acc' := match cfg.mode with
      | .hold =>
        if pressed && !wasPressed then
          match acc.tapHold with
          | some _ => acc  -- mutual exclusion: ignore
          | none => onTriggerPress acc idx
        else if !pressed && wasPressed then
          match acc.tapHold with
          | some th => if th.layerIdx == idx then onTriggerRelease acc else acc
          | none => acc
        else acc
      | .toggle =>
        if !pressed && wasPressed then
          let isOn := acc.toggled.getD idx false
          if isOn then
            { acc with toggled := acc.toggled.set idx false }
          else
            if (getActiveLayer acc (cfg :: rest)).isSome then acc
            else { acc with toggled := acc.toggled.set idx true }
        else acc
    processLayerTriggersAux rest acc' (idx + 1)

def processLayerTriggers (s : MapperState) (buttons : Nat) (layers : List LayerConfig)
    : MapperState :=
  processLayerTriggersAux layers { s with buttons, prevButtons := s.buttons } 0

/-! ## Remap — matching src/core/remap.zig -/

inductive RemapTarget where
  | gamepadButton (bit : Nat)
  | key (code : Nat)
  | mouseButton (code : Nat)
  | disabled
  deriving DecidableEq, Repr

structure RemapEntry where
  source : Nat         -- ButtonId bit position
  target : RemapTarget
  deriving DecidableEq, Repr

structure RemapResult where
  suppressMask : Nat := 0
  injectMask : Nat := 0
  auxEvents : List AuxEvent := []
  deriving Repr

def RemapResult.empty : RemapResult := {}

-- Collect suppress + inject from a remap list.
def applyRemaps (buttons prevButtons : Nat) (remaps : List RemapEntry) : RemapResult :=
  remaps.foldl (fun acc (entry : RemapEntry) =>
    let suppress := acc.suppressMask ||| (1 <<< entry.source)
    let pressed := testBit buttons entry.source
    let wasPressed := testBit prevButtons entry.source
    match entry.target with
    | RemapTarget.gamepadButton bit =>
      let inject := if pressed then acc.injectMask ||| (1 <<< bit) else acc.injectMask
      { acc with suppressMask := suppress, injectMask := inject }
    | RemapTarget.key code =>
      let aux := if pressed != wasPressed
        then acc.auxEvents ++ [AuxEvent.key code pressed]
        else acc.auxEvents
      { acc with suppressMask := suppress, auxEvents := aux }
    | RemapTarget.mouseButton code =>
      let aux := if pressed != wasPressed
        then acc.auxEvents ++ [AuxEvent.mouseButton code pressed]
        else acc.auxEvents
      { acc with suppressMask := suppress, auxEvents := aux }
    | RemapTarget.disabled =>
      { acc with suppressMask := suppress }
  ) RemapResult.empty

/-! ## Dpad — matching src/core/dpad.zig -/

inductive DpadMode where | gamepad | arrows
  deriving DecidableEq, Repr

-- Arrow key codes (Linux input-event-codes.h)
def KEY_UP : Nat := 103
def KEY_DOWN : Nat := 108
def KEY_LEFT : Nat := 105
def KEY_RIGHT : Nat := 106

structure DpadResult where
  dpadX : Int := 0
  dpadY : Int := 0
  auxEvents : List AuxEvent := []
  suppressDpadHat : Bool := false
  deriving Repr

def processDpad (dx dy prevDx prevDy : Int) (mode : DpadMode) (suppressGamepad : Bool)
    : DpadResult :=
  match mode with
  | .gamepad => { dpadX := dx, dpadY := dy }
  | .arrows =>
    let up := dy < 0
    let down := dy > 0
    let left := dx < 0
    let right := dx > 0
    let prevUp := prevDy < 0
    let prevDown := prevDy > 0
    let prevLeft := prevDx < 0
    let prevRight := prevDx > 0
    let aux : List AuxEvent :=
      (if up != prevUp then [AuxEvent.key KEY_UP up] else []) ++
      (if down != prevDown then [AuxEvent.key KEY_DOWN down] else []) ++
      (if left != prevLeft then [AuxEvent.key KEY_LEFT left] else []) ++
      (if right != prevRight then [AuxEvent.key KEY_RIGHT right] else [])
    let suppress := suppressGamepad
    { dpadX := if suppress then 0 else dx,
      dpadY := if suppress then 0 else dy,
      auxEvents := aux,
      suppressDpadHat := suppress }

/-! ## Button assembly — the core invariant

  Zig: (raw & ~suppress) | inject
  Nat bitwise: we use Nat.bitwise to avoid needing Complement on Nat.
  andNot a b = a AND (NOT b) at each bit position.
-/

-- a AND (NOT b): for each bit, true iff a-bit is 1 and b-bit is 0
def Nat.andNot (a b : Nat) : Nat := Nat.bitwise (fun x y => x && !y) a b

def assembleButtons (raw suppress inject : Nat) : Nat :=
  (Nat.andNot raw suppress) ||| inject

/-! ## Full apply config -/

structure MapperConfig where
  layers : List LayerConfig := []
  baseRemaps : List RemapEntry := []
  layerRemaps : List (List RemapEntry) := []  -- indexed by layer
  dpadMode : DpadMode := .gamepad
  dpadSuppressGamepad : Bool := false
  deriving Repr

/-! ## Full apply pipeline — matching mapper.zig apply() steps [1]-[7] -/

structure ApplyResult where
  mapperState : MapperState
  gamepad : GamepadState
  auxEvents : List AuxEvent
  deriving Repr

def Mapper.apply (s : MapperState) (gs : GamepadState) (delta : GamepadStateDelta)
    (config : MapperConfig) : ApplyResult :=
  -- [1] merge delta
  let newGs := applyDelta gs delta
  let buttons := newGs.buttons

  -- [2] layer trigger processing
  let s2 := processLayerTriggers s buttons config.layers

  -- [3] dpad processing
  let dpadRes := processDpad newGs.dpad_x newGs.dpad_y gs.dpad_x gs.dpad_y
      config.dpadMode config.dpadSuppressGamepad

  -- [4] base remap
  let baseRes := applyRemaps buttons s2.prevButtons config.baseRemaps

  -- [5] layer remap (OR-accumulate)
  let layerRes := match getActiveLayer s2 config.layers with
    | some idx => match config.layerRemaps.getD idx [] with
      | [] => RemapResult.empty
      | remaps => applyRemaps buttons s2.prevButtons remaps
    | none => RemapResult.empty

  -- [6] combine suppress/inject
  let suppress := baseRes.suppressMask ||| layerRes.suppressMask
  let inject := baseRes.injectMask ||| layerRes.injectMask
  let allAux := dpadRes.auxEvents ++ baseRes.auxEvents ++ layerRes.auxEvents

  -- [7] assemble emit state
  let emitButtons := assembleButtons buttons suppress inject
  let emitGs : GamepadState := {
    newGs with
    buttons := emitButtons
    dpad_x := dpadRes.dpadX
    dpad_y := dpadRes.dpadY
  }

  { mapperState := s2, gamepad := emitGs, auxEvents := allAux }
