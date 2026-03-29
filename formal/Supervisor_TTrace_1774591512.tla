---- MODULE Supervisor_TTrace_1774591512 ----
EXTENDS Supervisor, Sequences, TLCExt, Toolbox, Supervisor_TEConstants, Naturals, TLC

_expression ==
    LET Supervisor_TEExpression == INSTANCE Supervisor_TEExpression
    IN Supervisor_TEExpression!expression
----

_trace ==
    LET Supervisor_TETrace == INSTANCE Supervisor_TETrace
    IN Supervisor_TETrace!trace
----

_prop ==
    ~<>[](
        sup_phase = ("detaching")
        /\
        sup_target = (d2)
        /\
        managed = ({d2})
        /\
        pending_mapping = ((d1 :> "none" @@ d2 :> "none"))
        /\
        thread_state = ((d1 :> "none" @@ d2 :> "stopping"))
        /\
        arena_state = ((d1 :> "valid" @@ d2 :> "valid"))
        /\
        devname_map = ({})
        /\
        reload_count = (3)
        /\
        stop_signaled = ((d1 :> FALSE @@ d2 :> TRUE))
        /\
        mapper_owner = ((d1 :> "none" @@ d2 :> "thread"))
        /\
        debounce_armed = (TRUE)
    )
----

_init ==
    /\ arena_state = _TETrace[1].arena_state
    /\ reload_count = _TETrace[1].reload_count
    /\ devname_map = _TETrace[1].devname_map
    /\ managed = _TETrace[1].managed
    /\ mapper_owner = _TETrace[1].mapper_owner
    /\ sup_phase = _TETrace[1].sup_phase
    /\ sup_target = _TETrace[1].sup_target
    /\ thread_state = _TETrace[1].thread_state
    /\ debounce_armed = _TETrace[1].debounce_armed
    /\ pending_mapping = _TETrace[1].pending_mapping
    /\ stop_signaled = _TETrace[1].stop_signaled
----

_next ==
    /\ \E i,j \in DOMAIN _TETrace:
        /\ \/ /\ j = i + 1
              /\ i = TLCGet("level")
        /\ arena_state  = _TETrace[i].arena_state
        /\ arena_state' = _TETrace[j].arena_state
        /\ reload_count  = _TETrace[i].reload_count
        /\ reload_count' = _TETrace[j].reload_count
        /\ devname_map  = _TETrace[i].devname_map
        /\ devname_map' = _TETrace[j].devname_map
        /\ managed  = _TETrace[i].managed
        /\ managed' = _TETrace[j].managed
        /\ mapper_owner  = _TETrace[i].mapper_owner
        /\ mapper_owner' = _TETrace[j].mapper_owner
        /\ sup_phase  = _TETrace[i].sup_phase
        /\ sup_phase' = _TETrace[j].sup_phase
        /\ sup_target  = _TETrace[i].sup_target
        /\ sup_target' = _TETrace[j].sup_target
        /\ thread_state  = _TETrace[i].thread_state
        /\ thread_state' = _TETrace[j].thread_state
        /\ debounce_armed  = _TETrace[i].debounce_armed
        /\ debounce_armed' = _TETrace[j].debounce_armed
        /\ pending_mapping  = _TETrace[i].pending_mapping
        /\ pending_mapping' = _TETrace[j].pending_mapping
        /\ stop_signaled  = _TETrace[i].stop_signaled
        /\ stop_signaled' = _TETrace[j].stop_signaled

\* Uncomment the ASSUME below to write the states of the error trace
\* to the given file in Json format. Note that you can pass any tuple
\* to `JsonSerialize`. For example, a sub-sequence of _TETrace.
    \* ASSUME
    \*     LET J == INSTANCE Json
    \*         IN J!JsonSerialize("Supervisor_TTrace_1774591512.json", _TETrace)

=============================================================================

 Note that you can extract this module `Supervisor_TEExpression`
  to a dedicated file to reuse `expression` (the module in the 
  dedicated `Supervisor_TEExpression.tla` file takes precedence 
  over the module `Supervisor_TEExpression` below).

---- MODULE Supervisor_TEExpression ----
EXTENDS Supervisor, Sequences, TLCExt, Toolbox, Supervisor_TEConstants, Naturals, TLC

expression == 
    [
        \* To hide variables of the `Supervisor` spec from the error trace,
        \* remove the variables below.  The trace will be written in the order
        \* of the fields of this record.
        arena_state |-> arena_state
        ,reload_count |-> reload_count
        ,devname_map |-> devname_map
        ,managed |-> managed
        ,mapper_owner |-> mapper_owner
        ,sup_phase |-> sup_phase
        ,sup_target |-> sup_target
        ,thread_state |-> thread_state
        ,debounce_armed |-> debounce_armed
        ,pending_mapping |-> pending_mapping
        ,stop_signaled |-> stop_signaled
        
        \* Put additional constant-, state-, and action-level expressions here:
        \* ,_stateNumber |-> _TEPosition
        \* ,_arena_stateUnchanged |-> arena_state = arena_state'
        
        \* Format the `arena_state` variable as Json value.
        \* ,_arena_stateJson |->
        \*     LET J == INSTANCE Json
        \*     IN J!ToJson(arena_state)
        
        \* Lastly, you may build expressions over arbitrary sets of states by
        \* leveraging the _TETrace operator.  For example, this is how to
        \* count the number of times a spec variable changed up to the current
        \* state in the trace.
        \* ,_arena_stateModCount |->
        \*     LET F[s \in DOMAIN _TETrace] ==
        \*         IF s = 1 THEN 0
        \*         ELSE IF _TETrace[s].arena_state # _TETrace[s-1].arena_state
        \*             THEN 1 + F[s-1] ELSE F[s-1]
        \*     IN F[_TEPosition - 1]
    ]

=============================================================================



Parsing and semantic processing can take forever if the trace below is long.
 In this case, it is advised to uncomment the module below to deserialize the
 trace from a generated binary file.

\*
\*---- MODULE Supervisor_TETrace ----
\*EXTENDS Supervisor, IOUtils, Supervisor_TEConstants, TLC
\*
\*trace == IODeserialize("Supervisor_TTrace_1774591512.bin", TRUE)
\*
\*=============================================================================
\*

---- MODULE Supervisor_TETrace ----
EXTENDS Supervisor, Supervisor_TEConstants, TLC

trace == 
    <<
    ([sup_phase |-> "idle",sup_target |-> NONE,managed |-> {},pending_mapping |-> (d1 :> "none" @@ d2 :> "none"),thread_state |-> (d1 :> "none" @@ d2 :> "none"),arena_state |-> (d1 :> "valid" @@ d2 :> "valid"),devname_map |-> {},reload_count |-> 0,stop_signaled |-> (d1 :> FALSE @@ d2 :> FALSE),mapper_owner |-> (d1 :> "none" @@ d2 :> "none"),debounce_armed |-> FALSE]),
    ([sup_phase |-> "idle",sup_target |-> NONE,managed |-> {},pending_mapping |-> (d1 :> "none" @@ d2 :> "none"),thread_state |-> (d1 :> "none" @@ d2 :> "none"),arena_state |-> (d1 :> "valid" @@ d2 :> "valid"),devname_map |-> {},reload_count |-> 0,stop_signaled |-> (d1 :> FALSE @@ d2 :> FALSE),mapper_owner |-> (d1 :> "none" @@ d2 :> "none"),debounce_armed |-> TRUE]),
    ([sup_phase |-> "idle",sup_target |-> NONE,managed |-> {d2},pending_mapping |-> (d1 :> "none" @@ d2 :> "none"),thread_state |-> (d1 :> "none" @@ d2 :> "running"),arena_state |-> (d1 :> "valid" @@ d2 :> "valid"),devname_map |-> {d2},reload_count |-> 0,stop_signaled |-> (d1 :> FALSE @@ d2 :> FALSE),mapper_owner |-> (d1 :> "none" @@ d2 :> "thread"),debounce_armed |-> TRUE]),
    ([sup_phase |-> "reloading",sup_target |-> d2,managed |-> {d2},pending_mapping |-> (d1 :> "none" @@ d2 :> "none"),thread_state |-> (d1 :> "none" @@ d2 :> "stopping"),arena_state |-> (d1 :> "valid" @@ d2 :> "valid"),devname_map |-> {d2},reload_count |-> 0,stop_signaled |-> (d1 :> FALSE @@ d2 :> TRUE),mapper_owner |-> (d1 :> "none" @@ d2 :> "thread"),debounce_armed |-> TRUE]),
    ([sup_phase |-> "reloading",sup_target |-> d2,managed |-> {d2},pending_mapping |-> (d1 :> "none" @@ d2 :> "none"),thread_state |-> (d1 :> "none" @@ d2 :> "stopped"),arena_state |-> (d1 :> "valid" @@ d2 :> "valid"),devname_map |-> {d2},reload_count |-> 0,stop_signaled |-> (d1 :> FALSE @@ d2 :> TRUE),mapper_owner |-> (d1 :> "none" @@ d2 :> "thread"),debounce_armed |-> TRUE]),
    ([sup_phase |-> "reloading",sup_target |-> d2,managed |-> {d2},pending_mapping |-> (d1 :> "none" @@ d2 :> "none"),thread_state |-> (d1 :> "none" @@ d2 :> "stopped"),arena_state |-> (d1 :> "valid" @@ d2 :> "valid"),devname_map |-> {d2},reload_count |-> 0,stop_signaled |-> (d1 :> FALSE @@ d2 :> TRUE),mapper_owner |-> (d1 :> "none" @@ d2 :> "supervisor"),debounce_armed |-> TRUE]),
    ([sup_phase |-> "reloading",sup_target |-> d2,managed |-> {d2},pending_mapping |-> (d1 :> "none" @@ d2 :> "none"),thread_state |-> (d1 :> "none" @@ d2 :> "stopped"),arena_state |-> (d1 :> "valid" @@ d2 :> "reset"),devname_map |-> {d2},reload_count |-> 0,stop_signaled |-> (d1 :> FALSE @@ d2 :> TRUE),mapper_owner |-> (d1 :> "none" @@ d2 :> "supervisor"),debounce_armed |-> TRUE]),
    ([sup_phase |-> "idle",sup_target |-> NONE,managed |-> {d2},pending_mapping |-> (d1 :> "none" @@ d2 :> "none"),thread_state |-> (d1 :> "none" @@ d2 :> "running"),arena_state |-> (d1 :> "valid" @@ d2 :> "valid"),devname_map |-> {d2},reload_count |-> 1,stop_signaled |-> (d1 :> FALSE @@ d2 :> FALSE),mapper_owner |-> (d1 :> "none" @@ d2 :> "thread"),debounce_armed |-> TRUE]),
    ([sup_phase |-> "idle",sup_target |-> NONE,managed |-> {d2},pending_mapping |-> (d1 :> "none" @@ d2 :> "none"),thread_state |-> (d1 :> "none" @@ d2 :> "disconnected"),arena_state |-> (d1 :> "valid" @@ d2 :> "valid"),devname_map |-> {d2},reload_count |-> 1,stop_signaled |-> (d1 :> FALSE @@ d2 :> FALSE),mapper_owner |-> (d1 :> "none" @@ d2 :> "thread"),debounce_armed |-> TRUE]),
    ([sup_phase |-> "reloading",sup_target |-> d2,managed |-> {d2},pending_mapping |-> (d1 :> "none" @@ d2 :> "none"),thread_state |-> (d1 :> "none" @@ d2 :> "disconnected"),arena_state |-> (d1 :> "valid" @@ d2 :> "valid"),devname_map |-> {d2},reload_count |-> 1,stop_signaled |-> (d1 :> FALSE @@ d2 :> TRUE),mapper_owner |-> (d1 :> "none" @@ d2 :> "thread"),debounce_armed |-> TRUE]),
    ([sup_phase |-> "reloading",sup_target |-> d2,managed |-> {d2},pending_mapping |-> (d1 :> "none" @@ d2 :> "none"),thread_state |-> (d1 :> "none" @@ d2 :> "stopped"),arena_state |-> (d1 :> "valid" @@ d2 :> "valid"),devname_map |-> {d2},reload_count |-> 1,stop_signaled |-> (d1 :> FALSE @@ d2 :> TRUE),mapper_owner |-> (d1 :> "none" @@ d2 :> "supervisor"),debounce_armed |-> TRUE]),
    ([sup_phase |-> "reloading",sup_target |-> d2,managed |-> {d2},pending_mapping |-> (d1 :> "none" @@ d2 :> "none"),thread_state |-> (d1 :> "none" @@ d2 :> "stopped"),arena_state |-> (d1 :> "valid" @@ d2 :> "reset"),devname_map |-> {d2},reload_count |-> 1,stop_signaled |-> (d1 :> FALSE @@ d2 :> TRUE),mapper_owner |-> (d1 :> "none" @@ d2 :> "supervisor"),debounce_armed |-> TRUE]),
    ([sup_phase |-> "idle",sup_target |-> NONE,managed |-> {d2},pending_mapping |-> (d1 :> "none" @@ d2 :> "none"),thread_state |-> (d1 :> "none" @@ d2 :> "running"),arena_state |-> (d1 :> "valid" @@ d2 :> "valid"),devname_map |-> {d2},reload_count |-> 2,stop_signaled |-> (d1 :> FALSE @@ d2 :> FALSE),mapper_owner |-> (d1 :> "none" @@ d2 :> "thread"),debounce_armed |-> TRUE]),
    ([sup_phase |-> "reloading",sup_target |-> d2,managed |-> {d2},pending_mapping |-> (d1 :> "none" @@ d2 :> "none"),thread_state |-> (d1 :> "none" @@ d2 :> "stopping"),arena_state |-> (d1 :> "valid" @@ d2 :> "valid"),devname_map |-> {d2},reload_count |-> 2,stop_signaled |-> (d1 :> FALSE @@ d2 :> TRUE),mapper_owner |-> (d1 :> "none" @@ d2 :> "thread"),debounce_armed |-> TRUE]),
    ([sup_phase |-> "reloading",sup_target |-> d2,managed |-> {d2},pending_mapping |-> (d1 :> "none" @@ d2 :> "none"),thread_state |-> (d1 :> "none" @@ d2 :> "stopped"),arena_state |-> (d1 :> "valid" @@ d2 :> "valid"),devname_map |-> {d2},reload_count |-> 2,stop_signaled |-> (d1 :> FALSE @@ d2 :> TRUE),mapper_owner |-> (d1 :> "none" @@ d2 :> "thread"),debounce_armed |-> TRUE]),
    ([sup_phase |-> "reloading",sup_target |-> d2,managed |-> {d2},pending_mapping |-> (d1 :> "none" @@ d2 :> "none"),thread_state |-> (d1 :> "none" @@ d2 :> "stopped"),arena_state |-> (d1 :> "valid" @@ d2 :> "valid"),devname_map |-> {d2},reload_count |-> 2,stop_signaled |-> (d1 :> FALSE @@ d2 :> TRUE),mapper_owner |-> (d1 :> "none" @@ d2 :> "supervisor"),debounce_armed |-> TRUE]),
    ([sup_phase |-> "reloading",sup_target |-> d2,managed |-> {d2},pending_mapping |-> (d1 :> "none" @@ d2 :> "none"),thread_state |-> (d1 :> "none" @@ d2 :> "stopped"),arena_state |-> (d1 :> "valid" @@ d2 :> "reset"),devname_map |-> {d2},reload_count |-> 2,stop_signaled |-> (d1 :> FALSE @@ d2 :> TRUE),mapper_owner |-> (d1 :> "none" @@ d2 :> "supervisor"),debounce_armed |-> TRUE]),
    ([sup_phase |-> "idle",sup_target |-> NONE,managed |-> {d2},pending_mapping |-> (d1 :> "none" @@ d2 :> "none"),thread_state |-> (d1 :> "none" @@ d2 :> "running"),arena_state |-> (d1 :> "valid" @@ d2 :> "valid"),devname_map |-> {d2},reload_count |-> 3,stop_signaled |-> (d1 :> FALSE @@ d2 :> FALSE),mapper_owner |-> (d1 :> "none" @@ d2 :> "thread"),debounce_armed |-> TRUE]),
    ([sup_phase |-> "detaching",sup_target |-> d2,managed |-> {d2},pending_mapping |-> (d1 :> "none" @@ d2 :> "none"),thread_state |-> (d1 :> "none" @@ d2 :> "stopping"),arena_state |-> (d1 :> "valid" @@ d2 :> "valid"),devname_map |-> {},reload_count |-> 3,stop_signaled |-> (d1 :> FALSE @@ d2 :> TRUE),mapper_owner |-> (d1 :> "none" @@ d2 :> "thread"),debounce_armed |-> TRUE])
    >>
----


=============================================================================

---- MODULE Supervisor_TEConstants ----
EXTENDS Supervisor

CONSTANTS d1, d2

=============================================================================

---- CONFIG Supervisor_TTrace_1774591512 ----
CONSTANTS
    Devices = { d1 , d2 }
    MaxReloads = 3
    NONE = NONE
    d2 = d2
    NONE = NONE
    d1 = d1

PROPERTY
    _prop

CHECK_DEADLOCK
    \* CHECK_DEADLOCK off because of PROPERTY or INVARIANT above.
    FALSE

INIT
    _init

NEXT
    _next

CONSTANT
    _TETrace <- _trace

ALIAS
    _expression
=============================================================================
\* Generated on Thu Mar 26 23:05:12 PDT 2026