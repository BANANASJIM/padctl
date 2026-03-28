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
  elapsedMs : Nat := 0
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

-- Advance elapsed time; transition pending → active when holdTimeout reached
def advanceTimer (s : MapperState) (dtMs : Nat) (layers : List LayerConfig) : MapperState :=
  match s.tapHold with
  | some th =>
    if th.phase == .pending then
      let elapsed := th.elapsedMs + dtMs
      let timeout := match layers[th.layerIdx]? with
        | some cfg => LayerConfig.holdTimeout cfg
        | none => 200
      if elapsed >= timeout then
        { s with tapHold := some { th with phase := .active, layerActivated := true,
                                           elapsedMs := elapsed } }
      else
        { s with tapHold := some { th with elapsedMs := elapsed } }
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

-- Ensure toggled list has at least n elements (pad with false)
private def padToggled (toggled : List Bool) (n : Nat) : List Bool :=
  if toggled.length >= n then toggled
  else toggled ++ List.replicate (n - toggled.length) false

def processLayerTriggers (s : MapperState) (buttons : Nat) (layers : List LayerConfig)
    : MapperState :=
  let tog := padToggled s.toggled layers.length
  let s' := { s with buttons, prevButtons := s.buttons, toggled := tog }
  processLayerTriggersAux layers s' 0

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

-- Merge base + layer remaps: layer entries override base for the same source.
-- Matches Zig per_src_inject last-write-wins semantics.
def mergeRemaps (base layer : List RemapEntry) : List RemapEntry :=
  let layerSources := layer.map (·.source)
  let baseFiltered := base.filter (fun e => !layerSources.contains e.source)
  baseFiltered ++ layer

/-! ## Full apply pipeline — matching mapper.zig apply() steps [1]-[7] -/

structure ApplyResult where
  mapperState : MapperState
  gamepad : GamepadState
  auxEvents : List AuxEvent
  maskedPrev : GamepadState
  deriving Repr

def Mapper.apply (s : MapperState) (gs : GamepadState) (delta : GamepadStateDelta)
    (config : MapperConfig) (dtMs : Nat := 0) : ApplyResult :=
  -- [1] merge delta
  let newGs := applyDelta gs delta
  let buttons := newGs.buttons

  -- [2] layer trigger processing + timer advancement
  let s1 := processLayerTriggers s buttons config.layers
  let s2 := advanceTimer s1 dtMs config.layers

  -- [3] dpad processing
  let dpadRes := processDpad newGs.dpad_x newGs.dpad_y gs.dpad_x gs.dpad_y
      config.dpadMode config.dpadSuppressGamepad

  -- [4]+[5] two-pass remap: layer entries override base for the same source
  let layerRemaps := match getActiveLayer s2 config.layers with
    | some idx => config.layerRemaps.getD idx []
    | none => []
  let mergedRemaps := mergeRemaps config.baseRemaps layerRemaps
  let remapRes := applyRemaps buttons s2.prevButtons mergedRemaps

  -- [6] combine suppress/inject
  let suppress := remapRes.suppressMask
  let inject := remapRes.injectMask
  let allAux := dpadRes.auxEvents ++ remapRes.auxEvents

  -- [7] assemble emit state + prev-frame masking
  let emitButtons := assembleButtons buttons suppress inject
  let emitGs : GamepadState := {
    newGs with
    buttons := emitButtons
    dpad_x := dpadRes.dpadX
    dpad_y := dpadRes.dpadY
  }

  -- prev-frame masking: apply same suppress/inject to prevButtons so that
  -- downstream diff does not produce spurious release events for suppressed buttons
  let maskedPrevButtons := assembleButtons s2.prevButtons suppress inject
  let maskedPrevDpadX := if dpadRes.suppressDpadHat then 0 else gs.dpad_x
  let maskedPrevDpadY := if dpadRes.suppressDpadHat then 0 else gs.dpad_y
  let maskedPrev : GamepadState := {
    gs with
    buttons := maskedPrevButtons
    dpad_x := maskedPrevDpadX
    dpad_y := maskedPrevDpadY
  }

  { mapperState := s2, gamepad := emitGs, auxEvents := allAux, maskedPrev := maskedPrev }
