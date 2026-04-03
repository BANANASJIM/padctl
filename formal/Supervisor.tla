--------------------------- MODULE Supervisor ---------------------------
(*
 * TLA+ formal model of padctl supervisor lifecycle.
 *
 * Models the concurrency between:
 *   - Supervisor thread (reload, attach, detach, SIGHUP, inotify)
 *   - Device instance threads (run loop, disconnect, pending_mapping)
 *
 * The supervisor thread is single-threaded: reload/attach/detach are
 * mutually exclusive. Each multi-step operation (reload, detach) targets
 * exactly one device, tracked by `sup_target`.
 *
 * Device threads run concurrently with the supervisor and with each other.
 *)

EXTENDS Naturals, Sequences, FiniteSets, TLC

CONSTANTS
    Devices,        \* Set of possible device identifiers (e.g. {"d1", "d2"})
    MaxReloads,     \* Bound on reload operations for model checking
    NONE            \* Distinguished value not in Devices

VARIABLES
    \* -- Supervisor state --
    sup_phase,          \* "idle" | "reloading" | "attaching" | "detaching"
    sup_target,         \* The device currently being operated on (or "none")
    managed,            \* Set of device ids currently managed
    devname_map,        \* Set of device ids in the devname dedup map
    reload_count,       \* Number of reloads performed (bounded)
    debounce_armed,     \* Whether the inotify debounce timer is armed

    \* -- Per-device instance state --
    thread_state,       \* Function: Devices -> "none" | "running" | "stopping" | "stopped" | "disconnected"
    arena_state,        \* Function: Devices -> "valid" | "reset"
    mapper_owner,       \* Function: Devices -> "thread" | "supervisor" | "none"
    pending_mapping,    \* Function: Devices -> "none" | "pending" | "consumed"
    stop_signaled       \* Function: Devices -> BOOLEAN

vars == <<sup_phase, sup_target, managed, devname_map, reload_count, debounce_armed,
          thread_state, arena_state, mapper_owner, pending_mapping, stop_signaled>>

ASSUME NONE \notin Devices

-----------------------------------------------------------------------------
(* Type invariant *)

TypeOK ==
    /\ sup_phase \in {"idle", "reloading", "attaching", "detaching"}
    /\ sup_target \in Devices \union {NONE}
    /\ managed \subseteq Devices
    /\ devname_map \subseteq Devices
    /\ reload_count \in 0..MaxReloads
    /\ debounce_armed \in BOOLEAN
    /\ \A d \in Devices :
        /\ thread_state[d] \in {"none", "running", "stopping", "stopped", "disconnected"}
        /\ arena_state[d] \in {"valid", "reset"}
        /\ mapper_owner[d] \in {"thread", "supervisor", "none"}
        /\ pending_mapping[d] \in {"none", "pending", "consumed"}
        /\ stop_signaled[d] \in BOOLEAN

-----------------------------------------------------------------------------
(* Initial state *)

Init ==
    /\ sup_phase = "idle"
    /\ sup_target = NONE
    /\ managed = {}
    /\ devname_map = {}
    /\ reload_count = 0
    /\ debounce_armed = FALSE
    /\ thread_state  = [d \in Devices |-> "none"]
    /\ arena_state   = [d \in Devices |-> "valid"]
    /\ mapper_owner  = [d \in Devices |-> "none"]
    /\ pending_mapping = [d \in Devices |-> "none"]
    /\ stop_signaled = [d \in Devices |-> FALSE]

-----------------------------------------------------------------------------
(* Supervisor actions — all run on the supervisor thread (mutually exclusive) *)

(* Attach: atomic — init + spawn in one step (supervisor blocks until done) *)
Attach(d) ==
    /\ sup_phase = "idle"
    /\ d \notin devname_map
    /\ d \notin managed
    /\ sup_phase' = "idle"
    /\ sup_target' = NONE
    /\ managed' = managed \union {d}
    /\ devname_map' = devname_map \union {d}
    /\ thread_state' = [thread_state EXCEPT ![d] = "running"]
    /\ arena_state' = [arena_state EXCEPT ![d] = "valid"]
    /\ mapper_owner' = [mapper_owner EXCEPT ![d] = "thread"]
    /\ UNCHANGED <<reload_count, debounce_armed, pending_mapping, stop_signaled>>

(* Detach step 1: stop the target device *)
DetachStop(d) ==
    /\ sup_phase = "idle"
    /\ d \in managed
    /\ d \in devname_map
    /\ sup_phase' = "detaching"
    /\ sup_target' = d
    /\ devname_map' = devname_map \ {d}
    /\ stop_signaled' = [stop_signaled EXCEPT ![d] = TRUE]
    /\ thread_state' = [thread_state EXCEPT ![d] =
        IF thread_state[d] = "running" THEN "stopping"
        ELSE thread_state[d]]
    /\ UNCHANGED <<managed, reload_count, debounce_armed,
                   arena_state, mapper_owner, pending_mapping>>

(* Detach step 2: join the target device thread and cleanup *)
DetachJoin ==
    /\ sup_phase = "detaching"
    /\ sup_target \in Devices
    /\ LET d == sup_target IN
        /\ d \in managed
        /\ thread_state[d] \in {"stopped", "disconnected"}
        /\ managed' = managed \ {d}
        /\ thread_state' = [thread_state EXCEPT ![d] = "none"]
        /\ arena_state' = [arena_state EXCEPT ![d] = "valid"]
        /\ mapper_owner' = [mapper_owner EXCEPT ![d] = "none"]
        /\ pending_mapping' = [pending_mapping EXCEPT ![d] = "none"]
        /\ stop_signaled' = [stop_signaled EXCEPT ![d] = FALSE]
        /\ sup_phase' = "idle"
        /\ sup_target' = NONE
        /\ UNCHANGED <<devname_map, reload_count, debounce_armed>>

(* Reload step 1: stop the target device *)
ReloadBeginStop(d) ==
    /\ sup_phase = "idle"
    /\ d \in managed
    /\ reload_count < MaxReloads
    /\ sup_phase' = "reloading"
    /\ sup_target' = d
    /\ stop_signaled' = [stop_signaled EXCEPT ![d] = TRUE]
    /\ thread_state' = [thread_state EXCEPT ![d] =
        IF thread_state[d] = "running" THEN "stopping"
        ELSE thread_state[d]]
    /\ UNCHANGED <<managed, devname_map, reload_count, debounce_armed,
                   arena_state, mapper_owner, pending_mapping>>

(* Reload step 2: join target thread *)
ReloadJoin ==
    /\ sup_phase = "reloading"
    /\ sup_target \in Devices
    /\ LET d == sup_target IN
        /\ d \in managed
        /\ thread_state[d] \in {"stopped", "disconnected"}
        /\ mapper_owner' = [mapper_owner EXCEPT ![d] = "supervisor"]
        /\ thread_state' = [thread_state EXCEPT ![d] = "stopped"]
        /\ UNCHANGED <<sup_phase, sup_target, managed, devname_map, reload_count,
                       debounce_armed, arena_state, pending_mapping, stop_signaled>>

(* Reload step 3: reset arena (only after join, thread must be stopped) *)
ReloadResetArena ==
    /\ sup_phase = "reloading"
    /\ sup_target \in Devices
    /\ LET d == sup_target IN
        /\ mapper_owner[d] = "supervisor"
        /\ thread_state[d] = "stopped"
        /\ arena_state' = [arena_state EXCEPT ![d] = "reset"]
        /\ pending_mapping' = [pending_mapping EXCEPT ![d] = "none"]
        /\ UNCHANGED <<sup_phase, sup_target, managed, devname_map, reload_count,
                       debounce_armed, thread_state, mapper_owner, stop_signaled>>

(* Reload step 4: restart target with new mapper *)
ReloadRestart ==
    /\ sup_phase = "reloading"
    /\ sup_target \in Devices
    /\ LET d == sup_target IN
        /\ arena_state[d] = "reset"
        /\ mapper_owner[d] = "supervisor"
        /\ thread_state[d] = "stopped"
        /\ thread_state' = [thread_state EXCEPT ![d] = "running"]
        /\ arena_state' = [arena_state EXCEPT ![d] = "valid"]
        /\ mapper_owner' = [mapper_owner EXCEPT ![d] = "thread"]
        /\ stop_signaled' = [stop_signaled EXCEPT ![d] = FALSE]
        /\ sup_phase' = "idle"
        /\ sup_target' = NONE
        /\ reload_count' = reload_count + 1
        /\ UNCHANGED <<managed, devname_map, debounce_armed, pending_mapping>>

(* Live mapping update via pending_mapping atomic — no stop/restart *)
UpdateMapping(d) ==
    /\ sup_phase = "idle"
    /\ d \in managed
    /\ thread_state[d] = "running"
    /\ pending_mapping[d] = "none"
    /\ pending_mapping' = [pending_mapping EXCEPT ![d] = "pending"]
    /\ UNCHANGED <<sup_phase, sup_target, managed, devname_map, reload_count,
                   debounce_armed, thread_state, arena_state, mapper_owner, stop_signaled>>

(* Inotify triggers debounce timer *)
InotifyEvent ==
    /\ sup_phase = "idle"
    /\ debounce_armed' = TRUE
    /\ UNCHANGED <<sup_phase, sup_target, managed, devname_map, reload_count,
                   thread_state, arena_state, mapper_owner, pending_mapping, stop_signaled>>

(* Debounce timer fires — triggers reload of a managed device *)
DebounceFire(d) ==
    /\ sup_phase = "idle"
    /\ debounce_armed = TRUE
    /\ d \in managed
    /\ reload_count < MaxReloads
    /\ debounce_armed' = FALSE
    /\ sup_phase' = "reloading"
    /\ sup_target' = d
    /\ stop_signaled' = [stop_signaled EXCEPT ![d] = TRUE]
    /\ thread_state' = [thread_state EXCEPT ![d] =
        IF thread_state[d] = "running" THEN "stopping"
        ELSE thread_state[d]]
    /\ UNCHANGED <<managed, devname_map, reload_count,
                   arena_state, mapper_owner, pending_mapping>>

-----------------------------------------------------------------------------
(* Device thread actions — run concurrently on per-device threads *)

(* Thread processes stop signal and transitions to stopped *)
ThreadStop(d) ==
    /\ thread_state[d] = "stopping"
    /\ stop_signaled[d] = TRUE
    /\ thread_state' = [thread_state EXCEPT ![d] = "stopped"]
    /\ UNCHANGED <<sup_phase, sup_target, managed, devname_map, reload_count,
                   debounce_armed, arena_state, mapper_owner, pending_mapping, stop_signaled>>

(* Thread detects device disconnect (HUP/ERR on fd) *)
ThreadDisconnect(d) ==
    /\ thread_state[d] = "running"
    /\ thread_state' = [thread_state EXCEPT ![d] = "disconnected"]
    /\ UNCHANGED <<sup_phase, sup_target, managed, devname_map, reload_count,
                   debounce_armed, arena_state, mapper_owner, pending_mapping, stop_signaled>>

(* Thread consumes pending_mapping *)
ThreadConsumePendingMapping(d) ==
    /\ thread_state[d] = "running"
    /\ pending_mapping[d] = "pending"
    /\ pending_mapping' = [pending_mapping EXCEPT ![d] = "consumed"]
    /\ UNCHANGED <<sup_phase, sup_target, managed, devname_map, reload_count,
                   debounce_armed, thread_state, arena_state, mapper_owner, stop_signaled>>

(* Thread acknowledges consumed mapping (clears to none) *)
ThreadAckMapping(d) ==
    /\ thread_state[d] = "running"
    /\ pending_mapping[d] = "consumed"
    /\ pending_mapping' = [pending_mapping EXCEPT ![d] = "none"]
    /\ UNCHANGED <<sup_phase, sup_target, managed, devname_map, reload_count,
                   debounce_armed, thread_state, arena_state, mapper_owner, stop_signaled>>

-----------------------------------------------------------------------------
(* Next-state relation *)

Next ==
    \/ \E d \in Devices :
        \/ Attach(d)
        \/ DetachStop(d)
        \/ ReloadBeginStop(d)
        \/ UpdateMapping(d)
        \/ DebounceFire(d)
        \/ ThreadStop(d)
        \/ ThreadDisconnect(d)
        \/ ThreadConsumePendingMapping(d)
        \/ ThreadAckMapping(d)
    \/ DetachJoin
    \/ ReloadJoin
    \/ ReloadResetArena
    \/ ReloadRestart
    \/ InotifyEvent

Spec == Init /\ [][Next]_vars

-----------------------------------------------------------------------------
(* Safety properties *)

(* P1: Arena is never reset while thread is running or stopping *)
ArenaResetSafety ==
    \A d \in Devices :
        arena_state[d] = "reset" => thread_state[d] \in {"stopped", "none"}

(* P2: Mapper is only modified by supervisor when it owns it (thread stopped) *)
MapperConsistency ==
    \A d \in Devices :
        mapper_owner[d] = "supervisor" =>
            thread_state[d] \in {"stopped", "disconnected", "none"}

(* P3: Stop must be signaled before thread enters stopping state *)
StopBeforeJoin ==
    \A d \in Devices :
        thread_state[d] = "stopping" => stop_signaled[d] = TRUE

(* P4: No duplicate attach — managed implies tracked *)
NoDuplicateAttach ==
    \A d \in Devices :
        (d \in managed /\ sup_target # d) => d \in devname_map

(* P5: Thread state and arena state are consistent *)
ArenaThreadConsistency ==
    \A d \in Devices :
        /\ (thread_state[d] = "running" => arena_state[d] = "valid")
        /\ (thread_state[d] = "none" => arena_state[d] = "valid")

(* P6: pending_mapping can only exist for active devices *)
PendingMappingValid ==
    \A d \in Devices :
        pending_mapping[d] \in {"pending", "consumed"} =>
            thread_state[d] \in {"running", "stopping", "stopped", "disconnected"}

(* P7: sup_target must be a managed device when phase is not idle *)
TargetConsistency ==
    /\ (sup_phase = "idle" => sup_target = NONE)
    /\ (sup_phase \in {"reloading", "detaching"} => sup_target \in managed)

(* Combined safety invariant *)
Safety ==
    /\ TypeOK
    /\ ArenaResetSafety
    /\ MapperConsistency
    /\ StopBeforeJoin
    /\ NoDuplicateAttach
    /\ ArenaThreadConsistency
    /\ PendingMappingValid
    /\ TargetConsistency

-----------------------------------------------------------------------------
(* Liveness properties (checked under fairness) *)

Liveness ==
    \A d \in Devices :
        /\ (thread_state[d] = "stopping" ~> thread_state[d] \in {"stopped", "disconnected"})
        /\ (thread_state[d] = "stopped" /\ sup_phase \in {"reloading", "detaching"}
            ~> thread_state[d] \in {"running", "none"})

FairSpec == Spec /\ WF_vars(Next)

==========================================================================
