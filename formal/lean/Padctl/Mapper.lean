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

/-! ## Gyro activation — models checkGyroActivate boolean only -/

inductive GyroMode where | mouse | joystick
  deriving DecidableEq, Repr

def checkGyroActivate (buttons : Nat) (activationButton : Option Nat) : Bool :=
  match activationButton with
  | none => true  -- always-on
  | some bit => testBit buttons bit

/-! ## Stick mode — suppress flag only -/

inductive StickMode where | gamepad | mouse | scroll
  deriving DecidableEq, Repr

def checkStickSuppressGamepad (mode : StickMode) : Bool :=
  match mode with
  | .gamepad => false
  | .mouse => true
  | .scroll => true

/-! ## Macro state — trigger-on-rising-edge + cancel-on-layer-change -/

inductive MacroStep where
  | tap (code : Nat)
  | down (code : Nat)
  | up (code : Nat)
  | delay (ms : Nat)
  | pauseForRelease
  deriving DecidableEq, Repr

structure MacroState where
  active : Bool := false
  pendingReleases : List Nat := []  -- key codes to release
  steps : List MacroStep := []
  stepIndex : Nat := 0
  timerToken : Option Nat := none
  waitingRelease : Bool := false
  deriving DecidableEq, Repr

structure MapperState where
  buttons : Nat := 0
  prevButtons : Nat := 0
  tapHold : Option TapHoldState := none
  toggled : List Bool := []  -- per-layer toggle state, indexed by layer config position
  macros : List MacroState := []  -- per-remap-entry macro state
  pendingTapRelease : Option Nat := none  -- button bit to clear after one frame
  deriving DecidableEq, Repr

/-! ### Tap-hold state machine -/

def onTriggerPress (s : MapperState) (layerIdx : Nat) : MapperState :=
  match s.tapHold with
  | some _ => s  -- already PENDING or ACTIVE: ignore
  | none => { s with tapHold := some { layerIdx, phase := .pending } }

def onTapHoldTimerExpired (s : MapperState) : MapperState :=
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

-- TapEvent: emitted when trigger released during pending phase (before hold timeout)
structure TapEvent where
  buttonBit : Nat
  deriving DecidableEq, Repr

def onTriggerRelease (s : MapperState) : MapperState × Option TapEvent :=
  match s.tapHold with
  | some th =>
    if th.phase == .pending then
      -- released before hold timeout → emit tap event for the trigger button
      ({ s with tapHold := none }, some { buttonBit := th.layerIdx })
    else
      ({ s with tapHold := none }, none)
  | none => (s, none)

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
          | some th => if th.layerIdx == idx then
              let (s', tapEvt) := onTriggerRelease acc
              match tapEvt with
              | some evt => { s' with pendingTapRelease := some evt.buttonBit }
              | none => s'
            else acc
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
  | macro
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
    | RemapTarget.macro =>
      -- macro: suppress the source button (like disabled), macro player handles the rest
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
  suppressButtons : Nat := 0
  deriving Repr

-- Dpad button bits for suppression mask
private def dpadButtonMask : Nat :=
  (1 <<< dpadUpBit) ||| (1 <<< dpadDownBit) ||| (1 <<< dpadLeftBit) ||| (1 <<< dpadRightBit)

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
      suppressDpadHat := suppress,
      suppressButtons := if suppress then dpadButtonMask else 0 }

/-! ## Button assembly — the core invariant

  Zig: (raw & ~suppress) | inject
  Nat bitwise: we use Nat.bitwise to avoid needing Complement on Nat.
  andNot a b = a AND (NOT b) at each bit position.
-/

-- a AND (NOT b): for each bit, true iff a-bit is 1 and b-bit is 0
def Nat.andNot (a b : Nat) : Nat := Nat.bitwise (fun x y => x && !y) a b

def assembleButtons (raw suppress inject : Nat) : Nat :=
  (Nat.andNot raw suppress) ||| inject

/-! ## Per-layer config override — matching effectiveXxxConfig pattern -/

structure LayerOverrides where
  dpadMode : Option DpadMode := none
  leftStickMode : Option StickMode := none
  rightStickMode : Option StickMode := none
  gyroActivationButton : Option (Option Nat) := none
  gyroMode : Option GyroMode := none
  deriving DecidableEq, Repr

/-! ## Full apply config -/

structure MapperConfig where
  layers : List LayerConfig := []
  baseRemaps : List RemapEntry := []
  layerRemaps : List (List RemapEntry) := []  -- indexed by layer
  dpadMode : DpadMode := .gamepad
  dpadSuppressGamepad : Bool := false
  gyroActivationButton : Option Nat := none
  gyroMode : GyroMode := .mouse
  leftStickMode : StickMode := .gamepad
  rightStickMode : StickMode := .gamepad
  layerOverrides : List LayerOverrides := []
  deriving Repr

-- Merge base + layer remaps: layer entries override base for the same source.
-- Matches Zig per_src_inject last-write-wins semantics.
def mergeRemaps (base layer : List RemapEntry) : List RemapEntry :=
  let layerSources := layer.map (·.source)
  let baseFiltered := base.filter (fun e => !layerSources.contains e.source)
  baseFiltered ++ layer

def resolveConfig (base : MapperConfig) (activeLayer : Option Nat)
    (layers : List LayerOverrides) : MapperConfig :=
  match activeLayer with
  | none => base
  | some i =>
    match layers[i]? with
    | none => base
    | some ov =>
      { base with
        dpadMode := ov.dpadMode.getD base.dpadMode
        leftStickMode := ov.leftStickMode.getD base.leftStickMode
        rightStickMode := ov.rightStickMode.getD base.rightStickMode
        gyroActivationButton := ov.gyroActivationButton.getD base.gyroActivationButton }

/-! ## Macro trigger helpers -/

-- Trigger macros on rising edge for macro remap targets
private def triggerMacrosAux (buttons prevButtons : Nat) (remaps : List RemapEntry)
    (macros : List MacroState) (idx : Nat) : List MacroState :=
  match remaps with
  | [] => []
  | entry :: rest =>
    let prev := macros.getD idx {}
    let cur := match entry.target with
      | .macro =>
        let pressed := testBit buttons entry.source
        let wasPressed := testBit prevButtons entry.source
        if pressed && !wasPressed then { prev with active := true }
        else prev
      | _ => prev
    cur :: triggerMacrosAux buttons prevButtons rest macros (idx + 1)

private def triggerMacros (buttons prevButtons : Nat) (remaps : List RemapEntry)
    (macros : List MacroState) : List MacroState :=
  triggerMacrosAux buttons prevButtons remaps macros 0

-- Cancel all active macros, return pending release aux events
private def cancelMacros (macros : List MacroState) : List MacroState × List AuxEvent :=
  let (ms, auxs) := macros.foldl (fun (acc : List MacroState × List AuxEvent) m =>
    if m.active then
      let releases := m.pendingReleases.map fun code => AuxEvent.key code false
      (acc.1 ++ [{ active := false, pendingReleases := [] }], acc.2 ++ releases)
    else
      (acc.1 ++ [m], acc.2)
  ) ([], [])
  (ms, auxs)

/-! ## Macro timer — matching mapper.zig onTimerExpired for macro player -/

inductive MacroTimerEvent where
  | armTimer (ms : Nat)
  deriving DecidableEq, Repr

private def stepMacro (m : MacroState) : MacroState × List AuxEvent × Option MacroTimerEvent :=
  match m.steps[m.stepIndex]? with
  | none => ({ m with active := false }, [], none)
  | some step =>
    let next := { m with stepIndex := m.stepIndex + 1 }
    match step with
    | MacroStep.tap code =>
      let evts := [AuxEvent.key code true, AuxEvent.key code false]
      (next, evts, none)
    | MacroStep.down code =>
      let evts := [AuxEvent.key code true]
      ({ next with pendingReleases := next.pendingReleases ++ [code] }, evts, none)
    | MacroStep.up code =>
      let evts := [AuxEvent.key code false]
      ({ next with pendingReleases := next.pendingReleases.filter (· != code) }, evts, none)
    | MacroStep.delay ms =>
      (next, [], some (MacroTimerEvent.armTimer ms))
    | MacroStep.pauseForRelease =>
      ({ next with waitingRelease := true }, [], none)

def onMacroTimerExpired (s : MapperState) (token : Nat) : MapperState × List AuxEvent :=
  let (macros', auxs) := s.macros.foldl (fun (acc : List MacroState × List AuxEvent) m =>
    if m.active && m.timerToken == some token then
      let (m', aux, _timerReq) := stepMacro m
      (acc.1 ++ [m'], acc.2 ++ aux)
    else
      (acc.1 ++ [m], acc.2)
  ) ([], [])
  ({ s with macros := macros' }, auxs)

def notifyTriggerReleased (s : MapperState) : MapperState × List AuxEvent :=
  let (macros', auxs) := s.macros.foldl (fun (acc : List MacroState × List AuxEvent) m =>
    if m.active && m.waitingRelease then
      let m' := { m with waitingRelease := false }
      let (m'', aux, _) := stepMacro m'
      (acc.1 ++ [m''], acc.2 ++ aux)
    else
      (acc.1 ++ [m], acc.2)
  ) ([], [])
  ({ s with macros := macros' }, auxs)

/-! ## Full apply pipeline — matching mapper.zig apply() steps -/

structure ApplyResult where
  mapperState : MapperState
  gamepad : GamepadState
  auxEvents : List AuxEvent
  maskedPrev : GamepadState
  gyroActive : Bool := false
  gyroReset : Bool := false
  suppressRightStickGyro : Bool := false
  deriving Repr

def Mapper.apply (s : MapperState) (gs : GamepadState) (delta : GamepadStateDelta)
    (config : MapperConfig) (dtMs : Nat := 0) : ApplyResult :=
  -- [0] clear pending tap release from previous frame
  let tapClearMask := match s.pendingTapRelease with
    | some bit => 1 <<< bit
    | none => 0
  let s0 : MapperState := { s with pendingTapRelease := none }

  -- [1] merge delta
  let newGs := applyDelta gs delta
  let buttons := newGs.buttons

  -- [2] layer trigger processing + timer advancement
  let prevActiveLayer := getActiveLayer s0 config.layers
  let s1 := processLayerTriggers s0 buttons config.layers
  let s2 := advanceTimer s1 dtMs config.layers
  let curActiveLayer := getActiveLayer s2 config.layers
  let activeChanged := prevActiveLayer != curActiveLayer

  -- [2b] resolve per-layer config overrides
  let cfg := resolveConfig config curActiveLayer config.layerOverrides

  -- [3] dpad processing
  let dpadRes := processDpad newGs.dpad_x newGs.dpad_y gs.dpad_x gs.dpad_y
      cfg.dpadMode cfg.dpadSuppressGamepad

  -- [3b] gyro activation check (boolean only, not float math)
  let gyroActive := checkGyroActivate buttons cfg.gyroActivationButton

  -- [3b2] suppress_right_stick_gyro: when gyro active + joystick mode
  let suppressRightStickGyro := gyroActive && cfg.gyroMode == .joystick

  -- [3c] stick suppress → add to suppress mask
  let stickSuppressL := checkStickSuppressGamepad cfg.leftStickMode
  let stickSuppressR := checkStickSuppressGamepad cfg.rightStickMode

  -- [4]+[5] two-pass remap: layer entries override base for the same source
  let layerRemaps := match curActiveLayer with
    | some idx => config.layerRemaps.getD idx []
    | none => []
  let mergedRemaps := mergeRemaps config.baseRemaps layerRemaps
  let remapRes := applyRemaps buttons s2.prevButtons mergedRemaps

  -- [6] combine suppress/inject
  let suppress := remapRes.suppressMask ||| dpadRes.suppressButtons ||| tapClearMask
  let inject := remapRes.injectMask

  -- [6b] tap event injection: if pendingTapRelease was set, inject that button for one frame
  let (inject', s3tapRelease) := match s.pendingTapRelease with
    | some bit => (inject ||| (1 <<< bit), s2.pendingTapRelease)
    | none => (inject, s2.pendingTapRelease)

  -- [7] macro trigger on rising edge for macro remap targets
  let macros' := triggerMacros buttons s2.prevButtons mergedRemaps s2.macros

  -- [10] if layer active_changed, cancel macros + set gyro reset
  let (macrosFinal, macroCancelAux, gyroReset) :=
    if activeChanged then
      let (ms, aux) := cancelMacros macros'
      (ms, aux, true)
    else
      (macros', [], false)

  let allAux := dpadRes.auxEvents ++ remapRes.auxEvents ++ macroCancelAux

  -- [8] assemble emit state + prev-frame masking
  let emitButtons := assembleButtons buttons suppress inject'
  let emitGs : GamepadState := {
    newGs with
    buttons := emitButtons
    -- stick suppress: zero out axes for mouse/scroll modes
    ax := if stickSuppressL then 0 else newGs.ax
    ay := if stickSuppressL then 0 else newGs.ay
    -- skip rx/ry zeroing when gyro joystick overrides right stick
    rx := if suppressRightStickGyro then newGs.rx
          else if stickSuppressR then 0 else newGs.rx
    ry := if suppressRightStickGyro then newGs.ry
          else if stickSuppressR then 0 else newGs.ry
    dpad_x := dpadRes.dpadX
    dpad_y := dpadRes.dpadY
  }

  -- prev-frame masking: apply same suppress/inject to prevButtons so that
  -- downstream diff does not produce spurious release events for suppressed buttons
  let maskedPrevButtons := assembleButtons s2.prevButtons suppress inject'
  let maskedPrevDpadX := if dpadRes.suppressDpadHat then 0 else gs.dpad_x
  let maskedPrevDpadY := if dpadRes.suppressDpadHat then 0 else gs.dpad_y
  let maskedPrev : GamepadState := {
    gs with
    buttons := maskedPrevButtons
    dpad_x := maskedPrevDpadX
    dpad_y := maskedPrevDpadY
  }

  let sFinal : MapperState := { s2 with macros := macrosFinal, pendingTapRelease := s3tapRelease }

  { mapperState := sFinal, gamepad := emitGs, auxEvents := allAux, maskedPrev := maskedPrev,
    gyroActive := gyroActive, gyroReset := gyroReset,
    suppressRightStickGyro := suppressRightStickGyro }
