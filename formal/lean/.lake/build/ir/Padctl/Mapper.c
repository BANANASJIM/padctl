// Lean compiler output
// Module: Padctl.Mapper
// Imports: public import Init public import Padctl.State
#include <lean/lean.h>
#if defined(__clang__)
#pragma clang diagnostic ignored "-Wunused-parameter"
#pragma clang diagnostic ignored "-Wunused-label"
#elif defined(__GNUC__) && !defined(__CLANG__)
#pragma GCC diagnostic ignored "-Wunused-parameter"
#pragma GCC diagnostic ignored "-Wunused-label"
#pragma GCC diagnostic ignored "-Wunused-but-set-variable"
#endif
#ifdef __cplusplus
extern "C" {
#endif
lean_object* lean_nat_shiftl(lean_object*, lean_object*);
lean_object* lean_nat_lor(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_setBit(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_setBit___boxed(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_AuxEvent_ctorIdx(lean_object*);
LEAN_EXPORT lean_object* lp_padctl_AuxEvent_ctorIdx___boxed(lean_object*);
LEAN_EXPORT lean_object* lp_padctl_AuxEvent_ctorElim___redArg(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_AuxEvent_ctorElim(lean_object*, lean_object*, lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_AuxEvent_ctorElim___boxed(lean_object*, lean_object*, lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_AuxEvent_key_elim___redArg(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_AuxEvent_key_elim(lean_object*, lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_AuxEvent_mouseButton_elim___redArg(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_AuxEvent_mouseButton_elim(lean_object*, lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_AuxEvent_rel_elim___redArg(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_AuxEvent_rel_elim(lean_object*, lean_object*, lean_object*, lean_object*);
uint8_t lean_nat_dec_eq(lean_object*, lean_object*);
uint8_t lean_int_dec_eq(lean_object*, lean_object*);
LEAN_EXPORT uint8_t lp_padctl_instDecidableEqAuxEvent_decEq(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_instDecidableEqAuxEvent_decEq___boxed(lean_object*, lean_object*);
LEAN_EXPORT uint8_t lp_padctl_instDecidableEqAuxEvent(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_instDecidableEqAuxEvent___boxed(lean_object*, lean_object*);
static const lean_string_object lp_padctl_instReprAuxEvent_repr___closed__0_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 13, .m_capacity = 13, .m_length = 12, .m_data = "AuxEvent.key"};
static const lean_object* lp_padctl_instReprAuxEvent_repr___closed__0 = (const lean_object*)&lp_padctl_instReprAuxEvent_repr___closed__0_value;
static const lean_ctor_object lp_padctl_instReprAuxEvent_repr___closed__1_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*1 + 0, .m_other = 1, .m_tag = 3}, .m_objs = {((lean_object*)&lp_padctl_instReprAuxEvent_repr___closed__0_value)}};
static const lean_object* lp_padctl_instReprAuxEvent_repr___closed__1 = (const lean_object*)&lp_padctl_instReprAuxEvent_repr___closed__1_value;
static const lean_ctor_object lp_padctl_instReprAuxEvent_repr___closed__2_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*2 + 0, .m_other = 2, .m_tag = 5}, .m_objs = {((lean_object*)&lp_padctl_instReprAuxEvent_repr___closed__1_value),((lean_object*)(((size_t)(1) << 1) | 1))}};
static const lean_object* lp_padctl_instReprAuxEvent_repr___closed__2 = (const lean_object*)&lp_padctl_instReprAuxEvent_repr___closed__2_value;
lean_object* lean_nat_to_int(lean_object*);
static lean_once_cell_t lp_padctl_instReprAuxEvent_repr___closed__3_once = LEAN_ONCE_CELL_INITIALIZER;
static lean_object* lp_padctl_instReprAuxEvent_repr___closed__3;
static lean_once_cell_t lp_padctl_instReprAuxEvent_repr___closed__4_once = LEAN_ONCE_CELL_INITIALIZER;
static lean_object* lp_padctl_instReprAuxEvent_repr___closed__4;
static const lean_string_object lp_padctl_instReprAuxEvent_repr___closed__5_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 21, .m_capacity = 21, .m_length = 20, .m_data = "AuxEvent.mouseButton"};
static const lean_object* lp_padctl_instReprAuxEvent_repr___closed__5 = (const lean_object*)&lp_padctl_instReprAuxEvent_repr___closed__5_value;
static const lean_ctor_object lp_padctl_instReprAuxEvent_repr___closed__6_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*1 + 0, .m_other = 1, .m_tag = 3}, .m_objs = {((lean_object*)&lp_padctl_instReprAuxEvent_repr___closed__5_value)}};
static const lean_object* lp_padctl_instReprAuxEvent_repr___closed__6 = (const lean_object*)&lp_padctl_instReprAuxEvent_repr___closed__6_value;
static const lean_ctor_object lp_padctl_instReprAuxEvent_repr___closed__7_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*2 + 0, .m_other = 2, .m_tag = 5}, .m_objs = {((lean_object*)&lp_padctl_instReprAuxEvent_repr___closed__6_value),((lean_object*)(((size_t)(1) << 1) | 1))}};
static const lean_object* lp_padctl_instReprAuxEvent_repr___closed__7 = (const lean_object*)&lp_padctl_instReprAuxEvent_repr___closed__7_value;
static const lean_string_object lp_padctl_instReprAuxEvent_repr___closed__8_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 13, .m_capacity = 13, .m_length = 12, .m_data = "AuxEvent.rel"};
static const lean_object* lp_padctl_instReprAuxEvent_repr___closed__8 = (const lean_object*)&lp_padctl_instReprAuxEvent_repr___closed__8_value;
static const lean_ctor_object lp_padctl_instReprAuxEvent_repr___closed__9_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*1 + 0, .m_other = 1, .m_tag = 3}, .m_objs = {((lean_object*)&lp_padctl_instReprAuxEvent_repr___closed__8_value)}};
static const lean_object* lp_padctl_instReprAuxEvent_repr___closed__9 = (const lean_object*)&lp_padctl_instReprAuxEvent_repr___closed__9_value;
static const lean_ctor_object lp_padctl_instReprAuxEvent_repr___closed__10_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*2 + 0, .m_other = 2, .m_tag = 5}, .m_objs = {((lean_object*)&lp_padctl_instReprAuxEvent_repr___closed__9_value),((lean_object*)(((size_t)(1) << 1) | 1))}};
static const lean_object* lp_padctl_instReprAuxEvent_repr___closed__10 = (const lean_object*)&lp_padctl_instReprAuxEvent_repr___closed__10_value;
static lean_once_cell_t lp_padctl_instReprAuxEvent_repr___closed__11_once = LEAN_ONCE_CELL_INITIALIZER;
static lean_object* lp_padctl_instReprAuxEvent_repr___closed__11;
lean_object* l_Repr_addAppParen(lean_object*, lean_object*);
lean_object* l_Nat_reprFast(lean_object*);
lean_object* l_Bool_repr___redArg(uint8_t);
uint8_t lean_nat_dec_le(lean_object*, lean_object*);
uint8_t lean_int_dec_lt(lean_object*, lean_object*);
lean_object* l_Int_repr(lean_object*);
LEAN_EXPORT lean_object* lp_padctl_instReprAuxEvent_repr(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_instReprAuxEvent_repr___boxed(lean_object*, lean_object*);
static const lean_closure_object lp_padctl_instReprAuxEvent___closed__0_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_closure_object) + sizeof(void*)*0, .m_other = 0, .m_tag = 245}, .m_fun = (void*)lp_padctl_instReprAuxEvent_repr___boxed, .m_arity = 2, .m_num_fixed = 0, .m_objs = {} };
static const lean_object* lp_padctl_instReprAuxEvent___closed__0 = (const lean_object*)&lp_padctl_instReprAuxEvent___closed__0_value;
LEAN_EXPORT const lean_object* lp_padctl_instReprAuxEvent = (const lean_object*)&lp_padctl_instReprAuxEvent___closed__0_value;
LEAN_EXPORT lean_object* lp_padctl_TapHoldPhase_ctorIdx(uint8_t);
LEAN_EXPORT lean_object* lp_padctl_TapHoldPhase_ctorIdx___boxed(lean_object*);
LEAN_EXPORT lean_object* lp_padctl_TapHoldPhase_toCtorIdx(uint8_t);
LEAN_EXPORT lean_object* lp_padctl_TapHoldPhase_toCtorIdx___boxed(lean_object*);
LEAN_EXPORT lean_object* lp_padctl_TapHoldPhase_ctorElim___redArg(lean_object*);
LEAN_EXPORT lean_object* lp_padctl_TapHoldPhase_ctorElim___redArg___boxed(lean_object*);
LEAN_EXPORT lean_object* lp_padctl_TapHoldPhase_ctorElim(lean_object*, lean_object*, uint8_t, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_TapHoldPhase_ctorElim___boxed(lean_object*, lean_object*, lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_TapHoldPhase_pending_elim___redArg(lean_object*);
LEAN_EXPORT lean_object* lp_padctl_TapHoldPhase_pending_elim___redArg___boxed(lean_object*);
LEAN_EXPORT lean_object* lp_padctl_TapHoldPhase_pending_elim(lean_object*, uint8_t, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_TapHoldPhase_pending_elim___boxed(lean_object*, lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_TapHoldPhase_active_elim___redArg(lean_object*);
LEAN_EXPORT lean_object* lp_padctl_TapHoldPhase_active_elim___redArg___boxed(lean_object*);
LEAN_EXPORT lean_object* lp_padctl_TapHoldPhase_active_elim(lean_object*, uint8_t, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_TapHoldPhase_active_elim___boxed(lean_object*, lean_object*, lean_object*, lean_object*);
uint8_t lean_nat_dec_le(lean_object*, lean_object*);
LEAN_EXPORT uint8_t lp_padctl_TapHoldPhase_ofNat(lean_object*);
LEAN_EXPORT lean_object* lp_padctl_TapHoldPhase_ofNat___boxed(lean_object*);
LEAN_EXPORT uint8_t lp_padctl_instDecidableEqTapHoldPhase(uint8_t, uint8_t);
LEAN_EXPORT lean_object* lp_padctl_instDecidableEqTapHoldPhase___boxed(lean_object*, lean_object*);
static const lean_string_object lp_padctl_instReprTapHoldPhase_repr___closed__0_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 21, .m_capacity = 21, .m_length = 20, .m_data = "TapHoldPhase.pending"};
static const lean_object* lp_padctl_instReprTapHoldPhase_repr___closed__0 = (const lean_object*)&lp_padctl_instReprTapHoldPhase_repr___closed__0_value;
static const lean_ctor_object lp_padctl_instReprTapHoldPhase_repr___closed__1_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*1 + 0, .m_other = 1, .m_tag = 3}, .m_objs = {((lean_object*)&lp_padctl_instReprTapHoldPhase_repr___closed__0_value)}};
static const lean_object* lp_padctl_instReprTapHoldPhase_repr___closed__1 = (const lean_object*)&lp_padctl_instReprTapHoldPhase_repr___closed__1_value;
static const lean_string_object lp_padctl_instReprTapHoldPhase_repr___closed__2_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 20, .m_capacity = 20, .m_length = 19, .m_data = "TapHoldPhase.active"};
static const lean_object* lp_padctl_instReprTapHoldPhase_repr___closed__2 = (const lean_object*)&lp_padctl_instReprTapHoldPhase_repr___closed__2_value;
static const lean_ctor_object lp_padctl_instReprTapHoldPhase_repr___closed__3_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*1 + 0, .m_other = 1, .m_tag = 3}, .m_objs = {((lean_object*)&lp_padctl_instReprTapHoldPhase_repr___closed__2_value)}};
static const lean_object* lp_padctl_instReprTapHoldPhase_repr___closed__3 = (const lean_object*)&lp_padctl_instReprTapHoldPhase_repr___closed__3_value;
LEAN_EXPORT lean_object* lp_padctl_instReprTapHoldPhase_repr(uint8_t, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_instReprTapHoldPhase_repr___boxed(lean_object*, lean_object*);
static const lean_closure_object lp_padctl_instReprTapHoldPhase___closed__0_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_closure_object) + sizeof(void*)*0, .m_other = 0, .m_tag = 245}, .m_fun = (void*)lp_padctl_instReprTapHoldPhase_repr___boxed, .m_arity = 2, .m_num_fixed = 0, .m_objs = {} };
static const lean_object* lp_padctl_instReprTapHoldPhase___closed__0 = (const lean_object*)&lp_padctl_instReprTapHoldPhase___closed__0_value;
LEAN_EXPORT const lean_object* lp_padctl_instReprTapHoldPhase = (const lean_object*)&lp_padctl_instReprTapHoldPhase___closed__0_value;
LEAN_EXPORT lean_object* lp_padctl_LayerMode_ctorIdx(uint8_t);
LEAN_EXPORT lean_object* lp_padctl_LayerMode_ctorIdx___boxed(lean_object*);
LEAN_EXPORT lean_object* lp_padctl_LayerMode_toCtorIdx(uint8_t);
LEAN_EXPORT lean_object* lp_padctl_LayerMode_toCtorIdx___boxed(lean_object*);
LEAN_EXPORT lean_object* lp_padctl_LayerMode_ctorElim___redArg(lean_object*);
LEAN_EXPORT lean_object* lp_padctl_LayerMode_ctorElim___redArg___boxed(lean_object*);
LEAN_EXPORT lean_object* lp_padctl_LayerMode_ctorElim(lean_object*, lean_object*, uint8_t, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_LayerMode_ctorElim___boxed(lean_object*, lean_object*, lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_LayerMode_hold_elim___redArg(lean_object*);
LEAN_EXPORT lean_object* lp_padctl_LayerMode_hold_elim___redArg___boxed(lean_object*);
LEAN_EXPORT lean_object* lp_padctl_LayerMode_hold_elim(lean_object*, uint8_t, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_LayerMode_hold_elim___boxed(lean_object*, lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_LayerMode_toggle_elim___redArg(lean_object*);
LEAN_EXPORT lean_object* lp_padctl_LayerMode_toggle_elim___redArg___boxed(lean_object*);
LEAN_EXPORT lean_object* lp_padctl_LayerMode_toggle_elim(lean_object*, uint8_t, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_LayerMode_toggle_elim___boxed(lean_object*, lean_object*, lean_object*, lean_object*);
LEAN_EXPORT uint8_t lp_padctl_LayerMode_ofNat(lean_object*);
LEAN_EXPORT lean_object* lp_padctl_LayerMode_ofNat___boxed(lean_object*);
LEAN_EXPORT uint8_t lp_padctl_instDecidableEqLayerMode(uint8_t, uint8_t);
LEAN_EXPORT lean_object* lp_padctl_instDecidableEqLayerMode___boxed(lean_object*, lean_object*);
static const lean_string_object lp_padctl_instReprLayerMode_repr___closed__0_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 15, .m_capacity = 15, .m_length = 14, .m_data = "LayerMode.hold"};
static const lean_object* lp_padctl_instReprLayerMode_repr___closed__0 = (const lean_object*)&lp_padctl_instReprLayerMode_repr___closed__0_value;
static const lean_ctor_object lp_padctl_instReprLayerMode_repr___closed__1_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*1 + 0, .m_other = 1, .m_tag = 3}, .m_objs = {((lean_object*)&lp_padctl_instReprLayerMode_repr___closed__0_value)}};
static const lean_object* lp_padctl_instReprLayerMode_repr___closed__1 = (const lean_object*)&lp_padctl_instReprLayerMode_repr___closed__1_value;
static const lean_string_object lp_padctl_instReprLayerMode_repr___closed__2_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 17, .m_capacity = 17, .m_length = 16, .m_data = "LayerMode.toggle"};
static const lean_object* lp_padctl_instReprLayerMode_repr___closed__2 = (const lean_object*)&lp_padctl_instReprLayerMode_repr___closed__2_value;
static const lean_ctor_object lp_padctl_instReprLayerMode_repr___closed__3_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*1 + 0, .m_other = 1, .m_tag = 3}, .m_objs = {((lean_object*)&lp_padctl_instReprLayerMode_repr___closed__2_value)}};
static const lean_object* lp_padctl_instReprLayerMode_repr___closed__3 = (const lean_object*)&lp_padctl_instReprLayerMode_repr___closed__3_value;
LEAN_EXPORT lean_object* lp_padctl_instReprLayerMode_repr(uint8_t, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_instReprLayerMode_repr___boxed(lean_object*, lean_object*);
static const lean_closure_object lp_padctl_instReprLayerMode___closed__0_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_closure_object) + sizeof(void*)*0, .m_other = 0, .m_tag = 245}, .m_fun = (void*)lp_padctl_instReprLayerMode_repr___boxed, .m_arity = 2, .m_num_fixed = 0, .m_objs = {} };
static const lean_object* lp_padctl_instReprLayerMode___closed__0 = (const lean_object*)&lp_padctl_instReprLayerMode___closed__0_value;
LEAN_EXPORT const lean_object* lp_padctl_instReprLayerMode = (const lean_object*)&lp_padctl_instReprLayerMode___closed__0_value;
LEAN_EXPORT uint8_t lp_padctl_instDecidableEqLayerConfig_decEq(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_instDecidableEqLayerConfig_decEq___boxed(lean_object*, lean_object*);
LEAN_EXPORT uint8_t lp_padctl_instDecidableEqLayerConfig(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_instDecidableEqLayerConfig___boxed(lean_object*, lean_object*);
static const lean_string_object lp_padctl_instReprLayerConfig_repr___redArg___closed__0_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 3, .m_capacity = 3, .m_length = 2, .m_data = "{ "};
static const lean_object* lp_padctl_instReprLayerConfig_repr___redArg___closed__0 = (const lean_object*)&lp_padctl_instReprLayerConfig_repr___redArg___closed__0_value;
static const lean_string_object lp_padctl_instReprLayerConfig_repr___redArg___closed__1_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 8, .m_capacity = 8, .m_length = 7, .m_data = "trigger"};
static const lean_object* lp_padctl_instReprLayerConfig_repr___redArg___closed__1 = (const lean_object*)&lp_padctl_instReprLayerConfig_repr___redArg___closed__1_value;
static const lean_ctor_object lp_padctl_instReprLayerConfig_repr___redArg___closed__2_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*1 + 0, .m_other = 1, .m_tag = 3}, .m_objs = {((lean_object*)&lp_padctl_instReprLayerConfig_repr___redArg___closed__1_value)}};
static const lean_object* lp_padctl_instReprLayerConfig_repr___redArg___closed__2 = (const lean_object*)&lp_padctl_instReprLayerConfig_repr___redArg___closed__2_value;
static const lean_ctor_object lp_padctl_instReprLayerConfig_repr___redArg___closed__3_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*2 + 0, .m_other = 2, .m_tag = 5}, .m_objs = {((lean_object*)(((size_t)(0) << 1) | 1)),((lean_object*)&lp_padctl_instReprLayerConfig_repr___redArg___closed__2_value)}};
static const lean_object* lp_padctl_instReprLayerConfig_repr___redArg___closed__3 = (const lean_object*)&lp_padctl_instReprLayerConfig_repr___redArg___closed__3_value;
static const lean_string_object lp_padctl_instReprLayerConfig_repr___redArg___closed__4_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 5, .m_capacity = 5, .m_length = 4, .m_data = " := "};
static const lean_object* lp_padctl_instReprLayerConfig_repr___redArg___closed__4 = (const lean_object*)&lp_padctl_instReprLayerConfig_repr___redArg___closed__4_value;
static const lean_ctor_object lp_padctl_instReprLayerConfig_repr___redArg___closed__5_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*1 + 0, .m_other = 1, .m_tag = 3}, .m_objs = {((lean_object*)&lp_padctl_instReprLayerConfig_repr___redArg___closed__4_value)}};
static const lean_object* lp_padctl_instReprLayerConfig_repr___redArg___closed__5 = (const lean_object*)&lp_padctl_instReprLayerConfig_repr___redArg___closed__5_value;
static const lean_ctor_object lp_padctl_instReprLayerConfig_repr___redArg___closed__6_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*2 + 0, .m_other = 2, .m_tag = 5}, .m_objs = {((lean_object*)&lp_padctl_instReprLayerConfig_repr___redArg___closed__3_value),((lean_object*)&lp_padctl_instReprLayerConfig_repr___redArg___closed__5_value)}};
static const lean_object* lp_padctl_instReprLayerConfig_repr___redArg___closed__6 = (const lean_object*)&lp_padctl_instReprLayerConfig_repr___redArg___closed__6_value;
static lean_once_cell_t lp_padctl_instReprLayerConfig_repr___redArg___closed__7_once = LEAN_ONCE_CELL_INITIALIZER;
static lean_object* lp_padctl_instReprLayerConfig_repr___redArg___closed__7;
static const lean_string_object lp_padctl_instReprLayerConfig_repr___redArg___closed__8_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 2, .m_capacity = 2, .m_length = 1, .m_data = ","};
static const lean_object* lp_padctl_instReprLayerConfig_repr___redArg___closed__8 = (const lean_object*)&lp_padctl_instReprLayerConfig_repr___redArg___closed__8_value;
static const lean_ctor_object lp_padctl_instReprLayerConfig_repr___redArg___closed__9_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*1 + 0, .m_other = 1, .m_tag = 3}, .m_objs = {((lean_object*)&lp_padctl_instReprLayerConfig_repr___redArg___closed__8_value)}};
static const lean_object* lp_padctl_instReprLayerConfig_repr___redArg___closed__9 = (const lean_object*)&lp_padctl_instReprLayerConfig_repr___redArg___closed__9_value;
static const lean_string_object lp_padctl_instReprLayerConfig_repr___redArg___closed__10_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 5, .m_capacity = 5, .m_length = 4, .m_data = "mode"};
static const lean_object* lp_padctl_instReprLayerConfig_repr___redArg___closed__10 = (const lean_object*)&lp_padctl_instReprLayerConfig_repr___redArg___closed__10_value;
static const lean_ctor_object lp_padctl_instReprLayerConfig_repr___redArg___closed__11_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*1 + 0, .m_other = 1, .m_tag = 3}, .m_objs = {((lean_object*)&lp_padctl_instReprLayerConfig_repr___redArg___closed__10_value)}};
static const lean_object* lp_padctl_instReprLayerConfig_repr___redArg___closed__11 = (const lean_object*)&lp_padctl_instReprLayerConfig_repr___redArg___closed__11_value;
static lean_once_cell_t lp_padctl_instReprLayerConfig_repr___redArg___closed__12_once = LEAN_ONCE_CELL_INITIALIZER;
static lean_object* lp_padctl_instReprLayerConfig_repr___redArg___closed__12;
static const lean_string_object lp_padctl_instReprLayerConfig_repr___redArg___closed__13_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 12, .m_capacity = 12, .m_length = 11, .m_data = "holdTimeout"};
static const lean_object* lp_padctl_instReprLayerConfig_repr___redArg___closed__13 = (const lean_object*)&lp_padctl_instReprLayerConfig_repr___redArg___closed__13_value;
static const lean_ctor_object lp_padctl_instReprLayerConfig_repr___redArg___closed__14_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*1 + 0, .m_other = 1, .m_tag = 3}, .m_objs = {((lean_object*)&lp_padctl_instReprLayerConfig_repr___redArg___closed__13_value)}};
static const lean_object* lp_padctl_instReprLayerConfig_repr___redArg___closed__14 = (const lean_object*)&lp_padctl_instReprLayerConfig_repr___redArg___closed__14_value;
static lean_once_cell_t lp_padctl_instReprLayerConfig_repr___redArg___closed__15_once = LEAN_ONCE_CELL_INITIALIZER;
static lean_object* lp_padctl_instReprLayerConfig_repr___redArg___closed__15;
static const lean_string_object lp_padctl_instReprLayerConfig_repr___redArg___closed__16_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 3, .m_capacity = 3, .m_length = 2, .m_data = " }"};
static const lean_object* lp_padctl_instReprLayerConfig_repr___redArg___closed__16 = (const lean_object*)&lp_padctl_instReprLayerConfig_repr___redArg___closed__16_value;
lean_object* lean_string_length(lean_object*);
static lean_once_cell_t lp_padctl_instReprLayerConfig_repr___redArg___closed__17_once = LEAN_ONCE_CELL_INITIALIZER;
static lean_object* lp_padctl_instReprLayerConfig_repr___redArg___closed__17;
static lean_once_cell_t lp_padctl_instReprLayerConfig_repr___redArg___closed__18_once = LEAN_ONCE_CELL_INITIALIZER;
static lean_object* lp_padctl_instReprLayerConfig_repr___redArg___closed__18;
static const lean_ctor_object lp_padctl_instReprLayerConfig_repr___redArg___closed__19_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*1 + 0, .m_other = 1, .m_tag = 3}, .m_objs = {((lean_object*)&lp_padctl_instReprLayerConfig_repr___redArg___closed__0_value)}};
static const lean_object* lp_padctl_instReprLayerConfig_repr___redArg___closed__19 = (const lean_object*)&lp_padctl_instReprLayerConfig_repr___redArg___closed__19_value;
static const lean_ctor_object lp_padctl_instReprLayerConfig_repr___redArg___closed__20_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*1 + 0, .m_other = 1, .m_tag = 3}, .m_objs = {((lean_object*)&lp_padctl_instReprLayerConfig_repr___redArg___closed__16_value)}};
static const lean_object* lp_padctl_instReprLayerConfig_repr___redArg___closed__20 = (const lean_object*)&lp_padctl_instReprLayerConfig_repr___redArg___closed__20_value;
LEAN_EXPORT lean_object* lp_padctl_instReprLayerConfig_repr___redArg(lean_object*);
LEAN_EXPORT lean_object* lp_padctl_instReprLayerConfig_repr(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_instReprLayerConfig_repr___boxed(lean_object*, lean_object*);
static const lean_closure_object lp_padctl_instReprLayerConfig___closed__0_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_closure_object) + sizeof(void*)*0, .m_other = 0, .m_tag = 245}, .m_fun = (void*)lp_padctl_instReprLayerConfig_repr___boxed, .m_arity = 2, .m_num_fixed = 0, .m_objs = {} };
static const lean_object* lp_padctl_instReprLayerConfig___closed__0 = (const lean_object*)&lp_padctl_instReprLayerConfig___closed__0_value;
LEAN_EXPORT const lean_object* lp_padctl_instReprLayerConfig = (const lean_object*)&lp_padctl_instReprLayerConfig___closed__0_value;
LEAN_EXPORT uint8_t lp_padctl_instDecidableEqTapHoldState_decEq(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_instDecidableEqTapHoldState_decEq___boxed(lean_object*, lean_object*);
LEAN_EXPORT uint8_t lp_padctl_instDecidableEqTapHoldState(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_instDecidableEqTapHoldState___boxed(lean_object*, lean_object*);
static const lean_string_object lp_padctl_instReprTapHoldState_repr___redArg___closed__0_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 9, .m_capacity = 9, .m_length = 8, .m_data = "layerIdx"};
static const lean_object* lp_padctl_instReprTapHoldState_repr___redArg___closed__0 = (const lean_object*)&lp_padctl_instReprTapHoldState_repr___redArg___closed__0_value;
static const lean_ctor_object lp_padctl_instReprTapHoldState_repr___redArg___closed__1_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*1 + 0, .m_other = 1, .m_tag = 3}, .m_objs = {((lean_object*)&lp_padctl_instReprTapHoldState_repr___redArg___closed__0_value)}};
static const lean_object* lp_padctl_instReprTapHoldState_repr___redArg___closed__1 = (const lean_object*)&lp_padctl_instReprTapHoldState_repr___redArg___closed__1_value;
static const lean_ctor_object lp_padctl_instReprTapHoldState_repr___redArg___closed__2_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*2 + 0, .m_other = 2, .m_tag = 5}, .m_objs = {((lean_object*)(((size_t)(0) << 1) | 1)),((lean_object*)&lp_padctl_instReprTapHoldState_repr___redArg___closed__1_value)}};
static const lean_object* lp_padctl_instReprTapHoldState_repr___redArg___closed__2 = (const lean_object*)&lp_padctl_instReprTapHoldState_repr___redArg___closed__2_value;
static const lean_ctor_object lp_padctl_instReprTapHoldState_repr___redArg___closed__3_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*2 + 0, .m_other = 2, .m_tag = 5}, .m_objs = {((lean_object*)&lp_padctl_instReprTapHoldState_repr___redArg___closed__2_value),((lean_object*)&lp_padctl_instReprLayerConfig_repr___redArg___closed__5_value)}};
static const lean_object* lp_padctl_instReprTapHoldState_repr___redArg___closed__3 = (const lean_object*)&lp_padctl_instReprTapHoldState_repr___redArg___closed__3_value;
static lean_once_cell_t lp_padctl_instReprTapHoldState_repr___redArg___closed__4_once = LEAN_ONCE_CELL_INITIALIZER;
static lean_object* lp_padctl_instReprTapHoldState_repr___redArg___closed__4;
static const lean_string_object lp_padctl_instReprTapHoldState_repr___redArg___closed__5_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 6, .m_capacity = 6, .m_length = 5, .m_data = "phase"};
static const lean_object* lp_padctl_instReprTapHoldState_repr___redArg___closed__5 = (const lean_object*)&lp_padctl_instReprTapHoldState_repr___redArg___closed__5_value;
static const lean_ctor_object lp_padctl_instReprTapHoldState_repr___redArg___closed__6_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*1 + 0, .m_other = 1, .m_tag = 3}, .m_objs = {((lean_object*)&lp_padctl_instReprTapHoldState_repr___redArg___closed__5_value)}};
static const lean_object* lp_padctl_instReprTapHoldState_repr___redArg___closed__6 = (const lean_object*)&lp_padctl_instReprTapHoldState_repr___redArg___closed__6_value;
static lean_once_cell_t lp_padctl_instReprTapHoldState_repr___redArg___closed__7_once = LEAN_ONCE_CELL_INITIALIZER;
static lean_object* lp_padctl_instReprTapHoldState_repr___redArg___closed__7;
static const lean_string_object lp_padctl_instReprTapHoldState_repr___redArg___closed__8_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 15, .m_capacity = 15, .m_length = 14, .m_data = "layerActivated"};
static const lean_object* lp_padctl_instReprTapHoldState_repr___redArg___closed__8 = (const lean_object*)&lp_padctl_instReprTapHoldState_repr___redArg___closed__8_value;
static const lean_ctor_object lp_padctl_instReprTapHoldState_repr___redArg___closed__9_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*1 + 0, .m_other = 1, .m_tag = 3}, .m_objs = {((lean_object*)&lp_padctl_instReprTapHoldState_repr___redArg___closed__8_value)}};
static const lean_object* lp_padctl_instReprTapHoldState_repr___redArg___closed__9 = (const lean_object*)&lp_padctl_instReprTapHoldState_repr___redArg___closed__9_value;
static lean_once_cell_t lp_padctl_instReprTapHoldState_repr___redArg___closed__10_once = LEAN_ONCE_CELL_INITIALIZER;
static lean_object* lp_padctl_instReprTapHoldState_repr___redArg___closed__10;
static const lean_string_object lp_padctl_instReprTapHoldState_repr___redArg___closed__11_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 10, .m_capacity = 10, .m_length = 9, .m_data = "elapsedMs"};
static const lean_object* lp_padctl_instReprTapHoldState_repr___redArg___closed__11 = (const lean_object*)&lp_padctl_instReprTapHoldState_repr___redArg___closed__11_value;
static const lean_ctor_object lp_padctl_instReprTapHoldState_repr___redArg___closed__12_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*1 + 0, .m_other = 1, .m_tag = 3}, .m_objs = {((lean_object*)&lp_padctl_instReprTapHoldState_repr___redArg___closed__11_value)}};
static const lean_object* lp_padctl_instReprTapHoldState_repr___redArg___closed__12 = (const lean_object*)&lp_padctl_instReprTapHoldState_repr___redArg___closed__12_value;
static lean_once_cell_t lp_padctl_instReprTapHoldState_repr___redArg___closed__13_once = LEAN_ONCE_CELL_INITIALIZER;
static lean_object* lp_padctl_instReprTapHoldState_repr___redArg___closed__13;
LEAN_EXPORT lean_object* lp_padctl_instReprTapHoldState_repr___redArg(lean_object*);
LEAN_EXPORT lean_object* lp_padctl_instReprTapHoldState_repr(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_instReprTapHoldState_repr___boxed(lean_object*, lean_object*);
static const lean_closure_object lp_padctl_instReprTapHoldState___closed__0_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_closure_object) + sizeof(void*)*0, .m_other = 0, .m_tag = 245}, .m_fun = (void*)lp_padctl_instReprTapHoldState_repr___boxed, .m_arity = 2, .m_num_fixed = 0, .m_objs = {} };
static const lean_object* lp_padctl_instReprTapHoldState___closed__0 = (const lean_object*)&lp_padctl_instReprTapHoldState___closed__0_value;
LEAN_EXPORT const lean_object* lp_padctl_instReprTapHoldState = (const lean_object*)&lp_padctl_instReprTapHoldState___closed__0_value;
LEAN_EXPORT lean_object* lp_padctl_GyroMode_ctorIdx(uint8_t);
LEAN_EXPORT lean_object* lp_padctl_GyroMode_ctorIdx___boxed(lean_object*);
LEAN_EXPORT lean_object* lp_padctl_GyroMode_toCtorIdx(uint8_t);
LEAN_EXPORT lean_object* lp_padctl_GyroMode_toCtorIdx___boxed(lean_object*);
LEAN_EXPORT lean_object* lp_padctl_GyroMode_ctorElim___redArg(lean_object*);
LEAN_EXPORT lean_object* lp_padctl_GyroMode_ctorElim___redArg___boxed(lean_object*);
LEAN_EXPORT lean_object* lp_padctl_GyroMode_ctorElim(lean_object*, lean_object*, uint8_t, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_GyroMode_ctorElim___boxed(lean_object*, lean_object*, lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_GyroMode_mouse_elim___redArg(lean_object*);
LEAN_EXPORT lean_object* lp_padctl_GyroMode_mouse_elim___redArg___boxed(lean_object*);
LEAN_EXPORT lean_object* lp_padctl_GyroMode_mouse_elim(lean_object*, uint8_t, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_GyroMode_mouse_elim___boxed(lean_object*, lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_GyroMode_joystick_elim___redArg(lean_object*);
LEAN_EXPORT lean_object* lp_padctl_GyroMode_joystick_elim___redArg___boxed(lean_object*);
LEAN_EXPORT lean_object* lp_padctl_GyroMode_joystick_elim(lean_object*, uint8_t, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_GyroMode_joystick_elim___boxed(lean_object*, lean_object*, lean_object*, lean_object*);
LEAN_EXPORT uint8_t lp_padctl_GyroMode_ofNat(lean_object*);
LEAN_EXPORT lean_object* lp_padctl_GyroMode_ofNat___boxed(lean_object*);
LEAN_EXPORT uint8_t lp_padctl_instDecidableEqGyroMode(uint8_t, uint8_t);
LEAN_EXPORT lean_object* lp_padctl_instDecidableEqGyroMode___boxed(lean_object*, lean_object*);
static const lean_string_object lp_padctl_instReprGyroMode_repr___closed__0_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 15, .m_capacity = 15, .m_length = 14, .m_data = "GyroMode.mouse"};
static const lean_object* lp_padctl_instReprGyroMode_repr___closed__0 = (const lean_object*)&lp_padctl_instReprGyroMode_repr___closed__0_value;
static const lean_ctor_object lp_padctl_instReprGyroMode_repr___closed__1_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*1 + 0, .m_other = 1, .m_tag = 3}, .m_objs = {((lean_object*)&lp_padctl_instReprGyroMode_repr___closed__0_value)}};
static const lean_object* lp_padctl_instReprGyroMode_repr___closed__1 = (const lean_object*)&lp_padctl_instReprGyroMode_repr___closed__1_value;
static const lean_string_object lp_padctl_instReprGyroMode_repr___closed__2_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 18, .m_capacity = 18, .m_length = 17, .m_data = "GyroMode.joystick"};
static const lean_object* lp_padctl_instReprGyroMode_repr___closed__2 = (const lean_object*)&lp_padctl_instReprGyroMode_repr___closed__2_value;
static const lean_ctor_object lp_padctl_instReprGyroMode_repr___closed__3_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*1 + 0, .m_other = 1, .m_tag = 3}, .m_objs = {((lean_object*)&lp_padctl_instReprGyroMode_repr___closed__2_value)}};
static const lean_object* lp_padctl_instReprGyroMode_repr___closed__3 = (const lean_object*)&lp_padctl_instReprGyroMode_repr___closed__3_value;
LEAN_EXPORT lean_object* lp_padctl_instReprGyroMode_repr(uint8_t, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_instReprGyroMode_repr___boxed(lean_object*, lean_object*);
static const lean_closure_object lp_padctl_instReprGyroMode___closed__0_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_closure_object) + sizeof(void*)*0, .m_other = 0, .m_tag = 245}, .m_fun = (void*)lp_padctl_instReprGyroMode_repr___boxed, .m_arity = 2, .m_num_fixed = 0, .m_objs = {} };
static const lean_object* lp_padctl_instReprGyroMode___closed__0 = (const lean_object*)&lp_padctl_instReprGyroMode___closed__0_value;
LEAN_EXPORT const lean_object* lp_padctl_instReprGyroMode = (const lean_object*)&lp_padctl_instReprGyroMode___closed__0_value;
uint8_t lp_padctl_testBit(lean_object*, lean_object*);
LEAN_EXPORT uint8_t lp_padctl_checkGyroActivate(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_checkGyroActivate___boxed(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_StickMode_ctorIdx(uint8_t);
LEAN_EXPORT lean_object* lp_padctl_StickMode_ctorIdx___boxed(lean_object*);
LEAN_EXPORT lean_object* lp_padctl_StickMode_toCtorIdx(uint8_t);
LEAN_EXPORT lean_object* lp_padctl_StickMode_toCtorIdx___boxed(lean_object*);
LEAN_EXPORT lean_object* lp_padctl_StickMode_ctorElim___redArg(lean_object*);
LEAN_EXPORT lean_object* lp_padctl_StickMode_ctorElim___redArg___boxed(lean_object*);
LEAN_EXPORT lean_object* lp_padctl_StickMode_ctorElim(lean_object*, lean_object*, uint8_t, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_StickMode_ctorElim___boxed(lean_object*, lean_object*, lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_StickMode_gamepad_elim___redArg(lean_object*);
LEAN_EXPORT lean_object* lp_padctl_StickMode_gamepad_elim___redArg___boxed(lean_object*);
LEAN_EXPORT lean_object* lp_padctl_StickMode_gamepad_elim(lean_object*, uint8_t, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_StickMode_gamepad_elim___boxed(lean_object*, lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_StickMode_mouse_elim___redArg(lean_object*);
LEAN_EXPORT lean_object* lp_padctl_StickMode_mouse_elim___redArg___boxed(lean_object*);
LEAN_EXPORT lean_object* lp_padctl_StickMode_mouse_elim(lean_object*, uint8_t, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_StickMode_mouse_elim___boxed(lean_object*, lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_StickMode_scroll_elim___redArg(lean_object*);
LEAN_EXPORT lean_object* lp_padctl_StickMode_scroll_elim___redArg___boxed(lean_object*);
LEAN_EXPORT lean_object* lp_padctl_StickMode_scroll_elim(lean_object*, uint8_t, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_StickMode_scroll_elim___boxed(lean_object*, lean_object*, lean_object*, lean_object*);
LEAN_EXPORT uint8_t lp_padctl_StickMode_ofNat(lean_object*);
LEAN_EXPORT lean_object* lp_padctl_StickMode_ofNat___boxed(lean_object*);
LEAN_EXPORT uint8_t lp_padctl_instDecidableEqStickMode(uint8_t, uint8_t);
LEAN_EXPORT lean_object* lp_padctl_instDecidableEqStickMode___boxed(lean_object*, lean_object*);
static const lean_string_object lp_padctl_instReprStickMode_repr___closed__0_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 18, .m_capacity = 18, .m_length = 17, .m_data = "StickMode.gamepad"};
static const lean_object* lp_padctl_instReprStickMode_repr___closed__0 = (const lean_object*)&lp_padctl_instReprStickMode_repr___closed__0_value;
static const lean_ctor_object lp_padctl_instReprStickMode_repr___closed__1_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*1 + 0, .m_other = 1, .m_tag = 3}, .m_objs = {((lean_object*)&lp_padctl_instReprStickMode_repr___closed__0_value)}};
static const lean_object* lp_padctl_instReprStickMode_repr___closed__1 = (const lean_object*)&lp_padctl_instReprStickMode_repr___closed__1_value;
static const lean_string_object lp_padctl_instReprStickMode_repr___closed__2_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 16, .m_capacity = 16, .m_length = 15, .m_data = "StickMode.mouse"};
static const lean_object* lp_padctl_instReprStickMode_repr___closed__2 = (const lean_object*)&lp_padctl_instReprStickMode_repr___closed__2_value;
static const lean_ctor_object lp_padctl_instReprStickMode_repr___closed__3_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*1 + 0, .m_other = 1, .m_tag = 3}, .m_objs = {((lean_object*)&lp_padctl_instReprStickMode_repr___closed__2_value)}};
static const lean_object* lp_padctl_instReprStickMode_repr___closed__3 = (const lean_object*)&lp_padctl_instReprStickMode_repr___closed__3_value;
static const lean_string_object lp_padctl_instReprStickMode_repr___closed__4_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 17, .m_capacity = 17, .m_length = 16, .m_data = "StickMode.scroll"};
static const lean_object* lp_padctl_instReprStickMode_repr___closed__4 = (const lean_object*)&lp_padctl_instReprStickMode_repr___closed__4_value;
static const lean_ctor_object lp_padctl_instReprStickMode_repr___closed__5_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*1 + 0, .m_other = 1, .m_tag = 3}, .m_objs = {((lean_object*)&lp_padctl_instReprStickMode_repr___closed__4_value)}};
static const lean_object* lp_padctl_instReprStickMode_repr___closed__5 = (const lean_object*)&lp_padctl_instReprStickMode_repr___closed__5_value;
LEAN_EXPORT lean_object* lp_padctl_instReprStickMode_repr(uint8_t, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_instReprStickMode_repr___boxed(lean_object*, lean_object*);
static const lean_closure_object lp_padctl_instReprStickMode___closed__0_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_closure_object) + sizeof(void*)*0, .m_other = 0, .m_tag = 245}, .m_fun = (void*)lp_padctl_instReprStickMode_repr___boxed, .m_arity = 2, .m_num_fixed = 0, .m_objs = {} };
static const lean_object* lp_padctl_instReprStickMode___closed__0 = (const lean_object*)&lp_padctl_instReprStickMode___closed__0_value;
LEAN_EXPORT const lean_object* lp_padctl_instReprStickMode = (const lean_object*)&lp_padctl_instReprStickMode___closed__0_value;
LEAN_EXPORT uint8_t lp_padctl_checkStickSuppressGamepad(uint8_t);
LEAN_EXPORT lean_object* lp_padctl_checkStickSuppressGamepad___boxed(lean_object*);
LEAN_EXPORT lean_object* lp_padctl_MacroStep_ctorIdx(lean_object*);
LEAN_EXPORT lean_object* lp_padctl_MacroStep_ctorIdx___boxed(lean_object*);
LEAN_EXPORT lean_object* lp_padctl_MacroStep_ctorElim___redArg(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_MacroStep_ctorElim(lean_object*, lean_object*, lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_MacroStep_ctorElim___boxed(lean_object*, lean_object*, lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_MacroStep_tap_elim___redArg(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_MacroStep_tap_elim(lean_object*, lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_MacroStep_down_elim___redArg(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_MacroStep_down_elim(lean_object*, lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_MacroStep_up_elim___redArg(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_MacroStep_up_elim(lean_object*, lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_MacroStep_delay_elim___redArg(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_MacroStep_delay_elim(lean_object*, lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_MacroStep_pauseForRelease_elim___redArg(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_MacroStep_pauseForRelease_elim(lean_object*, lean_object*, lean_object*, lean_object*);
LEAN_EXPORT uint8_t lp_padctl_instDecidableEqMacroStep_decEq(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_instDecidableEqMacroStep_decEq___boxed(lean_object*, lean_object*);
LEAN_EXPORT uint8_t lp_padctl_instDecidableEqMacroStep(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_instDecidableEqMacroStep___boxed(lean_object*, lean_object*);
static const lean_string_object lp_padctl_instReprMacroStep_repr___closed__0_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 26, .m_capacity = 26, .m_length = 25, .m_data = "MacroStep.pauseForRelease"};
static const lean_object* lp_padctl_instReprMacroStep_repr___closed__0 = (const lean_object*)&lp_padctl_instReprMacroStep_repr___closed__0_value;
static const lean_ctor_object lp_padctl_instReprMacroStep_repr___closed__1_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*1 + 0, .m_other = 1, .m_tag = 3}, .m_objs = {((lean_object*)&lp_padctl_instReprMacroStep_repr___closed__0_value)}};
static const lean_object* lp_padctl_instReprMacroStep_repr___closed__1 = (const lean_object*)&lp_padctl_instReprMacroStep_repr___closed__1_value;
static const lean_string_object lp_padctl_instReprMacroStep_repr___closed__2_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 14, .m_capacity = 14, .m_length = 13, .m_data = "MacroStep.tap"};
static const lean_object* lp_padctl_instReprMacroStep_repr___closed__2 = (const lean_object*)&lp_padctl_instReprMacroStep_repr___closed__2_value;
static const lean_ctor_object lp_padctl_instReprMacroStep_repr___closed__3_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*1 + 0, .m_other = 1, .m_tag = 3}, .m_objs = {((lean_object*)&lp_padctl_instReprMacroStep_repr___closed__2_value)}};
static const lean_object* lp_padctl_instReprMacroStep_repr___closed__3 = (const lean_object*)&lp_padctl_instReprMacroStep_repr___closed__3_value;
static const lean_ctor_object lp_padctl_instReprMacroStep_repr___closed__4_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*2 + 0, .m_other = 2, .m_tag = 5}, .m_objs = {((lean_object*)&lp_padctl_instReprMacroStep_repr___closed__3_value),((lean_object*)(((size_t)(1) << 1) | 1))}};
static const lean_object* lp_padctl_instReprMacroStep_repr___closed__4 = (const lean_object*)&lp_padctl_instReprMacroStep_repr___closed__4_value;
static const lean_string_object lp_padctl_instReprMacroStep_repr___closed__5_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 15, .m_capacity = 15, .m_length = 14, .m_data = "MacroStep.down"};
static const lean_object* lp_padctl_instReprMacroStep_repr___closed__5 = (const lean_object*)&lp_padctl_instReprMacroStep_repr___closed__5_value;
static const lean_ctor_object lp_padctl_instReprMacroStep_repr___closed__6_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*1 + 0, .m_other = 1, .m_tag = 3}, .m_objs = {((lean_object*)&lp_padctl_instReprMacroStep_repr___closed__5_value)}};
static const lean_object* lp_padctl_instReprMacroStep_repr___closed__6 = (const lean_object*)&lp_padctl_instReprMacroStep_repr___closed__6_value;
static const lean_ctor_object lp_padctl_instReprMacroStep_repr___closed__7_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*2 + 0, .m_other = 2, .m_tag = 5}, .m_objs = {((lean_object*)&lp_padctl_instReprMacroStep_repr___closed__6_value),((lean_object*)(((size_t)(1) << 1) | 1))}};
static const lean_object* lp_padctl_instReprMacroStep_repr___closed__7 = (const lean_object*)&lp_padctl_instReprMacroStep_repr___closed__7_value;
static const lean_string_object lp_padctl_instReprMacroStep_repr___closed__8_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 13, .m_capacity = 13, .m_length = 12, .m_data = "MacroStep.up"};
static const lean_object* lp_padctl_instReprMacroStep_repr___closed__8 = (const lean_object*)&lp_padctl_instReprMacroStep_repr___closed__8_value;
static const lean_ctor_object lp_padctl_instReprMacroStep_repr___closed__9_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*1 + 0, .m_other = 1, .m_tag = 3}, .m_objs = {((lean_object*)&lp_padctl_instReprMacroStep_repr___closed__8_value)}};
static const lean_object* lp_padctl_instReprMacroStep_repr___closed__9 = (const lean_object*)&lp_padctl_instReprMacroStep_repr___closed__9_value;
static const lean_ctor_object lp_padctl_instReprMacroStep_repr___closed__10_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*2 + 0, .m_other = 2, .m_tag = 5}, .m_objs = {((lean_object*)&lp_padctl_instReprMacroStep_repr___closed__9_value),((lean_object*)(((size_t)(1) << 1) | 1))}};
static const lean_object* lp_padctl_instReprMacroStep_repr___closed__10 = (const lean_object*)&lp_padctl_instReprMacroStep_repr___closed__10_value;
static const lean_string_object lp_padctl_instReprMacroStep_repr___closed__11_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 16, .m_capacity = 16, .m_length = 15, .m_data = "MacroStep.delay"};
static const lean_object* lp_padctl_instReprMacroStep_repr___closed__11 = (const lean_object*)&lp_padctl_instReprMacroStep_repr___closed__11_value;
static const lean_ctor_object lp_padctl_instReprMacroStep_repr___closed__12_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*1 + 0, .m_other = 1, .m_tag = 3}, .m_objs = {((lean_object*)&lp_padctl_instReprMacroStep_repr___closed__11_value)}};
static const lean_object* lp_padctl_instReprMacroStep_repr___closed__12 = (const lean_object*)&lp_padctl_instReprMacroStep_repr___closed__12_value;
static const lean_ctor_object lp_padctl_instReprMacroStep_repr___closed__13_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*2 + 0, .m_other = 2, .m_tag = 5}, .m_objs = {((lean_object*)&lp_padctl_instReprMacroStep_repr___closed__12_value),((lean_object*)(((size_t)(1) << 1) | 1))}};
static const lean_object* lp_padctl_instReprMacroStep_repr___closed__13 = (const lean_object*)&lp_padctl_instReprMacroStep_repr___closed__13_value;
LEAN_EXPORT lean_object* lp_padctl_instReprMacroStep_repr(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_instReprMacroStep_repr___boxed(lean_object*, lean_object*);
static const lean_closure_object lp_padctl_instReprMacroStep___closed__0_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_closure_object) + sizeof(void*)*0, .m_other = 0, .m_tag = 245}, .m_fun = (void*)lp_padctl_instReprMacroStep_repr___boxed, .m_arity = 2, .m_num_fixed = 0, .m_objs = {} };
static const lean_object* lp_padctl_instReprMacroStep___closed__0 = (const lean_object*)&lp_padctl_instReprMacroStep___closed__0_value;
LEAN_EXPORT const lean_object* lp_padctl_instReprMacroStep = (const lean_object*)&lp_padctl_instReprMacroStep___closed__0_value;
lean_object* l_instDecidableEqNat___boxed(lean_object*, lean_object*);
uint8_t l_instDecidableEqList___redArg(lean_object*, lean_object*, lean_object*);
uint8_t l_Option_instDecidableEq___redArg(lean_object*, lean_object*, lean_object*);
LEAN_EXPORT uint8_t lp_padctl_instDecidableEqMacroState_decEq(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_instDecidableEqMacroState_decEq___boxed(lean_object*, lean_object*);
LEAN_EXPORT uint8_t lp_padctl_instDecidableEqMacroState(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_instDecidableEqMacroState___boxed(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_List_foldl___at___00List_foldl___at___00Std_Format_joinSep___at___00List_repr___at___00instReprMacroState_repr_spec__1_spec__2_spec__4_spec__6(lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_List_foldl___at___00Std_Format_joinSep___at___00List_repr___at___00instReprMacroState_repr_spec__1_spec__2_spec__4(lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_Std_Format_joinSep___at___00List_repr___at___00instReprMacroState_repr_spec__1_spec__2___lam__0(lean_object*);
LEAN_EXPORT lean_object* lp_padctl_Std_Format_joinSep___at___00List_repr___at___00instReprMacroState_repr_spec__1_spec__2(lean_object*, lean_object*);
static const lean_string_object lp_padctl_List_repr___at___00instReprMacroState_repr_spec__1___redArg___closed__0_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 3, .m_capacity = 3, .m_length = 2, .m_data = "[]"};
static const lean_object* lp_padctl_List_repr___at___00instReprMacroState_repr_spec__1___redArg___closed__0 = (const lean_object*)&lp_padctl_List_repr___at___00instReprMacroState_repr_spec__1___redArg___closed__0_value;
static const lean_ctor_object lp_padctl_List_repr___at___00instReprMacroState_repr_spec__1___redArg___closed__1_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*1 + 0, .m_other = 1, .m_tag = 3}, .m_objs = {((lean_object*)&lp_padctl_List_repr___at___00instReprMacroState_repr_spec__1___redArg___closed__0_value)}};
static const lean_object* lp_padctl_List_repr___at___00instReprMacroState_repr_spec__1___redArg___closed__1 = (const lean_object*)&lp_padctl_List_repr___at___00instReprMacroState_repr_spec__1___redArg___closed__1_value;
static const lean_string_object lp_padctl_List_repr___at___00instReprMacroState_repr_spec__1___redArg___closed__2_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 2, .m_capacity = 2, .m_length = 1, .m_data = "["};
static const lean_object* lp_padctl_List_repr___at___00instReprMacroState_repr_spec__1___redArg___closed__2 = (const lean_object*)&lp_padctl_List_repr___at___00instReprMacroState_repr_spec__1___redArg___closed__2_value;
static const lean_ctor_object lp_padctl_List_repr___at___00instReprMacroState_repr_spec__1___redArg___closed__3_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*2 + 0, .m_other = 2, .m_tag = 5}, .m_objs = {((lean_object*)&lp_padctl_instReprLayerConfig_repr___redArg___closed__9_value),((lean_object*)(((size_t)(1) << 1) | 1))}};
static const lean_object* lp_padctl_List_repr___at___00instReprMacroState_repr_spec__1___redArg___closed__3 = (const lean_object*)&lp_padctl_List_repr___at___00instReprMacroState_repr_spec__1___redArg___closed__3_value;
static const lean_string_object lp_padctl_List_repr___at___00instReprMacroState_repr_spec__1___redArg___closed__4_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 2, .m_capacity = 2, .m_length = 1, .m_data = "]"};
static const lean_object* lp_padctl_List_repr___at___00instReprMacroState_repr_spec__1___redArg___closed__4 = (const lean_object*)&lp_padctl_List_repr___at___00instReprMacroState_repr_spec__1___redArg___closed__4_value;
static lean_once_cell_t lp_padctl_List_repr___at___00instReprMacroState_repr_spec__1___redArg___closed__5_once = LEAN_ONCE_CELL_INITIALIZER;
static lean_object* lp_padctl_List_repr___at___00instReprMacroState_repr_spec__1___redArg___closed__5;
static lean_once_cell_t lp_padctl_List_repr___at___00instReprMacroState_repr_spec__1___redArg___closed__6_once = LEAN_ONCE_CELL_INITIALIZER;
static lean_object* lp_padctl_List_repr___at___00instReprMacroState_repr_spec__1___redArg___closed__6;
static const lean_ctor_object lp_padctl_List_repr___at___00instReprMacroState_repr_spec__1___redArg___closed__7_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*1 + 0, .m_other = 1, .m_tag = 3}, .m_objs = {((lean_object*)&lp_padctl_List_repr___at___00instReprMacroState_repr_spec__1___redArg___closed__2_value)}};
static const lean_object* lp_padctl_List_repr___at___00instReprMacroState_repr_spec__1___redArg___closed__7 = (const lean_object*)&lp_padctl_List_repr___at___00instReprMacroState_repr_spec__1___redArg___closed__7_value;
static const lean_ctor_object lp_padctl_List_repr___at___00instReprMacroState_repr_spec__1___redArg___closed__8_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*1 + 0, .m_other = 1, .m_tag = 3}, .m_objs = {((lean_object*)&lp_padctl_List_repr___at___00instReprMacroState_repr_spec__1___redArg___closed__4_value)}};
static const lean_object* lp_padctl_List_repr___at___00instReprMacroState_repr_spec__1___redArg___closed__8 = (const lean_object*)&lp_padctl_List_repr___at___00instReprMacroState_repr_spec__1___redArg___closed__8_value;
LEAN_EXPORT lean_object* lp_padctl_List_repr___at___00instReprMacroState_repr_spec__1___redArg(lean_object*);
LEAN_EXPORT lean_object* lp_padctl_List_foldl___at___00List_foldl___at___00Std_Format_joinSep___at___00List_repr_x27___at___00instReprMacroState_repr_spec__0_spec__0_spec__1_spec__3(lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_List_foldl___at___00Std_Format_joinSep___at___00List_repr_x27___at___00instReprMacroState_repr_spec__0_spec__0_spec__1(lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_Std_Format_joinSep___at___00List_repr_x27___at___00instReprMacroState_repr_spec__0_spec__0___lam__0(lean_object*);
LEAN_EXPORT lean_object* lp_padctl_Std_Format_joinSep___at___00List_repr_x27___at___00instReprMacroState_repr_spec__0_spec__0(lean_object*, lean_object*);
lean_object* l_Std_Format_fill(lean_object*);
LEAN_EXPORT lean_object* lp_padctl_List_repr_x27___at___00instReprMacroState_repr_spec__0___redArg(lean_object*);
static const lean_string_object lp_padctl_instReprMacroState_repr___redArg___closed__0_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 7, .m_capacity = 7, .m_length = 6, .m_data = "active"};
static const lean_object* lp_padctl_instReprMacroState_repr___redArg___closed__0 = (const lean_object*)&lp_padctl_instReprMacroState_repr___redArg___closed__0_value;
static const lean_ctor_object lp_padctl_instReprMacroState_repr___redArg___closed__1_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*1 + 0, .m_other = 1, .m_tag = 3}, .m_objs = {((lean_object*)&lp_padctl_instReprMacroState_repr___redArg___closed__0_value)}};
static const lean_object* lp_padctl_instReprMacroState_repr___redArg___closed__1 = (const lean_object*)&lp_padctl_instReprMacroState_repr___redArg___closed__1_value;
static const lean_ctor_object lp_padctl_instReprMacroState_repr___redArg___closed__2_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*2 + 0, .m_other = 2, .m_tag = 5}, .m_objs = {((lean_object*)(((size_t)(0) << 1) | 1)),((lean_object*)&lp_padctl_instReprMacroState_repr___redArg___closed__1_value)}};
static const lean_object* lp_padctl_instReprMacroState_repr___redArg___closed__2 = (const lean_object*)&lp_padctl_instReprMacroState_repr___redArg___closed__2_value;
static const lean_ctor_object lp_padctl_instReprMacroState_repr___redArg___closed__3_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*2 + 0, .m_other = 2, .m_tag = 5}, .m_objs = {((lean_object*)&lp_padctl_instReprMacroState_repr___redArg___closed__2_value),((lean_object*)&lp_padctl_instReprLayerConfig_repr___redArg___closed__5_value)}};
static const lean_object* lp_padctl_instReprMacroState_repr___redArg___closed__3 = (const lean_object*)&lp_padctl_instReprMacroState_repr___redArg___closed__3_value;
static lean_once_cell_t lp_padctl_instReprMacroState_repr___redArg___closed__4_once = LEAN_ONCE_CELL_INITIALIZER;
static lean_object* lp_padctl_instReprMacroState_repr___redArg___closed__4;
static const lean_string_object lp_padctl_instReprMacroState_repr___redArg___closed__5_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 16, .m_capacity = 16, .m_length = 15, .m_data = "pendingReleases"};
static const lean_object* lp_padctl_instReprMacroState_repr___redArg___closed__5 = (const lean_object*)&lp_padctl_instReprMacroState_repr___redArg___closed__5_value;
static const lean_ctor_object lp_padctl_instReprMacroState_repr___redArg___closed__6_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*1 + 0, .m_other = 1, .m_tag = 3}, .m_objs = {((lean_object*)&lp_padctl_instReprMacroState_repr___redArg___closed__5_value)}};
static const lean_object* lp_padctl_instReprMacroState_repr___redArg___closed__6 = (const lean_object*)&lp_padctl_instReprMacroState_repr___redArg___closed__6_value;
static lean_once_cell_t lp_padctl_instReprMacroState_repr___redArg___closed__7_once = LEAN_ONCE_CELL_INITIALIZER;
static lean_object* lp_padctl_instReprMacroState_repr___redArg___closed__7;
static const lean_string_object lp_padctl_instReprMacroState_repr___redArg___closed__8_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 6, .m_capacity = 6, .m_length = 5, .m_data = "steps"};
static const lean_object* lp_padctl_instReprMacroState_repr___redArg___closed__8 = (const lean_object*)&lp_padctl_instReprMacroState_repr___redArg___closed__8_value;
static const lean_ctor_object lp_padctl_instReprMacroState_repr___redArg___closed__9_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*1 + 0, .m_other = 1, .m_tag = 3}, .m_objs = {((lean_object*)&lp_padctl_instReprMacroState_repr___redArg___closed__8_value)}};
static const lean_object* lp_padctl_instReprMacroState_repr___redArg___closed__9 = (const lean_object*)&lp_padctl_instReprMacroState_repr___redArg___closed__9_value;
static const lean_string_object lp_padctl_instReprMacroState_repr___redArg___closed__10_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 10, .m_capacity = 10, .m_length = 9, .m_data = "stepIndex"};
static const lean_object* lp_padctl_instReprMacroState_repr___redArg___closed__10 = (const lean_object*)&lp_padctl_instReprMacroState_repr___redArg___closed__10_value;
static const lean_ctor_object lp_padctl_instReprMacroState_repr___redArg___closed__11_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*1 + 0, .m_other = 1, .m_tag = 3}, .m_objs = {((lean_object*)&lp_padctl_instReprMacroState_repr___redArg___closed__10_value)}};
static const lean_object* lp_padctl_instReprMacroState_repr___redArg___closed__11 = (const lean_object*)&lp_padctl_instReprMacroState_repr___redArg___closed__11_value;
static const lean_string_object lp_padctl_instReprMacroState_repr___redArg___closed__12_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 11, .m_capacity = 11, .m_length = 10, .m_data = "timerToken"};
static const lean_object* lp_padctl_instReprMacroState_repr___redArg___closed__12 = (const lean_object*)&lp_padctl_instReprMacroState_repr___redArg___closed__12_value;
static const lean_ctor_object lp_padctl_instReprMacroState_repr___redArg___closed__13_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*1 + 0, .m_other = 1, .m_tag = 3}, .m_objs = {((lean_object*)&lp_padctl_instReprMacroState_repr___redArg___closed__12_value)}};
static const lean_object* lp_padctl_instReprMacroState_repr___redArg___closed__13 = (const lean_object*)&lp_padctl_instReprMacroState_repr___redArg___closed__13_value;
static lean_once_cell_t lp_padctl_instReprMacroState_repr___redArg___closed__14_once = LEAN_ONCE_CELL_INITIALIZER;
static lean_object* lp_padctl_instReprMacroState_repr___redArg___closed__14;
static const lean_string_object lp_padctl_instReprMacroState_repr___redArg___closed__15_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 15, .m_capacity = 15, .m_length = 14, .m_data = "waitingRelease"};
static const lean_object* lp_padctl_instReprMacroState_repr___redArg___closed__15 = (const lean_object*)&lp_padctl_instReprMacroState_repr___redArg___closed__15_value;
static const lean_ctor_object lp_padctl_instReprMacroState_repr___redArg___closed__16_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*1 + 0, .m_other = 1, .m_tag = 3}, .m_objs = {((lean_object*)&lp_padctl_instReprMacroState_repr___redArg___closed__15_value)}};
static const lean_object* lp_padctl_instReprMacroState_repr___redArg___closed__16 = (const lean_object*)&lp_padctl_instReprMacroState_repr___redArg___closed__16_value;
lean_object* l_Option_repr___at___00Lean_Meta_instReprConfig__1_repr_spec__0(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_instReprMacroState_repr___redArg(lean_object*);
LEAN_EXPORT lean_object* lp_padctl_instReprMacroState_repr(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_instReprMacroState_repr___boxed(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_List_repr_x27___at___00instReprMacroState_repr_spec__0(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_List_repr_x27___at___00instReprMacroState_repr_spec__0___boxed(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_List_repr___at___00instReprMacroState_repr_spec__1(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_List_repr___at___00instReprMacroState_repr_spec__1___boxed(lean_object*, lean_object*);
static const lean_closure_object lp_padctl_instReprMacroState___closed__0_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_closure_object) + sizeof(void*)*0, .m_other = 0, .m_tag = 245}, .m_fun = (void*)lp_padctl_instReprMacroState_repr___boxed, .m_arity = 2, .m_num_fixed = 0, .m_objs = {} };
static const lean_object* lp_padctl_instReprMacroState___closed__0 = (const lean_object*)&lp_padctl_instReprMacroState___closed__0_value;
LEAN_EXPORT const lean_object* lp_padctl_instReprMacroState = (const lean_object*)&lp_padctl_instReprMacroState___closed__0_value;
LEAN_EXPORT uint8_t lp_padctl_instDecidableEqMapperState_decEq___lam__0(uint8_t, uint8_t, uint8_t);
LEAN_EXPORT lean_object* lp_padctl_instDecidableEqMapperState_decEq___lam__0___boxed(lean_object*, lean_object*, lean_object*);
LEAN_EXPORT uint8_t lp_padctl_instDecidableEqMapperState_decEq(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_instDecidableEqMapperState_decEq___boxed(lean_object*, lean_object*);
LEAN_EXPORT uint8_t lp_padctl_instDecidableEqMapperState(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_instDecidableEqMapperState___boxed(lean_object*, lean_object*);
static const lean_string_object lp_padctl_Option_repr___at___00instReprMapperState_repr_spec__0___closed__0_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 5, .m_capacity = 5, .m_length = 4, .m_data = "none"};
static const lean_object* lp_padctl_Option_repr___at___00instReprMapperState_repr_spec__0___closed__0 = (const lean_object*)&lp_padctl_Option_repr___at___00instReprMapperState_repr_spec__0___closed__0_value;
static const lean_ctor_object lp_padctl_Option_repr___at___00instReprMapperState_repr_spec__0___closed__1_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*1 + 0, .m_other = 1, .m_tag = 3}, .m_objs = {((lean_object*)&lp_padctl_Option_repr___at___00instReprMapperState_repr_spec__0___closed__0_value)}};
static const lean_object* lp_padctl_Option_repr___at___00instReprMapperState_repr_spec__0___closed__1 = (const lean_object*)&lp_padctl_Option_repr___at___00instReprMapperState_repr_spec__0___closed__1_value;
static const lean_string_object lp_padctl_Option_repr___at___00instReprMapperState_repr_spec__0___closed__2_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 6, .m_capacity = 6, .m_length = 5, .m_data = "some "};
static const lean_object* lp_padctl_Option_repr___at___00instReprMapperState_repr_spec__0___closed__2 = (const lean_object*)&lp_padctl_Option_repr___at___00instReprMapperState_repr_spec__0___closed__2_value;
static const lean_ctor_object lp_padctl_Option_repr___at___00instReprMapperState_repr_spec__0___closed__3_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*1 + 0, .m_other = 1, .m_tag = 3}, .m_objs = {((lean_object*)&lp_padctl_Option_repr___at___00instReprMapperState_repr_spec__0___closed__2_value)}};
static const lean_object* lp_padctl_Option_repr___at___00instReprMapperState_repr_spec__0___closed__3 = (const lean_object*)&lp_padctl_Option_repr___at___00instReprMapperState_repr_spec__0___closed__3_value;
LEAN_EXPORT lean_object* lp_padctl_Option_repr___at___00instReprMapperState_repr_spec__0(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_Option_repr___at___00instReprMapperState_repr_spec__0___boxed(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_List_foldl___at___00List_foldl___at___00Std_Format_joinSep___at___00List_repr___at___00instReprMapperState_repr_spec__2_spec__3_spec__5_spec__7(lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_List_foldl___at___00Std_Format_joinSep___at___00List_repr___at___00instReprMapperState_repr_spec__2_spec__3_spec__5(lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_Std_Format_joinSep___at___00List_repr___at___00instReprMapperState_repr_spec__2_spec__3(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_List_repr___at___00instReprMapperState_repr_spec__2___redArg(lean_object*);
LEAN_EXPORT lean_object* lp_padctl_List_foldl___at___00List_foldl___at___00Std_Format_joinSep___at___00List_repr_x27___at___00instReprMapperState_repr_spec__1_spec__1_spec__2_spec__4(lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_List_foldl___at___00Std_Format_joinSep___at___00List_repr_x27___at___00instReprMapperState_repr_spec__1_spec__1_spec__2(lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_Std_Format_joinSep___at___00List_repr_x27___at___00instReprMapperState_repr_spec__1_spec__1(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_List_repr_x27___at___00instReprMapperState_repr_spec__1___redArg(lean_object*);
static const lean_string_object lp_padctl_instReprMapperState_repr___redArg___closed__0_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 8, .m_capacity = 8, .m_length = 7, .m_data = "buttons"};
static const lean_object* lp_padctl_instReprMapperState_repr___redArg___closed__0 = (const lean_object*)&lp_padctl_instReprMapperState_repr___redArg___closed__0_value;
static const lean_ctor_object lp_padctl_instReprMapperState_repr___redArg___closed__1_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*1 + 0, .m_other = 1, .m_tag = 3}, .m_objs = {((lean_object*)&lp_padctl_instReprMapperState_repr___redArg___closed__0_value)}};
static const lean_object* lp_padctl_instReprMapperState_repr___redArg___closed__1 = (const lean_object*)&lp_padctl_instReprMapperState_repr___redArg___closed__1_value;
static const lean_ctor_object lp_padctl_instReprMapperState_repr___redArg___closed__2_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*2 + 0, .m_other = 2, .m_tag = 5}, .m_objs = {((lean_object*)(((size_t)(0) << 1) | 1)),((lean_object*)&lp_padctl_instReprMapperState_repr___redArg___closed__1_value)}};
static const lean_object* lp_padctl_instReprMapperState_repr___redArg___closed__2 = (const lean_object*)&lp_padctl_instReprMapperState_repr___redArg___closed__2_value;
static const lean_ctor_object lp_padctl_instReprMapperState_repr___redArg___closed__3_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*2 + 0, .m_other = 2, .m_tag = 5}, .m_objs = {((lean_object*)&lp_padctl_instReprMapperState_repr___redArg___closed__2_value),((lean_object*)&lp_padctl_instReprLayerConfig_repr___redArg___closed__5_value)}};
static const lean_object* lp_padctl_instReprMapperState_repr___redArg___closed__3 = (const lean_object*)&lp_padctl_instReprMapperState_repr___redArg___closed__3_value;
static const lean_string_object lp_padctl_instReprMapperState_repr___redArg___closed__4_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 12, .m_capacity = 12, .m_length = 11, .m_data = "prevButtons"};
static const lean_object* lp_padctl_instReprMapperState_repr___redArg___closed__4 = (const lean_object*)&lp_padctl_instReprMapperState_repr___redArg___closed__4_value;
static const lean_ctor_object lp_padctl_instReprMapperState_repr___redArg___closed__5_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*1 + 0, .m_other = 1, .m_tag = 3}, .m_objs = {((lean_object*)&lp_padctl_instReprMapperState_repr___redArg___closed__4_value)}};
static const lean_object* lp_padctl_instReprMapperState_repr___redArg___closed__5 = (const lean_object*)&lp_padctl_instReprMapperState_repr___redArg___closed__5_value;
static const lean_string_object lp_padctl_instReprMapperState_repr___redArg___closed__6_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 8, .m_capacity = 8, .m_length = 7, .m_data = "tapHold"};
static const lean_object* lp_padctl_instReprMapperState_repr___redArg___closed__6 = (const lean_object*)&lp_padctl_instReprMapperState_repr___redArg___closed__6_value;
static const lean_ctor_object lp_padctl_instReprMapperState_repr___redArg___closed__7_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*1 + 0, .m_other = 1, .m_tag = 3}, .m_objs = {((lean_object*)&lp_padctl_instReprMapperState_repr___redArg___closed__6_value)}};
static const lean_object* lp_padctl_instReprMapperState_repr___redArg___closed__7 = (const lean_object*)&lp_padctl_instReprMapperState_repr___redArg___closed__7_value;
static const lean_string_object lp_padctl_instReprMapperState_repr___redArg___closed__8_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 8, .m_capacity = 8, .m_length = 7, .m_data = "toggled"};
static const lean_object* lp_padctl_instReprMapperState_repr___redArg___closed__8 = (const lean_object*)&lp_padctl_instReprMapperState_repr___redArg___closed__8_value;
static const lean_ctor_object lp_padctl_instReprMapperState_repr___redArg___closed__9_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*1 + 0, .m_other = 1, .m_tag = 3}, .m_objs = {((lean_object*)&lp_padctl_instReprMapperState_repr___redArg___closed__8_value)}};
static const lean_object* lp_padctl_instReprMapperState_repr___redArg___closed__9 = (const lean_object*)&lp_padctl_instReprMapperState_repr___redArg___closed__9_value;
static const lean_string_object lp_padctl_instReprMapperState_repr___redArg___closed__10_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 7, .m_capacity = 7, .m_length = 6, .m_data = "macros"};
static const lean_object* lp_padctl_instReprMapperState_repr___redArg___closed__10 = (const lean_object*)&lp_padctl_instReprMapperState_repr___redArg___closed__10_value;
static const lean_ctor_object lp_padctl_instReprMapperState_repr___redArg___closed__11_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*1 + 0, .m_other = 1, .m_tag = 3}, .m_objs = {((lean_object*)&lp_padctl_instReprMapperState_repr___redArg___closed__10_value)}};
static const lean_object* lp_padctl_instReprMapperState_repr___redArg___closed__11 = (const lean_object*)&lp_padctl_instReprMapperState_repr___redArg___closed__11_value;
static const lean_string_object lp_padctl_instReprMapperState_repr___redArg___closed__12_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 18, .m_capacity = 18, .m_length = 17, .m_data = "pendingTapRelease"};
static const lean_object* lp_padctl_instReprMapperState_repr___redArg___closed__12 = (const lean_object*)&lp_padctl_instReprMapperState_repr___redArg___closed__12_value;
static const lean_ctor_object lp_padctl_instReprMapperState_repr___redArg___closed__13_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*1 + 0, .m_other = 1, .m_tag = 3}, .m_objs = {((lean_object*)&lp_padctl_instReprMapperState_repr___redArg___closed__12_value)}};
static const lean_object* lp_padctl_instReprMapperState_repr___redArg___closed__13 = (const lean_object*)&lp_padctl_instReprMapperState_repr___redArg___closed__13_value;
static lean_once_cell_t lp_padctl_instReprMapperState_repr___redArg___closed__14_once = LEAN_ONCE_CELL_INITIALIZER;
static lean_object* lp_padctl_instReprMapperState_repr___redArg___closed__14;
LEAN_EXPORT lean_object* lp_padctl_instReprMapperState_repr___redArg(lean_object*);
LEAN_EXPORT lean_object* lp_padctl_instReprMapperState_repr(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_instReprMapperState_repr___boxed(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_List_repr_x27___at___00instReprMapperState_repr_spec__1(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_List_repr_x27___at___00instReprMapperState_repr_spec__1___boxed(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_List_repr___at___00instReprMapperState_repr_spec__2(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_List_repr___at___00instReprMapperState_repr_spec__2___boxed(lean_object*, lean_object*);
static const lean_closure_object lp_padctl_instReprMapperState___closed__0_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_closure_object) + sizeof(void*)*0, .m_other = 0, .m_tag = 245}, .m_fun = (void*)lp_padctl_instReprMapperState_repr___boxed, .m_arity = 2, .m_num_fixed = 0, .m_objs = {} };
static const lean_object* lp_padctl_instReprMapperState___closed__0 = (const lean_object*)&lp_padctl_instReprMapperState___closed__0_value;
LEAN_EXPORT const lean_object* lp_padctl_instReprMapperState = (const lean_object*)&lp_padctl_instReprMapperState___closed__0_value;
LEAN_EXPORT lean_object* lp_padctl_onTriggerPress(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_onTapHoldTimerExpired(lean_object*);
lean_object* lean_nat_add(lean_object*, lean_object*);
lean_object* l_List_get_x3fInternal___redArg(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_advanceTimer(lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_advanceTimer___boxed(lean_object*, lean_object*, lean_object*);
LEAN_EXPORT uint8_t lp_padctl_instDecidableEqTapEvent_decEq(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_instDecidableEqTapEvent_decEq___boxed(lean_object*, lean_object*);
LEAN_EXPORT uint8_t lp_padctl_instDecidableEqTapEvent(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_instDecidableEqTapEvent___boxed(lean_object*, lean_object*);
static const lean_string_object lp_padctl_instReprTapEvent_repr___redArg___closed__0_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 10, .m_capacity = 10, .m_length = 9, .m_data = "buttonBit"};
static const lean_object* lp_padctl_instReprTapEvent_repr___redArg___closed__0 = (const lean_object*)&lp_padctl_instReprTapEvent_repr___redArg___closed__0_value;
static const lean_ctor_object lp_padctl_instReprTapEvent_repr___redArg___closed__1_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*1 + 0, .m_other = 1, .m_tag = 3}, .m_objs = {((lean_object*)&lp_padctl_instReprTapEvent_repr___redArg___closed__0_value)}};
static const lean_object* lp_padctl_instReprTapEvent_repr___redArg___closed__1 = (const lean_object*)&lp_padctl_instReprTapEvent_repr___redArg___closed__1_value;
static const lean_ctor_object lp_padctl_instReprTapEvent_repr___redArg___closed__2_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*2 + 0, .m_other = 2, .m_tag = 5}, .m_objs = {((lean_object*)(((size_t)(0) << 1) | 1)),((lean_object*)&lp_padctl_instReprTapEvent_repr___redArg___closed__1_value)}};
static const lean_object* lp_padctl_instReprTapEvent_repr___redArg___closed__2 = (const lean_object*)&lp_padctl_instReprTapEvent_repr___redArg___closed__2_value;
static const lean_ctor_object lp_padctl_instReprTapEvent_repr___redArg___closed__3_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*2 + 0, .m_other = 2, .m_tag = 5}, .m_objs = {((lean_object*)&lp_padctl_instReprTapEvent_repr___redArg___closed__2_value),((lean_object*)&lp_padctl_instReprLayerConfig_repr___redArg___closed__5_value)}};
static const lean_object* lp_padctl_instReprTapEvent_repr___redArg___closed__3 = (const lean_object*)&lp_padctl_instReprTapEvent_repr___redArg___closed__3_value;
LEAN_EXPORT lean_object* lp_padctl_instReprTapEvent_repr___redArg(lean_object*);
LEAN_EXPORT lean_object* lp_padctl_instReprTapEvent_repr(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_instReprTapEvent_repr___boxed(lean_object*, lean_object*);
static const lean_closure_object lp_padctl_instReprTapEvent___closed__0_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_closure_object) + sizeof(void*)*0, .m_other = 0, .m_tag = 245}, .m_fun = (void*)lp_padctl_instReprTapEvent_repr___boxed, .m_arity = 2, .m_num_fixed = 0, .m_objs = {} };
static const lean_object* lp_padctl_instReprTapEvent___closed__0 = (const lean_object*)&lp_padctl_instReprTapEvent___closed__0_value;
LEAN_EXPORT const lean_object* lp_padctl_instReprTapEvent = (const lean_object*)&lp_padctl_instReprTapEvent___closed__0_value;
LEAN_EXPORT lean_object* lp_padctl_onTriggerRelease(lean_object*);
LEAN_EXPORT lean_object* lp_padctl___private_Padctl_Mapper_0__firstToggled(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl___private_Padctl_Mapper_0__firstToggled___boxed(lean_object*, lean_object*);
lean_object* l_List_lengthTR___redArg(lean_object*);
uint8_t lean_nat_dec_lt(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_getActiveLayer(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_getActiveLayer___boxed(lean_object*, lean_object*);
lean_object* lean_mk_empty_array_with_capacity(lean_object*);
static lean_once_cell_t lp_padctl___private_Padctl_Mapper_0__processLayerTriggersAux___closed__0_once = LEAN_ONCE_CELL_INITIALIZER;
static lean_object* lp_padctl___private_Padctl_Mapper_0__processLayerTriggersAux___closed__0;
LEAN_EXPORT lean_object* lp_padctl___private_Padctl_Mapper_0__processLayerTriggersAux(lean_object*, lean_object*, lean_object*);
lean_object* l_List_getD___redArg(lean_object*, lean_object*, lean_object*);
lean_object* l___private_Init_Data_List_Impl_0__List_setTR_go___redArg(lean_object*, lean_object*, lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl___private_Padctl_Mapper_0__processLayerTriggersAux___boxed(lean_object*, lean_object*, lean_object*);
lean_object* lean_nat_sub(lean_object*, lean_object*);
lean_object* l_List_replicateTR___redArg(lean_object*, lean_object*);
lean_object* l_List_appendTR___redArg(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl___private_Padctl_Mapper_0__padToggled(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl___private_Padctl_Mapper_0__padToggled___boxed(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_processLayerTriggers(lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_processLayerTriggers___boxed(lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_RemapTarget_ctorIdx(lean_object*);
LEAN_EXPORT lean_object* lp_padctl_RemapTarget_ctorIdx___boxed(lean_object*);
LEAN_EXPORT lean_object* lp_padctl_RemapTarget_ctorElim___redArg(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_RemapTarget_ctorElim(lean_object*, lean_object*, lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_RemapTarget_ctorElim___boxed(lean_object*, lean_object*, lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_RemapTarget_gamepadButton_elim___redArg(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_RemapTarget_gamepadButton_elim(lean_object*, lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_RemapTarget_key_elim___redArg(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_RemapTarget_key_elim(lean_object*, lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_RemapTarget_mouseButton_elim___redArg(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_RemapTarget_mouseButton_elim(lean_object*, lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_RemapTarget_disabled_elim___redArg(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_RemapTarget_disabled_elim(lean_object*, lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_RemapTarget_macro_elim___redArg(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_RemapTarget_macro_elim(lean_object*, lean_object*, lean_object*, lean_object*);
LEAN_EXPORT uint8_t lp_padctl_instDecidableEqRemapTarget_decEq(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_instDecidableEqRemapTarget_decEq___boxed(lean_object*, lean_object*);
LEAN_EXPORT uint8_t lp_padctl_instDecidableEqRemapTarget(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_instDecidableEqRemapTarget___boxed(lean_object*, lean_object*);
static const lean_string_object lp_padctl_instReprRemapTarget_repr___closed__0_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 21, .m_capacity = 21, .m_length = 20, .m_data = "RemapTarget.disabled"};
static const lean_object* lp_padctl_instReprRemapTarget_repr___closed__0 = (const lean_object*)&lp_padctl_instReprRemapTarget_repr___closed__0_value;
static const lean_ctor_object lp_padctl_instReprRemapTarget_repr___closed__1_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*1 + 0, .m_other = 1, .m_tag = 3}, .m_objs = {((lean_object*)&lp_padctl_instReprRemapTarget_repr___closed__0_value)}};
static const lean_object* lp_padctl_instReprRemapTarget_repr___closed__1 = (const lean_object*)&lp_padctl_instReprRemapTarget_repr___closed__1_value;
static const lean_string_object lp_padctl_instReprRemapTarget_repr___closed__2_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 18, .m_capacity = 18, .m_length = 17, .m_data = "RemapTarget.macro"};
static const lean_object* lp_padctl_instReprRemapTarget_repr___closed__2 = (const lean_object*)&lp_padctl_instReprRemapTarget_repr___closed__2_value;
static const lean_ctor_object lp_padctl_instReprRemapTarget_repr___closed__3_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*1 + 0, .m_other = 1, .m_tag = 3}, .m_objs = {((lean_object*)&lp_padctl_instReprRemapTarget_repr___closed__2_value)}};
static const lean_object* lp_padctl_instReprRemapTarget_repr___closed__3 = (const lean_object*)&lp_padctl_instReprRemapTarget_repr___closed__3_value;
static const lean_string_object lp_padctl_instReprRemapTarget_repr___closed__4_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 26, .m_capacity = 26, .m_length = 25, .m_data = "RemapTarget.gamepadButton"};
static const lean_object* lp_padctl_instReprRemapTarget_repr___closed__4 = (const lean_object*)&lp_padctl_instReprRemapTarget_repr___closed__4_value;
static const lean_ctor_object lp_padctl_instReprRemapTarget_repr___closed__5_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*1 + 0, .m_other = 1, .m_tag = 3}, .m_objs = {((lean_object*)&lp_padctl_instReprRemapTarget_repr___closed__4_value)}};
static const lean_object* lp_padctl_instReprRemapTarget_repr___closed__5 = (const lean_object*)&lp_padctl_instReprRemapTarget_repr___closed__5_value;
static const lean_ctor_object lp_padctl_instReprRemapTarget_repr___closed__6_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*2 + 0, .m_other = 2, .m_tag = 5}, .m_objs = {((lean_object*)&lp_padctl_instReprRemapTarget_repr___closed__5_value),((lean_object*)(((size_t)(1) << 1) | 1))}};
static const lean_object* lp_padctl_instReprRemapTarget_repr___closed__6 = (const lean_object*)&lp_padctl_instReprRemapTarget_repr___closed__6_value;
static const lean_string_object lp_padctl_instReprRemapTarget_repr___closed__7_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 16, .m_capacity = 16, .m_length = 15, .m_data = "RemapTarget.key"};
static const lean_object* lp_padctl_instReprRemapTarget_repr___closed__7 = (const lean_object*)&lp_padctl_instReprRemapTarget_repr___closed__7_value;
static const lean_ctor_object lp_padctl_instReprRemapTarget_repr___closed__8_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*1 + 0, .m_other = 1, .m_tag = 3}, .m_objs = {((lean_object*)&lp_padctl_instReprRemapTarget_repr___closed__7_value)}};
static const lean_object* lp_padctl_instReprRemapTarget_repr___closed__8 = (const lean_object*)&lp_padctl_instReprRemapTarget_repr___closed__8_value;
static const lean_ctor_object lp_padctl_instReprRemapTarget_repr___closed__9_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*2 + 0, .m_other = 2, .m_tag = 5}, .m_objs = {((lean_object*)&lp_padctl_instReprRemapTarget_repr___closed__8_value),((lean_object*)(((size_t)(1) << 1) | 1))}};
static const lean_object* lp_padctl_instReprRemapTarget_repr___closed__9 = (const lean_object*)&lp_padctl_instReprRemapTarget_repr___closed__9_value;
static const lean_string_object lp_padctl_instReprRemapTarget_repr___closed__10_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 24, .m_capacity = 24, .m_length = 23, .m_data = "RemapTarget.mouseButton"};
static const lean_object* lp_padctl_instReprRemapTarget_repr___closed__10 = (const lean_object*)&lp_padctl_instReprRemapTarget_repr___closed__10_value;
static const lean_ctor_object lp_padctl_instReprRemapTarget_repr___closed__11_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*1 + 0, .m_other = 1, .m_tag = 3}, .m_objs = {((lean_object*)&lp_padctl_instReprRemapTarget_repr___closed__10_value)}};
static const lean_object* lp_padctl_instReprRemapTarget_repr___closed__11 = (const lean_object*)&lp_padctl_instReprRemapTarget_repr___closed__11_value;
static const lean_ctor_object lp_padctl_instReprRemapTarget_repr___closed__12_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*2 + 0, .m_other = 2, .m_tag = 5}, .m_objs = {((lean_object*)&lp_padctl_instReprRemapTarget_repr___closed__11_value),((lean_object*)(((size_t)(1) << 1) | 1))}};
static const lean_object* lp_padctl_instReprRemapTarget_repr___closed__12 = (const lean_object*)&lp_padctl_instReprRemapTarget_repr___closed__12_value;
LEAN_EXPORT lean_object* lp_padctl_instReprRemapTarget_repr(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_instReprRemapTarget_repr___boxed(lean_object*, lean_object*);
static const lean_closure_object lp_padctl_instReprRemapTarget___closed__0_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_closure_object) + sizeof(void*)*0, .m_other = 0, .m_tag = 245}, .m_fun = (void*)lp_padctl_instReprRemapTarget_repr___boxed, .m_arity = 2, .m_num_fixed = 0, .m_objs = {} };
static const lean_object* lp_padctl_instReprRemapTarget___closed__0 = (const lean_object*)&lp_padctl_instReprRemapTarget___closed__0_value;
LEAN_EXPORT const lean_object* lp_padctl_instReprRemapTarget = (const lean_object*)&lp_padctl_instReprRemapTarget___closed__0_value;
LEAN_EXPORT uint8_t lp_padctl_instDecidableEqRemapEntry_decEq(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_instDecidableEqRemapEntry_decEq___boxed(lean_object*, lean_object*);
LEAN_EXPORT uint8_t lp_padctl_instDecidableEqRemapEntry(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_instDecidableEqRemapEntry___boxed(lean_object*, lean_object*);
static const lean_string_object lp_padctl_instReprRemapEntry_repr___redArg___closed__0_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 7, .m_capacity = 7, .m_length = 6, .m_data = "source"};
static const lean_object* lp_padctl_instReprRemapEntry_repr___redArg___closed__0 = (const lean_object*)&lp_padctl_instReprRemapEntry_repr___redArg___closed__0_value;
static const lean_ctor_object lp_padctl_instReprRemapEntry_repr___redArg___closed__1_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*1 + 0, .m_other = 1, .m_tag = 3}, .m_objs = {((lean_object*)&lp_padctl_instReprRemapEntry_repr___redArg___closed__0_value)}};
static const lean_object* lp_padctl_instReprRemapEntry_repr___redArg___closed__1 = (const lean_object*)&lp_padctl_instReprRemapEntry_repr___redArg___closed__1_value;
static const lean_ctor_object lp_padctl_instReprRemapEntry_repr___redArg___closed__2_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*2 + 0, .m_other = 2, .m_tag = 5}, .m_objs = {((lean_object*)(((size_t)(0) << 1) | 1)),((lean_object*)&lp_padctl_instReprRemapEntry_repr___redArg___closed__1_value)}};
static const lean_object* lp_padctl_instReprRemapEntry_repr___redArg___closed__2 = (const lean_object*)&lp_padctl_instReprRemapEntry_repr___redArg___closed__2_value;
static const lean_ctor_object lp_padctl_instReprRemapEntry_repr___redArg___closed__3_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*2 + 0, .m_other = 2, .m_tag = 5}, .m_objs = {((lean_object*)&lp_padctl_instReprRemapEntry_repr___redArg___closed__2_value),((lean_object*)&lp_padctl_instReprLayerConfig_repr___redArg___closed__5_value)}};
static const lean_object* lp_padctl_instReprRemapEntry_repr___redArg___closed__3 = (const lean_object*)&lp_padctl_instReprRemapEntry_repr___redArg___closed__3_value;
static const lean_string_object lp_padctl_instReprRemapEntry_repr___redArg___closed__4_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 7, .m_capacity = 7, .m_length = 6, .m_data = "target"};
static const lean_object* lp_padctl_instReprRemapEntry_repr___redArg___closed__4 = (const lean_object*)&lp_padctl_instReprRemapEntry_repr___redArg___closed__4_value;
static const lean_ctor_object lp_padctl_instReprRemapEntry_repr___redArg___closed__5_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*1 + 0, .m_other = 1, .m_tag = 3}, .m_objs = {((lean_object*)&lp_padctl_instReprRemapEntry_repr___redArg___closed__4_value)}};
static const lean_object* lp_padctl_instReprRemapEntry_repr___redArg___closed__5 = (const lean_object*)&lp_padctl_instReprRemapEntry_repr___redArg___closed__5_value;
LEAN_EXPORT lean_object* lp_padctl_instReprRemapEntry_repr___redArg(lean_object*);
LEAN_EXPORT lean_object* lp_padctl_instReprRemapEntry_repr(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_instReprRemapEntry_repr___boxed(lean_object*, lean_object*);
static const lean_closure_object lp_padctl_instReprRemapEntry___closed__0_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_closure_object) + sizeof(void*)*0, .m_other = 0, .m_tag = 245}, .m_fun = (void*)lp_padctl_instReprRemapEntry_repr___boxed, .m_arity = 2, .m_num_fixed = 0, .m_objs = {} };
static const lean_object* lp_padctl_instReprRemapEntry___closed__0 = (const lean_object*)&lp_padctl_instReprRemapEntry___closed__0_value;
LEAN_EXPORT const lean_object* lp_padctl_instReprRemapEntry = (const lean_object*)&lp_padctl_instReprRemapEntry___closed__0_value;
LEAN_EXPORT lean_object* lp_padctl_List_foldl___at___00List_foldl___at___00Std_Format_joinSep___at___00List_repr___at___00instReprRemapResult_repr_spec__0_spec__0_spec__1_spec__2(lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_List_foldl___at___00Std_Format_joinSep___at___00List_repr___at___00instReprRemapResult_repr_spec__0_spec__0_spec__1(lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_Std_Format_joinSep___at___00List_repr___at___00instReprRemapResult_repr_spec__0_spec__0___lam__0(lean_object*);
LEAN_EXPORT lean_object* lp_padctl_Std_Format_joinSep___at___00List_repr___at___00instReprRemapResult_repr_spec__0_spec__0(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_List_repr___at___00instReprRemapResult_repr_spec__0___redArg(lean_object*);
static const lean_string_object lp_padctl_instReprRemapResult_repr___redArg___closed__0_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 13, .m_capacity = 13, .m_length = 12, .m_data = "suppressMask"};
static const lean_object* lp_padctl_instReprRemapResult_repr___redArg___closed__0 = (const lean_object*)&lp_padctl_instReprRemapResult_repr___redArg___closed__0_value;
static const lean_ctor_object lp_padctl_instReprRemapResult_repr___redArg___closed__1_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*1 + 0, .m_other = 1, .m_tag = 3}, .m_objs = {((lean_object*)&lp_padctl_instReprRemapResult_repr___redArg___closed__0_value)}};
static const lean_object* lp_padctl_instReprRemapResult_repr___redArg___closed__1 = (const lean_object*)&lp_padctl_instReprRemapResult_repr___redArg___closed__1_value;
static const lean_ctor_object lp_padctl_instReprRemapResult_repr___redArg___closed__2_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*2 + 0, .m_other = 2, .m_tag = 5}, .m_objs = {((lean_object*)(((size_t)(0) << 1) | 1)),((lean_object*)&lp_padctl_instReprRemapResult_repr___redArg___closed__1_value)}};
static const lean_object* lp_padctl_instReprRemapResult_repr___redArg___closed__2 = (const lean_object*)&lp_padctl_instReprRemapResult_repr___redArg___closed__2_value;
static const lean_ctor_object lp_padctl_instReprRemapResult_repr___redArg___closed__3_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*2 + 0, .m_other = 2, .m_tag = 5}, .m_objs = {((lean_object*)&lp_padctl_instReprRemapResult_repr___redArg___closed__2_value),((lean_object*)&lp_padctl_instReprLayerConfig_repr___redArg___closed__5_value)}};
static const lean_object* lp_padctl_instReprRemapResult_repr___redArg___closed__3 = (const lean_object*)&lp_padctl_instReprRemapResult_repr___redArg___closed__3_value;
static lean_once_cell_t lp_padctl_instReprRemapResult_repr___redArg___closed__4_once = LEAN_ONCE_CELL_INITIALIZER;
static lean_object* lp_padctl_instReprRemapResult_repr___redArg___closed__4;
static const lean_string_object lp_padctl_instReprRemapResult_repr___redArg___closed__5_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 11, .m_capacity = 11, .m_length = 10, .m_data = "injectMask"};
static const lean_object* lp_padctl_instReprRemapResult_repr___redArg___closed__5 = (const lean_object*)&lp_padctl_instReprRemapResult_repr___redArg___closed__5_value;
static const lean_ctor_object lp_padctl_instReprRemapResult_repr___redArg___closed__6_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*1 + 0, .m_other = 1, .m_tag = 3}, .m_objs = {((lean_object*)&lp_padctl_instReprRemapResult_repr___redArg___closed__5_value)}};
static const lean_object* lp_padctl_instReprRemapResult_repr___redArg___closed__6 = (const lean_object*)&lp_padctl_instReprRemapResult_repr___redArg___closed__6_value;
static const lean_string_object lp_padctl_instReprRemapResult_repr___redArg___closed__7_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 10, .m_capacity = 10, .m_length = 9, .m_data = "auxEvents"};
static const lean_object* lp_padctl_instReprRemapResult_repr___redArg___closed__7 = (const lean_object*)&lp_padctl_instReprRemapResult_repr___redArg___closed__7_value;
static const lean_ctor_object lp_padctl_instReprRemapResult_repr___redArg___closed__8_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*1 + 0, .m_other = 1, .m_tag = 3}, .m_objs = {((lean_object*)&lp_padctl_instReprRemapResult_repr___redArg___closed__7_value)}};
static const lean_object* lp_padctl_instReprRemapResult_repr___redArg___closed__8 = (const lean_object*)&lp_padctl_instReprRemapResult_repr___redArg___closed__8_value;
LEAN_EXPORT lean_object* lp_padctl_instReprRemapResult_repr___redArg(lean_object*);
LEAN_EXPORT lean_object* lp_padctl_instReprRemapResult_repr(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_instReprRemapResult_repr___boxed(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_List_repr___at___00instReprRemapResult_repr_spec__0(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_List_repr___at___00instReprRemapResult_repr_spec__0___boxed(lean_object*, lean_object*);
static const lean_closure_object lp_padctl_instReprRemapResult___closed__0_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_closure_object) + sizeof(void*)*0, .m_other = 0, .m_tag = 245}, .m_fun = (void*)lp_padctl_instReprRemapResult_repr___boxed, .m_arity = 2, .m_num_fixed = 0, .m_objs = {} };
static const lean_object* lp_padctl_instReprRemapResult___closed__0 = (const lean_object*)&lp_padctl_instReprRemapResult___closed__0_value;
LEAN_EXPORT const lean_object* lp_padctl_instReprRemapResult = (const lean_object*)&lp_padctl_instReprRemapResult___closed__0_value;
static const lean_ctor_object lp_padctl_RemapResult_empty___closed__0_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*3 + 0, .m_other = 3, .m_tag = 0}, .m_objs = {((lean_object*)(((size_t)(0) << 1) | 1)),((lean_object*)(((size_t)(0) << 1) | 1)),((lean_object*)(((size_t)(0) << 1) | 1))}};
static const lean_object* lp_padctl_RemapResult_empty___closed__0 = (const lean_object*)&lp_padctl_RemapResult_empty___closed__0_value;
LEAN_EXPORT const lean_object* lp_padctl_RemapResult_empty = (const lean_object*)&lp_padctl_RemapResult_empty___closed__0_value;
LEAN_EXPORT lean_object* lp_padctl_List_foldl___at___00applyRemaps_spec__0(lean_object*, lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_List_foldl___at___00applyRemaps_spec__0___boxed(lean_object*, lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_applyRemaps(lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_applyRemaps___boxed(lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_DpadMode_ctorIdx(uint8_t);
LEAN_EXPORT lean_object* lp_padctl_DpadMode_ctorIdx___boxed(lean_object*);
LEAN_EXPORT lean_object* lp_padctl_DpadMode_toCtorIdx(uint8_t);
LEAN_EXPORT lean_object* lp_padctl_DpadMode_toCtorIdx___boxed(lean_object*);
LEAN_EXPORT lean_object* lp_padctl_DpadMode_ctorElim___redArg(lean_object*);
LEAN_EXPORT lean_object* lp_padctl_DpadMode_ctorElim___redArg___boxed(lean_object*);
LEAN_EXPORT lean_object* lp_padctl_DpadMode_ctorElim(lean_object*, lean_object*, uint8_t, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_DpadMode_ctorElim___boxed(lean_object*, lean_object*, lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_DpadMode_gamepad_elim___redArg(lean_object*);
LEAN_EXPORT lean_object* lp_padctl_DpadMode_gamepad_elim___redArg___boxed(lean_object*);
LEAN_EXPORT lean_object* lp_padctl_DpadMode_gamepad_elim(lean_object*, uint8_t, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_DpadMode_gamepad_elim___boxed(lean_object*, lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_DpadMode_arrows_elim___redArg(lean_object*);
LEAN_EXPORT lean_object* lp_padctl_DpadMode_arrows_elim___redArg___boxed(lean_object*);
LEAN_EXPORT lean_object* lp_padctl_DpadMode_arrows_elim(lean_object*, uint8_t, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_DpadMode_arrows_elim___boxed(lean_object*, lean_object*, lean_object*, lean_object*);
LEAN_EXPORT uint8_t lp_padctl_DpadMode_ofNat(lean_object*);
LEAN_EXPORT lean_object* lp_padctl_DpadMode_ofNat___boxed(lean_object*);
LEAN_EXPORT uint8_t lp_padctl_instDecidableEqDpadMode(uint8_t, uint8_t);
LEAN_EXPORT lean_object* lp_padctl_instDecidableEqDpadMode___boxed(lean_object*, lean_object*);
static const lean_string_object lp_padctl_instReprDpadMode_repr___closed__0_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 17, .m_capacity = 17, .m_length = 16, .m_data = "DpadMode.gamepad"};
static const lean_object* lp_padctl_instReprDpadMode_repr___closed__0 = (const lean_object*)&lp_padctl_instReprDpadMode_repr___closed__0_value;
static const lean_ctor_object lp_padctl_instReprDpadMode_repr___closed__1_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*1 + 0, .m_other = 1, .m_tag = 3}, .m_objs = {((lean_object*)&lp_padctl_instReprDpadMode_repr___closed__0_value)}};
static const lean_object* lp_padctl_instReprDpadMode_repr___closed__1 = (const lean_object*)&lp_padctl_instReprDpadMode_repr___closed__1_value;
static const lean_string_object lp_padctl_instReprDpadMode_repr___closed__2_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 16, .m_capacity = 16, .m_length = 15, .m_data = "DpadMode.arrows"};
static const lean_object* lp_padctl_instReprDpadMode_repr___closed__2 = (const lean_object*)&lp_padctl_instReprDpadMode_repr___closed__2_value;
static const lean_ctor_object lp_padctl_instReprDpadMode_repr___closed__3_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*1 + 0, .m_other = 1, .m_tag = 3}, .m_objs = {((lean_object*)&lp_padctl_instReprDpadMode_repr___closed__2_value)}};
static const lean_object* lp_padctl_instReprDpadMode_repr___closed__3 = (const lean_object*)&lp_padctl_instReprDpadMode_repr___closed__3_value;
LEAN_EXPORT lean_object* lp_padctl_instReprDpadMode_repr(uint8_t, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_instReprDpadMode_repr___boxed(lean_object*, lean_object*);
static const lean_closure_object lp_padctl_instReprDpadMode___closed__0_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_closure_object) + sizeof(void*)*0, .m_other = 0, .m_tag = 245}, .m_fun = (void*)lp_padctl_instReprDpadMode_repr___boxed, .m_arity = 2, .m_num_fixed = 0, .m_objs = {} };
static const lean_object* lp_padctl_instReprDpadMode___closed__0 = (const lean_object*)&lp_padctl_instReprDpadMode___closed__0_value;
LEAN_EXPORT const lean_object* lp_padctl_instReprDpadMode = (const lean_object*)&lp_padctl_instReprDpadMode___closed__0_value;
LEAN_EXPORT lean_object* lp_padctl_KEY__UP;
LEAN_EXPORT lean_object* lp_padctl_KEY__DOWN;
LEAN_EXPORT lean_object* lp_padctl_KEY__LEFT;
LEAN_EXPORT lean_object* lp_padctl_KEY__RIGHT;
static const lean_string_object lp_padctl_instReprDpadResult_repr___redArg___closed__0_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 6, .m_capacity = 6, .m_length = 5, .m_data = "dpadX"};
static const lean_object* lp_padctl_instReprDpadResult_repr___redArg___closed__0 = (const lean_object*)&lp_padctl_instReprDpadResult_repr___redArg___closed__0_value;
static const lean_ctor_object lp_padctl_instReprDpadResult_repr___redArg___closed__1_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*1 + 0, .m_other = 1, .m_tag = 3}, .m_objs = {((lean_object*)&lp_padctl_instReprDpadResult_repr___redArg___closed__0_value)}};
static const lean_object* lp_padctl_instReprDpadResult_repr___redArg___closed__1 = (const lean_object*)&lp_padctl_instReprDpadResult_repr___redArg___closed__1_value;
static const lean_ctor_object lp_padctl_instReprDpadResult_repr___redArg___closed__2_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*2 + 0, .m_other = 2, .m_tag = 5}, .m_objs = {((lean_object*)(((size_t)(0) << 1) | 1)),((lean_object*)&lp_padctl_instReprDpadResult_repr___redArg___closed__1_value)}};
static const lean_object* lp_padctl_instReprDpadResult_repr___redArg___closed__2 = (const lean_object*)&lp_padctl_instReprDpadResult_repr___redArg___closed__2_value;
static const lean_ctor_object lp_padctl_instReprDpadResult_repr___redArg___closed__3_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*2 + 0, .m_other = 2, .m_tag = 5}, .m_objs = {((lean_object*)&lp_padctl_instReprDpadResult_repr___redArg___closed__2_value),((lean_object*)&lp_padctl_instReprLayerConfig_repr___redArg___closed__5_value)}};
static const lean_object* lp_padctl_instReprDpadResult_repr___redArg___closed__3 = (const lean_object*)&lp_padctl_instReprDpadResult_repr___redArg___closed__3_value;
static const lean_string_object lp_padctl_instReprDpadResult_repr___redArg___closed__4_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 16, .m_capacity = 16, .m_length = 15, .m_data = "suppressDpadHat"};
static const lean_object* lp_padctl_instReprDpadResult_repr___redArg___closed__4 = (const lean_object*)&lp_padctl_instReprDpadResult_repr___redArg___closed__4_value;
static const lean_ctor_object lp_padctl_instReprDpadResult_repr___redArg___closed__5_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*1 + 0, .m_other = 1, .m_tag = 3}, .m_objs = {((lean_object*)&lp_padctl_instReprDpadResult_repr___redArg___closed__4_value)}};
static const lean_object* lp_padctl_instReprDpadResult_repr___redArg___closed__5 = (const lean_object*)&lp_padctl_instReprDpadResult_repr___redArg___closed__5_value;
static const lean_string_object lp_padctl_instReprDpadResult_repr___redArg___closed__6_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 16, .m_capacity = 16, .m_length = 15, .m_data = "suppressButtons"};
static const lean_object* lp_padctl_instReprDpadResult_repr___redArg___closed__6 = (const lean_object*)&lp_padctl_instReprDpadResult_repr___redArg___closed__6_value;
static const lean_ctor_object lp_padctl_instReprDpadResult_repr___redArg___closed__7_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*1 + 0, .m_other = 1, .m_tag = 3}, .m_objs = {((lean_object*)&lp_padctl_instReprDpadResult_repr___redArg___closed__6_value)}};
static const lean_object* lp_padctl_instReprDpadResult_repr___redArg___closed__7 = (const lean_object*)&lp_padctl_instReprDpadResult_repr___redArg___closed__7_value;
static const lean_string_object lp_padctl_instReprDpadResult_repr___redArg___closed__8_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 6, .m_capacity = 6, .m_length = 5, .m_data = "dpadY"};
static const lean_object* lp_padctl_instReprDpadResult_repr___redArg___closed__8 = (const lean_object*)&lp_padctl_instReprDpadResult_repr___redArg___closed__8_value;
static const lean_ctor_object lp_padctl_instReprDpadResult_repr___redArg___closed__9_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*1 + 0, .m_other = 1, .m_tag = 3}, .m_objs = {((lean_object*)&lp_padctl_instReprDpadResult_repr___redArg___closed__8_value)}};
static const lean_object* lp_padctl_instReprDpadResult_repr___redArg___closed__9 = (const lean_object*)&lp_padctl_instReprDpadResult_repr___redArg___closed__9_value;
LEAN_EXPORT lean_object* lp_padctl_instReprDpadResult_repr___redArg(lean_object*);
LEAN_EXPORT lean_object* lp_padctl_instReprDpadResult_repr(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_instReprDpadResult_repr___boxed(lean_object*, lean_object*);
static const lean_closure_object lp_padctl_instReprDpadResult___closed__0_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_closure_object) + sizeof(void*)*0, .m_other = 0, .m_tag = 245}, .m_fun = (void*)lp_padctl_instReprDpadResult_repr___boxed, .m_arity = 2, .m_num_fixed = 0, .m_objs = {} };
static const lean_object* lp_padctl_instReprDpadResult___closed__0 = (const lean_object*)&lp_padctl_instReprDpadResult___closed__0_value;
LEAN_EXPORT const lean_object* lp_padctl_instReprDpadResult = (const lean_object*)&lp_padctl_instReprDpadResult___closed__0_value;
extern lean_object* lp_padctl_dpadUpBit;
static lean_once_cell_t lp_padctl___private_Padctl_Mapper_0__dpadButtonMask___closed__0_once = LEAN_ONCE_CELL_INITIALIZER;
static lean_object* lp_padctl___private_Padctl_Mapper_0__dpadButtonMask___closed__0;
extern lean_object* lp_padctl_dpadDownBit;
static lean_once_cell_t lp_padctl___private_Padctl_Mapper_0__dpadButtonMask___closed__1_once = LEAN_ONCE_CELL_INITIALIZER;
static lean_object* lp_padctl___private_Padctl_Mapper_0__dpadButtonMask___closed__1;
static lean_once_cell_t lp_padctl___private_Padctl_Mapper_0__dpadButtonMask___closed__2_once = LEAN_ONCE_CELL_INITIALIZER;
static lean_object* lp_padctl___private_Padctl_Mapper_0__dpadButtonMask___closed__2;
extern lean_object* lp_padctl_dpadLeftBit;
static lean_once_cell_t lp_padctl___private_Padctl_Mapper_0__dpadButtonMask___closed__3_once = LEAN_ONCE_CELL_INITIALIZER;
static lean_object* lp_padctl___private_Padctl_Mapper_0__dpadButtonMask___closed__3;
static lean_once_cell_t lp_padctl___private_Padctl_Mapper_0__dpadButtonMask___closed__4_once = LEAN_ONCE_CELL_INITIALIZER;
static lean_object* lp_padctl___private_Padctl_Mapper_0__dpadButtonMask___closed__4;
extern lean_object* lp_padctl_dpadRightBit;
static lean_once_cell_t lp_padctl___private_Padctl_Mapper_0__dpadButtonMask___closed__5_once = LEAN_ONCE_CELL_INITIALIZER;
static lean_object* lp_padctl___private_Padctl_Mapper_0__dpadButtonMask___closed__5;
static lean_once_cell_t lp_padctl___private_Padctl_Mapper_0__dpadButtonMask___closed__6_once = LEAN_ONCE_CELL_INITIALIZER;
static lean_object* lp_padctl___private_Padctl_Mapper_0__dpadButtonMask___closed__6;
LEAN_EXPORT lean_object* lp_padctl___private_Padctl_Mapper_0__dpadButtonMask;
LEAN_EXPORT lean_object* lp_padctl_processDpad(lean_object*, lean_object*, lean_object*, lean_object*, uint8_t, uint8_t);
LEAN_EXPORT lean_object* lp_padctl_processDpad___boxed(lean_object*, lean_object*, lean_object*, lean_object*, lean_object*, lean_object*);
LEAN_EXPORT uint8_t lp_padctl_Nat_andNot___lam__0(uint8_t, uint8_t);
LEAN_EXPORT lean_object* lp_padctl_Nat_andNot___lam__0___boxed(lean_object*, lean_object*);
static const lean_closure_object lp_padctl_Nat_andNot___closed__0_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_closure_object) + sizeof(void*)*0, .m_other = 0, .m_tag = 245}, .m_fun = (void*)lp_padctl_Nat_andNot___lam__0___boxed, .m_arity = 2, .m_num_fixed = 0, .m_objs = {} };
static const lean_object* lp_padctl_Nat_andNot___closed__0 = (const lean_object*)&lp_padctl_Nat_andNot___closed__0_value;
lean_object* l_Nat_bitwise(lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_Nat_andNot(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_Nat_andNot___boxed(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_assembleButtons(lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_assembleButtons___boxed(lean_object*, lean_object*, lean_object*);
LEAN_EXPORT uint8_t lp_padctl_instDecidableEqLayerOverrides_decEq___lam__0(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_instDecidableEqLayerOverrides_decEq___lam__0___boxed(lean_object*, lean_object*);
static const lean_closure_object lp_padctl_instDecidableEqLayerOverrides_decEq___closed__0_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_closure_object) + sizeof(void*)*0, .m_other = 0, .m_tag = 245}, .m_fun = (void*)lp_padctl_instDecidableEqLayerOverrides_decEq___lam__0___boxed, .m_arity = 2, .m_num_fixed = 0, .m_objs = {} };
static const lean_object* lp_padctl_instDecidableEqLayerOverrides_decEq___closed__0 = (const lean_object*)&lp_padctl_instDecidableEqLayerOverrides_decEq___closed__0_value;
LEAN_EXPORT uint8_t lp_padctl_instDecidableEqLayerOverrides_decEq(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_instDecidableEqLayerOverrides_decEq___boxed(lean_object*, lean_object*);
LEAN_EXPORT uint8_t lp_padctl_instDecidableEqLayerOverrides(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_instDecidableEqLayerOverrides___boxed(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_Option_repr___at___00instReprLayerOverrides_repr_spec__0(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_Option_repr___at___00instReprLayerOverrides_repr_spec__0___boxed(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_Option_repr___at___00instReprLayerOverrides_repr_spec__1(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_Option_repr___at___00instReprLayerOverrides_repr_spec__1___boxed(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_Option_repr___at___00instReprLayerOverrides_repr_spec__3(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_Option_repr___at___00instReprLayerOverrides_repr_spec__3___boxed(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_Option_repr___at___00instReprLayerOverrides_repr_spec__2(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_Option_repr___at___00instReprLayerOverrides_repr_spec__2___boxed(lean_object*, lean_object*);
static const lean_string_object lp_padctl_instReprLayerOverrides_repr___redArg___closed__0_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 9, .m_capacity = 9, .m_length = 8, .m_data = "dpadMode"};
static const lean_object* lp_padctl_instReprLayerOverrides_repr___redArg___closed__0 = (const lean_object*)&lp_padctl_instReprLayerOverrides_repr___redArg___closed__0_value;
static const lean_ctor_object lp_padctl_instReprLayerOverrides_repr___redArg___closed__1_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*1 + 0, .m_other = 1, .m_tag = 3}, .m_objs = {((lean_object*)&lp_padctl_instReprLayerOverrides_repr___redArg___closed__0_value)}};
static const lean_object* lp_padctl_instReprLayerOverrides_repr___redArg___closed__1 = (const lean_object*)&lp_padctl_instReprLayerOverrides_repr___redArg___closed__1_value;
static const lean_ctor_object lp_padctl_instReprLayerOverrides_repr___redArg___closed__2_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*2 + 0, .m_other = 2, .m_tag = 5}, .m_objs = {((lean_object*)(((size_t)(0) << 1) | 1)),((lean_object*)&lp_padctl_instReprLayerOverrides_repr___redArg___closed__1_value)}};
static const lean_object* lp_padctl_instReprLayerOverrides_repr___redArg___closed__2 = (const lean_object*)&lp_padctl_instReprLayerOverrides_repr___redArg___closed__2_value;
static const lean_ctor_object lp_padctl_instReprLayerOverrides_repr___redArg___closed__3_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*2 + 0, .m_other = 2, .m_tag = 5}, .m_objs = {((lean_object*)&lp_padctl_instReprLayerOverrides_repr___redArg___closed__2_value),((lean_object*)&lp_padctl_instReprLayerConfig_repr___redArg___closed__5_value)}};
static const lean_object* lp_padctl_instReprLayerOverrides_repr___redArg___closed__3 = (const lean_object*)&lp_padctl_instReprLayerOverrides_repr___redArg___closed__3_value;
static const lean_string_object lp_padctl_instReprLayerOverrides_repr___redArg___closed__4_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 14, .m_capacity = 14, .m_length = 13, .m_data = "leftStickMode"};
static const lean_object* lp_padctl_instReprLayerOverrides_repr___redArg___closed__4 = (const lean_object*)&lp_padctl_instReprLayerOverrides_repr___redArg___closed__4_value;
static const lean_ctor_object lp_padctl_instReprLayerOverrides_repr___redArg___closed__5_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*1 + 0, .m_other = 1, .m_tag = 3}, .m_objs = {((lean_object*)&lp_padctl_instReprLayerOverrides_repr___redArg___closed__4_value)}};
static const lean_object* lp_padctl_instReprLayerOverrides_repr___redArg___closed__5 = (const lean_object*)&lp_padctl_instReprLayerOverrides_repr___redArg___closed__5_value;
static lean_once_cell_t lp_padctl_instReprLayerOverrides_repr___redArg___closed__6_once = LEAN_ONCE_CELL_INITIALIZER;
static lean_object* lp_padctl_instReprLayerOverrides_repr___redArg___closed__6;
static const lean_string_object lp_padctl_instReprLayerOverrides_repr___redArg___closed__7_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 15, .m_capacity = 15, .m_length = 14, .m_data = "rightStickMode"};
static const lean_object* lp_padctl_instReprLayerOverrides_repr___redArg___closed__7 = (const lean_object*)&lp_padctl_instReprLayerOverrides_repr___redArg___closed__7_value;
static const lean_ctor_object lp_padctl_instReprLayerOverrides_repr___redArg___closed__8_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*1 + 0, .m_other = 1, .m_tag = 3}, .m_objs = {((lean_object*)&lp_padctl_instReprLayerOverrides_repr___redArg___closed__7_value)}};
static const lean_object* lp_padctl_instReprLayerOverrides_repr___redArg___closed__8 = (const lean_object*)&lp_padctl_instReprLayerOverrides_repr___redArg___closed__8_value;
static const lean_string_object lp_padctl_instReprLayerOverrides_repr___redArg___closed__9_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 21, .m_capacity = 21, .m_length = 20, .m_data = "gyroActivationButton"};
static const lean_object* lp_padctl_instReprLayerOverrides_repr___redArg___closed__9 = (const lean_object*)&lp_padctl_instReprLayerOverrides_repr___redArg___closed__9_value;
static const lean_ctor_object lp_padctl_instReprLayerOverrides_repr___redArg___closed__10_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*1 + 0, .m_other = 1, .m_tag = 3}, .m_objs = {((lean_object*)&lp_padctl_instReprLayerOverrides_repr___redArg___closed__9_value)}};
static const lean_object* lp_padctl_instReprLayerOverrides_repr___redArg___closed__10 = (const lean_object*)&lp_padctl_instReprLayerOverrides_repr___redArg___closed__10_value;
static lean_once_cell_t lp_padctl_instReprLayerOverrides_repr___redArg___closed__11_once = LEAN_ONCE_CELL_INITIALIZER;
static lean_object* lp_padctl_instReprLayerOverrides_repr___redArg___closed__11;
static const lean_string_object lp_padctl_instReprLayerOverrides_repr___redArg___closed__12_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 9, .m_capacity = 9, .m_length = 8, .m_data = "gyroMode"};
static const lean_object* lp_padctl_instReprLayerOverrides_repr___redArg___closed__12 = (const lean_object*)&lp_padctl_instReprLayerOverrides_repr___redArg___closed__12_value;
static const lean_ctor_object lp_padctl_instReprLayerOverrides_repr___redArg___closed__13_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*1 + 0, .m_other = 1, .m_tag = 3}, .m_objs = {((lean_object*)&lp_padctl_instReprLayerOverrides_repr___redArg___closed__12_value)}};
static const lean_object* lp_padctl_instReprLayerOverrides_repr___redArg___closed__13 = (const lean_object*)&lp_padctl_instReprLayerOverrides_repr___redArg___closed__13_value;
LEAN_EXPORT lean_object* lp_padctl_instReprLayerOverrides_repr___redArg(lean_object*);
LEAN_EXPORT lean_object* lp_padctl_instReprLayerOverrides_repr(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_instReprLayerOverrides_repr___boxed(lean_object*, lean_object*);
static const lean_closure_object lp_padctl_instReprLayerOverrides___closed__0_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_closure_object) + sizeof(void*)*0, .m_other = 0, .m_tag = 245}, .m_fun = (void*)lp_padctl_instReprLayerOverrides_repr___boxed, .m_arity = 2, .m_num_fixed = 0, .m_objs = {} };
static const lean_object* lp_padctl_instReprLayerOverrides___closed__0 = (const lean_object*)&lp_padctl_instReprLayerOverrides___closed__0_value;
LEAN_EXPORT const lean_object* lp_padctl_instReprLayerOverrides = (const lean_object*)&lp_padctl_instReprLayerOverrides___closed__0_value;
LEAN_EXPORT lean_object* lp_padctl_List_foldl___at___00List_foldl___at___00Std_Format_joinSep___at___00List_repr___at___00instReprMapperConfig_repr_spec__1_spec__2_spec__4_spec__8(lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_List_foldl___at___00Std_Format_joinSep___at___00List_repr___at___00instReprMapperConfig_repr_spec__1_spec__2_spec__4(lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_Std_Format_joinSep___at___00List_repr___at___00instReprMapperConfig_repr_spec__1_spec__2(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_List_repr___at___00instReprMapperConfig_repr_spec__1___redArg(lean_object*);
LEAN_EXPORT lean_object* lp_padctl_List_foldl___at___00List_foldl___at___00Std_Format_joinSep___at___00List_repr___at___00instReprMapperConfig_repr_spec__3_spec__6_spec__10_spec__14(lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_List_foldl___at___00Std_Format_joinSep___at___00List_repr___at___00instReprMapperConfig_repr_spec__3_spec__6_spec__10(lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_Std_Format_joinSep___at___00List_repr___at___00instReprMapperConfig_repr_spec__3_spec__6(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_List_repr___at___00instReprMapperConfig_repr_spec__3___redArg(lean_object*);
LEAN_EXPORT lean_object* lp_padctl_List_foldl___at___00List_foldl___at___00Std_Format_joinSep___at___00List_repr___at___00instReprMapperConfig_repr_spec__0_spec__0_spec__1_spec__5(lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_List_foldl___at___00Std_Format_joinSep___at___00List_repr___at___00instReprMapperConfig_repr_spec__0_spec__0_spec__1(lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_Std_Format_joinSep___at___00List_repr___at___00instReprMapperConfig_repr_spec__0_spec__0(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_List_repr___at___00instReprMapperConfig_repr_spec__0___redArg(lean_object*);
LEAN_EXPORT lean_object* lp_padctl_List_foldl___at___00List_foldl___at___00Std_Format_joinSep___at___00List_repr___at___00instReprMapperConfig_repr_spec__2_spec__4_spec__7_spec__11(lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_List_foldl___at___00Std_Format_joinSep___at___00List_repr___at___00instReprMapperConfig_repr_spec__2_spec__4_spec__7(lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_Std_Format_joinSep___at___00List_repr___at___00instReprMapperConfig_repr_spec__2_spec__4(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_List_repr___at___00instReprMapperConfig_repr_spec__2___redArg(lean_object*);
static const lean_string_object lp_padctl_instReprMapperConfig_repr___redArg___closed__0_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 7, .m_capacity = 7, .m_length = 6, .m_data = "layers"};
static const lean_object* lp_padctl_instReprMapperConfig_repr___redArg___closed__0 = (const lean_object*)&lp_padctl_instReprMapperConfig_repr___redArg___closed__0_value;
static const lean_ctor_object lp_padctl_instReprMapperConfig_repr___redArg___closed__1_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*1 + 0, .m_other = 1, .m_tag = 3}, .m_objs = {((lean_object*)&lp_padctl_instReprMapperConfig_repr___redArg___closed__0_value)}};
static const lean_object* lp_padctl_instReprMapperConfig_repr___redArg___closed__1 = (const lean_object*)&lp_padctl_instReprMapperConfig_repr___redArg___closed__1_value;
static const lean_ctor_object lp_padctl_instReprMapperConfig_repr___redArg___closed__2_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*2 + 0, .m_other = 2, .m_tag = 5}, .m_objs = {((lean_object*)(((size_t)(0) << 1) | 1)),((lean_object*)&lp_padctl_instReprMapperConfig_repr___redArg___closed__1_value)}};
static const lean_object* lp_padctl_instReprMapperConfig_repr___redArg___closed__2 = (const lean_object*)&lp_padctl_instReprMapperConfig_repr___redArg___closed__2_value;
static const lean_ctor_object lp_padctl_instReprMapperConfig_repr___redArg___closed__3_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*2 + 0, .m_other = 2, .m_tag = 5}, .m_objs = {((lean_object*)&lp_padctl_instReprMapperConfig_repr___redArg___closed__2_value),((lean_object*)&lp_padctl_instReprLayerConfig_repr___redArg___closed__5_value)}};
static const lean_object* lp_padctl_instReprMapperConfig_repr___redArg___closed__3 = (const lean_object*)&lp_padctl_instReprMapperConfig_repr___redArg___closed__3_value;
static const lean_string_object lp_padctl_instReprMapperConfig_repr___redArg___closed__4_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 11, .m_capacity = 11, .m_length = 10, .m_data = "baseRemaps"};
static const lean_object* lp_padctl_instReprMapperConfig_repr___redArg___closed__4 = (const lean_object*)&lp_padctl_instReprMapperConfig_repr___redArg___closed__4_value;
static const lean_ctor_object lp_padctl_instReprMapperConfig_repr___redArg___closed__5_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*1 + 0, .m_other = 1, .m_tag = 3}, .m_objs = {((lean_object*)&lp_padctl_instReprMapperConfig_repr___redArg___closed__4_value)}};
static const lean_object* lp_padctl_instReprMapperConfig_repr___redArg___closed__5 = (const lean_object*)&lp_padctl_instReprMapperConfig_repr___redArg___closed__5_value;
static const lean_string_object lp_padctl_instReprMapperConfig_repr___redArg___closed__6_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 12, .m_capacity = 12, .m_length = 11, .m_data = "layerRemaps"};
static const lean_object* lp_padctl_instReprMapperConfig_repr___redArg___closed__6 = (const lean_object*)&lp_padctl_instReprMapperConfig_repr___redArg___closed__6_value;
static const lean_ctor_object lp_padctl_instReprMapperConfig_repr___redArg___closed__7_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*1 + 0, .m_other = 1, .m_tag = 3}, .m_objs = {((lean_object*)&lp_padctl_instReprMapperConfig_repr___redArg___closed__6_value)}};
static const lean_object* lp_padctl_instReprMapperConfig_repr___redArg___closed__7 = (const lean_object*)&lp_padctl_instReprMapperConfig_repr___redArg___closed__7_value;
static const lean_string_object lp_padctl_instReprMapperConfig_repr___redArg___closed__8_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 20, .m_capacity = 20, .m_length = 19, .m_data = "dpadSuppressGamepad"};
static const lean_object* lp_padctl_instReprMapperConfig_repr___redArg___closed__8 = (const lean_object*)&lp_padctl_instReprMapperConfig_repr___redArg___closed__8_value;
static const lean_ctor_object lp_padctl_instReprMapperConfig_repr___redArg___closed__9_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*1 + 0, .m_other = 1, .m_tag = 3}, .m_objs = {((lean_object*)&lp_padctl_instReprMapperConfig_repr___redArg___closed__8_value)}};
static const lean_object* lp_padctl_instReprMapperConfig_repr___redArg___closed__9 = (const lean_object*)&lp_padctl_instReprMapperConfig_repr___redArg___closed__9_value;
static lean_once_cell_t lp_padctl_instReprMapperConfig_repr___redArg___closed__10_once = LEAN_ONCE_CELL_INITIALIZER;
static lean_object* lp_padctl_instReprMapperConfig_repr___redArg___closed__10;
static const lean_string_object lp_padctl_instReprMapperConfig_repr___redArg___closed__11_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 15, .m_capacity = 15, .m_length = 14, .m_data = "layerOverrides"};
static const lean_object* lp_padctl_instReprMapperConfig_repr___redArg___closed__11 = (const lean_object*)&lp_padctl_instReprMapperConfig_repr___redArg___closed__11_value;
static const lean_ctor_object lp_padctl_instReprMapperConfig_repr___redArg___closed__12_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*1 + 0, .m_other = 1, .m_tag = 3}, .m_objs = {((lean_object*)&lp_padctl_instReprMapperConfig_repr___redArg___closed__11_value)}};
static const lean_object* lp_padctl_instReprMapperConfig_repr___redArg___closed__12 = (const lean_object*)&lp_padctl_instReprMapperConfig_repr___redArg___closed__12_value;
LEAN_EXPORT lean_object* lp_padctl_instReprMapperConfig_repr___redArg(lean_object*);
LEAN_EXPORT lean_object* lp_padctl_instReprMapperConfig_repr(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_instReprMapperConfig_repr___boxed(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_List_repr___at___00instReprMapperConfig_repr_spec__0(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_List_repr___at___00instReprMapperConfig_repr_spec__0___boxed(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_List_repr___at___00instReprMapperConfig_repr_spec__1(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_List_repr___at___00instReprMapperConfig_repr_spec__1___boxed(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_List_repr___at___00instReprMapperConfig_repr_spec__2(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_List_repr___at___00instReprMapperConfig_repr_spec__2___boxed(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_List_repr___at___00instReprMapperConfig_repr_spec__3(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_List_repr___at___00instReprMapperConfig_repr_spec__3___boxed(lean_object*, lean_object*);
static const lean_closure_object lp_padctl_instReprMapperConfig___closed__0_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_closure_object) + sizeof(void*)*0, .m_other = 0, .m_tag = 245}, .m_fun = (void*)lp_padctl_instReprMapperConfig_repr___boxed, .m_arity = 2, .m_num_fixed = 0, .m_objs = {} };
static const lean_object* lp_padctl_instReprMapperConfig___closed__0 = (const lean_object*)&lp_padctl_instReprMapperConfig___closed__0_value;
LEAN_EXPORT const lean_object* lp_padctl_instReprMapperConfig = (const lean_object*)&lp_padctl_instReprMapperConfig___closed__0_value;
lean_object* l_List_reverse___redArg(lean_object*);
uint8_t l_List_elem___at___00Lean_Meta_Occurrences_contains_spec__0(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_List_filterTR_loop___at___00mergeRemaps_spec__1(lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_List_filterTR_loop___at___00mergeRemaps_spec__1___boxed(lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_List_mapTR_loop___at___00mergeRemaps_spec__0(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_mergeRemaps(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_resolveConfig(lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_resolveConfig___boxed(lean_object*, lean_object*, lean_object*);
static const lean_ctor_object lp_padctl___private_Padctl_Mapper_0__triggerMacrosAux___closed__0_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*4 + 8, .m_other = 4, .m_tag = 0}, .m_objs = {((lean_object*)(((size_t)(0) << 1) | 1)),((lean_object*)(((size_t)(0) << 1) | 1)),((lean_object*)(((size_t)(0) << 1) | 1)),((lean_object*)(((size_t)(0) << 1) | 1)),LEAN_SCALAR_PTR_LITERAL(0, 0, 0, 0, 0, 0, 0, 0)}};
static const lean_object* lp_padctl___private_Padctl_Mapper_0__triggerMacrosAux___closed__0 = (const lean_object*)&lp_padctl___private_Padctl_Mapper_0__triggerMacrosAux___closed__0_value;
LEAN_EXPORT lean_object* lp_padctl___private_Padctl_Mapper_0__triggerMacrosAux(lean_object*, lean_object*, lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl___private_Padctl_Mapper_0__triggerMacrosAux___boxed(lean_object*, lean_object*, lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl___private_Padctl_Mapper_0__triggerMacros(lean_object*, lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl___private_Padctl_Mapper_0__triggerMacros___boxed(lean_object*, lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_List_mapTR_loop___at___00__private_Padctl_Mapper_0__cancelMacros_spec__0(lean_object*, lean_object*);
static const lean_ctor_object lp_padctl_List_foldl___at___00__private_Padctl_Mapper_0__cancelMacros_spec__1___closed__0_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*4 + 8, .m_other = 4, .m_tag = 0}, .m_objs = {((lean_object*)(((size_t)(0) << 1) | 1)),((lean_object*)(((size_t)(0) << 1) | 1)),((lean_object*)(((size_t)(0) << 1) | 1)),((lean_object*)(((size_t)(0) << 1) | 1)),LEAN_SCALAR_PTR_LITERAL(0, 0, 0, 0, 0, 0, 0, 0)}};
static const lean_object* lp_padctl_List_foldl___at___00__private_Padctl_Mapper_0__cancelMacros_spec__1___closed__0 = (const lean_object*)&lp_padctl_List_foldl___at___00__private_Padctl_Mapper_0__cancelMacros_spec__1___closed__0_value;
static const lean_ctor_object lp_padctl_List_foldl___at___00__private_Padctl_Mapper_0__cancelMacros_spec__1___closed__1_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*2 + 0, .m_other = 2, .m_tag = 1}, .m_objs = {((lean_object*)&lp_padctl_List_foldl___at___00__private_Padctl_Mapper_0__cancelMacros_spec__1___closed__0_value),((lean_object*)(((size_t)(0) << 1) | 1))}};
static const lean_object* lp_padctl_List_foldl___at___00__private_Padctl_Mapper_0__cancelMacros_spec__1___closed__1 = (const lean_object*)&lp_padctl_List_foldl___at___00__private_Padctl_Mapper_0__cancelMacros_spec__1___closed__1_value;
LEAN_EXPORT lean_object* lp_padctl_List_foldl___at___00__private_Padctl_Mapper_0__cancelMacros_spec__1(lean_object*, lean_object*);
static const lean_ctor_object lp_padctl___private_Padctl_Mapper_0__cancelMacros___closed__0_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*2 + 0, .m_other = 2, .m_tag = 0}, .m_objs = {((lean_object*)(((size_t)(0) << 1) | 1)),((lean_object*)(((size_t)(0) << 1) | 1))}};
static const lean_object* lp_padctl___private_Padctl_Mapper_0__cancelMacros___closed__0 = (const lean_object*)&lp_padctl___private_Padctl_Mapper_0__cancelMacros___closed__0_value;
LEAN_EXPORT lean_object* lp_padctl___private_Padctl_Mapper_0__cancelMacros(lean_object*);
LEAN_EXPORT uint8_t lp_padctl_instDecidableEqMacroTimerEvent_decEq(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_instDecidableEqMacroTimerEvent_decEq___boxed(lean_object*, lean_object*);
LEAN_EXPORT uint8_t lp_padctl_instDecidableEqMacroTimerEvent(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_instDecidableEqMacroTimerEvent___boxed(lean_object*, lean_object*);
static const lean_string_object lp_padctl_instReprMacroTimerEvent_repr___closed__0_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 25, .m_capacity = 25, .m_length = 24, .m_data = "MacroTimerEvent.armTimer"};
static const lean_object* lp_padctl_instReprMacroTimerEvent_repr___closed__0 = (const lean_object*)&lp_padctl_instReprMacroTimerEvent_repr___closed__0_value;
static const lean_ctor_object lp_padctl_instReprMacroTimerEvent_repr___closed__1_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*1 + 0, .m_other = 1, .m_tag = 3}, .m_objs = {((lean_object*)&lp_padctl_instReprMacroTimerEvent_repr___closed__0_value)}};
static const lean_object* lp_padctl_instReprMacroTimerEvent_repr___closed__1 = (const lean_object*)&lp_padctl_instReprMacroTimerEvent_repr___closed__1_value;
static const lean_ctor_object lp_padctl_instReprMacroTimerEvent_repr___closed__2_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*2 + 0, .m_other = 2, .m_tag = 5}, .m_objs = {((lean_object*)&lp_padctl_instReprMacroTimerEvent_repr___closed__1_value),((lean_object*)(((size_t)(1) << 1) | 1))}};
static const lean_object* lp_padctl_instReprMacroTimerEvent_repr___closed__2 = (const lean_object*)&lp_padctl_instReprMacroTimerEvent_repr___closed__2_value;
LEAN_EXPORT lean_object* lp_padctl_instReprMacroTimerEvent_repr(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_instReprMacroTimerEvent_repr___boxed(lean_object*, lean_object*);
static const lean_closure_object lp_padctl_instReprMacroTimerEvent___closed__0_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_closure_object) + sizeof(void*)*0, .m_other = 0, .m_tag = 245}, .m_fun = (void*)lp_padctl_instReprMacroTimerEvent_repr___boxed, .m_arity = 2, .m_num_fixed = 0, .m_objs = {} };
static const lean_object* lp_padctl_instReprMacroTimerEvent___closed__0 = (const lean_object*)&lp_padctl_instReprMacroTimerEvent___closed__0_value;
LEAN_EXPORT const lean_object* lp_padctl_instReprMacroTimerEvent = (const lean_object*)&lp_padctl_instReprMacroTimerEvent___closed__0_value;
LEAN_EXPORT lean_object* lp_padctl_List_filterTR_loop___at___00__private_Padctl_Mapper_0__stepMacro_spec__0(lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_List_filterTR_loop___at___00__private_Padctl_Mapper_0__stepMacro_spec__0___boxed(lean_object*, lean_object*, lean_object*);
static const lean_ctor_object lp_padctl___private_Padctl_Mapper_0__stepMacro___closed__0_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*2 + 0, .m_other = 2, .m_tag = 0}, .m_objs = {((lean_object*)(((size_t)(0) << 1) | 1)),((lean_object*)(((size_t)(0) << 1) | 1))}};
static const lean_object* lp_padctl___private_Padctl_Mapper_0__stepMacro___closed__0 = (const lean_object*)&lp_padctl___private_Padctl_Mapper_0__stepMacro___closed__0_value;
LEAN_EXPORT lean_object* lp_padctl___private_Padctl_Mapper_0__stepMacro(lean_object*);
LEAN_EXPORT uint8_t lp_padctl_Option_instBEq_beq___at___00onMacroTimerExpired_spec__0(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_Option_instBEq_beq___at___00onMacroTimerExpired_spec__0___boxed(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_List_foldl___at___00onMacroTimerExpired_spec__1(lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_onMacroTimerExpired(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_List_foldl___at___00notifyTriggerReleased_spec__0(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_notifyTriggerReleased(lean_object*);
static const lean_string_object lp_padctl_instReprApplyResult_repr___redArg___closed__0_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 12, .m_capacity = 12, .m_length = 11, .m_data = "mapperState"};
static const lean_object* lp_padctl_instReprApplyResult_repr___redArg___closed__0 = (const lean_object*)&lp_padctl_instReprApplyResult_repr___redArg___closed__0_value;
static const lean_ctor_object lp_padctl_instReprApplyResult_repr___redArg___closed__1_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*1 + 0, .m_other = 1, .m_tag = 3}, .m_objs = {((lean_object*)&lp_padctl_instReprApplyResult_repr___redArg___closed__0_value)}};
static const lean_object* lp_padctl_instReprApplyResult_repr___redArg___closed__1 = (const lean_object*)&lp_padctl_instReprApplyResult_repr___redArg___closed__1_value;
static const lean_ctor_object lp_padctl_instReprApplyResult_repr___redArg___closed__2_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*2 + 0, .m_other = 2, .m_tag = 5}, .m_objs = {((lean_object*)(((size_t)(0) << 1) | 1)),((lean_object*)&lp_padctl_instReprApplyResult_repr___redArg___closed__1_value)}};
static const lean_object* lp_padctl_instReprApplyResult_repr___redArg___closed__2 = (const lean_object*)&lp_padctl_instReprApplyResult_repr___redArg___closed__2_value;
static const lean_ctor_object lp_padctl_instReprApplyResult_repr___redArg___closed__3_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*2 + 0, .m_other = 2, .m_tag = 5}, .m_objs = {((lean_object*)&lp_padctl_instReprApplyResult_repr___redArg___closed__2_value),((lean_object*)&lp_padctl_instReprLayerConfig_repr___redArg___closed__5_value)}};
static const lean_object* lp_padctl_instReprApplyResult_repr___redArg___closed__3 = (const lean_object*)&lp_padctl_instReprApplyResult_repr___redArg___closed__3_value;
static const lean_string_object lp_padctl_instReprApplyResult_repr___redArg___closed__4_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 8, .m_capacity = 8, .m_length = 7, .m_data = "gamepad"};
static const lean_object* lp_padctl_instReprApplyResult_repr___redArg___closed__4 = (const lean_object*)&lp_padctl_instReprApplyResult_repr___redArg___closed__4_value;
static const lean_ctor_object lp_padctl_instReprApplyResult_repr___redArg___closed__5_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*1 + 0, .m_other = 1, .m_tag = 3}, .m_objs = {((lean_object*)&lp_padctl_instReprApplyResult_repr___redArg___closed__4_value)}};
static const lean_object* lp_padctl_instReprApplyResult_repr___redArg___closed__5 = (const lean_object*)&lp_padctl_instReprApplyResult_repr___redArg___closed__5_value;
static const lean_string_object lp_padctl_instReprApplyResult_repr___redArg___closed__6_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 11, .m_capacity = 11, .m_length = 10, .m_data = "maskedPrev"};
static const lean_object* lp_padctl_instReprApplyResult_repr___redArg___closed__6 = (const lean_object*)&lp_padctl_instReprApplyResult_repr___redArg___closed__6_value;
static const lean_ctor_object lp_padctl_instReprApplyResult_repr___redArg___closed__7_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*1 + 0, .m_other = 1, .m_tag = 3}, .m_objs = {((lean_object*)&lp_padctl_instReprApplyResult_repr___redArg___closed__6_value)}};
static const lean_object* lp_padctl_instReprApplyResult_repr___redArg___closed__7 = (const lean_object*)&lp_padctl_instReprApplyResult_repr___redArg___closed__7_value;
static const lean_string_object lp_padctl_instReprApplyResult_repr___redArg___closed__8_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 11, .m_capacity = 11, .m_length = 10, .m_data = "gyroActive"};
static const lean_object* lp_padctl_instReprApplyResult_repr___redArg___closed__8 = (const lean_object*)&lp_padctl_instReprApplyResult_repr___redArg___closed__8_value;
static const lean_ctor_object lp_padctl_instReprApplyResult_repr___redArg___closed__9_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*1 + 0, .m_other = 1, .m_tag = 3}, .m_objs = {((lean_object*)&lp_padctl_instReprApplyResult_repr___redArg___closed__8_value)}};
static const lean_object* lp_padctl_instReprApplyResult_repr___redArg___closed__9 = (const lean_object*)&lp_padctl_instReprApplyResult_repr___redArg___closed__9_value;
static const lean_string_object lp_padctl_instReprApplyResult_repr___redArg___closed__10_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 10, .m_capacity = 10, .m_length = 9, .m_data = "gyroReset"};
static const lean_object* lp_padctl_instReprApplyResult_repr___redArg___closed__10 = (const lean_object*)&lp_padctl_instReprApplyResult_repr___redArg___closed__10_value;
static const lean_ctor_object lp_padctl_instReprApplyResult_repr___redArg___closed__11_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*1 + 0, .m_other = 1, .m_tag = 3}, .m_objs = {((lean_object*)&lp_padctl_instReprApplyResult_repr___redArg___closed__10_value)}};
static const lean_object* lp_padctl_instReprApplyResult_repr___redArg___closed__11 = (const lean_object*)&lp_padctl_instReprApplyResult_repr___redArg___closed__11_value;
static const lean_string_object lp_padctl_instReprApplyResult_repr___redArg___closed__12_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 23, .m_capacity = 23, .m_length = 22, .m_data = "suppressRightStickGyro"};
static const lean_object* lp_padctl_instReprApplyResult_repr___redArg___closed__12 = (const lean_object*)&lp_padctl_instReprApplyResult_repr___redArg___closed__12_value;
static const lean_ctor_object lp_padctl_instReprApplyResult_repr___redArg___closed__13_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*1 + 0, .m_other = 1, .m_tag = 3}, .m_objs = {((lean_object*)&lp_padctl_instReprApplyResult_repr___redArg___closed__12_value)}};
static const lean_object* lp_padctl_instReprApplyResult_repr___redArg___closed__13 = (const lean_object*)&lp_padctl_instReprApplyResult_repr___redArg___closed__13_value;
static lean_once_cell_t lp_padctl_instReprApplyResult_repr___redArg___closed__14_once = LEAN_ONCE_CELL_INITIALIZER;
static lean_object* lp_padctl_instReprApplyResult_repr___redArg___closed__14;
lean_object* lp_padctl_instReprGamepadState_repr___redArg(lean_object*);
LEAN_EXPORT lean_object* lp_padctl_instReprApplyResult_repr___redArg(lean_object*);
LEAN_EXPORT lean_object* lp_padctl_instReprApplyResult_repr(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_instReprApplyResult_repr___boxed(lean_object*, lean_object*);
static const lean_closure_object lp_padctl_instReprApplyResult___closed__0_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_closure_object) + sizeof(void*)*0, .m_other = 0, .m_tag = 245}, .m_fun = (void*)lp_padctl_instReprApplyResult_repr___boxed, .m_arity = 2, .m_num_fixed = 0, .m_objs = {} };
static const lean_object* lp_padctl_instReprApplyResult___closed__0 = (const lean_object*)&lp_padctl_instReprApplyResult___closed__0_value;
LEAN_EXPORT const lean_object* lp_padctl_instReprApplyResult = (const lean_object*)&lp_padctl_instReprApplyResult___closed__0_value;
lean_object* lp_padctl_applyDelta(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_Mapper_apply(lean_object*, lean_object*, lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_Mapper_apply___boxed(lean_object*, lean_object*, lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_setBit(lean_object* x_1, lean_object* x_2) {
_start:
{
lean_object* x_3; lean_object* x_4; lean_object* x_5; 
x_3 = lean_unsigned_to_nat(1u);
x_4 = lean_nat_shiftl(x_3, x_2);
x_5 = lean_nat_lor(x_1, x_4);
lean_dec(x_4);
return x_5;
}
}
LEAN_EXPORT lean_object* lp_padctl_setBit___boxed(lean_object* x_1, lean_object* x_2) {
_start:
{
lean_object* x_3; 
x_3 = lp_padctl_setBit(x_1, x_2);
lean_dec(x_2);
lean_dec(x_1);
return x_3;
}
}
LEAN_EXPORT lean_object* lp_padctl_AuxEvent_ctorIdx(lean_object* x_1) {
_start:
{
switch (lean_obj_tag(x_1)) {
case 0:
{
lean_object* x_2; 
x_2 = lean_unsigned_to_nat(0u);
return x_2;
}
case 1:
{
lean_object* x_3; 
x_3 = lean_unsigned_to_nat(1u);
return x_3;
}
default: 
{
lean_object* x_4; 
x_4 = lean_unsigned_to_nat(2u);
return x_4;
}
}
}
}
LEAN_EXPORT lean_object* lp_padctl_AuxEvent_ctorIdx___boxed(lean_object* x_1) {
_start:
{
lean_object* x_2; 
x_2 = lp_padctl_AuxEvent_ctorIdx(x_1);
lean_dec_ref(x_1);
return x_2;
}
}
LEAN_EXPORT lean_object* lp_padctl_AuxEvent_ctorElim___redArg(lean_object* x_1, lean_object* x_2) {
_start:
{
if (lean_obj_tag(x_1) == 2)
{
lean_object* x_3; lean_object* x_4; lean_object* x_5; 
x_3 = lean_ctor_get(x_1, 0);
lean_inc(x_3);
x_4 = lean_ctor_get(x_1, 1);
lean_inc(x_4);
lean_dec_ref(x_1);
x_5 = lean_apply_2(x_2, x_3, x_4);
return x_5;
}
else
{
lean_object* x_6; uint8_t x_7; lean_object* x_8; lean_object* x_9; 
x_6 = lean_ctor_get(x_1, 0);
lean_inc(x_6);
x_7 = lean_ctor_get_uint8(x_1, sizeof(void*)*1);
lean_dec_ref(x_1);
x_8 = lean_box(x_7);
x_9 = lean_apply_2(x_2, x_6, x_8);
return x_9;
}
}
}
LEAN_EXPORT lean_object* lp_padctl_AuxEvent_ctorElim(lean_object* x_1, lean_object* x_2, lean_object* x_3, lean_object* x_4, lean_object* x_5) {
_start:
{
lean_object* x_6; 
x_6 = lp_padctl_AuxEvent_ctorElim___redArg(x_3, x_5);
return x_6;
}
}
LEAN_EXPORT lean_object* lp_padctl_AuxEvent_ctorElim___boxed(lean_object* x_1, lean_object* x_2, lean_object* x_3, lean_object* x_4, lean_object* x_5) {
_start:
{
lean_object* x_6; 
x_6 = lp_padctl_AuxEvent_ctorElim(x_1, x_2, x_3, x_4, x_5);
lean_dec(x_2);
return x_6;
}
}
LEAN_EXPORT lean_object* lp_padctl_AuxEvent_key_elim___redArg(lean_object* x_1, lean_object* x_2) {
_start:
{
lean_object* x_3; 
x_3 = lp_padctl_AuxEvent_ctorElim___redArg(x_1, x_2);
return x_3;
}
}
LEAN_EXPORT lean_object* lp_padctl_AuxEvent_key_elim(lean_object* x_1, lean_object* x_2, lean_object* x_3, lean_object* x_4) {
_start:
{
lean_object* x_5; 
x_5 = lp_padctl_AuxEvent_ctorElim___redArg(x_2, x_4);
return x_5;
}
}
LEAN_EXPORT lean_object* lp_padctl_AuxEvent_mouseButton_elim___redArg(lean_object* x_1, lean_object* x_2) {
_start:
{
lean_object* x_3; 
x_3 = lp_padctl_AuxEvent_ctorElim___redArg(x_1, x_2);
return x_3;
}
}
LEAN_EXPORT lean_object* lp_padctl_AuxEvent_mouseButton_elim(lean_object* x_1, lean_object* x_2, lean_object* x_3, lean_object* x_4) {
_start:
{
lean_object* x_5; 
x_5 = lp_padctl_AuxEvent_ctorElim___redArg(x_2, x_4);
return x_5;
}
}
LEAN_EXPORT lean_object* lp_padctl_AuxEvent_rel_elim___redArg(lean_object* x_1, lean_object* x_2) {
_start:
{
lean_object* x_3; 
x_3 = lp_padctl_AuxEvent_ctorElim___redArg(x_1, x_2);
return x_3;
}
}
LEAN_EXPORT lean_object* lp_padctl_AuxEvent_rel_elim(lean_object* x_1, lean_object* x_2, lean_object* x_3, lean_object* x_4) {
_start:
{
lean_object* x_5; 
x_5 = lp_padctl_AuxEvent_ctorElim___redArg(x_2, x_4);
return x_5;
}
}
LEAN_EXPORT uint8_t lp_padctl_instDecidableEqAuxEvent_decEq(lean_object* x_1, lean_object* x_2) {
_start:
{
switch (lean_obj_tag(x_1)) {
case 0:
{
if (lean_obj_tag(x_2) == 0)
{
lean_object* x_3; uint8_t x_4; lean_object* x_5; uint8_t x_6; uint8_t x_7; 
x_3 = lean_ctor_get(x_1, 0);
x_4 = lean_ctor_get_uint8(x_1, sizeof(void*)*1);
x_5 = lean_ctor_get(x_2, 0);
x_6 = lean_ctor_get_uint8(x_2, sizeof(void*)*1);
x_7 = lean_nat_dec_eq(x_3, x_5);
if (x_7 == 0)
{
return x_7;
}
else
{
if (x_4 == 0)
{
if (x_6 == 0)
{
return x_7;
}
else
{
return x_4;
}
}
else
{
return x_6;
}
}
}
else
{
uint8_t x_8; 
x_8 = 0;
return x_8;
}
}
case 1:
{
if (lean_obj_tag(x_2) == 1)
{
lean_object* x_9; uint8_t x_10; lean_object* x_11; uint8_t x_12; uint8_t x_13; 
x_9 = lean_ctor_get(x_1, 0);
x_10 = lean_ctor_get_uint8(x_1, sizeof(void*)*1);
x_11 = lean_ctor_get(x_2, 0);
x_12 = lean_ctor_get_uint8(x_2, sizeof(void*)*1);
x_13 = lean_nat_dec_eq(x_9, x_11);
if (x_13 == 0)
{
return x_13;
}
else
{
if (x_10 == 0)
{
if (x_12 == 0)
{
return x_13;
}
else
{
return x_10;
}
}
else
{
return x_12;
}
}
}
else
{
uint8_t x_14; 
x_14 = 0;
return x_14;
}
}
default: 
{
if (lean_obj_tag(x_2) == 2)
{
lean_object* x_15; lean_object* x_16; lean_object* x_17; lean_object* x_18; uint8_t x_19; 
x_15 = lean_ctor_get(x_1, 0);
x_16 = lean_ctor_get(x_1, 1);
x_17 = lean_ctor_get(x_2, 0);
x_18 = lean_ctor_get(x_2, 1);
x_19 = lean_nat_dec_eq(x_15, x_17);
if (x_19 == 0)
{
return x_19;
}
else
{
uint8_t x_20; 
x_20 = lean_int_dec_eq(x_16, x_18);
return x_20;
}
}
else
{
uint8_t x_21; 
x_21 = 0;
return x_21;
}
}
}
}
}
LEAN_EXPORT lean_object* lp_padctl_instDecidableEqAuxEvent_decEq___boxed(lean_object* x_1, lean_object* x_2) {
_start:
{
uint8_t x_3; lean_object* x_4; 
x_3 = lp_padctl_instDecidableEqAuxEvent_decEq(x_1, x_2);
lean_dec_ref(x_2);
lean_dec_ref(x_1);
x_4 = lean_box(x_3);
return x_4;
}
}
LEAN_EXPORT uint8_t lp_padctl_instDecidableEqAuxEvent(lean_object* x_1, lean_object* x_2) {
_start:
{
uint8_t x_3; 
x_3 = lp_padctl_instDecidableEqAuxEvent_decEq(x_1, x_2);
return x_3;
}
}
LEAN_EXPORT lean_object* lp_padctl_instDecidableEqAuxEvent___boxed(lean_object* x_1, lean_object* x_2) {
_start:
{
uint8_t x_3; lean_object* x_4; 
x_3 = lp_padctl_instDecidableEqAuxEvent(x_1, x_2);
lean_dec_ref(x_2);
lean_dec_ref(x_1);
x_4 = lean_box(x_3);
return x_4;
}
}
static lean_object* _init_lp_padctl_instReprAuxEvent_repr___closed__3(void) {
_start:
{
lean_object* x_1; lean_object* x_2; 
x_1 = lean_unsigned_to_nat(2u);
x_2 = lean_nat_to_int(x_1);
return x_2;
}
}
static lean_object* _init_lp_padctl_instReprAuxEvent_repr___closed__4(void) {
_start:
{
lean_object* x_1; lean_object* x_2; 
x_1 = lean_unsigned_to_nat(1u);
x_2 = lean_nat_to_int(x_1);
return x_2;
}
}
static lean_object* _init_lp_padctl_instReprAuxEvent_repr___closed__11(void) {
_start:
{
lean_object* x_1; lean_object* x_2; 
x_1 = lean_unsigned_to_nat(0u);
x_2 = lean_nat_to_int(x_1);
return x_2;
}
}
LEAN_EXPORT lean_object* lp_padctl_instReprAuxEvent_repr(lean_object* x_1, lean_object* x_2) {
_start:
{
lean_object* x_3; lean_object* x_4; lean_object* x_5; 
switch (lean_obj_tag(x_1)) {
case 0:
{
lean_object* x_12; uint8_t x_13; lean_object* x_14; lean_object* x_15; lean_object* x_29; uint8_t x_30; 
x_12 = lean_ctor_get(x_1, 0);
lean_inc(x_12);
x_13 = lean_ctor_get_uint8(x_1, sizeof(void*)*1);
if (lean_is_exclusive(x_1)) {
 lean_ctor_release(x_1, 0);
 x_14 = x_1;
} else {
 lean_dec_ref(x_1);
 x_14 = lean_box(0);
}
x_29 = lean_unsigned_to_nat(1024u);
x_30 = lean_nat_dec_le(x_29, x_2);
if (x_30 == 0)
{
lean_object* x_31; 
x_31 = lean_obj_once(&lp_padctl_instReprAuxEvent_repr___closed__3, &lp_padctl_instReprAuxEvent_repr___closed__3_once, _init_lp_padctl_instReprAuxEvent_repr___closed__3);
x_15 = x_31;
goto block_28;
}
else
{
lean_object* x_32; 
x_32 = lean_obj_once(&lp_padctl_instReprAuxEvent_repr___closed__4, &lp_padctl_instReprAuxEvent_repr___closed__4_once, _init_lp_padctl_instReprAuxEvent_repr___closed__4);
x_15 = x_32;
goto block_28;
}
block_28:
{
lean_object* x_16; lean_object* x_17; lean_object* x_18; lean_object* x_19; lean_object* x_20; lean_object* x_21; lean_object* x_22; lean_object* x_23; lean_object* x_24; uint8_t x_25; lean_object* x_26; lean_object* x_27; 
x_16 = lean_box(1);
x_17 = ((lean_object*)(lp_padctl_instReprAuxEvent_repr___closed__2));
x_18 = l_Nat_reprFast(x_12);
x_19 = lean_alloc_ctor(3, 1, 0);
lean_ctor_set(x_19, 0, x_18);
x_20 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_20, 0, x_17);
lean_ctor_set(x_20, 1, x_19);
x_21 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_21, 0, x_20);
lean_ctor_set(x_21, 1, x_16);
x_22 = l_Bool_repr___redArg(x_13);
x_23 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_23, 0, x_21);
lean_ctor_set(x_23, 1, x_22);
x_24 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_24, 0, x_15);
lean_ctor_set(x_24, 1, x_23);
x_25 = 0;
if (lean_is_scalar(x_14)) {
 x_26 = lean_alloc_ctor(6, 1, 1);
} else {
 x_26 = x_14;
 lean_ctor_set_tag(x_26, 6);
}
lean_ctor_set(x_26, 0, x_24);
lean_ctor_set_uint8(x_26, sizeof(void*)*1, x_25);
x_27 = l_Repr_addAppParen(x_26, x_2);
return x_27;
}
}
case 1:
{
lean_object* x_33; uint8_t x_34; lean_object* x_35; lean_object* x_36; lean_object* x_50; uint8_t x_51; 
x_33 = lean_ctor_get(x_1, 0);
lean_inc(x_33);
x_34 = lean_ctor_get_uint8(x_1, sizeof(void*)*1);
if (lean_is_exclusive(x_1)) {
 lean_ctor_release(x_1, 0);
 x_35 = x_1;
} else {
 lean_dec_ref(x_1);
 x_35 = lean_box(0);
}
x_50 = lean_unsigned_to_nat(1024u);
x_51 = lean_nat_dec_le(x_50, x_2);
if (x_51 == 0)
{
lean_object* x_52; 
x_52 = lean_obj_once(&lp_padctl_instReprAuxEvent_repr___closed__3, &lp_padctl_instReprAuxEvent_repr___closed__3_once, _init_lp_padctl_instReprAuxEvent_repr___closed__3);
x_36 = x_52;
goto block_49;
}
else
{
lean_object* x_53; 
x_53 = lean_obj_once(&lp_padctl_instReprAuxEvent_repr___closed__4, &lp_padctl_instReprAuxEvent_repr___closed__4_once, _init_lp_padctl_instReprAuxEvent_repr___closed__4);
x_36 = x_53;
goto block_49;
}
block_49:
{
lean_object* x_37; lean_object* x_38; lean_object* x_39; lean_object* x_40; lean_object* x_41; lean_object* x_42; lean_object* x_43; lean_object* x_44; lean_object* x_45; uint8_t x_46; lean_object* x_47; lean_object* x_48; 
x_37 = lean_box(1);
x_38 = ((lean_object*)(lp_padctl_instReprAuxEvent_repr___closed__7));
x_39 = l_Nat_reprFast(x_33);
x_40 = lean_alloc_ctor(3, 1, 0);
lean_ctor_set(x_40, 0, x_39);
x_41 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_41, 0, x_38);
lean_ctor_set(x_41, 1, x_40);
x_42 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_42, 0, x_41);
lean_ctor_set(x_42, 1, x_37);
x_43 = l_Bool_repr___redArg(x_34);
x_44 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_44, 0, x_42);
lean_ctor_set(x_44, 1, x_43);
x_45 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_45, 0, x_36);
lean_ctor_set(x_45, 1, x_44);
x_46 = 0;
if (lean_is_scalar(x_35)) {
 x_47 = lean_alloc_ctor(6, 1, 1);
} else {
 x_47 = x_35;
 lean_ctor_set_tag(x_47, 6);
}
lean_ctor_set(x_47, 0, x_45);
lean_ctor_set_uint8(x_47, sizeof(void*)*1, x_46);
x_48 = l_Repr_addAppParen(x_47, x_2);
return x_48;
}
}
default: 
{
lean_object* x_54; lean_object* x_55; lean_object* x_56; lean_object* x_57; lean_object* x_73; uint8_t x_74; 
x_54 = lean_ctor_get(x_1, 0);
lean_inc(x_54);
x_55 = lean_ctor_get(x_1, 1);
lean_inc(x_55);
if (lean_is_exclusive(x_1)) {
 lean_ctor_release(x_1, 0);
 lean_ctor_release(x_1, 1);
 x_56 = x_1;
} else {
 lean_dec_ref(x_1);
 x_56 = lean_box(0);
}
x_73 = lean_unsigned_to_nat(1024u);
x_74 = lean_nat_dec_le(x_73, x_2);
if (x_74 == 0)
{
lean_object* x_75; 
x_75 = lean_obj_once(&lp_padctl_instReprAuxEvent_repr___closed__3, &lp_padctl_instReprAuxEvent_repr___closed__3_once, _init_lp_padctl_instReprAuxEvent_repr___closed__3);
x_57 = x_75;
goto block_72;
}
else
{
lean_object* x_76; 
x_76 = lean_obj_once(&lp_padctl_instReprAuxEvent_repr___closed__4, &lp_padctl_instReprAuxEvent_repr___closed__4_once, _init_lp_padctl_instReprAuxEvent_repr___closed__4);
x_57 = x_76;
goto block_72;
}
block_72:
{
lean_object* x_58; lean_object* x_59; lean_object* x_60; lean_object* x_61; lean_object* x_62; lean_object* x_63; lean_object* x_64; uint8_t x_65; 
x_58 = lean_box(1);
x_59 = ((lean_object*)(lp_padctl_instReprAuxEvent_repr___closed__10));
x_60 = l_Nat_reprFast(x_54);
x_61 = lean_alloc_ctor(3, 1, 0);
lean_ctor_set(x_61, 0, x_60);
if (lean_is_scalar(x_56)) {
 x_62 = lean_alloc_ctor(5, 2, 0);
} else {
 x_62 = x_56;
 lean_ctor_set_tag(x_62, 5);
}
lean_ctor_set(x_62, 0, x_59);
lean_ctor_set(x_62, 1, x_61);
x_63 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_63, 0, x_62);
lean_ctor_set(x_63, 1, x_58);
x_64 = lean_obj_once(&lp_padctl_instReprAuxEvent_repr___closed__11, &lp_padctl_instReprAuxEvent_repr___closed__11_once, _init_lp_padctl_instReprAuxEvent_repr___closed__11);
x_65 = lean_int_dec_lt(x_55, x_64);
if (x_65 == 0)
{
lean_object* x_66; lean_object* x_67; 
x_66 = l_Int_repr(x_55);
lean_dec(x_55);
x_67 = lean_alloc_ctor(3, 1, 0);
lean_ctor_set(x_67, 0, x_66);
x_3 = x_63;
x_4 = x_57;
x_5 = x_67;
goto block_11;
}
else
{
lean_object* x_68; lean_object* x_69; lean_object* x_70; lean_object* x_71; 
x_68 = lean_unsigned_to_nat(1024u);
x_69 = l_Int_repr(x_55);
lean_dec(x_55);
x_70 = lean_alloc_ctor(3, 1, 0);
lean_ctor_set(x_70, 0, x_69);
x_71 = l_Repr_addAppParen(x_70, x_68);
x_3 = x_63;
x_4 = x_57;
x_5 = x_71;
goto block_11;
}
}
}
}
block_11:
{
lean_object* x_6; lean_object* x_7; uint8_t x_8; lean_object* x_9; lean_object* x_10; 
x_6 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_6, 0, x_3);
lean_ctor_set(x_6, 1, x_5);
x_7 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_7, 0, x_4);
lean_ctor_set(x_7, 1, x_6);
x_8 = 0;
x_9 = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(x_9, 0, x_7);
lean_ctor_set_uint8(x_9, sizeof(void*)*1, x_8);
x_10 = l_Repr_addAppParen(x_9, x_2);
return x_10;
}
}
}
LEAN_EXPORT lean_object* lp_padctl_instReprAuxEvent_repr___boxed(lean_object* x_1, lean_object* x_2) {
_start:
{
lean_object* x_3; 
x_3 = lp_padctl_instReprAuxEvent_repr(x_1, x_2);
lean_dec(x_2);
return x_3;
}
}
LEAN_EXPORT lean_object* lp_padctl_TapHoldPhase_ctorIdx(uint8_t x_1) {
_start:
{
if (x_1 == 0)
{
lean_object* x_2; 
x_2 = lean_unsigned_to_nat(0u);
return x_2;
}
else
{
lean_object* x_3; 
x_3 = lean_unsigned_to_nat(1u);
return x_3;
}
}
}
LEAN_EXPORT lean_object* lp_padctl_TapHoldPhase_ctorIdx___boxed(lean_object* x_1) {
_start:
{
uint8_t x_2; lean_object* x_3; 
x_2 = lean_unbox(x_1);
x_3 = lp_padctl_TapHoldPhase_ctorIdx(x_2);
return x_3;
}
}
LEAN_EXPORT lean_object* lp_padctl_TapHoldPhase_toCtorIdx(uint8_t x_1) {
_start:
{
lean_object* x_2; 
x_2 = lp_padctl_TapHoldPhase_ctorIdx(x_1);
return x_2;
}
}
LEAN_EXPORT lean_object* lp_padctl_TapHoldPhase_toCtorIdx___boxed(lean_object* x_1) {
_start:
{
uint8_t x_2; lean_object* x_3; 
x_2 = lean_unbox(x_1);
x_3 = lp_padctl_TapHoldPhase_toCtorIdx(x_2);
return x_3;
}
}
LEAN_EXPORT lean_object* lp_padctl_TapHoldPhase_ctorElim___redArg(lean_object* x_1) {
_start:
{
lean_inc(x_1);
return x_1;
}
}
LEAN_EXPORT lean_object* lp_padctl_TapHoldPhase_ctorElim___redArg___boxed(lean_object* x_1) {
_start:
{
lean_object* x_2; 
x_2 = lp_padctl_TapHoldPhase_ctorElim___redArg(x_1);
lean_dec(x_1);
return x_2;
}
}
LEAN_EXPORT lean_object* lp_padctl_TapHoldPhase_ctorElim(lean_object* x_1, lean_object* x_2, uint8_t x_3, lean_object* x_4, lean_object* x_5) {
_start:
{
lean_inc(x_5);
return x_5;
}
}
LEAN_EXPORT lean_object* lp_padctl_TapHoldPhase_ctorElim___boxed(lean_object* x_1, lean_object* x_2, lean_object* x_3, lean_object* x_4, lean_object* x_5) {
_start:
{
uint8_t x_6; lean_object* x_7; 
x_6 = lean_unbox(x_3);
x_7 = lp_padctl_TapHoldPhase_ctorElim(x_1, x_2, x_6, x_4, x_5);
lean_dec(x_5);
lean_dec(x_2);
return x_7;
}
}
LEAN_EXPORT lean_object* lp_padctl_TapHoldPhase_pending_elim___redArg(lean_object* x_1) {
_start:
{
lean_inc(x_1);
return x_1;
}
}
LEAN_EXPORT lean_object* lp_padctl_TapHoldPhase_pending_elim___redArg___boxed(lean_object* x_1) {
_start:
{
lean_object* x_2; 
x_2 = lp_padctl_TapHoldPhase_pending_elim___redArg(x_1);
lean_dec(x_1);
return x_2;
}
}
LEAN_EXPORT lean_object* lp_padctl_TapHoldPhase_pending_elim(lean_object* x_1, uint8_t x_2, lean_object* x_3, lean_object* x_4) {
_start:
{
lean_inc(x_4);
return x_4;
}
}
LEAN_EXPORT lean_object* lp_padctl_TapHoldPhase_pending_elim___boxed(lean_object* x_1, lean_object* x_2, lean_object* x_3, lean_object* x_4) {
_start:
{
uint8_t x_5; lean_object* x_6; 
x_5 = lean_unbox(x_2);
x_6 = lp_padctl_TapHoldPhase_pending_elim(x_1, x_5, x_3, x_4);
lean_dec(x_4);
return x_6;
}
}
LEAN_EXPORT lean_object* lp_padctl_TapHoldPhase_active_elim___redArg(lean_object* x_1) {
_start:
{
lean_inc(x_1);
return x_1;
}
}
LEAN_EXPORT lean_object* lp_padctl_TapHoldPhase_active_elim___redArg___boxed(lean_object* x_1) {
_start:
{
lean_object* x_2; 
x_2 = lp_padctl_TapHoldPhase_active_elim___redArg(x_1);
lean_dec(x_1);
return x_2;
}
}
LEAN_EXPORT lean_object* lp_padctl_TapHoldPhase_active_elim(lean_object* x_1, uint8_t x_2, lean_object* x_3, lean_object* x_4) {
_start:
{
lean_inc(x_4);
return x_4;
}
}
LEAN_EXPORT lean_object* lp_padctl_TapHoldPhase_active_elim___boxed(lean_object* x_1, lean_object* x_2, lean_object* x_3, lean_object* x_4) {
_start:
{
uint8_t x_5; lean_object* x_6; 
x_5 = lean_unbox(x_2);
x_6 = lp_padctl_TapHoldPhase_active_elim(x_1, x_5, x_3, x_4);
lean_dec(x_4);
return x_6;
}
}
LEAN_EXPORT uint8_t lp_padctl_TapHoldPhase_ofNat(lean_object* x_1) {
_start:
{
lean_object* x_2; uint8_t x_3; 
x_2 = lean_unsigned_to_nat(0u);
x_3 = lean_nat_dec_le(x_1, x_2);
if (x_3 == 0)
{
uint8_t x_4; 
x_4 = 1;
return x_4;
}
else
{
uint8_t x_5; 
x_5 = 0;
return x_5;
}
}
}
LEAN_EXPORT lean_object* lp_padctl_TapHoldPhase_ofNat___boxed(lean_object* x_1) {
_start:
{
uint8_t x_2; lean_object* x_3; 
x_2 = lp_padctl_TapHoldPhase_ofNat(x_1);
lean_dec(x_1);
x_3 = lean_box(x_2);
return x_3;
}
}
LEAN_EXPORT uint8_t lp_padctl_instDecidableEqTapHoldPhase(uint8_t x_1, uint8_t x_2) {
_start:
{
lean_object* x_3; lean_object* x_4; uint8_t x_5; 
x_3 = lp_padctl_TapHoldPhase_ctorIdx(x_1);
x_4 = lp_padctl_TapHoldPhase_ctorIdx(x_2);
x_5 = lean_nat_dec_eq(x_3, x_4);
lean_dec(x_4);
lean_dec(x_3);
return x_5;
}
}
LEAN_EXPORT lean_object* lp_padctl_instDecidableEqTapHoldPhase___boxed(lean_object* x_1, lean_object* x_2) {
_start:
{
uint8_t x_3; uint8_t x_4; uint8_t x_5; lean_object* x_6; 
x_3 = lean_unbox(x_1);
x_4 = lean_unbox(x_2);
x_5 = lp_padctl_instDecidableEqTapHoldPhase(x_3, x_4);
x_6 = lean_box(x_5);
return x_6;
}
}
LEAN_EXPORT lean_object* lp_padctl_instReprTapHoldPhase_repr(uint8_t x_1, lean_object* x_2) {
_start:
{
lean_object* x_3; lean_object* x_10; 
if (x_1 == 0)
{
lean_object* x_17; uint8_t x_18; 
x_17 = lean_unsigned_to_nat(1024u);
x_18 = lean_nat_dec_le(x_17, x_2);
if (x_18 == 0)
{
lean_object* x_19; 
x_19 = lean_obj_once(&lp_padctl_instReprAuxEvent_repr___closed__3, &lp_padctl_instReprAuxEvent_repr___closed__3_once, _init_lp_padctl_instReprAuxEvent_repr___closed__3);
x_3 = x_19;
goto block_9;
}
else
{
lean_object* x_20; 
x_20 = lean_obj_once(&lp_padctl_instReprAuxEvent_repr___closed__4, &lp_padctl_instReprAuxEvent_repr___closed__4_once, _init_lp_padctl_instReprAuxEvent_repr___closed__4);
x_3 = x_20;
goto block_9;
}
}
else
{
lean_object* x_21; uint8_t x_22; 
x_21 = lean_unsigned_to_nat(1024u);
x_22 = lean_nat_dec_le(x_21, x_2);
if (x_22 == 0)
{
lean_object* x_23; 
x_23 = lean_obj_once(&lp_padctl_instReprAuxEvent_repr___closed__3, &lp_padctl_instReprAuxEvent_repr___closed__3_once, _init_lp_padctl_instReprAuxEvent_repr___closed__3);
x_10 = x_23;
goto block_16;
}
else
{
lean_object* x_24; 
x_24 = lean_obj_once(&lp_padctl_instReprAuxEvent_repr___closed__4, &lp_padctl_instReprAuxEvent_repr___closed__4_once, _init_lp_padctl_instReprAuxEvent_repr___closed__4);
x_10 = x_24;
goto block_16;
}
}
block_9:
{
lean_object* x_4; lean_object* x_5; uint8_t x_6; lean_object* x_7; lean_object* x_8; 
x_4 = ((lean_object*)(lp_padctl_instReprTapHoldPhase_repr___closed__1));
x_5 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_5, 0, x_3);
lean_ctor_set(x_5, 1, x_4);
x_6 = 0;
x_7 = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(x_7, 0, x_5);
lean_ctor_set_uint8(x_7, sizeof(void*)*1, x_6);
x_8 = l_Repr_addAppParen(x_7, x_2);
return x_8;
}
block_16:
{
lean_object* x_11; lean_object* x_12; uint8_t x_13; lean_object* x_14; lean_object* x_15; 
x_11 = ((lean_object*)(lp_padctl_instReprTapHoldPhase_repr___closed__3));
x_12 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_12, 0, x_10);
lean_ctor_set(x_12, 1, x_11);
x_13 = 0;
x_14 = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(x_14, 0, x_12);
lean_ctor_set_uint8(x_14, sizeof(void*)*1, x_13);
x_15 = l_Repr_addAppParen(x_14, x_2);
return x_15;
}
}
}
LEAN_EXPORT lean_object* lp_padctl_instReprTapHoldPhase_repr___boxed(lean_object* x_1, lean_object* x_2) {
_start:
{
uint8_t x_3; lean_object* x_4; 
x_3 = lean_unbox(x_1);
x_4 = lp_padctl_instReprTapHoldPhase_repr(x_3, x_2);
lean_dec(x_2);
return x_4;
}
}
LEAN_EXPORT lean_object* lp_padctl_LayerMode_ctorIdx(uint8_t x_1) {
_start:
{
if (x_1 == 0)
{
lean_object* x_2; 
x_2 = lean_unsigned_to_nat(0u);
return x_2;
}
else
{
lean_object* x_3; 
x_3 = lean_unsigned_to_nat(1u);
return x_3;
}
}
}
LEAN_EXPORT lean_object* lp_padctl_LayerMode_ctorIdx___boxed(lean_object* x_1) {
_start:
{
uint8_t x_2; lean_object* x_3; 
x_2 = lean_unbox(x_1);
x_3 = lp_padctl_LayerMode_ctorIdx(x_2);
return x_3;
}
}
LEAN_EXPORT lean_object* lp_padctl_LayerMode_toCtorIdx(uint8_t x_1) {
_start:
{
lean_object* x_2; 
x_2 = lp_padctl_LayerMode_ctorIdx(x_1);
return x_2;
}
}
LEAN_EXPORT lean_object* lp_padctl_LayerMode_toCtorIdx___boxed(lean_object* x_1) {
_start:
{
uint8_t x_2; lean_object* x_3; 
x_2 = lean_unbox(x_1);
x_3 = lp_padctl_LayerMode_toCtorIdx(x_2);
return x_3;
}
}
LEAN_EXPORT lean_object* lp_padctl_LayerMode_ctorElim___redArg(lean_object* x_1) {
_start:
{
lean_inc(x_1);
return x_1;
}
}
LEAN_EXPORT lean_object* lp_padctl_LayerMode_ctorElim___redArg___boxed(lean_object* x_1) {
_start:
{
lean_object* x_2; 
x_2 = lp_padctl_LayerMode_ctorElim___redArg(x_1);
lean_dec(x_1);
return x_2;
}
}
LEAN_EXPORT lean_object* lp_padctl_LayerMode_ctorElim(lean_object* x_1, lean_object* x_2, uint8_t x_3, lean_object* x_4, lean_object* x_5) {
_start:
{
lean_inc(x_5);
return x_5;
}
}
LEAN_EXPORT lean_object* lp_padctl_LayerMode_ctorElim___boxed(lean_object* x_1, lean_object* x_2, lean_object* x_3, lean_object* x_4, lean_object* x_5) {
_start:
{
uint8_t x_6; lean_object* x_7; 
x_6 = lean_unbox(x_3);
x_7 = lp_padctl_LayerMode_ctorElim(x_1, x_2, x_6, x_4, x_5);
lean_dec(x_5);
lean_dec(x_2);
return x_7;
}
}
LEAN_EXPORT lean_object* lp_padctl_LayerMode_hold_elim___redArg(lean_object* x_1) {
_start:
{
lean_inc(x_1);
return x_1;
}
}
LEAN_EXPORT lean_object* lp_padctl_LayerMode_hold_elim___redArg___boxed(lean_object* x_1) {
_start:
{
lean_object* x_2; 
x_2 = lp_padctl_LayerMode_hold_elim___redArg(x_1);
lean_dec(x_1);
return x_2;
}
}
LEAN_EXPORT lean_object* lp_padctl_LayerMode_hold_elim(lean_object* x_1, uint8_t x_2, lean_object* x_3, lean_object* x_4) {
_start:
{
lean_inc(x_4);
return x_4;
}
}
LEAN_EXPORT lean_object* lp_padctl_LayerMode_hold_elim___boxed(lean_object* x_1, lean_object* x_2, lean_object* x_3, lean_object* x_4) {
_start:
{
uint8_t x_5; lean_object* x_6; 
x_5 = lean_unbox(x_2);
x_6 = lp_padctl_LayerMode_hold_elim(x_1, x_5, x_3, x_4);
lean_dec(x_4);
return x_6;
}
}
LEAN_EXPORT lean_object* lp_padctl_LayerMode_toggle_elim___redArg(lean_object* x_1) {
_start:
{
lean_inc(x_1);
return x_1;
}
}
LEAN_EXPORT lean_object* lp_padctl_LayerMode_toggle_elim___redArg___boxed(lean_object* x_1) {
_start:
{
lean_object* x_2; 
x_2 = lp_padctl_LayerMode_toggle_elim___redArg(x_1);
lean_dec(x_1);
return x_2;
}
}
LEAN_EXPORT lean_object* lp_padctl_LayerMode_toggle_elim(lean_object* x_1, uint8_t x_2, lean_object* x_3, lean_object* x_4) {
_start:
{
lean_inc(x_4);
return x_4;
}
}
LEAN_EXPORT lean_object* lp_padctl_LayerMode_toggle_elim___boxed(lean_object* x_1, lean_object* x_2, lean_object* x_3, lean_object* x_4) {
_start:
{
uint8_t x_5; lean_object* x_6; 
x_5 = lean_unbox(x_2);
x_6 = lp_padctl_LayerMode_toggle_elim(x_1, x_5, x_3, x_4);
lean_dec(x_4);
return x_6;
}
}
LEAN_EXPORT uint8_t lp_padctl_LayerMode_ofNat(lean_object* x_1) {
_start:
{
lean_object* x_2; uint8_t x_3; 
x_2 = lean_unsigned_to_nat(0u);
x_3 = lean_nat_dec_le(x_1, x_2);
if (x_3 == 0)
{
uint8_t x_4; 
x_4 = 1;
return x_4;
}
else
{
uint8_t x_5; 
x_5 = 0;
return x_5;
}
}
}
LEAN_EXPORT lean_object* lp_padctl_LayerMode_ofNat___boxed(lean_object* x_1) {
_start:
{
uint8_t x_2; lean_object* x_3; 
x_2 = lp_padctl_LayerMode_ofNat(x_1);
lean_dec(x_1);
x_3 = lean_box(x_2);
return x_3;
}
}
LEAN_EXPORT uint8_t lp_padctl_instDecidableEqLayerMode(uint8_t x_1, uint8_t x_2) {
_start:
{
lean_object* x_3; lean_object* x_4; uint8_t x_5; 
x_3 = lp_padctl_LayerMode_ctorIdx(x_1);
x_4 = lp_padctl_LayerMode_ctorIdx(x_2);
x_5 = lean_nat_dec_eq(x_3, x_4);
lean_dec(x_4);
lean_dec(x_3);
return x_5;
}
}
LEAN_EXPORT lean_object* lp_padctl_instDecidableEqLayerMode___boxed(lean_object* x_1, lean_object* x_2) {
_start:
{
uint8_t x_3; uint8_t x_4; uint8_t x_5; lean_object* x_6; 
x_3 = lean_unbox(x_1);
x_4 = lean_unbox(x_2);
x_5 = lp_padctl_instDecidableEqLayerMode(x_3, x_4);
x_6 = lean_box(x_5);
return x_6;
}
}
LEAN_EXPORT lean_object* lp_padctl_instReprLayerMode_repr(uint8_t x_1, lean_object* x_2) {
_start:
{
lean_object* x_3; lean_object* x_10; 
if (x_1 == 0)
{
lean_object* x_17; uint8_t x_18; 
x_17 = lean_unsigned_to_nat(1024u);
x_18 = lean_nat_dec_le(x_17, x_2);
if (x_18 == 0)
{
lean_object* x_19; 
x_19 = lean_obj_once(&lp_padctl_instReprAuxEvent_repr___closed__3, &lp_padctl_instReprAuxEvent_repr___closed__3_once, _init_lp_padctl_instReprAuxEvent_repr___closed__3);
x_3 = x_19;
goto block_9;
}
else
{
lean_object* x_20; 
x_20 = lean_obj_once(&lp_padctl_instReprAuxEvent_repr___closed__4, &lp_padctl_instReprAuxEvent_repr___closed__4_once, _init_lp_padctl_instReprAuxEvent_repr___closed__4);
x_3 = x_20;
goto block_9;
}
}
else
{
lean_object* x_21; uint8_t x_22; 
x_21 = lean_unsigned_to_nat(1024u);
x_22 = lean_nat_dec_le(x_21, x_2);
if (x_22 == 0)
{
lean_object* x_23; 
x_23 = lean_obj_once(&lp_padctl_instReprAuxEvent_repr___closed__3, &lp_padctl_instReprAuxEvent_repr___closed__3_once, _init_lp_padctl_instReprAuxEvent_repr___closed__3);
x_10 = x_23;
goto block_16;
}
else
{
lean_object* x_24; 
x_24 = lean_obj_once(&lp_padctl_instReprAuxEvent_repr___closed__4, &lp_padctl_instReprAuxEvent_repr___closed__4_once, _init_lp_padctl_instReprAuxEvent_repr___closed__4);
x_10 = x_24;
goto block_16;
}
}
block_9:
{
lean_object* x_4; lean_object* x_5; uint8_t x_6; lean_object* x_7; lean_object* x_8; 
x_4 = ((lean_object*)(lp_padctl_instReprLayerMode_repr___closed__1));
x_5 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_5, 0, x_3);
lean_ctor_set(x_5, 1, x_4);
x_6 = 0;
x_7 = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(x_7, 0, x_5);
lean_ctor_set_uint8(x_7, sizeof(void*)*1, x_6);
x_8 = l_Repr_addAppParen(x_7, x_2);
return x_8;
}
block_16:
{
lean_object* x_11; lean_object* x_12; uint8_t x_13; lean_object* x_14; lean_object* x_15; 
x_11 = ((lean_object*)(lp_padctl_instReprLayerMode_repr___closed__3));
x_12 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_12, 0, x_10);
lean_ctor_set(x_12, 1, x_11);
x_13 = 0;
x_14 = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(x_14, 0, x_12);
lean_ctor_set_uint8(x_14, sizeof(void*)*1, x_13);
x_15 = l_Repr_addAppParen(x_14, x_2);
return x_15;
}
}
}
LEAN_EXPORT lean_object* lp_padctl_instReprLayerMode_repr___boxed(lean_object* x_1, lean_object* x_2) {
_start:
{
uint8_t x_3; lean_object* x_4; 
x_3 = lean_unbox(x_1);
x_4 = lp_padctl_instReprLayerMode_repr(x_3, x_2);
lean_dec(x_2);
return x_4;
}
}
LEAN_EXPORT uint8_t lp_padctl_instDecidableEqLayerConfig_decEq(lean_object* x_1, lean_object* x_2) {
_start:
{
lean_object* x_3; uint8_t x_4; lean_object* x_5; lean_object* x_6; uint8_t x_7; lean_object* x_8; uint8_t x_9; 
x_3 = lean_ctor_get(x_1, 0);
x_4 = lean_ctor_get_uint8(x_1, sizeof(void*)*2);
x_5 = lean_ctor_get(x_1, 1);
x_6 = lean_ctor_get(x_2, 0);
x_7 = lean_ctor_get_uint8(x_2, sizeof(void*)*2);
x_8 = lean_ctor_get(x_2, 1);
x_9 = lean_nat_dec_eq(x_3, x_6);
if (x_9 == 0)
{
return x_9;
}
else
{
uint8_t x_10; 
x_10 = lp_padctl_instDecidableEqLayerMode(x_4, x_7);
if (x_10 == 0)
{
return x_10;
}
else
{
uint8_t x_11; 
x_11 = lean_nat_dec_eq(x_5, x_8);
return x_11;
}
}
}
}
LEAN_EXPORT lean_object* lp_padctl_instDecidableEqLayerConfig_decEq___boxed(lean_object* x_1, lean_object* x_2) {
_start:
{
uint8_t x_3; lean_object* x_4; 
x_3 = lp_padctl_instDecidableEqLayerConfig_decEq(x_1, x_2);
lean_dec_ref(x_2);
lean_dec_ref(x_1);
x_4 = lean_box(x_3);
return x_4;
}
}
LEAN_EXPORT uint8_t lp_padctl_instDecidableEqLayerConfig(lean_object* x_1, lean_object* x_2) {
_start:
{
uint8_t x_3; 
x_3 = lp_padctl_instDecidableEqLayerConfig_decEq(x_1, x_2);
return x_3;
}
}
LEAN_EXPORT lean_object* lp_padctl_instDecidableEqLayerConfig___boxed(lean_object* x_1, lean_object* x_2) {
_start:
{
uint8_t x_3; lean_object* x_4; 
x_3 = lp_padctl_instDecidableEqLayerConfig(x_1, x_2);
lean_dec_ref(x_2);
lean_dec_ref(x_1);
x_4 = lean_box(x_3);
return x_4;
}
}
static lean_object* _init_lp_padctl_instReprLayerConfig_repr___redArg___closed__7(void) {
_start:
{
lean_object* x_1; lean_object* x_2; 
x_1 = lean_unsigned_to_nat(11u);
x_2 = lean_nat_to_int(x_1);
return x_2;
}
}
static lean_object* _init_lp_padctl_instReprLayerConfig_repr___redArg___closed__12(void) {
_start:
{
lean_object* x_1; lean_object* x_2; 
x_1 = lean_unsigned_to_nat(8u);
x_2 = lean_nat_to_int(x_1);
return x_2;
}
}
static lean_object* _init_lp_padctl_instReprLayerConfig_repr___redArg___closed__15(void) {
_start:
{
lean_object* x_1; lean_object* x_2; 
x_1 = lean_unsigned_to_nat(15u);
x_2 = lean_nat_to_int(x_1);
return x_2;
}
}
static lean_object* _init_lp_padctl_instReprLayerConfig_repr___redArg___closed__17(void) {
_start:
{
lean_object* x_1; lean_object* x_2; 
x_1 = ((lean_object*)(lp_padctl_instReprLayerConfig_repr___redArg___closed__0));
x_2 = lean_string_length(x_1);
return x_2;
}
}
static lean_object* _init_lp_padctl_instReprLayerConfig_repr___redArg___closed__18(void) {
_start:
{
lean_object* x_1; lean_object* x_2; 
x_1 = lean_obj_once(&lp_padctl_instReprLayerConfig_repr___redArg___closed__17, &lp_padctl_instReprLayerConfig_repr___redArg___closed__17_once, _init_lp_padctl_instReprLayerConfig_repr___redArg___closed__17);
x_2 = lean_nat_to_int(x_1);
return x_2;
}
}
LEAN_EXPORT lean_object* lp_padctl_instReprLayerConfig_repr___redArg(lean_object* x_1) {
_start:
{
lean_object* x_2; uint8_t x_3; lean_object* x_4; lean_object* x_5; lean_object* x_6; lean_object* x_7; lean_object* x_8; lean_object* x_9; lean_object* x_10; uint8_t x_11; lean_object* x_12; lean_object* x_13; lean_object* x_14; lean_object* x_15; lean_object* x_16; lean_object* x_17; lean_object* x_18; lean_object* x_19; lean_object* x_20; lean_object* x_21; lean_object* x_22; lean_object* x_23; lean_object* x_24; lean_object* x_25; lean_object* x_26; lean_object* x_27; lean_object* x_28; lean_object* x_29; lean_object* x_30; lean_object* x_31; lean_object* x_32; lean_object* x_33; lean_object* x_34; lean_object* x_35; lean_object* x_36; lean_object* x_37; lean_object* x_38; lean_object* x_39; lean_object* x_40; lean_object* x_41; lean_object* x_42; lean_object* x_43; lean_object* x_44; 
x_2 = lean_ctor_get(x_1, 0);
lean_inc(x_2);
x_3 = lean_ctor_get_uint8(x_1, sizeof(void*)*2);
x_4 = lean_ctor_get(x_1, 1);
lean_inc(x_4);
lean_dec_ref(x_1);
x_5 = ((lean_object*)(lp_padctl_instReprLayerConfig_repr___redArg___closed__5));
x_6 = ((lean_object*)(lp_padctl_instReprLayerConfig_repr___redArg___closed__6));
x_7 = lean_obj_once(&lp_padctl_instReprLayerConfig_repr___redArg___closed__7, &lp_padctl_instReprLayerConfig_repr___redArg___closed__7_once, _init_lp_padctl_instReprLayerConfig_repr___redArg___closed__7);
x_8 = l_Nat_reprFast(x_2);
x_9 = lean_alloc_ctor(3, 1, 0);
lean_ctor_set(x_9, 0, x_8);
x_10 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_10, 0, x_7);
lean_ctor_set(x_10, 1, x_9);
x_11 = 0;
x_12 = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(x_12, 0, x_10);
lean_ctor_set_uint8(x_12, sizeof(void*)*1, x_11);
x_13 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_13, 0, x_6);
lean_ctor_set(x_13, 1, x_12);
x_14 = ((lean_object*)(lp_padctl_instReprLayerConfig_repr___redArg___closed__9));
x_15 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_15, 0, x_13);
lean_ctor_set(x_15, 1, x_14);
x_16 = lean_box(1);
x_17 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_17, 0, x_15);
lean_ctor_set(x_17, 1, x_16);
x_18 = ((lean_object*)(lp_padctl_instReprLayerConfig_repr___redArg___closed__11));
x_19 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_19, 0, x_17);
lean_ctor_set(x_19, 1, x_18);
x_20 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_20, 0, x_19);
lean_ctor_set(x_20, 1, x_5);
x_21 = lean_obj_once(&lp_padctl_instReprLayerConfig_repr___redArg___closed__12, &lp_padctl_instReprLayerConfig_repr___redArg___closed__12_once, _init_lp_padctl_instReprLayerConfig_repr___redArg___closed__12);
x_22 = lean_unsigned_to_nat(0u);
x_23 = lp_padctl_instReprLayerMode_repr(x_3, x_22);
x_24 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_24, 0, x_21);
lean_ctor_set(x_24, 1, x_23);
x_25 = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(x_25, 0, x_24);
lean_ctor_set_uint8(x_25, sizeof(void*)*1, x_11);
x_26 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_26, 0, x_20);
lean_ctor_set(x_26, 1, x_25);
x_27 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_27, 0, x_26);
lean_ctor_set(x_27, 1, x_14);
x_28 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_28, 0, x_27);
lean_ctor_set(x_28, 1, x_16);
x_29 = ((lean_object*)(lp_padctl_instReprLayerConfig_repr___redArg___closed__14));
x_30 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_30, 0, x_28);
lean_ctor_set(x_30, 1, x_29);
x_31 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_31, 0, x_30);
lean_ctor_set(x_31, 1, x_5);
x_32 = lean_obj_once(&lp_padctl_instReprLayerConfig_repr___redArg___closed__15, &lp_padctl_instReprLayerConfig_repr___redArg___closed__15_once, _init_lp_padctl_instReprLayerConfig_repr___redArg___closed__15);
x_33 = l_Nat_reprFast(x_4);
x_34 = lean_alloc_ctor(3, 1, 0);
lean_ctor_set(x_34, 0, x_33);
x_35 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_35, 0, x_32);
lean_ctor_set(x_35, 1, x_34);
x_36 = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(x_36, 0, x_35);
lean_ctor_set_uint8(x_36, sizeof(void*)*1, x_11);
x_37 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_37, 0, x_31);
lean_ctor_set(x_37, 1, x_36);
x_38 = lean_obj_once(&lp_padctl_instReprLayerConfig_repr___redArg___closed__18, &lp_padctl_instReprLayerConfig_repr___redArg___closed__18_once, _init_lp_padctl_instReprLayerConfig_repr___redArg___closed__18);
x_39 = ((lean_object*)(lp_padctl_instReprLayerConfig_repr___redArg___closed__19));
x_40 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_40, 0, x_39);
lean_ctor_set(x_40, 1, x_37);
x_41 = ((lean_object*)(lp_padctl_instReprLayerConfig_repr___redArg___closed__20));
x_42 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_42, 0, x_40);
lean_ctor_set(x_42, 1, x_41);
x_43 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_43, 0, x_38);
lean_ctor_set(x_43, 1, x_42);
x_44 = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(x_44, 0, x_43);
lean_ctor_set_uint8(x_44, sizeof(void*)*1, x_11);
return x_44;
}
}
LEAN_EXPORT lean_object* lp_padctl_instReprLayerConfig_repr(lean_object* x_1, lean_object* x_2) {
_start:
{
lean_object* x_3; 
x_3 = lp_padctl_instReprLayerConfig_repr___redArg(x_1);
return x_3;
}
}
LEAN_EXPORT lean_object* lp_padctl_instReprLayerConfig_repr___boxed(lean_object* x_1, lean_object* x_2) {
_start:
{
lean_object* x_3; 
x_3 = lp_padctl_instReprLayerConfig_repr(x_1, x_2);
lean_dec(x_2);
return x_3;
}
}
LEAN_EXPORT uint8_t lp_padctl_instDecidableEqTapHoldState_decEq(lean_object* x_1, lean_object* x_2) {
_start:
{
lean_object* x_3; uint8_t x_4; uint8_t x_5; lean_object* x_6; lean_object* x_7; uint8_t x_8; uint8_t x_9; lean_object* x_10; uint8_t x_11; 
x_3 = lean_ctor_get(x_1, 0);
x_4 = lean_ctor_get_uint8(x_1, sizeof(void*)*2);
x_5 = lean_ctor_get_uint8(x_1, sizeof(void*)*2 + 1);
x_6 = lean_ctor_get(x_1, 1);
x_7 = lean_ctor_get(x_2, 0);
x_8 = lean_ctor_get_uint8(x_2, sizeof(void*)*2);
x_9 = lean_ctor_get_uint8(x_2, sizeof(void*)*2 + 1);
x_10 = lean_ctor_get(x_2, 1);
x_11 = lean_nat_dec_eq(x_3, x_7);
if (x_11 == 0)
{
return x_11;
}
else
{
uint8_t x_12; 
x_12 = lp_padctl_instDecidableEqTapHoldPhase(x_4, x_8);
if (x_12 == 0)
{
return x_12;
}
else
{
if (x_5 == 0)
{
if (x_9 == 0)
{
uint8_t x_13; 
x_13 = lean_nat_dec_eq(x_6, x_10);
return x_13;
}
else
{
return x_5;
}
}
else
{
if (x_9 == 0)
{
return x_9;
}
else
{
uint8_t x_14; 
x_14 = lean_nat_dec_eq(x_6, x_10);
return x_14;
}
}
}
}
}
}
LEAN_EXPORT lean_object* lp_padctl_instDecidableEqTapHoldState_decEq___boxed(lean_object* x_1, lean_object* x_2) {
_start:
{
uint8_t x_3; lean_object* x_4; 
x_3 = lp_padctl_instDecidableEqTapHoldState_decEq(x_1, x_2);
lean_dec_ref(x_2);
lean_dec_ref(x_1);
x_4 = lean_box(x_3);
return x_4;
}
}
LEAN_EXPORT uint8_t lp_padctl_instDecidableEqTapHoldState(lean_object* x_1, lean_object* x_2) {
_start:
{
uint8_t x_3; 
x_3 = lp_padctl_instDecidableEqTapHoldState_decEq(x_1, x_2);
return x_3;
}
}
LEAN_EXPORT lean_object* lp_padctl_instDecidableEqTapHoldState___boxed(lean_object* x_1, lean_object* x_2) {
_start:
{
uint8_t x_3; lean_object* x_4; 
x_3 = lp_padctl_instDecidableEqTapHoldState(x_1, x_2);
lean_dec_ref(x_2);
lean_dec_ref(x_1);
x_4 = lean_box(x_3);
return x_4;
}
}
static lean_object* _init_lp_padctl_instReprTapHoldState_repr___redArg___closed__4(void) {
_start:
{
lean_object* x_1; lean_object* x_2; 
x_1 = lean_unsigned_to_nat(12u);
x_2 = lean_nat_to_int(x_1);
return x_2;
}
}
static lean_object* _init_lp_padctl_instReprTapHoldState_repr___redArg___closed__7(void) {
_start:
{
lean_object* x_1; lean_object* x_2; 
x_1 = lean_unsigned_to_nat(9u);
x_2 = lean_nat_to_int(x_1);
return x_2;
}
}
static lean_object* _init_lp_padctl_instReprTapHoldState_repr___redArg___closed__10(void) {
_start:
{
lean_object* x_1; lean_object* x_2; 
x_1 = lean_unsigned_to_nat(18u);
x_2 = lean_nat_to_int(x_1);
return x_2;
}
}
static lean_object* _init_lp_padctl_instReprTapHoldState_repr___redArg___closed__13(void) {
_start:
{
lean_object* x_1; lean_object* x_2; 
x_1 = lean_unsigned_to_nat(13u);
x_2 = lean_nat_to_int(x_1);
return x_2;
}
}
LEAN_EXPORT lean_object* lp_padctl_instReprTapHoldState_repr___redArg(lean_object* x_1) {
_start:
{
lean_object* x_2; uint8_t x_3; uint8_t x_4; lean_object* x_5; lean_object* x_6; lean_object* x_7; lean_object* x_8; lean_object* x_9; lean_object* x_10; lean_object* x_11; uint8_t x_12; lean_object* x_13; lean_object* x_14; lean_object* x_15; lean_object* x_16; lean_object* x_17; lean_object* x_18; lean_object* x_19; lean_object* x_20; lean_object* x_21; lean_object* x_22; lean_object* x_23; lean_object* x_24; lean_object* x_25; lean_object* x_26; lean_object* x_27; lean_object* x_28; lean_object* x_29; lean_object* x_30; lean_object* x_31; lean_object* x_32; lean_object* x_33; lean_object* x_34; lean_object* x_35; lean_object* x_36; lean_object* x_37; lean_object* x_38; lean_object* x_39; lean_object* x_40; lean_object* x_41; lean_object* x_42; lean_object* x_43; lean_object* x_44; lean_object* x_45; lean_object* x_46; lean_object* x_47; lean_object* x_48; lean_object* x_49; lean_object* x_50; lean_object* x_51; lean_object* x_52; lean_object* x_53; lean_object* x_54; lean_object* x_55; 
x_2 = lean_ctor_get(x_1, 0);
lean_inc(x_2);
x_3 = lean_ctor_get_uint8(x_1, sizeof(void*)*2);
x_4 = lean_ctor_get_uint8(x_1, sizeof(void*)*2 + 1);
x_5 = lean_ctor_get(x_1, 1);
lean_inc(x_5);
lean_dec_ref(x_1);
x_6 = ((lean_object*)(lp_padctl_instReprLayerConfig_repr___redArg___closed__5));
x_7 = ((lean_object*)(lp_padctl_instReprTapHoldState_repr___redArg___closed__3));
x_8 = lean_obj_once(&lp_padctl_instReprTapHoldState_repr___redArg___closed__4, &lp_padctl_instReprTapHoldState_repr___redArg___closed__4_once, _init_lp_padctl_instReprTapHoldState_repr___redArg___closed__4);
x_9 = l_Nat_reprFast(x_2);
x_10 = lean_alloc_ctor(3, 1, 0);
lean_ctor_set(x_10, 0, x_9);
x_11 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_11, 0, x_8);
lean_ctor_set(x_11, 1, x_10);
x_12 = 0;
x_13 = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(x_13, 0, x_11);
lean_ctor_set_uint8(x_13, sizeof(void*)*1, x_12);
x_14 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_14, 0, x_7);
lean_ctor_set(x_14, 1, x_13);
x_15 = ((lean_object*)(lp_padctl_instReprLayerConfig_repr___redArg___closed__9));
x_16 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_16, 0, x_14);
lean_ctor_set(x_16, 1, x_15);
x_17 = lean_box(1);
x_18 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_18, 0, x_16);
lean_ctor_set(x_18, 1, x_17);
x_19 = ((lean_object*)(lp_padctl_instReprTapHoldState_repr___redArg___closed__6));
x_20 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_20, 0, x_18);
lean_ctor_set(x_20, 1, x_19);
x_21 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_21, 0, x_20);
lean_ctor_set(x_21, 1, x_6);
x_22 = lean_obj_once(&lp_padctl_instReprTapHoldState_repr___redArg___closed__7, &lp_padctl_instReprTapHoldState_repr___redArg___closed__7_once, _init_lp_padctl_instReprTapHoldState_repr___redArg___closed__7);
x_23 = lean_unsigned_to_nat(0u);
x_24 = lp_padctl_instReprTapHoldPhase_repr(x_3, x_23);
x_25 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_25, 0, x_22);
lean_ctor_set(x_25, 1, x_24);
x_26 = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(x_26, 0, x_25);
lean_ctor_set_uint8(x_26, sizeof(void*)*1, x_12);
x_27 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_27, 0, x_21);
lean_ctor_set(x_27, 1, x_26);
x_28 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_28, 0, x_27);
lean_ctor_set(x_28, 1, x_15);
x_29 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_29, 0, x_28);
lean_ctor_set(x_29, 1, x_17);
x_30 = ((lean_object*)(lp_padctl_instReprTapHoldState_repr___redArg___closed__9));
x_31 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_31, 0, x_29);
lean_ctor_set(x_31, 1, x_30);
x_32 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_32, 0, x_31);
lean_ctor_set(x_32, 1, x_6);
x_33 = lean_obj_once(&lp_padctl_instReprTapHoldState_repr___redArg___closed__10, &lp_padctl_instReprTapHoldState_repr___redArg___closed__10_once, _init_lp_padctl_instReprTapHoldState_repr___redArg___closed__10);
x_34 = l_Bool_repr___redArg(x_4);
x_35 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_35, 0, x_33);
lean_ctor_set(x_35, 1, x_34);
x_36 = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(x_36, 0, x_35);
lean_ctor_set_uint8(x_36, sizeof(void*)*1, x_12);
x_37 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_37, 0, x_32);
lean_ctor_set(x_37, 1, x_36);
x_38 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_38, 0, x_37);
lean_ctor_set(x_38, 1, x_15);
x_39 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_39, 0, x_38);
lean_ctor_set(x_39, 1, x_17);
x_40 = ((lean_object*)(lp_padctl_instReprTapHoldState_repr___redArg___closed__12));
x_41 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_41, 0, x_39);
lean_ctor_set(x_41, 1, x_40);
x_42 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_42, 0, x_41);
lean_ctor_set(x_42, 1, x_6);
x_43 = lean_obj_once(&lp_padctl_instReprTapHoldState_repr___redArg___closed__13, &lp_padctl_instReprTapHoldState_repr___redArg___closed__13_once, _init_lp_padctl_instReprTapHoldState_repr___redArg___closed__13);
x_44 = l_Nat_reprFast(x_5);
x_45 = lean_alloc_ctor(3, 1, 0);
lean_ctor_set(x_45, 0, x_44);
x_46 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_46, 0, x_43);
lean_ctor_set(x_46, 1, x_45);
x_47 = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(x_47, 0, x_46);
lean_ctor_set_uint8(x_47, sizeof(void*)*1, x_12);
x_48 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_48, 0, x_42);
lean_ctor_set(x_48, 1, x_47);
x_49 = lean_obj_once(&lp_padctl_instReprLayerConfig_repr___redArg___closed__18, &lp_padctl_instReprLayerConfig_repr___redArg___closed__18_once, _init_lp_padctl_instReprLayerConfig_repr___redArg___closed__18);
x_50 = ((lean_object*)(lp_padctl_instReprLayerConfig_repr___redArg___closed__19));
x_51 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_51, 0, x_50);
lean_ctor_set(x_51, 1, x_48);
x_52 = ((lean_object*)(lp_padctl_instReprLayerConfig_repr___redArg___closed__20));
x_53 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_53, 0, x_51);
lean_ctor_set(x_53, 1, x_52);
x_54 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_54, 0, x_49);
lean_ctor_set(x_54, 1, x_53);
x_55 = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(x_55, 0, x_54);
lean_ctor_set_uint8(x_55, sizeof(void*)*1, x_12);
return x_55;
}
}
LEAN_EXPORT lean_object* lp_padctl_instReprTapHoldState_repr(lean_object* x_1, lean_object* x_2) {
_start:
{
lean_object* x_3; 
x_3 = lp_padctl_instReprTapHoldState_repr___redArg(x_1);
return x_3;
}
}
LEAN_EXPORT lean_object* lp_padctl_instReprTapHoldState_repr___boxed(lean_object* x_1, lean_object* x_2) {
_start:
{
lean_object* x_3; 
x_3 = lp_padctl_instReprTapHoldState_repr(x_1, x_2);
lean_dec(x_2);
return x_3;
}
}
LEAN_EXPORT lean_object* lp_padctl_GyroMode_ctorIdx(uint8_t x_1) {
_start:
{
if (x_1 == 0)
{
lean_object* x_2; 
x_2 = lean_unsigned_to_nat(0u);
return x_2;
}
else
{
lean_object* x_3; 
x_3 = lean_unsigned_to_nat(1u);
return x_3;
}
}
}
LEAN_EXPORT lean_object* lp_padctl_GyroMode_ctorIdx___boxed(lean_object* x_1) {
_start:
{
uint8_t x_2; lean_object* x_3; 
x_2 = lean_unbox(x_1);
x_3 = lp_padctl_GyroMode_ctorIdx(x_2);
return x_3;
}
}
LEAN_EXPORT lean_object* lp_padctl_GyroMode_toCtorIdx(uint8_t x_1) {
_start:
{
lean_object* x_2; 
x_2 = lp_padctl_GyroMode_ctorIdx(x_1);
return x_2;
}
}
LEAN_EXPORT lean_object* lp_padctl_GyroMode_toCtorIdx___boxed(lean_object* x_1) {
_start:
{
uint8_t x_2; lean_object* x_3; 
x_2 = lean_unbox(x_1);
x_3 = lp_padctl_GyroMode_toCtorIdx(x_2);
return x_3;
}
}
LEAN_EXPORT lean_object* lp_padctl_GyroMode_ctorElim___redArg(lean_object* x_1) {
_start:
{
lean_inc(x_1);
return x_1;
}
}
LEAN_EXPORT lean_object* lp_padctl_GyroMode_ctorElim___redArg___boxed(lean_object* x_1) {
_start:
{
lean_object* x_2; 
x_2 = lp_padctl_GyroMode_ctorElim___redArg(x_1);
lean_dec(x_1);
return x_2;
}
}
LEAN_EXPORT lean_object* lp_padctl_GyroMode_ctorElim(lean_object* x_1, lean_object* x_2, uint8_t x_3, lean_object* x_4, lean_object* x_5) {
_start:
{
lean_inc(x_5);
return x_5;
}
}
LEAN_EXPORT lean_object* lp_padctl_GyroMode_ctorElim___boxed(lean_object* x_1, lean_object* x_2, lean_object* x_3, lean_object* x_4, lean_object* x_5) {
_start:
{
uint8_t x_6; lean_object* x_7; 
x_6 = lean_unbox(x_3);
x_7 = lp_padctl_GyroMode_ctorElim(x_1, x_2, x_6, x_4, x_5);
lean_dec(x_5);
lean_dec(x_2);
return x_7;
}
}
LEAN_EXPORT lean_object* lp_padctl_GyroMode_mouse_elim___redArg(lean_object* x_1) {
_start:
{
lean_inc(x_1);
return x_1;
}
}
LEAN_EXPORT lean_object* lp_padctl_GyroMode_mouse_elim___redArg___boxed(lean_object* x_1) {
_start:
{
lean_object* x_2; 
x_2 = lp_padctl_GyroMode_mouse_elim___redArg(x_1);
lean_dec(x_1);
return x_2;
}
}
LEAN_EXPORT lean_object* lp_padctl_GyroMode_mouse_elim(lean_object* x_1, uint8_t x_2, lean_object* x_3, lean_object* x_4) {
_start:
{
lean_inc(x_4);
return x_4;
}
}
LEAN_EXPORT lean_object* lp_padctl_GyroMode_mouse_elim___boxed(lean_object* x_1, lean_object* x_2, lean_object* x_3, lean_object* x_4) {
_start:
{
uint8_t x_5; lean_object* x_6; 
x_5 = lean_unbox(x_2);
x_6 = lp_padctl_GyroMode_mouse_elim(x_1, x_5, x_3, x_4);
lean_dec(x_4);
return x_6;
}
}
LEAN_EXPORT lean_object* lp_padctl_GyroMode_joystick_elim___redArg(lean_object* x_1) {
_start:
{
lean_inc(x_1);
return x_1;
}
}
LEAN_EXPORT lean_object* lp_padctl_GyroMode_joystick_elim___redArg___boxed(lean_object* x_1) {
_start:
{
lean_object* x_2; 
x_2 = lp_padctl_GyroMode_joystick_elim___redArg(x_1);
lean_dec(x_1);
return x_2;
}
}
LEAN_EXPORT lean_object* lp_padctl_GyroMode_joystick_elim(lean_object* x_1, uint8_t x_2, lean_object* x_3, lean_object* x_4) {
_start:
{
lean_inc(x_4);
return x_4;
}
}
LEAN_EXPORT lean_object* lp_padctl_GyroMode_joystick_elim___boxed(lean_object* x_1, lean_object* x_2, lean_object* x_3, lean_object* x_4) {
_start:
{
uint8_t x_5; lean_object* x_6; 
x_5 = lean_unbox(x_2);
x_6 = lp_padctl_GyroMode_joystick_elim(x_1, x_5, x_3, x_4);
lean_dec(x_4);
return x_6;
}
}
LEAN_EXPORT uint8_t lp_padctl_GyroMode_ofNat(lean_object* x_1) {
_start:
{
lean_object* x_2; uint8_t x_3; 
x_2 = lean_unsigned_to_nat(0u);
x_3 = lean_nat_dec_le(x_1, x_2);
if (x_3 == 0)
{
uint8_t x_4; 
x_4 = 1;
return x_4;
}
else
{
uint8_t x_5; 
x_5 = 0;
return x_5;
}
}
}
LEAN_EXPORT lean_object* lp_padctl_GyroMode_ofNat___boxed(lean_object* x_1) {
_start:
{
uint8_t x_2; lean_object* x_3; 
x_2 = lp_padctl_GyroMode_ofNat(x_1);
lean_dec(x_1);
x_3 = lean_box(x_2);
return x_3;
}
}
LEAN_EXPORT uint8_t lp_padctl_instDecidableEqGyroMode(uint8_t x_1, uint8_t x_2) {
_start:
{
lean_object* x_3; lean_object* x_4; uint8_t x_5; 
x_3 = lp_padctl_GyroMode_ctorIdx(x_1);
x_4 = lp_padctl_GyroMode_ctorIdx(x_2);
x_5 = lean_nat_dec_eq(x_3, x_4);
lean_dec(x_4);
lean_dec(x_3);
return x_5;
}
}
LEAN_EXPORT lean_object* lp_padctl_instDecidableEqGyroMode___boxed(lean_object* x_1, lean_object* x_2) {
_start:
{
uint8_t x_3; uint8_t x_4; uint8_t x_5; lean_object* x_6; 
x_3 = lean_unbox(x_1);
x_4 = lean_unbox(x_2);
x_5 = lp_padctl_instDecidableEqGyroMode(x_3, x_4);
x_6 = lean_box(x_5);
return x_6;
}
}
LEAN_EXPORT lean_object* lp_padctl_instReprGyroMode_repr(uint8_t x_1, lean_object* x_2) {
_start:
{
lean_object* x_3; lean_object* x_10; 
if (x_1 == 0)
{
lean_object* x_17; uint8_t x_18; 
x_17 = lean_unsigned_to_nat(1024u);
x_18 = lean_nat_dec_le(x_17, x_2);
if (x_18 == 0)
{
lean_object* x_19; 
x_19 = lean_obj_once(&lp_padctl_instReprAuxEvent_repr___closed__3, &lp_padctl_instReprAuxEvent_repr___closed__3_once, _init_lp_padctl_instReprAuxEvent_repr___closed__3);
x_3 = x_19;
goto block_9;
}
else
{
lean_object* x_20; 
x_20 = lean_obj_once(&lp_padctl_instReprAuxEvent_repr___closed__4, &lp_padctl_instReprAuxEvent_repr___closed__4_once, _init_lp_padctl_instReprAuxEvent_repr___closed__4);
x_3 = x_20;
goto block_9;
}
}
else
{
lean_object* x_21; uint8_t x_22; 
x_21 = lean_unsigned_to_nat(1024u);
x_22 = lean_nat_dec_le(x_21, x_2);
if (x_22 == 0)
{
lean_object* x_23; 
x_23 = lean_obj_once(&lp_padctl_instReprAuxEvent_repr___closed__3, &lp_padctl_instReprAuxEvent_repr___closed__3_once, _init_lp_padctl_instReprAuxEvent_repr___closed__3);
x_10 = x_23;
goto block_16;
}
else
{
lean_object* x_24; 
x_24 = lean_obj_once(&lp_padctl_instReprAuxEvent_repr___closed__4, &lp_padctl_instReprAuxEvent_repr___closed__4_once, _init_lp_padctl_instReprAuxEvent_repr___closed__4);
x_10 = x_24;
goto block_16;
}
}
block_9:
{
lean_object* x_4; lean_object* x_5; uint8_t x_6; lean_object* x_7; lean_object* x_8; 
x_4 = ((lean_object*)(lp_padctl_instReprGyroMode_repr___closed__1));
x_5 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_5, 0, x_3);
lean_ctor_set(x_5, 1, x_4);
x_6 = 0;
x_7 = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(x_7, 0, x_5);
lean_ctor_set_uint8(x_7, sizeof(void*)*1, x_6);
x_8 = l_Repr_addAppParen(x_7, x_2);
return x_8;
}
block_16:
{
lean_object* x_11; lean_object* x_12; uint8_t x_13; lean_object* x_14; lean_object* x_15; 
x_11 = ((lean_object*)(lp_padctl_instReprGyroMode_repr___closed__3));
x_12 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_12, 0, x_10);
lean_ctor_set(x_12, 1, x_11);
x_13 = 0;
x_14 = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(x_14, 0, x_12);
lean_ctor_set_uint8(x_14, sizeof(void*)*1, x_13);
x_15 = l_Repr_addAppParen(x_14, x_2);
return x_15;
}
}
}
LEAN_EXPORT lean_object* lp_padctl_instReprGyroMode_repr___boxed(lean_object* x_1, lean_object* x_2) {
_start:
{
uint8_t x_3; lean_object* x_4; 
x_3 = lean_unbox(x_1);
x_4 = lp_padctl_instReprGyroMode_repr(x_3, x_2);
lean_dec(x_2);
return x_4;
}
}
LEAN_EXPORT uint8_t lp_padctl_checkGyroActivate(lean_object* x_1, lean_object* x_2) {
_start:
{
if (lean_obj_tag(x_2) == 0)
{
uint8_t x_3; 
x_3 = 1;
return x_3;
}
else
{
lean_object* x_4; uint8_t x_5; 
x_4 = lean_ctor_get(x_2, 0);
x_5 = lp_padctl_testBit(x_1, x_4);
return x_5;
}
}
}
LEAN_EXPORT lean_object* lp_padctl_checkGyroActivate___boxed(lean_object* x_1, lean_object* x_2) {
_start:
{
uint8_t x_3; lean_object* x_4; 
x_3 = lp_padctl_checkGyroActivate(x_1, x_2);
lean_dec(x_2);
lean_dec(x_1);
x_4 = lean_box(x_3);
return x_4;
}
}
LEAN_EXPORT lean_object* lp_padctl_StickMode_ctorIdx(uint8_t x_1) {
_start:
{
switch (x_1) {
case 0:
{
lean_object* x_2; 
x_2 = lean_unsigned_to_nat(0u);
return x_2;
}
case 1:
{
lean_object* x_3; 
x_3 = lean_unsigned_to_nat(1u);
return x_3;
}
default: 
{
lean_object* x_4; 
x_4 = lean_unsigned_to_nat(2u);
return x_4;
}
}
}
}
LEAN_EXPORT lean_object* lp_padctl_StickMode_ctorIdx___boxed(lean_object* x_1) {
_start:
{
uint8_t x_2; lean_object* x_3; 
x_2 = lean_unbox(x_1);
x_3 = lp_padctl_StickMode_ctorIdx(x_2);
return x_3;
}
}
LEAN_EXPORT lean_object* lp_padctl_StickMode_toCtorIdx(uint8_t x_1) {
_start:
{
lean_object* x_2; 
x_2 = lp_padctl_StickMode_ctorIdx(x_1);
return x_2;
}
}
LEAN_EXPORT lean_object* lp_padctl_StickMode_toCtorIdx___boxed(lean_object* x_1) {
_start:
{
uint8_t x_2; lean_object* x_3; 
x_2 = lean_unbox(x_1);
x_3 = lp_padctl_StickMode_toCtorIdx(x_2);
return x_3;
}
}
LEAN_EXPORT lean_object* lp_padctl_StickMode_ctorElim___redArg(lean_object* x_1) {
_start:
{
lean_inc(x_1);
return x_1;
}
}
LEAN_EXPORT lean_object* lp_padctl_StickMode_ctorElim___redArg___boxed(lean_object* x_1) {
_start:
{
lean_object* x_2; 
x_2 = lp_padctl_StickMode_ctorElim___redArg(x_1);
lean_dec(x_1);
return x_2;
}
}
LEAN_EXPORT lean_object* lp_padctl_StickMode_ctorElim(lean_object* x_1, lean_object* x_2, uint8_t x_3, lean_object* x_4, lean_object* x_5) {
_start:
{
lean_inc(x_5);
return x_5;
}
}
LEAN_EXPORT lean_object* lp_padctl_StickMode_ctorElim___boxed(lean_object* x_1, lean_object* x_2, lean_object* x_3, lean_object* x_4, lean_object* x_5) {
_start:
{
uint8_t x_6; lean_object* x_7; 
x_6 = lean_unbox(x_3);
x_7 = lp_padctl_StickMode_ctorElim(x_1, x_2, x_6, x_4, x_5);
lean_dec(x_5);
lean_dec(x_2);
return x_7;
}
}
LEAN_EXPORT lean_object* lp_padctl_StickMode_gamepad_elim___redArg(lean_object* x_1) {
_start:
{
lean_inc(x_1);
return x_1;
}
}
LEAN_EXPORT lean_object* lp_padctl_StickMode_gamepad_elim___redArg___boxed(lean_object* x_1) {
_start:
{
lean_object* x_2; 
x_2 = lp_padctl_StickMode_gamepad_elim___redArg(x_1);
lean_dec(x_1);
return x_2;
}
}
LEAN_EXPORT lean_object* lp_padctl_StickMode_gamepad_elim(lean_object* x_1, uint8_t x_2, lean_object* x_3, lean_object* x_4) {
_start:
{
lean_inc(x_4);
return x_4;
}
}
LEAN_EXPORT lean_object* lp_padctl_StickMode_gamepad_elim___boxed(lean_object* x_1, lean_object* x_2, lean_object* x_3, lean_object* x_4) {
_start:
{
uint8_t x_5; lean_object* x_6; 
x_5 = lean_unbox(x_2);
x_6 = lp_padctl_StickMode_gamepad_elim(x_1, x_5, x_3, x_4);
lean_dec(x_4);
return x_6;
}
}
LEAN_EXPORT lean_object* lp_padctl_StickMode_mouse_elim___redArg(lean_object* x_1) {
_start:
{
lean_inc(x_1);
return x_1;
}
}
LEAN_EXPORT lean_object* lp_padctl_StickMode_mouse_elim___redArg___boxed(lean_object* x_1) {
_start:
{
lean_object* x_2; 
x_2 = lp_padctl_StickMode_mouse_elim___redArg(x_1);
lean_dec(x_1);
return x_2;
}
}
LEAN_EXPORT lean_object* lp_padctl_StickMode_mouse_elim(lean_object* x_1, uint8_t x_2, lean_object* x_3, lean_object* x_4) {
_start:
{
lean_inc(x_4);
return x_4;
}
}
LEAN_EXPORT lean_object* lp_padctl_StickMode_mouse_elim___boxed(lean_object* x_1, lean_object* x_2, lean_object* x_3, lean_object* x_4) {
_start:
{
uint8_t x_5; lean_object* x_6; 
x_5 = lean_unbox(x_2);
x_6 = lp_padctl_StickMode_mouse_elim(x_1, x_5, x_3, x_4);
lean_dec(x_4);
return x_6;
}
}
LEAN_EXPORT lean_object* lp_padctl_StickMode_scroll_elim___redArg(lean_object* x_1) {
_start:
{
lean_inc(x_1);
return x_1;
}
}
LEAN_EXPORT lean_object* lp_padctl_StickMode_scroll_elim___redArg___boxed(lean_object* x_1) {
_start:
{
lean_object* x_2; 
x_2 = lp_padctl_StickMode_scroll_elim___redArg(x_1);
lean_dec(x_1);
return x_2;
}
}
LEAN_EXPORT lean_object* lp_padctl_StickMode_scroll_elim(lean_object* x_1, uint8_t x_2, lean_object* x_3, lean_object* x_4) {
_start:
{
lean_inc(x_4);
return x_4;
}
}
LEAN_EXPORT lean_object* lp_padctl_StickMode_scroll_elim___boxed(lean_object* x_1, lean_object* x_2, lean_object* x_3, lean_object* x_4) {
_start:
{
uint8_t x_5; lean_object* x_6; 
x_5 = lean_unbox(x_2);
x_6 = lp_padctl_StickMode_scroll_elim(x_1, x_5, x_3, x_4);
lean_dec(x_4);
return x_6;
}
}
LEAN_EXPORT uint8_t lp_padctl_StickMode_ofNat(lean_object* x_1) {
_start:
{
lean_object* x_2; uint8_t x_3; 
x_2 = lean_unsigned_to_nat(0u);
x_3 = lean_nat_dec_le(x_1, x_2);
if (x_3 == 0)
{
lean_object* x_4; uint8_t x_5; 
x_4 = lean_unsigned_to_nat(1u);
x_5 = lean_nat_dec_le(x_1, x_4);
if (x_5 == 0)
{
uint8_t x_6; 
x_6 = 2;
return x_6;
}
else
{
uint8_t x_7; 
x_7 = 1;
return x_7;
}
}
else
{
uint8_t x_8; 
x_8 = 0;
return x_8;
}
}
}
LEAN_EXPORT lean_object* lp_padctl_StickMode_ofNat___boxed(lean_object* x_1) {
_start:
{
uint8_t x_2; lean_object* x_3; 
x_2 = lp_padctl_StickMode_ofNat(x_1);
lean_dec(x_1);
x_3 = lean_box(x_2);
return x_3;
}
}
LEAN_EXPORT uint8_t lp_padctl_instDecidableEqStickMode(uint8_t x_1, uint8_t x_2) {
_start:
{
lean_object* x_3; lean_object* x_4; uint8_t x_5; 
x_3 = lp_padctl_StickMode_ctorIdx(x_1);
x_4 = lp_padctl_StickMode_ctorIdx(x_2);
x_5 = lean_nat_dec_eq(x_3, x_4);
lean_dec(x_4);
lean_dec(x_3);
return x_5;
}
}
LEAN_EXPORT lean_object* lp_padctl_instDecidableEqStickMode___boxed(lean_object* x_1, lean_object* x_2) {
_start:
{
uint8_t x_3; uint8_t x_4; uint8_t x_5; lean_object* x_6; 
x_3 = lean_unbox(x_1);
x_4 = lean_unbox(x_2);
x_5 = lp_padctl_instDecidableEqStickMode(x_3, x_4);
x_6 = lean_box(x_5);
return x_6;
}
}
LEAN_EXPORT lean_object* lp_padctl_instReprStickMode_repr(uint8_t x_1, lean_object* x_2) {
_start:
{
lean_object* x_3; lean_object* x_10; lean_object* x_17; 
switch (x_1) {
case 0:
{
lean_object* x_24; uint8_t x_25; 
x_24 = lean_unsigned_to_nat(1024u);
x_25 = lean_nat_dec_le(x_24, x_2);
if (x_25 == 0)
{
lean_object* x_26; 
x_26 = lean_obj_once(&lp_padctl_instReprAuxEvent_repr___closed__3, &lp_padctl_instReprAuxEvent_repr___closed__3_once, _init_lp_padctl_instReprAuxEvent_repr___closed__3);
x_3 = x_26;
goto block_9;
}
else
{
lean_object* x_27; 
x_27 = lean_obj_once(&lp_padctl_instReprAuxEvent_repr___closed__4, &lp_padctl_instReprAuxEvent_repr___closed__4_once, _init_lp_padctl_instReprAuxEvent_repr___closed__4);
x_3 = x_27;
goto block_9;
}
}
case 1:
{
lean_object* x_28; uint8_t x_29; 
x_28 = lean_unsigned_to_nat(1024u);
x_29 = lean_nat_dec_le(x_28, x_2);
if (x_29 == 0)
{
lean_object* x_30; 
x_30 = lean_obj_once(&lp_padctl_instReprAuxEvent_repr___closed__3, &lp_padctl_instReprAuxEvent_repr___closed__3_once, _init_lp_padctl_instReprAuxEvent_repr___closed__3);
x_10 = x_30;
goto block_16;
}
else
{
lean_object* x_31; 
x_31 = lean_obj_once(&lp_padctl_instReprAuxEvent_repr___closed__4, &lp_padctl_instReprAuxEvent_repr___closed__4_once, _init_lp_padctl_instReprAuxEvent_repr___closed__4);
x_10 = x_31;
goto block_16;
}
}
default: 
{
lean_object* x_32; uint8_t x_33; 
x_32 = lean_unsigned_to_nat(1024u);
x_33 = lean_nat_dec_le(x_32, x_2);
if (x_33 == 0)
{
lean_object* x_34; 
x_34 = lean_obj_once(&lp_padctl_instReprAuxEvent_repr___closed__3, &lp_padctl_instReprAuxEvent_repr___closed__3_once, _init_lp_padctl_instReprAuxEvent_repr___closed__3);
x_17 = x_34;
goto block_23;
}
else
{
lean_object* x_35; 
x_35 = lean_obj_once(&lp_padctl_instReprAuxEvent_repr___closed__4, &lp_padctl_instReprAuxEvent_repr___closed__4_once, _init_lp_padctl_instReprAuxEvent_repr___closed__4);
x_17 = x_35;
goto block_23;
}
}
}
block_9:
{
lean_object* x_4; lean_object* x_5; uint8_t x_6; lean_object* x_7; lean_object* x_8; 
x_4 = ((lean_object*)(lp_padctl_instReprStickMode_repr___closed__1));
x_5 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_5, 0, x_3);
lean_ctor_set(x_5, 1, x_4);
x_6 = 0;
x_7 = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(x_7, 0, x_5);
lean_ctor_set_uint8(x_7, sizeof(void*)*1, x_6);
x_8 = l_Repr_addAppParen(x_7, x_2);
return x_8;
}
block_16:
{
lean_object* x_11; lean_object* x_12; uint8_t x_13; lean_object* x_14; lean_object* x_15; 
x_11 = ((lean_object*)(lp_padctl_instReprStickMode_repr___closed__3));
x_12 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_12, 0, x_10);
lean_ctor_set(x_12, 1, x_11);
x_13 = 0;
x_14 = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(x_14, 0, x_12);
lean_ctor_set_uint8(x_14, sizeof(void*)*1, x_13);
x_15 = l_Repr_addAppParen(x_14, x_2);
return x_15;
}
block_23:
{
lean_object* x_18; lean_object* x_19; uint8_t x_20; lean_object* x_21; lean_object* x_22; 
x_18 = ((lean_object*)(lp_padctl_instReprStickMode_repr___closed__5));
x_19 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_19, 0, x_17);
lean_ctor_set(x_19, 1, x_18);
x_20 = 0;
x_21 = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(x_21, 0, x_19);
lean_ctor_set_uint8(x_21, sizeof(void*)*1, x_20);
x_22 = l_Repr_addAppParen(x_21, x_2);
return x_22;
}
}
}
LEAN_EXPORT lean_object* lp_padctl_instReprStickMode_repr___boxed(lean_object* x_1, lean_object* x_2) {
_start:
{
uint8_t x_3; lean_object* x_4; 
x_3 = lean_unbox(x_1);
x_4 = lp_padctl_instReprStickMode_repr(x_3, x_2);
lean_dec(x_2);
return x_4;
}
}
LEAN_EXPORT uint8_t lp_padctl_checkStickSuppressGamepad(uint8_t x_1) {
_start:
{
if (x_1 == 0)
{
uint8_t x_2; 
x_2 = 0;
return x_2;
}
else
{
uint8_t x_3; 
x_3 = 1;
return x_3;
}
}
}
LEAN_EXPORT lean_object* lp_padctl_checkStickSuppressGamepad___boxed(lean_object* x_1) {
_start:
{
uint8_t x_2; uint8_t x_3; lean_object* x_4; 
x_2 = lean_unbox(x_1);
x_3 = lp_padctl_checkStickSuppressGamepad(x_2);
x_4 = lean_box(x_3);
return x_4;
}
}
LEAN_EXPORT lean_object* lp_padctl_MacroStep_ctorIdx(lean_object* x_1) {
_start:
{
switch (lean_obj_tag(x_1)) {
case 0:
{
lean_object* x_2; 
x_2 = lean_unsigned_to_nat(0u);
return x_2;
}
case 1:
{
lean_object* x_3; 
x_3 = lean_unsigned_to_nat(1u);
return x_3;
}
case 2:
{
lean_object* x_4; 
x_4 = lean_unsigned_to_nat(2u);
return x_4;
}
case 3:
{
lean_object* x_5; 
x_5 = lean_unsigned_to_nat(3u);
return x_5;
}
default: 
{
lean_object* x_6; 
x_6 = lean_unsigned_to_nat(4u);
return x_6;
}
}
}
}
LEAN_EXPORT lean_object* lp_padctl_MacroStep_ctorIdx___boxed(lean_object* x_1) {
_start:
{
lean_object* x_2; 
x_2 = lp_padctl_MacroStep_ctorIdx(x_1);
lean_dec(x_1);
return x_2;
}
}
LEAN_EXPORT lean_object* lp_padctl_MacroStep_ctorElim___redArg(lean_object* x_1, lean_object* x_2) {
_start:
{
if (lean_obj_tag(x_1) == 4)
{
return x_2;
}
else
{
lean_object* x_3; lean_object* x_4; 
x_3 = lean_ctor_get(x_1, 0);
lean_inc(x_3);
lean_dec(x_1);
x_4 = lean_apply_1(x_2, x_3);
return x_4;
}
}
}
LEAN_EXPORT lean_object* lp_padctl_MacroStep_ctorElim(lean_object* x_1, lean_object* x_2, lean_object* x_3, lean_object* x_4, lean_object* x_5) {
_start:
{
lean_object* x_6; 
x_6 = lp_padctl_MacroStep_ctorElim___redArg(x_3, x_5);
return x_6;
}
}
LEAN_EXPORT lean_object* lp_padctl_MacroStep_ctorElim___boxed(lean_object* x_1, lean_object* x_2, lean_object* x_3, lean_object* x_4, lean_object* x_5) {
_start:
{
lean_object* x_6; 
x_6 = lp_padctl_MacroStep_ctorElim(x_1, x_2, x_3, x_4, x_5);
lean_dec(x_2);
return x_6;
}
}
LEAN_EXPORT lean_object* lp_padctl_MacroStep_tap_elim___redArg(lean_object* x_1, lean_object* x_2) {
_start:
{
lean_object* x_3; 
x_3 = lp_padctl_MacroStep_ctorElim___redArg(x_1, x_2);
return x_3;
}
}
LEAN_EXPORT lean_object* lp_padctl_MacroStep_tap_elim(lean_object* x_1, lean_object* x_2, lean_object* x_3, lean_object* x_4) {
_start:
{
lean_object* x_5; 
x_5 = lp_padctl_MacroStep_ctorElim___redArg(x_2, x_4);
return x_5;
}
}
LEAN_EXPORT lean_object* lp_padctl_MacroStep_down_elim___redArg(lean_object* x_1, lean_object* x_2) {
_start:
{
lean_object* x_3; 
x_3 = lp_padctl_MacroStep_ctorElim___redArg(x_1, x_2);
return x_3;
}
}
LEAN_EXPORT lean_object* lp_padctl_MacroStep_down_elim(lean_object* x_1, lean_object* x_2, lean_object* x_3, lean_object* x_4) {
_start:
{
lean_object* x_5; 
x_5 = lp_padctl_MacroStep_ctorElim___redArg(x_2, x_4);
return x_5;
}
}
LEAN_EXPORT lean_object* lp_padctl_MacroStep_up_elim___redArg(lean_object* x_1, lean_object* x_2) {
_start:
{
lean_object* x_3; 
x_3 = lp_padctl_MacroStep_ctorElim___redArg(x_1, x_2);
return x_3;
}
}
LEAN_EXPORT lean_object* lp_padctl_MacroStep_up_elim(lean_object* x_1, lean_object* x_2, lean_object* x_3, lean_object* x_4) {
_start:
{
lean_object* x_5; 
x_5 = lp_padctl_MacroStep_ctorElim___redArg(x_2, x_4);
return x_5;
}
}
LEAN_EXPORT lean_object* lp_padctl_MacroStep_delay_elim___redArg(lean_object* x_1, lean_object* x_2) {
_start:
{
lean_object* x_3; 
x_3 = lp_padctl_MacroStep_ctorElim___redArg(x_1, x_2);
return x_3;
}
}
LEAN_EXPORT lean_object* lp_padctl_MacroStep_delay_elim(lean_object* x_1, lean_object* x_2, lean_object* x_3, lean_object* x_4) {
_start:
{
lean_object* x_5; 
x_5 = lp_padctl_MacroStep_ctorElim___redArg(x_2, x_4);
return x_5;
}
}
LEAN_EXPORT lean_object* lp_padctl_MacroStep_pauseForRelease_elim___redArg(lean_object* x_1, lean_object* x_2) {
_start:
{
lean_object* x_3; 
x_3 = lp_padctl_MacroStep_ctorElim___redArg(x_1, x_2);
return x_3;
}
}
LEAN_EXPORT lean_object* lp_padctl_MacroStep_pauseForRelease_elim(lean_object* x_1, lean_object* x_2, lean_object* x_3, lean_object* x_4) {
_start:
{
lean_object* x_5; 
x_5 = lp_padctl_MacroStep_ctorElim___redArg(x_2, x_4);
return x_5;
}
}
LEAN_EXPORT uint8_t lp_padctl_instDecidableEqMacroStep_decEq(lean_object* x_1, lean_object* x_2) {
_start:
{
switch (lean_obj_tag(x_1)) {
case 0:
{
lean_object* x_3; uint8_t x_4; 
x_3 = lean_ctor_get(x_1, 0);
x_4 = 0;
switch (lean_obj_tag(x_2)) {
case 0:
{
lean_object* x_5; uint8_t x_6; 
x_5 = lean_ctor_get(x_2, 0);
x_6 = lean_nat_dec_eq(x_3, x_5);
if (x_6 == 0)
{
return x_4;
}
else
{
return x_6;
}
}
case 4:
{
return x_4;
}
default: 
{
return x_4;
}
}
}
case 1:
{
lean_object* x_7; uint8_t x_8; 
x_7 = lean_ctor_get(x_1, 0);
x_8 = 0;
switch (lean_obj_tag(x_2)) {
case 1:
{
lean_object* x_9; uint8_t x_10; 
x_9 = lean_ctor_get(x_2, 0);
x_10 = lean_nat_dec_eq(x_7, x_9);
if (x_10 == 0)
{
return x_8;
}
else
{
return x_10;
}
}
case 4:
{
return x_8;
}
default: 
{
return x_8;
}
}
}
case 2:
{
lean_object* x_11; uint8_t x_12; 
x_11 = lean_ctor_get(x_1, 0);
x_12 = 0;
switch (lean_obj_tag(x_2)) {
case 2:
{
lean_object* x_13; uint8_t x_14; 
x_13 = lean_ctor_get(x_2, 0);
x_14 = lean_nat_dec_eq(x_11, x_13);
if (x_14 == 0)
{
return x_12;
}
else
{
return x_14;
}
}
case 4:
{
return x_12;
}
default: 
{
return x_12;
}
}
}
case 3:
{
lean_object* x_15; uint8_t x_16; 
x_15 = lean_ctor_get(x_1, 0);
x_16 = 0;
switch (lean_obj_tag(x_2)) {
case 3:
{
lean_object* x_17; uint8_t x_18; 
x_17 = lean_ctor_get(x_2, 0);
x_18 = lean_nat_dec_eq(x_15, x_17);
if (x_18 == 0)
{
return x_16;
}
else
{
return x_18;
}
}
case 4:
{
return x_16;
}
default: 
{
return x_16;
}
}
}
default: 
{
if (lean_obj_tag(x_2) == 4)
{
uint8_t x_19; 
x_19 = 1;
return x_19;
}
else
{
uint8_t x_20; 
x_20 = 0;
return x_20;
}
}
}
}
}
LEAN_EXPORT lean_object* lp_padctl_instDecidableEqMacroStep_decEq___boxed(lean_object* x_1, lean_object* x_2) {
_start:
{
uint8_t x_3; lean_object* x_4; 
x_3 = lp_padctl_instDecidableEqMacroStep_decEq(x_1, x_2);
lean_dec(x_2);
lean_dec(x_1);
x_4 = lean_box(x_3);
return x_4;
}
}
LEAN_EXPORT uint8_t lp_padctl_instDecidableEqMacroStep(lean_object* x_1, lean_object* x_2) {
_start:
{
uint8_t x_3; 
x_3 = lp_padctl_instDecidableEqMacroStep_decEq(x_1, x_2);
return x_3;
}
}
LEAN_EXPORT lean_object* lp_padctl_instDecidableEqMacroStep___boxed(lean_object* x_1, lean_object* x_2) {
_start:
{
uint8_t x_3; lean_object* x_4; 
x_3 = lp_padctl_instDecidableEqMacroStep(x_1, x_2);
lean_dec(x_2);
lean_dec(x_1);
x_4 = lean_box(x_3);
return x_4;
}
}
LEAN_EXPORT lean_object* lp_padctl_instReprMacroStep_repr(lean_object* x_1, lean_object* x_2) {
_start:
{
lean_object* x_3; 
switch (lean_obj_tag(x_1)) {
case 0:
{
lean_object* x_10; lean_object* x_11; lean_object* x_12; lean_object* x_22; uint8_t x_23; 
x_10 = lean_ctor_get(x_1, 0);
lean_inc(x_10);
if (lean_is_exclusive(x_1)) {
 lean_ctor_release(x_1, 0);
 x_11 = x_1;
} else {
 lean_dec_ref(x_1);
 x_11 = lean_box(0);
}
x_22 = lean_unsigned_to_nat(1024u);
x_23 = lean_nat_dec_le(x_22, x_2);
if (x_23 == 0)
{
lean_object* x_24; 
x_24 = lean_obj_once(&lp_padctl_instReprAuxEvent_repr___closed__3, &lp_padctl_instReprAuxEvent_repr___closed__3_once, _init_lp_padctl_instReprAuxEvent_repr___closed__3);
x_12 = x_24;
goto block_21;
}
else
{
lean_object* x_25; 
x_25 = lean_obj_once(&lp_padctl_instReprAuxEvent_repr___closed__4, &lp_padctl_instReprAuxEvent_repr___closed__4_once, _init_lp_padctl_instReprAuxEvent_repr___closed__4);
x_12 = x_25;
goto block_21;
}
block_21:
{
lean_object* x_13; lean_object* x_14; lean_object* x_15; lean_object* x_16; lean_object* x_17; uint8_t x_18; lean_object* x_19; lean_object* x_20; 
x_13 = ((lean_object*)(lp_padctl_instReprMacroStep_repr___closed__4));
x_14 = l_Nat_reprFast(x_10);
if (lean_is_scalar(x_11)) {
 x_15 = lean_alloc_ctor(3, 1, 0);
} else {
 x_15 = x_11;
 lean_ctor_set_tag(x_15, 3);
}
lean_ctor_set(x_15, 0, x_14);
x_16 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_16, 0, x_13);
lean_ctor_set(x_16, 1, x_15);
x_17 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_17, 0, x_12);
lean_ctor_set(x_17, 1, x_16);
x_18 = 0;
x_19 = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(x_19, 0, x_17);
lean_ctor_set_uint8(x_19, sizeof(void*)*1, x_18);
x_20 = l_Repr_addAppParen(x_19, x_2);
return x_20;
}
}
case 1:
{
lean_object* x_26; lean_object* x_27; lean_object* x_28; lean_object* x_38; uint8_t x_39; 
x_26 = lean_ctor_get(x_1, 0);
lean_inc(x_26);
if (lean_is_exclusive(x_1)) {
 lean_ctor_release(x_1, 0);
 x_27 = x_1;
} else {
 lean_dec_ref(x_1);
 x_27 = lean_box(0);
}
x_38 = lean_unsigned_to_nat(1024u);
x_39 = lean_nat_dec_le(x_38, x_2);
if (x_39 == 0)
{
lean_object* x_40; 
x_40 = lean_obj_once(&lp_padctl_instReprAuxEvent_repr___closed__3, &lp_padctl_instReprAuxEvent_repr___closed__3_once, _init_lp_padctl_instReprAuxEvent_repr___closed__3);
x_28 = x_40;
goto block_37;
}
else
{
lean_object* x_41; 
x_41 = lean_obj_once(&lp_padctl_instReprAuxEvent_repr___closed__4, &lp_padctl_instReprAuxEvent_repr___closed__4_once, _init_lp_padctl_instReprAuxEvent_repr___closed__4);
x_28 = x_41;
goto block_37;
}
block_37:
{
lean_object* x_29; lean_object* x_30; lean_object* x_31; lean_object* x_32; lean_object* x_33; uint8_t x_34; lean_object* x_35; lean_object* x_36; 
x_29 = ((lean_object*)(lp_padctl_instReprMacroStep_repr___closed__7));
x_30 = l_Nat_reprFast(x_26);
if (lean_is_scalar(x_27)) {
 x_31 = lean_alloc_ctor(3, 1, 0);
} else {
 x_31 = x_27;
 lean_ctor_set_tag(x_31, 3);
}
lean_ctor_set(x_31, 0, x_30);
x_32 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_32, 0, x_29);
lean_ctor_set(x_32, 1, x_31);
x_33 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_33, 0, x_28);
lean_ctor_set(x_33, 1, x_32);
x_34 = 0;
x_35 = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(x_35, 0, x_33);
lean_ctor_set_uint8(x_35, sizeof(void*)*1, x_34);
x_36 = l_Repr_addAppParen(x_35, x_2);
return x_36;
}
}
case 2:
{
lean_object* x_42; lean_object* x_43; lean_object* x_44; lean_object* x_54; uint8_t x_55; 
x_42 = lean_ctor_get(x_1, 0);
lean_inc(x_42);
if (lean_is_exclusive(x_1)) {
 lean_ctor_release(x_1, 0);
 x_43 = x_1;
} else {
 lean_dec_ref(x_1);
 x_43 = lean_box(0);
}
x_54 = lean_unsigned_to_nat(1024u);
x_55 = lean_nat_dec_le(x_54, x_2);
if (x_55 == 0)
{
lean_object* x_56; 
x_56 = lean_obj_once(&lp_padctl_instReprAuxEvent_repr___closed__3, &lp_padctl_instReprAuxEvent_repr___closed__3_once, _init_lp_padctl_instReprAuxEvent_repr___closed__3);
x_44 = x_56;
goto block_53;
}
else
{
lean_object* x_57; 
x_57 = lean_obj_once(&lp_padctl_instReprAuxEvent_repr___closed__4, &lp_padctl_instReprAuxEvent_repr___closed__4_once, _init_lp_padctl_instReprAuxEvent_repr___closed__4);
x_44 = x_57;
goto block_53;
}
block_53:
{
lean_object* x_45; lean_object* x_46; lean_object* x_47; lean_object* x_48; lean_object* x_49; uint8_t x_50; lean_object* x_51; lean_object* x_52; 
x_45 = ((lean_object*)(lp_padctl_instReprMacroStep_repr___closed__10));
x_46 = l_Nat_reprFast(x_42);
if (lean_is_scalar(x_43)) {
 x_47 = lean_alloc_ctor(3, 1, 0);
} else {
 x_47 = x_43;
 lean_ctor_set_tag(x_47, 3);
}
lean_ctor_set(x_47, 0, x_46);
x_48 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_48, 0, x_45);
lean_ctor_set(x_48, 1, x_47);
x_49 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_49, 0, x_44);
lean_ctor_set(x_49, 1, x_48);
x_50 = 0;
x_51 = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(x_51, 0, x_49);
lean_ctor_set_uint8(x_51, sizeof(void*)*1, x_50);
x_52 = l_Repr_addAppParen(x_51, x_2);
return x_52;
}
}
case 3:
{
lean_object* x_58; lean_object* x_59; lean_object* x_60; lean_object* x_70; uint8_t x_71; 
x_58 = lean_ctor_get(x_1, 0);
lean_inc(x_58);
if (lean_is_exclusive(x_1)) {
 lean_ctor_release(x_1, 0);
 x_59 = x_1;
} else {
 lean_dec_ref(x_1);
 x_59 = lean_box(0);
}
x_70 = lean_unsigned_to_nat(1024u);
x_71 = lean_nat_dec_le(x_70, x_2);
if (x_71 == 0)
{
lean_object* x_72; 
x_72 = lean_obj_once(&lp_padctl_instReprAuxEvent_repr___closed__3, &lp_padctl_instReprAuxEvent_repr___closed__3_once, _init_lp_padctl_instReprAuxEvent_repr___closed__3);
x_60 = x_72;
goto block_69;
}
else
{
lean_object* x_73; 
x_73 = lean_obj_once(&lp_padctl_instReprAuxEvent_repr___closed__4, &lp_padctl_instReprAuxEvent_repr___closed__4_once, _init_lp_padctl_instReprAuxEvent_repr___closed__4);
x_60 = x_73;
goto block_69;
}
block_69:
{
lean_object* x_61; lean_object* x_62; lean_object* x_63; lean_object* x_64; lean_object* x_65; uint8_t x_66; lean_object* x_67; lean_object* x_68; 
x_61 = ((lean_object*)(lp_padctl_instReprMacroStep_repr___closed__13));
x_62 = l_Nat_reprFast(x_58);
if (lean_is_scalar(x_59)) {
 x_63 = lean_alloc_ctor(3, 1, 0);
} else {
 x_63 = x_59;
}
lean_ctor_set(x_63, 0, x_62);
x_64 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_64, 0, x_61);
lean_ctor_set(x_64, 1, x_63);
x_65 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_65, 0, x_60);
lean_ctor_set(x_65, 1, x_64);
x_66 = 0;
x_67 = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(x_67, 0, x_65);
lean_ctor_set_uint8(x_67, sizeof(void*)*1, x_66);
x_68 = l_Repr_addAppParen(x_67, x_2);
return x_68;
}
}
default: 
{
lean_object* x_74; uint8_t x_75; 
x_74 = lean_unsigned_to_nat(1024u);
x_75 = lean_nat_dec_le(x_74, x_2);
if (x_75 == 0)
{
lean_object* x_76; 
x_76 = lean_obj_once(&lp_padctl_instReprAuxEvent_repr___closed__3, &lp_padctl_instReprAuxEvent_repr___closed__3_once, _init_lp_padctl_instReprAuxEvent_repr___closed__3);
x_3 = x_76;
goto block_9;
}
else
{
lean_object* x_77; 
x_77 = lean_obj_once(&lp_padctl_instReprAuxEvent_repr___closed__4, &lp_padctl_instReprAuxEvent_repr___closed__4_once, _init_lp_padctl_instReprAuxEvent_repr___closed__4);
x_3 = x_77;
goto block_9;
}
}
}
block_9:
{
lean_object* x_4; lean_object* x_5; uint8_t x_6; lean_object* x_7; lean_object* x_8; 
x_4 = ((lean_object*)(lp_padctl_instReprMacroStep_repr___closed__1));
x_5 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_5, 0, x_3);
lean_ctor_set(x_5, 1, x_4);
x_6 = 0;
x_7 = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(x_7, 0, x_5);
lean_ctor_set_uint8(x_7, sizeof(void*)*1, x_6);
x_8 = l_Repr_addAppParen(x_7, x_2);
return x_8;
}
}
}
LEAN_EXPORT lean_object* lp_padctl_instReprMacroStep_repr___boxed(lean_object* x_1, lean_object* x_2) {
_start:
{
lean_object* x_3; 
x_3 = lp_padctl_instReprMacroStep_repr(x_1, x_2);
lean_dec(x_2);
return x_3;
}
}
LEAN_EXPORT uint8_t lp_padctl_instDecidableEqMacroState_decEq(lean_object* x_1, lean_object* x_2) {
_start:
{
uint8_t x_3; lean_object* x_4; lean_object* x_5; lean_object* x_6; lean_object* x_7; uint8_t x_8; uint8_t x_9; lean_object* x_10; lean_object* x_11; lean_object* x_12; lean_object* x_13; uint8_t x_14; 
x_3 = lean_ctor_get_uint8(x_1, sizeof(void*)*4);
x_4 = lean_ctor_get(x_1, 0);
lean_inc(x_4);
x_5 = lean_ctor_get(x_1, 1);
lean_inc(x_5);
x_6 = lean_ctor_get(x_1, 2);
lean_inc(x_6);
x_7 = lean_ctor_get(x_1, 3);
lean_inc(x_7);
x_8 = lean_ctor_get_uint8(x_1, sizeof(void*)*4 + 1);
lean_dec_ref(x_1);
x_9 = lean_ctor_get_uint8(x_2, sizeof(void*)*4);
x_10 = lean_ctor_get(x_2, 0);
lean_inc(x_10);
x_11 = lean_ctor_get(x_2, 1);
lean_inc(x_11);
x_12 = lean_ctor_get(x_2, 2);
lean_inc(x_12);
x_13 = lean_ctor_get(x_2, 3);
lean_inc(x_13);
x_14 = lean_ctor_get_uint8(x_2, sizeof(void*)*4 + 1);
lean_dec_ref(x_2);
if (x_3 == 0)
{
if (x_9 == 0)
{
goto block_21;
}
else
{
lean_dec(x_13);
lean_dec(x_12);
lean_dec(x_11);
lean_dec(x_10);
lean_dec(x_7);
lean_dec(x_6);
lean_dec(x_5);
lean_dec(x_4);
return x_3;
}
}
else
{
if (x_9 == 0)
{
lean_dec(x_13);
lean_dec(x_12);
lean_dec(x_11);
lean_dec(x_10);
lean_dec(x_7);
lean_dec(x_6);
lean_dec(x_5);
lean_dec(x_4);
return x_9;
}
else
{
goto block_21;
}
}
block_21:
{
lean_object* x_15; uint8_t x_16; 
x_15 = lean_alloc_closure((void*)(l_instDecidableEqNat___boxed), 2, 0);
lean_inc_ref(x_15);
x_16 = l_instDecidableEqList___redArg(x_15, x_4, x_10);
if (x_16 == 0)
{
lean_dec_ref(x_15);
lean_dec(x_13);
lean_dec(x_12);
lean_dec(x_11);
lean_dec(x_7);
lean_dec(x_6);
lean_dec(x_5);
return x_16;
}
else
{
lean_object* x_17; uint8_t x_18; 
x_17 = lean_alloc_closure((void*)(lp_padctl_instDecidableEqMacroStep___boxed), 2, 0);
x_18 = l_instDecidableEqList___redArg(x_17, x_5, x_11);
if (x_18 == 0)
{
lean_dec_ref(x_15);
lean_dec(x_13);
lean_dec(x_12);
lean_dec(x_7);
lean_dec(x_6);
return x_18;
}
else
{
uint8_t x_19; 
x_19 = lean_nat_dec_eq(x_6, x_12);
lean_dec(x_12);
lean_dec(x_6);
if (x_19 == 0)
{
lean_dec_ref(x_15);
lean_dec(x_13);
lean_dec(x_7);
return x_19;
}
else
{
uint8_t x_20; 
x_20 = l_Option_instDecidableEq___redArg(x_15, x_7, x_13);
if (x_20 == 0)
{
return x_20;
}
else
{
if (x_8 == 0)
{
if (x_14 == 0)
{
return x_20;
}
else
{
return x_8;
}
}
else
{
return x_14;
}
}
}
}
}
}
}
}
LEAN_EXPORT lean_object* lp_padctl_instDecidableEqMacroState_decEq___boxed(lean_object* x_1, lean_object* x_2) {
_start:
{
uint8_t x_3; lean_object* x_4; 
x_3 = lp_padctl_instDecidableEqMacroState_decEq(x_1, x_2);
x_4 = lean_box(x_3);
return x_4;
}
}
LEAN_EXPORT uint8_t lp_padctl_instDecidableEqMacroState(lean_object* x_1, lean_object* x_2) {
_start:
{
uint8_t x_3; 
x_3 = lp_padctl_instDecidableEqMacroState_decEq(x_1, x_2);
return x_3;
}
}
LEAN_EXPORT lean_object* lp_padctl_instDecidableEqMacroState___boxed(lean_object* x_1, lean_object* x_2) {
_start:
{
uint8_t x_3; lean_object* x_4; 
x_3 = lp_padctl_instDecidableEqMacroState(x_1, x_2);
x_4 = lean_box(x_3);
return x_4;
}
}
LEAN_EXPORT lean_object* lp_padctl_List_foldl___at___00List_foldl___at___00Std_Format_joinSep___at___00List_repr___at___00instReprMacroState_repr_spec__1_spec__2_spec__4_spec__6(lean_object* x_1, lean_object* x_2, lean_object* x_3) {
_start:
{
if (lean_obj_tag(x_3) == 0)
{
lean_dec(x_1);
return x_2;
}
else
{
uint8_t x_4; 
x_4 = !lean_is_exclusive(x_3);
if (x_4 == 0)
{
lean_object* x_5; lean_object* x_6; lean_object* x_7; lean_object* x_8; lean_object* x_9; 
x_5 = lean_ctor_get(x_3, 0);
x_6 = lean_ctor_get(x_3, 1);
lean_inc(x_1);
lean_ctor_set_tag(x_3, 5);
lean_ctor_set(x_3, 1, x_1);
lean_ctor_set(x_3, 0, x_2);
x_7 = lean_unsigned_to_nat(0u);
x_8 = lp_padctl_instReprMacroStep_repr(x_5, x_7);
x_9 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_9, 0, x_3);
lean_ctor_set(x_9, 1, x_8);
x_2 = x_9;
x_3 = x_6;
goto _start;
}
else
{
lean_object* x_11; lean_object* x_12; lean_object* x_13; lean_object* x_14; lean_object* x_15; lean_object* x_16; 
x_11 = lean_ctor_get(x_3, 0);
x_12 = lean_ctor_get(x_3, 1);
lean_inc(x_12);
lean_inc(x_11);
lean_dec(x_3);
lean_inc(x_1);
x_13 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_13, 0, x_2);
lean_ctor_set(x_13, 1, x_1);
x_14 = lean_unsigned_to_nat(0u);
x_15 = lp_padctl_instReprMacroStep_repr(x_11, x_14);
x_16 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_16, 0, x_13);
lean_ctor_set(x_16, 1, x_15);
x_2 = x_16;
x_3 = x_12;
goto _start;
}
}
}
}
LEAN_EXPORT lean_object* lp_padctl_List_foldl___at___00Std_Format_joinSep___at___00List_repr___at___00instReprMacroState_repr_spec__1_spec__2_spec__4(lean_object* x_1, lean_object* x_2, lean_object* x_3) {
_start:
{
if (lean_obj_tag(x_3) == 0)
{
lean_dec(x_1);
return x_2;
}
else
{
uint8_t x_4; 
x_4 = !lean_is_exclusive(x_3);
if (x_4 == 0)
{
lean_object* x_5; lean_object* x_6; lean_object* x_7; lean_object* x_8; lean_object* x_9; lean_object* x_10; 
x_5 = lean_ctor_get(x_3, 0);
x_6 = lean_ctor_get(x_3, 1);
lean_inc(x_1);
lean_ctor_set_tag(x_3, 5);
lean_ctor_set(x_3, 1, x_1);
lean_ctor_set(x_3, 0, x_2);
x_7 = lean_unsigned_to_nat(0u);
x_8 = lp_padctl_instReprMacroStep_repr(x_5, x_7);
x_9 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_9, 0, x_3);
lean_ctor_set(x_9, 1, x_8);
x_10 = lp_padctl_List_foldl___at___00List_foldl___at___00Std_Format_joinSep___at___00List_repr___at___00instReprMacroState_repr_spec__1_spec__2_spec__4_spec__6(x_1, x_9, x_6);
return x_10;
}
else
{
lean_object* x_11; lean_object* x_12; lean_object* x_13; lean_object* x_14; lean_object* x_15; lean_object* x_16; lean_object* x_17; 
x_11 = lean_ctor_get(x_3, 0);
x_12 = lean_ctor_get(x_3, 1);
lean_inc(x_12);
lean_inc(x_11);
lean_dec(x_3);
lean_inc(x_1);
x_13 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_13, 0, x_2);
lean_ctor_set(x_13, 1, x_1);
x_14 = lean_unsigned_to_nat(0u);
x_15 = lp_padctl_instReprMacroStep_repr(x_11, x_14);
x_16 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_16, 0, x_13);
lean_ctor_set(x_16, 1, x_15);
x_17 = lp_padctl_List_foldl___at___00List_foldl___at___00Std_Format_joinSep___at___00List_repr___at___00instReprMacroState_repr_spec__1_spec__2_spec__4_spec__6(x_1, x_16, x_12);
return x_17;
}
}
}
}
LEAN_EXPORT lean_object* lp_padctl_Std_Format_joinSep___at___00List_repr___at___00instReprMacroState_repr_spec__1_spec__2___lam__0(lean_object* x_1) {
_start:
{
lean_object* x_2; lean_object* x_3; 
x_2 = lean_unsigned_to_nat(0u);
x_3 = lp_padctl_instReprMacroStep_repr(x_1, x_2);
return x_3;
}
}
LEAN_EXPORT lean_object* lp_padctl_Std_Format_joinSep___at___00List_repr___at___00instReprMacroState_repr_spec__1_spec__2(lean_object* x_1, lean_object* x_2) {
_start:
{
if (lean_obj_tag(x_1) == 0)
{
lean_object* x_3; 
lean_dec(x_2);
x_3 = lean_box(0);
return x_3;
}
else
{
lean_object* x_4; 
x_4 = lean_ctor_get(x_1, 1);
if (lean_obj_tag(x_4) == 0)
{
lean_object* x_5; lean_object* x_6; 
lean_dec(x_2);
x_5 = lean_ctor_get(x_1, 0);
lean_inc(x_5);
lean_dec_ref(x_1);
x_6 = lp_padctl_Std_Format_joinSep___at___00List_repr___at___00instReprMacroState_repr_spec__1_spec__2___lam__0(x_5);
return x_6;
}
else
{
lean_object* x_7; lean_object* x_8; lean_object* x_9; 
lean_inc(x_4);
x_7 = lean_ctor_get(x_1, 0);
lean_inc(x_7);
lean_dec_ref(x_1);
x_8 = lp_padctl_Std_Format_joinSep___at___00List_repr___at___00instReprMacroState_repr_spec__1_spec__2___lam__0(x_7);
x_9 = lp_padctl_List_foldl___at___00Std_Format_joinSep___at___00List_repr___at___00instReprMacroState_repr_spec__1_spec__2_spec__4(x_2, x_8, x_4);
return x_9;
}
}
}
}
static lean_object* _init_lp_padctl_List_repr___at___00instReprMacroState_repr_spec__1___redArg___closed__5(void) {
_start:
{
lean_object* x_1; lean_object* x_2; 
x_1 = ((lean_object*)(lp_padctl_List_repr___at___00instReprMacroState_repr_spec__1___redArg___closed__2));
x_2 = lean_string_length(x_1);
return x_2;
}
}
static lean_object* _init_lp_padctl_List_repr___at___00instReprMacroState_repr_spec__1___redArg___closed__6(void) {
_start:
{
lean_object* x_1; lean_object* x_2; 
x_1 = lean_obj_once(&lp_padctl_List_repr___at___00instReprMacroState_repr_spec__1___redArg___closed__5, &lp_padctl_List_repr___at___00instReprMacroState_repr_spec__1___redArg___closed__5_once, _init_lp_padctl_List_repr___at___00instReprMacroState_repr_spec__1___redArg___closed__5);
x_2 = lean_nat_to_int(x_1);
return x_2;
}
}
LEAN_EXPORT lean_object* lp_padctl_List_repr___at___00instReprMacroState_repr_spec__1___redArg(lean_object* x_1) {
_start:
{
if (lean_obj_tag(x_1) == 0)
{
lean_object* x_2; 
x_2 = ((lean_object*)(lp_padctl_List_repr___at___00instReprMacroState_repr_spec__1___redArg___closed__1));
return x_2;
}
else
{
lean_object* x_3; lean_object* x_4; lean_object* x_5; lean_object* x_6; lean_object* x_7; lean_object* x_8; lean_object* x_9; lean_object* x_10; uint8_t x_11; lean_object* x_12; 
x_3 = ((lean_object*)(lp_padctl_List_repr___at___00instReprMacroState_repr_spec__1___redArg___closed__3));
x_4 = lp_padctl_Std_Format_joinSep___at___00List_repr___at___00instReprMacroState_repr_spec__1_spec__2(x_1, x_3);
x_5 = lean_obj_once(&lp_padctl_List_repr___at___00instReprMacroState_repr_spec__1___redArg___closed__6, &lp_padctl_List_repr___at___00instReprMacroState_repr_spec__1___redArg___closed__6_once, _init_lp_padctl_List_repr___at___00instReprMacroState_repr_spec__1___redArg___closed__6);
x_6 = ((lean_object*)(lp_padctl_List_repr___at___00instReprMacroState_repr_spec__1___redArg___closed__7));
x_7 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_7, 0, x_6);
lean_ctor_set(x_7, 1, x_4);
x_8 = ((lean_object*)(lp_padctl_List_repr___at___00instReprMacroState_repr_spec__1___redArg___closed__8));
x_9 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_9, 0, x_7);
lean_ctor_set(x_9, 1, x_8);
x_10 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_10, 0, x_5);
lean_ctor_set(x_10, 1, x_9);
x_11 = 0;
x_12 = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(x_12, 0, x_10);
lean_ctor_set_uint8(x_12, sizeof(void*)*1, x_11);
return x_12;
}
}
}
LEAN_EXPORT lean_object* lp_padctl_List_foldl___at___00List_foldl___at___00Std_Format_joinSep___at___00List_repr_x27___at___00instReprMacroState_repr_spec__0_spec__0_spec__1_spec__3(lean_object* x_1, lean_object* x_2, lean_object* x_3) {
_start:
{
if (lean_obj_tag(x_3) == 0)
{
lean_dec(x_1);
return x_2;
}
else
{
uint8_t x_4; 
x_4 = !lean_is_exclusive(x_3);
if (x_4 == 0)
{
lean_object* x_5; lean_object* x_6; lean_object* x_7; lean_object* x_8; lean_object* x_9; 
x_5 = lean_ctor_get(x_3, 0);
x_6 = lean_ctor_get(x_3, 1);
lean_inc(x_1);
lean_ctor_set_tag(x_3, 5);
lean_ctor_set(x_3, 1, x_1);
lean_ctor_set(x_3, 0, x_2);
x_7 = l_Nat_reprFast(x_5);
x_8 = lean_alloc_ctor(3, 1, 0);
lean_ctor_set(x_8, 0, x_7);
x_9 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_9, 0, x_3);
lean_ctor_set(x_9, 1, x_8);
x_2 = x_9;
x_3 = x_6;
goto _start;
}
else
{
lean_object* x_11; lean_object* x_12; lean_object* x_13; lean_object* x_14; lean_object* x_15; lean_object* x_16; 
x_11 = lean_ctor_get(x_3, 0);
x_12 = lean_ctor_get(x_3, 1);
lean_inc(x_12);
lean_inc(x_11);
lean_dec(x_3);
lean_inc(x_1);
x_13 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_13, 0, x_2);
lean_ctor_set(x_13, 1, x_1);
x_14 = l_Nat_reprFast(x_11);
x_15 = lean_alloc_ctor(3, 1, 0);
lean_ctor_set(x_15, 0, x_14);
x_16 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_16, 0, x_13);
lean_ctor_set(x_16, 1, x_15);
x_2 = x_16;
x_3 = x_12;
goto _start;
}
}
}
}
LEAN_EXPORT lean_object* lp_padctl_List_foldl___at___00Std_Format_joinSep___at___00List_repr_x27___at___00instReprMacroState_repr_spec__0_spec__0_spec__1(lean_object* x_1, lean_object* x_2, lean_object* x_3) {
_start:
{
if (lean_obj_tag(x_3) == 0)
{
lean_dec(x_1);
return x_2;
}
else
{
uint8_t x_4; 
x_4 = !lean_is_exclusive(x_3);
if (x_4 == 0)
{
lean_object* x_5; lean_object* x_6; lean_object* x_7; lean_object* x_8; lean_object* x_9; lean_object* x_10; 
x_5 = lean_ctor_get(x_3, 0);
x_6 = lean_ctor_get(x_3, 1);
lean_inc(x_1);
lean_ctor_set_tag(x_3, 5);
lean_ctor_set(x_3, 1, x_1);
lean_ctor_set(x_3, 0, x_2);
x_7 = l_Nat_reprFast(x_5);
x_8 = lean_alloc_ctor(3, 1, 0);
lean_ctor_set(x_8, 0, x_7);
x_9 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_9, 0, x_3);
lean_ctor_set(x_9, 1, x_8);
x_10 = lp_padctl_List_foldl___at___00List_foldl___at___00Std_Format_joinSep___at___00List_repr_x27___at___00instReprMacroState_repr_spec__0_spec__0_spec__1_spec__3(x_1, x_9, x_6);
return x_10;
}
else
{
lean_object* x_11; lean_object* x_12; lean_object* x_13; lean_object* x_14; lean_object* x_15; lean_object* x_16; lean_object* x_17; 
x_11 = lean_ctor_get(x_3, 0);
x_12 = lean_ctor_get(x_3, 1);
lean_inc(x_12);
lean_inc(x_11);
lean_dec(x_3);
lean_inc(x_1);
x_13 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_13, 0, x_2);
lean_ctor_set(x_13, 1, x_1);
x_14 = l_Nat_reprFast(x_11);
x_15 = lean_alloc_ctor(3, 1, 0);
lean_ctor_set(x_15, 0, x_14);
x_16 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_16, 0, x_13);
lean_ctor_set(x_16, 1, x_15);
x_17 = lp_padctl_List_foldl___at___00List_foldl___at___00Std_Format_joinSep___at___00List_repr_x27___at___00instReprMacroState_repr_spec__0_spec__0_spec__1_spec__3(x_1, x_16, x_12);
return x_17;
}
}
}
}
LEAN_EXPORT lean_object* lp_padctl_Std_Format_joinSep___at___00List_repr_x27___at___00instReprMacroState_repr_spec__0_spec__0___lam__0(lean_object* x_1) {
_start:
{
lean_object* x_2; lean_object* x_3; 
x_2 = l_Nat_reprFast(x_1);
x_3 = lean_alloc_ctor(3, 1, 0);
lean_ctor_set(x_3, 0, x_2);
return x_3;
}
}
LEAN_EXPORT lean_object* lp_padctl_Std_Format_joinSep___at___00List_repr_x27___at___00instReprMacroState_repr_spec__0_spec__0(lean_object* x_1, lean_object* x_2) {
_start:
{
if (lean_obj_tag(x_1) == 0)
{
lean_object* x_3; 
lean_dec(x_2);
x_3 = lean_box(0);
return x_3;
}
else
{
lean_object* x_4; 
x_4 = lean_ctor_get(x_1, 1);
if (lean_obj_tag(x_4) == 0)
{
lean_object* x_5; lean_object* x_6; 
lean_dec(x_2);
x_5 = lean_ctor_get(x_1, 0);
lean_inc(x_5);
lean_dec_ref(x_1);
x_6 = lp_padctl_Std_Format_joinSep___at___00List_repr_x27___at___00instReprMacroState_repr_spec__0_spec__0___lam__0(x_5);
return x_6;
}
else
{
lean_object* x_7; lean_object* x_8; lean_object* x_9; 
lean_inc(x_4);
x_7 = lean_ctor_get(x_1, 0);
lean_inc(x_7);
lean_dec_ref(x_1);
x_8 = lp_padctl_Std_Format_joinSep___at___00List_repr_x27___at___00instReprMacroState_repr_spec__0_spec__0___lam__0(x_7);
x_9 = lp_padctl_List_foldl___at___00Std_Format_joinSep___at___00List_repr_x27___at___00instReprMacroState_repr_spec__0_spec__0_spec__1(x_2, x_8, x_4);
return x_9;
}
}
}
}
LEAN_EXPORT lean_object* lp_padctl_List_repr_x27___at___00instReprMacroState_repr_spec__0___redArg(lean_object* x_1) {
_start:
{
if (lean_obj_tag(x_1) == 0)
{
lean_object* x_2; 
x_2 = ((lean_object*)(lp_padctl_List_repr___at___00instReprMacroState_repr_spec__1___redArg___closed__1));
return x_2;
}
else
{
lean_object* x_3; lean_object* x_4; lean_object* x_5; lean_object* x_6; lean_object* x_7; lean_object* x_8; lean_object* x_9; lean_object* x_10; lean_object* x_11; 
x_3 = ((lean_object*)(lp_padctl_List_repr___at___00instReprMacroState_repr_spec__1___redArg___closed__3));
x_4 = lp_padctl_Std_Format_joinSep___at___00List_repr_x27___at___00instReprMacroState_repr_spec__0_spec__0(x_1, x_3);
x_5 = lean_obj_once(&lp_padctl_List_repr___at___00instReprMacroState_repr_spec__1___redArg___closed__6, &lp_padctl_List_repr___at___00instReprMacroState_repr_spec__1___redArg___closed__6_once, _init_lp_padctl_List_repr___at___00instReprMacroState_repr_spec__1___redArg___closed__6);
x_6 = ((lean_object*)(lp_padctl_List_repr___at___00instReprMacroState_repr_spec__1___redArg___closed__7));
x_7 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_7, 0, x_6);
lean_ctor_set(x_7, 1, x_4);
x_8 = ((lean_object*)(lp_padctl_List_repr___at___00instReprMacroState_repr_spec__1___redArg___closed__8));
x_9 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_9, 0, x_7);
lean_ctor_set(x_9, 1, x_8);
x_10 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_10, 0, x_5);
lean_ctor_set(x_10, 1, x_9);
x_11 = l_Std_Format_fill(x_10);
return x_11;
}
}
}
static lean_object* _init_lp_padctl_instReprMacroState_repr___redArg___closed__4(void) {
_start:
{
lean_object* x_1; lean_object* x_2; 
x_1 = lean_unsigned_to_nat(10u);
x_2 = lean_nat_to_int(x_1);
return x_2;
}
}
static lean_object* _init_lp_padctl_instReprMacroState_repr___redArg___closed__7(void) {
_start:
{
lean_object* x_1; lean_object* x_2; 
x_1 = lean_unsigned_to_nat(19u);
x_2 = lean_nat_to_int(x_1);
return x_2;
}
}
static lean_object* _init_lp_padctl_instReprMacroState_repr___redArg___closed__14(void) {
_start:
{
lean_object* x_1; lean_object* x_2; 
x_1 = lean_unsigned_to_nat(14u);
x_2 = lean_nat_to_int(x_1);
return x_2;
}
}
LEAN_EXPORT lean_object* lp_padctl_instReprMacroState_repr___redArg(lean_object* x_1) {
_start:
{
uint8_t x_2; lean_object* x_3; lean_object* x_4; lean_object* x_5; lean_object* x_6; uint8_t x_7; lean_object* x_8; lean_object* x_9; lean_object* x_10; lean_object* x_11; lean_object* x_12; lean_object* x_13; uint8_t x_14; lean_object* x_15; lean_object* x_16; lean_object* x_17; lean_object* x_18; lean_object* x_19; lean_object* x_20; lean_object* x_21; lean_object* x_22; lean_object* x_23; lean_object* x_24; lean_object* x_25; lean_object* x_26; lean_object* x_27; lean_object* x_28; lean_object* x_29; lean_object* x_30; lean_object* x_31; lean_object* x_32; lean_object* x_33; lean_object* x_34; lean_object* x_35; lean_object* x_36; lean_object* x_37; lean_object* x_38; lean_object* x_39; lean_object* x_40; lean_object* x_41; lean_object* x_42; lean_object* x_43; lean_object* x_44; lean_object* x_45; lean_object* x_46; lean_object* x_47; lean_object* x_48; lean_object* x_49; lean_object* x_50; lean_object* x_51; lean_object* x_52; lean_object* x_53; lean_object* x_54; lean_object* x_55; lean_object* x_56; lean_object* x_57; lean_object* x_58; lean_object* x_59; lean_object* x_60; lean_object* x_61; lean_object* x_62; lean_object* x_63; lean_object* x_64; lean_object* x_65; lean_object* x_66; lean_object* x_67; lean_object* x_68; lean_object* x_69; lean_object* x_70; lean_object* x_71; lean_object* x_72; lean_object* x_73; lean_object* x_74; lean_object* x_75; lean_object* x_76; 
x_2 = lean_ctor_get_uint8(x_1, sizeof(void*)*4);
x_3 = lean_ctor_get(x_1, 0);
lean_inc(x_3);
x_4 = lean_ctor_get(x_1, 1);
lean_inc(x_4);
x_5 = lean_ctor_get(x_1, 2);
lean_inc(x_5);
x_6 = lean_ctor_get(x_1, 3);
lean_inc(x_6);
x_7 = lean_ctor_get_uint8(x_1, sizeof(void*)*4 + 1);
lean_dec_ref(x_1);
x_8 = ((lean_object*)(lp_padctl_instReprLayerConfig_repr___redArg___closed__5));
x_9 = ((lean_object*)(lp_padctl_instReprMacroState_repr___redArg___closed__3));
x_10 = lean_obj_once(&lp_padctl_instReprMacroState_repr___redArg___closed__4, &lp_padctl_instReprMacroState_repr___redArg___closed__4_once, _init_lp_padctl_instReprMacroState_repr___redArg___closed__4);
x_11 = lean_unsigned_to_nat(0u);
x_12 = l_Bool_repr___redArg(x_2);
x_13 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_13, 0, x_10);
lean_ctor_set(x_13, 1, x_12);
x_14 = 0;
x_15 = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(x_15, 0, x_13);
lean_ctor_set_uint8(x_15, sizeof(void*)*1, x_14);
x_16 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_16, 0, x_9);
lean_ctor_set(x_16, 1, x_15);
x_17 = ((lean_object*)(lp_padctl_instReprLayerConfig_repr___redArg___closed__9));
x_18 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_18, 0, x_16);
lean_ctor_set(x_18, 1, x_17);
x_19 = lean_box(1);
x_20 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_20, 0, x_18);
lean_ctor_set(x_20, 1, x_19);
x_21 = ((lean_object*)(lp_padctl_instReprMacroState_repr___redArg___closed__6));
x_22 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_22, 0, x_20);
lean_ctor_set(x_22, 1, x_21);
x_23 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_23, 0, x_22);
lean_ctor_set(x_23, 1, x_8);
x_24 = lean_obj_once(&lp_padctl_instReprMacroState_repr___redArg___closed__7, &lp_padctl_instReprMacroState_repr___redArg___closed__7_once, _init_lp_padctl_instReprMacroState_repr___redArg___closed__7);
x_25 = lp_padctl_List_repr_x27___at___00instReprMacroState_repr_spec__0___redArg(x_3);
x_26 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_26, 0, x_24);
lean_ctor_set(x_26, 1, x_25);
x_27 = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(x_27, 0, x_26);
lean_ctor_set_uint8(x_27, sizeof(void*)*1, x_14);
x_28 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_28, 0, x_23);
lean_ctor_set(x_28, 1, x_27);
x_29 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_29, 0, x_28);
lean_ctor_set(x_29, 1, x_17);
x_30 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_30, 0, x_29);
lean_ctor_set(x_30, 1, x_19);
x_31 = ((lean_object*)(lp_padctl_instReprMacroState_repr___redArg___closed__9));
x_32 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_32, 0, x_30);
lean_ctor_set(x_32, 1, x_31);
x_33 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_33, 0, x_32);
lean_ctor_set(x_33, 1, x_8);
x_34 = lean_obj_once(&lp_padctl_instReprTapHoldState_repr___redArg___closed__7, &lp_padctl_instReprTapHoldState_repr___redArg___closed__7_once, _init_lp_padctl_instReprTapHoldState_repr___redArg___closed__7);
x_35 = lp_padctl_List_repr___at___00instReprMacroState_repr_spec__1___redArg(x_4);
x_36 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_36, 0, x_34);
lean_ctor_set(x_36, 1, x_35);
x_37 = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(x_37, 0, x_36);
lean_ctor_set_uint8(x_37, sizeof(void*)*1, x_14);
x_38 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_38, 0, x_33);
lean_ctor_set(x_38, 1, x_37);
x_39 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_39, 0, x_38);
lean_ctor_set(x_39, 1, x_17);
x_40 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_40, 0, x_39);
lean_ctor_set(x_40, 1, x_19);
x_41 = ((lean_object*)(lp_padctl_instReprMacroState_repr___redArg___closed__11));
x_42 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_42, 0, x_40);
lean_ctor_set(x_42, 1, x_41);
x_43 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_43, 0, x_42);
lean_ctor_set(x_43, 1, x_8);
x_44 = lean_obj_once(&lp_padctl_instReprTapHoldState_repr___redArg___closed__13, &lp_padctl_instReprTapHoldState_repr___redArg___closed__13_once, _init_lp_padctl_instReprTapHoldState_repr___redArg___closed__13);
x_45 = l_Nat_reprFast(x_5);
x_46 = lean_alloc_ctor(3, 1, 0);
lean_ctor_set(x_46, 0, x_45);
x_47 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_47, 0, x_44);
lean_ctor_set(x_47, 1, x_46);
x_48 = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(x_48, 0, x_47);
lean_ctor_set_uint8(x_48, sizeof(void*)*1, x_14);
x_49 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_49, 0, x_43);
lean_ctor_set(x_49, 1, x_48);
x_50 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_50, 0, x_49);
lean_ctor_set(x_50, 1, x_17);
x_51 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_51, 0, x_50);
lean_ctor_set(x_51, 1, x_19);
x_52 = ((lean_object*)(lp_padctl_instReprMacroState_repr___redArg___closed__13));
x_53 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_53, 0, x_51);
lean_ctor_set(x_53, 1, x_52);
x_54 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_54, 0, x_53);
lean_ctor_set(x_54, 1, x_8);
x_55 = lean_obj_once(&lp_padctl_instReprMacroState_repr___redArg___closed__14, &lp_padctl_instReprMacroState_repr___redArg___closed__14_once, _init_lp_padctl_instReprMacroState_repr___redArg___closed__14);
x_56 = l_Option_repr___at___00Lean_Meta_instReprConfig__1_repr_spec__0(x_6, x_11);
x_57 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_57, 0, x_55);
lean_ctor_set(x_57, 1, x_56);
x_58 = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(x_58, 0, x_57);
lean_ctor_set_uint8(x_58, sizeof(void*)*1, x_14);
x_59 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_59, 0, x_54);
lean_ctor_set(x_59, 1, x_58);
x_60 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_60, 0, x_59);
lean_ctor_set(x_60, 1, x_17);
x_61 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_61, 0, x_60);
lean_ctor_set(x_61, 1, x_19);
x_62 = ((lean_object*)(lp_padctl_instReprMacroState_repr___redArg___closed__16));
x_63 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_63, 0, x_61);
lean_ctor_set(x_63, 1, x_62);
x_64 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_64, 0, x_63);
lean_ctor_set(x_64, 1, x_8);
x_65 = lean_obj_once(&lp_padctl_instReprTapHoldState_repr___redArg___closed__10, &lp_padctl_instReprTapHoldState_repr___redArg___closed__10_once, _init_lp_padctl_instReprTapHoldState_repr___redArg___closed__10);
x_66 = l_Bool_repr___redArg(x_7);
x_67 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_67, 0, x_65);
lean_ctor_set(x_67, 1, x_66);
x_68 = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(x_68, 0, x_67);
lean_ctor_set_uint8(x_68, sizeof(void*)*1, x_14);
x_69 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_69, 0, x_64);
lean_ctor_set(x_69, 1, x_68);
x_70 = lean_obj_once(&lp_padctl_instReprLayerConfig_repr___redArg___closed__18, &lp_padctl_instReprLayerConfig_repr___redArg___closed__18_once, _init_lp_padctl_instReprLayerConfig_repr___redArg___closed__18);
x_71 = ((lean_object*)(lp_padctl_instReprLayerConfig_repr___redArg___closed__19));
x_72 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_72, 0, x_71);
lean_ctor_set(x_72, 1, x_69);
x_73 = ((lean_object*)(lp_padctl_instReprLayerConfig_repr___redArg___closed__20));
x_74 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_74, 0, x_72);
lean_ctor_set(x_74, 1, x_73);
x_75 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_75, 0, x_70);
lean_ctor_set(x_75, 1, x_74);
x_76 = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(x_76, 0, x_75);
lean_ctor_set_uint8(x_76, sizeof(void*)*1, x_14);
return x_76;
}
}
LEAN_EXPORT lean_object* lp_padctl_instReprMacroState_repr(lean_object* x_1, lean_object* x_2) {
_start:
{
lean_object* x_3; 
x_3 = lp_padctl_instReprMacroState_repr___redArg(x_1);
return x_3;
}
}
LEAN_EXPORT lean_object* lp_padctl_instReprMacroState_repr___boxed(lean_object* x_1, lean_object* x_2) {
_start:
{
lean_object* x_3; 
x_3 = lp_padctl_instReprMacroState_repr(x_1, x_2);
lean_dec(x_2);
return x_3;
}
}
LEAN_EXPORT lean_object* lp_padctl_List_repr_x27___at___00instReprMacroState_repr_spec__0(lean_object* x_1, lean_object* x_2) {
_start:
{
lean_object* x_3; 
x_3 = lp_padctl_List_repr_x27___at___00instReprMacroState_repr_spec__0___redArg(x_1);
return x_3;
}
}
LEAN_EXPORT lean_object* lp_padctl_List_repr_x27___at___00instReprMacroState_repr_spec__0___boxed(lean_object* x_1, lean_object* x_2) {
_start:
{
lean_object* x_3; 
x_3 = lp_padctl_List_repr_x27___at___00instReprMacroState_repr_spec__0(x_1, x_2);
lean_dec(x_2);
return x_3;
}
}
LEAN_EXPORT lean_object* lp_padctl_List_repr___at___00instReprMacroState_repr_spec__1(lean_object* x_1, lean_object* x_2) {
_start:
{
lean_object* x_3; 
x_3 = lp_padctl_List_repr___at___00instReprMacroState_repr_spec__1___redArg(x_1);
return x_3;
}
}
LEAN_EXPORT lean_object* lp_padctl_List_repr___at___00instReprMacroState_repr_spec__1___boxed(lean_object* x_1, lean_object* x_2) {
_start:
{
lean_object* x_3; 
x_3 = lp_padctl_List_repr___at___00instReprMacroState_repr_spec__1(x_1, x_2);
lean_dec(x_2);
return x_3;
}
}
LEAN_EXPORT uint8_t lp_padctl_instDecidableEqMapperState_decEq___lam__0(uint8_t x_1, uint8_t x_2, uint8_t x_3) {
_start:
{
if (x_2 == 0)
{
if (x_3 == 0)
{
return x_1;
}
else
{
return x_2;
}
}
else
{
return x_3;
}
}
}
LEAN_EXPORT lean_object* lp_padctl_instDecidableEqMapperState_decEq___lam__0___boxed(lean_object* x_1, lean_object* x_2, lean_object* x_3) {
_start:
{
uint8_t x_4; uint8_t x_5; uint8_t x_6; uint8_t x_7; lean_object* x_8; 
x_4 = lean_unbox(x_1);
x_5 = lean_unbox(x_2);
x_6 = lean_unbox(x_3);
x_7 = lp_padctl_instDecidableEqMapperState_decEq___lam__0(x_4, x_5, x_6);
x_8 = lean_box(x_7);
return x_8;
}
}
LEAN_EXPORT uint8_t lp_padctl_instDecidableEqMapperState_decEq(lean_object* x_1, lean_object* x_2) {
_start:
{
lean_object* x_3; lean_object* x_4; lean_object* x_5; lean_object* x_6; lean_object* x_7; lean_object* x_8; lean_object* x_9; lean_object* x_10; lean_object* x_11; lean_object* x_12; lean_object* x_13; lean_object* x_14; uint8_t x_15; 
x_3 = lean_ctor_get(x_1, 0);
lean_inc(x_3);
x_4 = lean_ctor_get(x_1, 1);
lean_inc(x_4);
x_5 = lean_ctor_get(x_1, 2);
lean_inc(x_5);
x_6 = lean_ctor_get(x_1, 3);
lean_inc(x_6);
x_7 = lean_ctor_get(x_1, 4);
lean_inc(x_7);
x_8 = lean_ctor_get(x_1, 5);
lean_inc(x_8);
lean_dec_ref(x_1);
x_9 = lean_ctor_get(x_2, 0);
lean_inc(x_9);
x_10 = lean_ctor_get(x_2, 1);
lean_inc(x_10);
x_11 = lean_ctor_get(x_2, 2);
lean_inc(x_11);
x_12 = lean_ctor_get(x_2, 3);
lean_inc(x_12);
x_13 = lean_ctor_get(x_2, 4);
lean_inc(x_13);
x_14 = lean_ctor_get(x_2, 5);
lean_inc(x_14);
lean_dec_ref(x_2);
x_15 = lean_nat_dec_eq(x_3, x_9);
lean_dec(x_9);
lean_dec(x_3);
if (x_15 == 0)
{
lean_dec(x_14);
lean_dec(x_13);
lean_dec(x_12);
lean_dec(x_11);
lean_dec(x_10);
lean_dec(x_8);
lean_dec(x_7);
lean_dec(x_6);
lean_dec(x_5);
lean_dec(x_4);
return x_15;
}
else
{
uint8_t x_16; 
x_16 = lean_nat_dec_eq(x_4, x_10);
lean_dec(x_10);
lean_dec(x_4);
if (x_16 == 0)
{
lean_dec(x_14);
lean_dec(x_13);
lean_dec(x_12);
lean_dec(x_11);
lean_dec(x_8);
lean_dec(x_7);
lean_dec(x_6);
lean_dec(x_5);
return x_16;
}
else
{
lean_object* x_17; uint8_t x_18; 
x_17 = lean_alloc_closure((void*)(lp_padctl_instDecidableEqTapHoldState___boxed), 2, 0);
x_18 = l_Option_instDecidableEq___redArg(x_17, x_5, x_11);
if (x_18 == 0)
{
lean_dec(x_14);
lean_dec(x_13);
lean_dec(x_12);
lean_dec(x_8);
lean_dec(x_7);
lean_dec(x_6);
return x_18;
}
else
{
lean_object* x_19; lean_object* x_20; uint8_t x_21; 
x_19 = lean_box(x_18);
x_20 = lean_alloc_closure((void*)(lp_padctl_instDecidableEqMapperState_decEq___lam__0___boxed), 3, 1);
lean_closure_set(x_20, 0, x_19);
x_21 = l_instDecidableEqList___redArg(x_20, x_6, x_12);
if (x_21 == 0)
{
lean_dec(x_14);
lean_dec(x_13);
lean_dec(x_8);
lean_dec(x_7);
return x_21;
}
else
{
lean_object* x_22; uint8_t x_23; 
x_22 = lean_alloc_closure((void*)(lp_padctl_instDecidableEqMacroState___boxed), 2, 0);
x_23 = l_instDecidableEqList___redArg(x_22, x_7, x_13);
if (x_23 == 0)
{
lean_dec(x_14);
lean_dec(x_8);
return x_23;
}
else
{
lean_object* x_24; uint8_t x_25; 
x_24 = lean_alloc_closure((void*)(l_instDecidableEqNat___boxed), 2, 0);
x_25 = l_Option_instDecidableEq___redArg(x_24, x_8, x_14);
return x_25;
}
}
}
}
}
}
}
LEAN_EXPORT lean_object* lp_padctl_instDecidableEqMapperState_decEq___boxed(lean_object* x_1, lean_object* x_2) {
_start:
{
uint8_t x_3; lean_object* x_4; 
x_3 = lp_padctl_instDecidableEqMapperState_decEq(x_1, x_2);
x_4 = lean_box(x_3);
return x_4;
}
}
LEAN_EXPORT uint8_t lp_padctl_instDecidableEqMapperState(lean_object* x_1, lean_object* x_2) {
_start:
{
uint8_t x_3; 
x_3 = lp_padctl_instDecidableEqMapperState_decEq(x_1, x_2);
return x_3;
}
}
LEAN_EXPORT lean_object* lp_padctl_instDecidableEqMapperState___boxed(lean_object* x_1, lean_object* x_2) {
_start:
{
uint8_t x_3; lean_object* x_4; 
x_3 = lp_padctl_instDecidableEqMapperState(x_1, x_2);
x_4 = lean_box(x_3);
return x_4;
}
}
LEAN_EXPORT lean_object* lp_padctl_Option_repr___at___00instReprMapperState_repr_spec__0(lean_object* x_1, lean_object* x_2) {
_start:
{
if (lean_obj_tag(x_1) == 0)
{
lean_object* x_3; 
x_3 = ((lean_object*)(lp_padctl_Option_repr___at___00instReprMapperState_repr_spec__0___closed__1));
return x_3;
}
else
{
lean_object* x_4; lean_object* x_5; lean_object* x_6; lean_object* x_7; lean_object* x_8; 
x_4 = lean_ctor_get(x_1, 0);
lean_inc(x_4);
lean_dec_ref(x_1);
x_5 = ((lean_object*)(lp_padctl_Option_repr___at___00instReprMapperState_repr_spec__0___closed__3));
x_6 = lp_padctl_instReprTapHoldState_repr___redArg(x_4);
x_7 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_7, 0, x_5);
lean_ctor_set(x_7, 1, x_6);
x_8 = l_Repr_addAppParen(x_7, x_2);
return x_8;
}
}
}
LEAN_EXPORT lean_object* lp_padctl_Option_repr___at___00instReprMapperState_repr_spec__0___boxed(lean_object* x_1, lean_object* x_2) {
_start:
{
lean_object* x_3; 
x_3 = lp_padctl_Option_repr___at___00instReprMapperState_repr_spec__0(x_1, x_2);
lean_dec(x_2);
return x_3;
}
}
LEAN_EXPORT lean_object* lp_padctl_List_foldl___at___00List_foldl___at___00Std_Format_joinSep___at___00List_repr___at___00instReprMapperState_repr_spec__2_spec__3_spec__5_spec__7(lean_object* x_1, lean_object* x_2, lean_object* x_3) {
_start:
{
if (lean_obj_tag(x_3) == 0)
{
lean_dec(x_1);
return x_2;
}
else
{
uint8_t x_4; 
x_4 = !lean_is_exclusive(x_3);
if (x_4 == 0)
{
lean_object* x_5; lean_object* x_6; lean_object* x_7; lean_object* x_8; 
x_5 = lean_ctor_get(x_3, 0);
x_6 = lean_ctor_get(x_3, 1);
lean_inc(x_1);
lean_ctor_set_tag(x_3, 5);
lean_ctor_set(x_3, 1, x_1);
lean_ctor_set(x_3, 0, x_2);
x_7 = lp_padctl_instReprMacroState_repr___redArg(x_5);
x_8 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_8, 0, x_3);
lean_ctor_set(x_8, 1, x_7);
x_2 = x_8;
x_3 = x_6;
goto _start;
}
else
{
lean_object* x_10; lean_object* x_11; lean_object* x_12; lean_object* x_13; lean_object* x_14; 
x_10 = lean_ctor_get(x_3, 0);
x_11 = lean_ctor_get(x_3, 1);
lean_inc(x_11);
lean_inc(x_10);
lean_dec(x_3);
lean_inc(x_1);
x_12 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_12, 0, x_2);
lean_ctor_set(x_12, 1, x_1);
x_13 = lp_padctl_instReprMacroState_repr___redArg(x_10);
x_14 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_14, 0, x_12);
lean_ctor_set(x_14, 1, x_13);
x_2 = x_14;
x_3 = x_11;
goto _start;
}
}
}
}
LEAN_EXPORT lean_object* lp_padctl_List_foldl___at___00Std_Format_joinSep___at___00List_repr___at___00instReprMapperState_repr_spec__2_spec__3_spec__5(lean_object* x_1, lean_object* x_2, lean_object* x_3) {
_start:
{
if (lean_obj_tag(x_3) == 0)
{
lean_dec(x_1);
return x_2;
}
else
{
uint8_t x_4; 
x_4 = !lean_is_exclusive(x_3);
if (x_4 == 0)
{
lean_object* x_5; lean_object* x_6; lean_object* x_7; lean_object* x_8; lean_object* x_9; 
x_5 = lean_ctor_get(x_3, 0);
x_6 = lean_ctor_get(x_3, 1);
lean_inc(x_1);
lean_ctor_set_tag(x_3, 5);
lean_ctor_set(x_3, 1, x_1);
lean_ctor_set(x_3, 0, x_2);
x_7 = lp_padctl_instReprMacroState_repr___redArg(x_5);
x_8 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_8, 0, x_3);
lean_ctor_set(x_8, 1, x_7);
x_9 = lp_padctl_List_foldl___at___00List_foldl___at___00Std_Format_joinSep___at___00List_repr___at___00instReprMapperState_repr_spec__2_spec__3_spec__5_spec__7(x_1, x_8, x_6);
return x_9;
}
else
{
lean_object* x_10; lean_object* x_11; lean_object* x_12; lean_object* x_13; lean_object* x_14; lean_object* x_15; 
x_10 = lean_ctor_get(x_3, 0);
x_11 = lean_ctor_get(x_3, 1);
lean_inc(x_11);
lean_inc(x_10);
lean_dec(x_3);
lean_inc(x_1);
x_12 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_12, 0, x_2);
lean_ctor_set(x_12, 1, x_1);
x_13 = lp_padctl_instReprMacroState_repr___redArg(x_10);
x_14 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_14, 0, x_12);
lean_ctor_set(x_14, 1, x_13);
x_15 = lp_padctl_List_foldl___at___00List_foldl___at___00Std_Format_joinSep___at___00List_repr___at___00instReprMapperState_repr_spec__2_spec__3_spec__5_spec__7(x_1, x_14, x_11);
return x_15;
}
}
}
}
LEAN_EXPORT lean_object* lp_padctl_Std_Format_joinSep___at___00List_repr___at___00instReprMapperState_repr_spec__2_spec__3(lean_object* x_1, lean_object* x_2) {
_start:
{
if (lean_obj_tag(x_1) == 0)
{
lean_object* x_3; 
lean_dec(x_2);
x_3 = lean_box(0);
return x_3;
}
else
{
lean_object* x_4; 
x_4 = lean_ctor_get(x_1, 1);
if (lean_obj_tag(x_4) == 0)
{
lean_object* x_5; lean_object* x_6; 
lean_dec(x_2);
x_5 = lean_ctor_get(x_1, 0);
lean_inc(x_5);
lean_dec_ref(x_1);
x_6 = lp_padctl_instReprMacroState_repr___redArg(x_5);
return x_6;
}
else
{
lean_object* x_7; lean_object* x_8; lean_object* x_9; 
lean_inc(x_4);
x_7 = lean_ctor_get(x_1, 0);
lean_inc(x_7);
lean_dec_ref(x_1);
x_8 = lp_padctl_instReprMacroState_repr___redArg(x_7);
x_9 = lp_padctl_List_foldl___at___00Std_Format_joinSep___at___00List_repr___at___00instReprMapperState_repr_spec__2_spec__3_spec__5(x_2, x_8, x_4);
return x_9;
}
}
}
}
LEAN_EXPORT lean_object* lp_padctl_List_repr___at___00instReprMapperState_repr_spec__2___redArg(lean_object* x_1) {
_start:
{
if (lean_obj_tag(x_1) == 0)
{
lean_object* x_2; 
x_2 = ((lean_object*)(lp_padctl_List_repr___at___00instReprMacroState_repr_spec__1___redArg___closed__1));
return x_2;
}
else
{
lean_object* x_3; lean_object* x_4; lean_object* x_5; lean_object* x_6; lean_object* x_7; lean_object* x_8; lean_object* x_9; lean_object* x_10; uint8_t x_11; lean_object* x_12; 
x_3 = ((lean_object*)(lp_padctl_List_repr___at___00instReprMacroState_repr_spec__1___redArg___closed__3));
x_4 = lp_padctl_Std_Format_joinSep___at___00List_repr___at___00instReprMapperState_repr_spec__2_spec__3(x_1, x_3);
x_5 = lean_obj_once(&lp_padctl_List_repr___at___00instReprMacroState_repr_spec__1___redArg___closed__6, &lp_padctl_List_repr___at___00instReprMacroState_repr_spec__1___redArg___closed__6_once, _init_lp_padctl_List_repr___at___00instReprMacroState_repr_spec__1___redArg___closed__6);
x_6 = ((lean_object*)(lp_padctl_List_repr___at___00instReprMacroState_repr_spec__1___redArg___closed__7));
x_7 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_7, 0, x_6);
lean_ctor_set(x_7, 1, x_4);
x_8 = ((lean_object*)(lp_padctl_List_repr___at___00instReprMacroState_repr_spec__1___redArg___closed__8));
x_9 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_9, 0, x_7);
lean_ctor_set(x_9, 1, x_8);
x_10 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_10, 0, x_5);
lean_ctor_set(x_10, 1, x_9);
x_11 = 0;
x_12 = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(x_12, 0, x_10);
lean_ctor_set_uint8(x_12, sizeof(void*)*1, x_11);
return x_12;
}
}
}
LEAN_EXPORT lean_object* lp_padctl_List_foldl___at___00List_foldl___at___00Std_Format_joinSep___at___00List_repr_x27___at___00instReprMapperState_repr_spec__1_spec__1_spec__2_spec__4(lean_object* x_1, lean_object* x_2, lean_object* x_3) {
_start:
{
if (lean_obj_tag(x_3) == 0)
{
lean_dec(x_1);
return x_2;
}
else
{
uint8_t x_4; 
x_4 = !lean_is_exclusive(x_3);
if (x_4 == 0)
{
lean_object* x_5; lean_object* x_6; uint8_t x_7; lean_object* x_8; lean_object* x_9; 
x_5 = lean_ctor_get(x_3, 0);
x_6 = lean_ctor_get(x_3, 1);
lean_inc(x_1);
lean_ctor_set_tag(x_3, 5);
lean_ctor_set(x_3, 1, x_1);
lean_ctor_set(x_3, 0, x_2);
x_7 = lean_unbox(x_5);
lean_dec(x_5);
x_8 = l_Bool_repr___redArg(x_7);
x_9 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_9, 0, x_3);
lean_ctor_set(x_9, 1, x_8);
x_2 = x_9;
x_3 = x_6;
goto _start;
}
else
{
lean_object* x_11; lean_object* x_12; lean_object* x_13; uint8_t x_14; lean_object* x_15; lean_object* x_16; 
x_11 = lean_ctor_get(x_3, 0);
x_12 = lean_ctor_get(x_3, 1);
lean_inc(x_12);
lean_inc(x_11);
lean_dec(x_3);
lean_inc(x_1);
x_13 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_13, 0, x_2);
lean_ctor_set(x_13, 1, x_1);
x_14 = lean_unbox(x_11);
lean_dec(x_11);
x_15 = l_Bool_repr___redArg(x_14);
x_16 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_16, 0, x_13);
lean_ctor_set(x_16, 1, x_15);
x_2 = x_16;
x_3 = x_12;
goto _start;
}
}
}
}
LEAN_EXPORT lean_object* lp_padctl_List_foldl___at___00Std_Format_joinSep___at___00List_repr_x27___at___00instReprMapperState_repr_spec__1_spec__1_spec__2(lean_object* x_1, lean_object* x_2, lean_object* x_3) {
_start:
{
if (lean_obj_tag(x_3) == 0)
{
lean_dec(x_1);
return x_2;
}
else
{
uint8_t x_4; 
x_4 = !lean_is_exclusive(x_3);
if (x_4 == 0)
{
lean_object* x_5; lean_object* x_6; uint8_t x_7; lean_object* x_8; lean_object* x_9; lean_object* x_10; 
x_5 = lean_ctor_get(x_3, 0);
x_6 = lean_ctor_get(x_3, 1);
lean_inc(x_1);
lean_ctor_set_tag(x_3, 5);
lean_ctor_set(x_3, 1, x_1);
lean_ctor_set(x_3, 0, x_2);
x_7 = lean_unbox(x_5);
lean_dec(x_5);
x_8 = l_Bool_repr___redArg(x_7);
x_9 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_9, 0, x_3);
lean_ctor_set(x_9, 1, x_8);
x_10 = lp_padctl_List_foldl___at___00List_foldl___at___00Std_Format_joinSep___at___00List_repr_x27___at___00instReprMapperState_repr_spec__1_spec__1_spec__2_spec__4(x_1, x_9, x_6);
return x_10;
}
else
{
lean_object* x_11; lean_object* x_12; lean_object* x_13; uint8_t x_14; lean_object* x_15; lean_object* x_16; lean_object* x_17; 
x_11 = lean_ctor_get(x_3, 0);
x_12 = lean_ctor_get(x_3, 1);
lean_inc(x_12);
lean_inc(x_11);
lean_dec(x_3);
lean_inc(x_1);
x_13 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_13, 0, x_2);
lean_ctor_set(x_13, 1, x_1);
x_14 = lean_unbox(x_11);
lean_dec(x_11);
x_15 = l_Bool_repr___redArg(x_14);
x_16 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_16, 0, x_13);
lean_ctor_set(x_16, 1, x_15);
x_17 = lp_padctl_List_foldl___at___00List_foldl___at___00Std_Format_joinSep___at___00List_repr_x27___at___00instReprMapperState_repr_spec__1_spec__1_spec__2_spec__4(x_1, x_16, x_12);
return x_17;
}
}
}
}
LEAN_EXPORT lean_object* lp_padctl_Std_Format_joinSep___at___00List_repr_x27___at___00instReprMapperState_repr_spec__1_spec__1(lean_object* x_1, lean_object* x_2) {
_start:
{
if (lean_obj_tag(x_1) == 0)
{
lean_object* x_3; 
lean_dec(x_2);
x_3 = lean_box(0);
return x_3;
}
else
{
lean_object* x_4; 
x_4 = lean_ctor_get(x_1, 1);
if (lean_obj_tag(x_4) == 0)
{
lean_object* x_5; uint8_t x_6; lean_object* x_7; 
lean_dec(x_2);
x_5 = lean_ctor_get(x_1, 0);
lean_inc(x_5);
lean_dec_ref(x_1);
x_6 = lean_unbox(x_5);
lean_dec(x_5);
x_7 = l_Bool_repr___redArg(x_6);
return x_7;
}
else
{
lean_object* x_8; uint8_t x_9; lean_object* x_10; lean_object* x_11; 
lean_inc(x_4);
x_8 = lean_ctor_get(x_1, 0);
lean_inc(x_8);
lean_dec_ref(x_1);
x_9 = lean_unbox(x_8);
lean_dec(x_8);
x_10 = l_Bool_repr___redArg(x_9);
x_11 = lp_padctl_List_foldl___at___00Std_Format_joinSep___at___00List_repr_x27___at___00instReprMapperState_repr_spec__1_spec__1_spec__2(x_2, x_10, x_4);
return x_11;
}
}
}
}
LEAN_EXPORT lean_object* lp_padctl_List_repr_x27___at___00instReprMapperState_repr_spec__1___redArg(lean_object* x_1) {
_start:
{
if (lean_obj_tag(x_1) == 0)
{
lean_object* x_2; 
x_2 = ((lean_object*)(lp_padctl_List_repr___at___00instReprMacroState_repr_spec__1___redArg___closed__1));
return x_2;
}
else
{
lean_object* x_3; lean_object* x_4; lean_object* x_5; lean_object* x_6; lean_object* x_7; lean_object* x_8; lean_object* x_9; lean_object* x_10; lean_object* x_11; 
x_3 = ((lean_object*)(lp_padctl_List_repr___at___00instReprMacroState_repr_spec__1___redArg___closed__3));
x_4 = lp_padctl_Std_Format_joinSep___at___00List_repr_x27___at___00instReprMapperState_repr_spec__1_spec__1(x_1, x_3);
x_5 = lean_obj_once(&lp_padctl_List_repr___at___00instReprMacroState_repr_spec__1___redArg___closed__6, &lp_padctl_List_repr___at___00instReprMacroState_repr_spec__1___redArg___closed__6_once, _init_lp_padctl_List_repr___at___00instReprMacroState_repr_spec__1___redArg___closed__6);
x_6 = ((lean_object*)(lp_padctl_List_repr___at___00instReprMacroState_repr_spec__1___redArg___closed__7));
x_7 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_7, 0, x_6);
lean_ctor_set(x_7, 1, x_4);
x_8 = ((lean_object*)(lp_padctl_List_repr___at___00instReprMacroState_repr_spec__1___redArg___closed__8));
x_9 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_9, 0, x_7);
lean_ctor_set(x_9, 1, x_8);
x_10 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_10, 0, x_5);
lean_ctor_set(x_10, 1, x_9);
x_11 = l_Std_Format_fill(x_10);
return x_11;
}
}
}
static lean_object* _init_lp_padctl_instReprMapperState_repr___redArg___closed__14(void) {
_start:
{
lean_object* x_1; lean_object* x_2; 
x_1 = lean_unsigned_to_nat(21u);
x_2 = lean_nat_to_int(x_1);
return x_2;
}
}
LEAN_EXPORT lean_object* lp_padctl_instReprMapperState_repr___redArg(lean_object* x_1) {
_start:
{
lean_object* x_2; lean_object* x_3; lean_object* x_4; lean_object* x_5; lean_object* x_6; lean_object* x_7; lean_object* x_8; lean_object* x_9; lean_object* x_10; lean_object* x_11; lean_object* x_12; lean_object* x_13; uint8_t x_14; lean_object* x_15; lean_object* x_16; lean_object* x_17; lean_object* x_18; lean_object* x_19; lean_object* x_20; lean_object* x_21; lean_object* x_22; lean_object* x_23; lean_object* x_24; lean_object* x_25; lean_object* x_26; lean_object* x_27; lean_object* x_28; lean_object* x_29; lean_object* x_30; lean_object* x_31; lean_object* x_32; lean_object* x_33; lean_object* x_34; lean_object* x_35; lean_object* x_36; lean_object* x_37; lean_object* x_38; lean_object* x_39; lean_object* x_40; lean_object* x_41; lean_object* x_42; lean_object* x_43; lean_object* x_44; lean_object* x_45; lean_object* x_46; lean_object* x_47; lean_object* x_48; lean_object* x_49; lean_object* x_50; lean_object* x_51; lean_object* x_52; lean_object* x_53; lean_object* x_54; lean_object* x_55; lean_object* x_56; lean_object* x_57; lean_object* x_58; lean_object* x_59; lean_object* x_60; lean_object* x_61; lean_object* x_62; lean_object* x_63; lean_object* x_64; lean_object* x_65; lean_object* x_66; lean_object* x_67; lean_object* x_68; lean_object* x_69; lean_object* x_70; lean_object* x_71; lean_object* x_72; lean_object* x_73; lean_object* x_74; lean_object* x_75; 
x_2 = lean_ctor_get(x_1, 0);
lean_inc(x_2);
x_3 = lean_ctor_get(x_1, 1);
lean_inc(x_3);
x_4 = lean_ctor_get(x_1, 2);
lean_inc(x_4);
x_5 = lean_ctor_get(x_1, 3);
lean_inc(x_5);
x_6 = lean_ctor_get(x_1, 4);
lean_inc(x_6);
x_7 = lean_ctor_get(x_1, 5);
lean_inc(x_7);
lean_dec_ref(x_1);
x_8 = ((lean_object*)(lp_padctl_instReprLayerConfig_repr___redArg___closed__5));
x_9 = ((lean_object*)(lp_padctl_instReprMapperState_repr___redArg___closed__3));
x_10 = lean_obj_once(&lp_padctl_instReprLayerConfig_repr___redArg___closed__7, &lp_padctl_instReprLayerConfig_repr___redArg___closed__7_once, _init_lp_padctl_instReprLayerConfig_repr___redArg___closed__7);
x_11 = l_Nat_reprFast(x_2);
x_12 = lean_alloc_ctor(3, 1, 0);
lean_ctor_set(x_12, 0, x_11);
x_13 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_13, 0, x_10);
lean_ctor_set(x_13, 1, x_12);
x_14 = 0;
x_15 = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(x_15, 0, x_13);
lean_ctor_set_uint8(x_15, sizeof(void*)*1, x_14);
x_16 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_16, 0, x_9);
lean_ctor_set(x_16, 1, x_15);
x_17 = ((lean_object*)(lp_padctl_instReprLayerConfig_repr___redArg___closed__9));
x_18 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_18, 0, x_16);
lean_ctor_set(x_18, 1, x_17);
x_19 = lean_box(1);
x_20 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_20, 0, x_18);
lean_ctor_set(x_20, 1, x_19);
x_21 = ((lean_object*)(lp_padctl_instReprMapperState_repr___redArg___closed__5));
x_22 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_22, 0, x_20);
lean_ctor_set(x_22, 1, x_21);
x_23 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_23, 0, x_22);
lean_ctor_set(x_23, 1, x_8);
x_24 = lean_obj_once(&lp_padctl_instReprLayerConfig_repr___redArg___closed__15, &lp_padctl_instReprLayerConfig_repr___redArg___closed__15_once, _init_lp_padctl_instReprLayerConfig_repr___redArg___closed__15);
x_25 = l_Nat_reprFast(x_3);
x_26 = lean_alloc_ctor(3, 1, 0);
lean_ctor_set(x_26, 0, x_25);
x_27 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_27, 0, x_24);
lean_ctor_set(x_27, 1, x_26);
x_28 = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(x_28, 0, x_27);
lean_ctor_set_uint8(x_28, sizeof(void*)*1, x_14);
x_29 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_29, 0, x_23);
lean_ctor_set(x_29, 1, x_28);
x_30 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_30, 0, x_29);
lean_ctor_set(x_30, 1, x_17);
x_31 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_31, 0, x_30);
lean_ctor_set(x_31, 1, x_19);
x_32 = ((lean_object*)(lp_padctl_instReprMapperState_repr___redArg___closed__7));
x_33 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_33, 0, x_31);
lean_ctor_set(x_33, 1, x_32);
x_34 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_34, 0, x_33);
lean_ctor_set(x_34, 1, x_8);
x_35 = lean_unsigned_to_nat(0u);
x_36 = lp_padctl_Option_repr___at___00instReprMapperState_repr_spec__0(x_4, x_35);
x_37 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_37, 0, x_10);
lean_ctor_set(x_37, 1, x_36);
x_38 = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(x_38, 0, x_37);
lean_ctor_set_uint8(x_38, sizeof(void*)*1, x_14);
x_39 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_39, 0, x_34);
lean_ctor_set(x_39, 1, x_38);
x_40 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_40, 0, x_39);
lean_ctor_set(x_40, 1, x_17);
x_41 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_41, 0, x_40);
lean_ctor_set(x_41, 1, x_19);
x_42 = ((lean_object*)(lp_padctl_instReprMapperState_repr___redArg___closed__9));
x_43 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_43, 0, x_41);
lean_ctor_set(x_43, 1, x_42);
x_44 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_44, 0, x_43);
lean_ctor_set(x_44, 1, x_8);
x_45 = lp_padctl_List_repr_x27___at___00instReprMapperState_repr_spec__1___redArg(x_5);
x_46 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_46, 0, x_10);
lean_ctor_set(x_46, 1, x_45);
x_47 = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(x_47, 0, x_46);
lean_ctor_set_uint8(x_47, sizeof(void*)*1, x_14);
x_48 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_48, 0, x_44);
lean_ctor_set(x_48, 1, x_47);
x_49 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_49, 0, x_48);
lean_ctor_set(x_49, 1, x_17);
x_50 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_50, 0, x_49);
lean_ctor_set(x_50, 1, x_19);
x_51 = ((lean_object*)(lp_padctl_instReprMapperState_repr___redArg___closed__11));
x_52 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_52, 0, x_50);
lean_ctor_set(x_52, 1, x_51);
x_53 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_53, 0, x_52);
lean_ctor_set(x_53, 1, x_8);
x_54 = lean_obj_once(&lp_padctl_instReprMacroState_repr___redArg___closed__4, &lp_padctl_instReprMacroState_repr___redArg___closed__4_once, _init_lp_padctl_instReprMacroState_repr___redArg___closed__4);
x_55 = lp_padctl_List_repr___at___00instReprMapperState_repr_spec__2___redArg(x_6);
x_56 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_56, 0, x_54);
lean_ctor_set(x_56, 1, x_55);
x_57 = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(x_57, 0, x_56);
lean_ctor_set_uint8(x_57, sizeof(void*)*1, x_14);
x_58 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_58, 0, x_53);
lean_ctor_set(x_58, 1, x_57);
x_59 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_59, 0, x_58);
lean_ctor_set(x_59, 1, x_17);
x_60 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_60, 0, x_59);
lean_ctor_set(x_60, 1, x_19);
x_61 = ((lean_object*)(lp_padctl_instReprMapperState_repr___redArg___closed__13));
x_62 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_62, 0, x_60);
lean_ctor_set(x_62, 1, x_61);
x_63 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_63, 0, x_62);
lean_ctor_set(x_63, 1, x_8);
x_64 = lean_obj_once(&lp_padctl_instReprMapperState_repr___redArg___closed__14, &lp_padctl_instReprMapperState_repr___redArg___closed__14_once, _init_lp_padctl_instReprMapperState_repr___redArg___closed__14);
x_65 = l_Option_repr___at___00Lean_Meta_instReprConfig__1_repr_spec__0(x_7, x_35);
x_66 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_66, 0, x_64);
lean_ctor_set(x_66, 1, x_65);
x_67 = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(x_67, 0, x_66);
lean_ctor_set_uint8(x_67, sizeof(void*)*1, x_14);
x_68 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_68, 0, x_63);
lean_ctor_set(x_68, 1, x_67);
x_69 = lean_obj_once(&lp_padctl_instReprLayerConfig_repr___redArg___closed__18, &lp_padctl_instReprLayerConfig_repr___redArg___closed__18_once, _init_lp_padctl_instReprLayerConfig_repr___redArg___closed__18);
x_70 = ((lean_object*)(lp_padctl_instReprLayerConfig_repr___redArg___closed__19));
x_71 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_71, 0, x_70);
lean_ctor_set(x_71, 1, x_68);
x_72 = ((lean_object*)(lp_padctl_instReprLayerConfig_repr___redArg___closed__20));
x_73 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_73, 0, x_71);
lean_ctor_set(x_73, 1, x_72);
x_74 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_74, 0, x_69);
lean_ctor_set(x_74, 1, x_73);
x_75 = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(x_75, 0, x_74);
lean_ctor_set_uint8(x_75, sizeof(void*)*1, x_14);
return x_75;
}
}
LEAN_EXPORT lean_object* lp_padctl_instReprMapperState_repr(lean_object* x_1, lean_object* x_2) {
_start:
{
lean_object* x_3; 
x_3 = lp_padctl_instReprMapperState_repr___redArg(x_1);
return x_3;
}
}
LEAN_EXPORT lean_object* lp_padctl_instReprMapperState_repr___boxed(lean_object* x_1, lean_object* x_2) {
_start:
{
lean_object* x_3; 
x_3 = lp_padctl_instReprMapperState_repr(x_1, x_2);
lean_dec(x_2);
return x_3;
}
}
LEAN_EXPORT lean_object* lp_padctl_List_repr_x27___at___00instReprMapperState_repr_spec__1(lean_object* x_1, lean_object* x_2) {
_start:
{
lean_object* x_3; 
x_3 = lp_padctl_List_repr_x27___at___00instReprMapperState_repr_spec__1___redArg(x_1);
return x_3;
}
}
LEAN_EXPORT lean_object* lp_padctl_List_repr_x27___at___00instReprMapperState_repr_spec__1___boxed(lean_object* x_1, lean_object* x_2) {
_start:
{
lean_object* x_3; 
x_3 = lp_padctl_List_repr_x27___at___00instReprMapperState_repr_spec__1(x_1, x_2);
lean_dec(x_2);
return x_3;
}
}
LEAN_EXPORT lean_object* lp_padctl_List_repr___at___00instReprMapperState_repr_spec__2(lean_object* x_1, lean_object* x_2) {
_start:
{
lean_object* x_3; 
x_3 = lp_padctl_List_repr___at___00instReprMapperState_repr_spec__2___redArg(x_1);
return x_3;
}
}
LEAN_EXPORT lean_object* lp_padctl_List_repr___at___00instReprMapperState_repr_spec__2___boxed(lean_object* x_1, lean_object* x_2) {
_start:
{
lean_object* x_3; 
x_3 = lp_padctl_List_repr___at___00instReprMapperState_repr_spec__2(x_1, x_2);
lean_dec(x_2);
return x_3;
}
}
LEAN_EXPORT lean_object* lp_padctl_onTriggerPress(lean_object* x_1, lean_object* x_2) {
_start:
{
lean_object* x_3; 
x_3 = lean_ctor_get(x_1, 2);
if (lean_obj_tag(x_3) == 0)
{
uint8_t x_4; 
x_4 = !lean_is_exclusive(x_1);
if (x_4 == 0)
{
lean_object* x_5; uint8_t x_6; uint8_t x_7; lean_object* x_8; lean_object* x_9; lean_object* x_10; 
x_5 = lean_ctor_get(x_1, 2);
lean_dec(x_5);
x_6 = 0;
x_7 = 0;
x_8 = lean_unsigned_to_nat(0u);
x_9 = lean_alloc_ctor(0, 2, 2);
lean_ctor_set(x_9, 0, x_2);
lean_ctor_set(x_9, 1, x_8);
lean_ctor_set_uint8(x_9, sizeof(void*)*2, x_6);
lean_ctor_set_uint8(x_9, sizeof(void*)*2 + 1, x_7);
x_10 = lean_alloc_ctor(1, 1, 0);
lean_ctor_set(x_10, 0, x_9);
lean_ctor_set(x_1, 2, x_10);
return x_1;
}
else
{
lean_object* x_11; lean_object* x_12; lean_object* x_13; lean_object* x_14; lean_object* x_15; uint8_t x_16; uint8_t x_17; lean_object* x_18; lean_object* x_19; lean_object* x_20; lean_object* x_21; 
x_11 = lean_ctor_get(x_1, 0);
x_12 = lean_ctor_get(x_1, 1);
x_13 = lean_ctor_get(x_1, 3);
x_14 = lean_ctor_get(x_1, 4);
x_15 = lean_ctor_get(x_1, 5);
lean_inc(x_15);
lean_inc(x_14);
lean_inc(x_13);
lean_inc(x_12);
lean_inc(x_11);
lean_dec(x_1);
x_16 = 0;
x_17 = 0;
x_18 = lean_unsigned_to_nat(0u);
x_19 = lean_alloc_ctor(0, 2, 2);
lean_ctor_set(x_19, 0, x_2);
lean_ctor_set(x_19, 1, x_18);
lean_ctor_set_uint8(x_19, sizeof(void*)*2, x_16);
lean_ctor_set_uint8(x_19, sizeof(void*)*2 + 1, x_17);
x_20 = lean_alloc_ctor(1, 1, 0);
lean_ctor_set(x_20, 0, x_19);
x_21 = lean_alloc_ctor(0, 6, 0);
lean_ctor_set(x_21, 0, x_11);
lean_ctor_set(x_21, 1, x_12);
lean_ctor_set(x_21, 2, x_20);
lean_ctor_set(x_21, 3, x_13);
lean_ctor_set(x_21, 4, x_14);
lean_ctor_set(x_21, 5, x_15);
return x_21;
}
}
else
{
lean_dec(x_2);
return x_1;
}
}
}
LEAN_EXPORT lean_object* lp_padctl_onTapHoldTimerExpired(lean_object* x_1) {
_start:
{
lean_object* x_2; 
x_2 = lean_ctor_get(x_1, 2);
lean_inc(x_2);
if (lean_obj_tag(x_2) == 0)
{
return x_1;
}
else
{
uint8_t x_3; 
x_3 = !lean_is_exclusive(x_2);
if (x_3 == 0)
{
lean_object* x_4; uint8_t x_5; 
x_4 = lean_ctor_get(x_2, 0);
x_5 = !lean_is_exclusive(x_4);
if (x_5 == 0)
{
lean_object* x_6; lean_object* x_7; lean_object* x_8; lean_object* x_9; lean_object* x_10; lean_object* x_11; uint8_t x_12; lean_object* x_13; uint8_t x_14; uint8_t x_15; 
x_6 = lean_ctor_get(x_1, 0);
x_7 = lean_ctor_get(x_1, 1);
x_8 = lean_ctor_get(x_1, 3);
x_9 = lean_ctor_get(x_1, 4);
x_10 = lean_ctor_get(x_1, 5);
x_11 = lean_ctor_get(x_4, 0);
x_12 = lean_ctor_get_uint8(x_4, sizeof(void*)*2);
x_13 = lean_ctor_get(x_4, 1);
x_14 = 0;
x_15 = lp_padctl_instDecidableEqTapHoldPhase(x_12, x_14);
if (x_15 == 0)
{
lean_free_object(x_4);
lean_dec(x_13);
lean_dec(x_11);
lean_free_object(x_2);
return x_1;
}
else
{
uint8_t x_16; 
lean_inc(x_10);
lean_inc(x_9);
lean_inc(x_8);
lean_inc(x_7);
lean_inc(x_6);
x_16 = !lean_is_exclusive(x_1);
if (x_16 == 0)
{
lean_object* x_17; lean_object* x_18; lean_object* x_19; lean_object* x_20; lean_object* x_21; lean_object* x_22; uint8_t x_23; 
x_17 = lean_ctor_get(x_1, 5);
lean_dec(x_17);
x_18 = lean_ctor_get(x_1, 4);
lean_dec(x_18);
x_19 = lean_ctor_get(x_1, 3);
lean_dec(x_19);
x_20 = lean_ctor_get(x_1, 2);
lean_dec(x_20);
x_21 = lean_ctor_get(x_1, 1);
lean_dec(x_21);
x_22 = lean_ctor_get(x_1, 0);
lean_dec(x_22);
x_23 = 1;
lean_ctor_set_uint8(x_4, sizeof(void*)*2, x_23);
lean_ctor_set_uint8(x_4, sizeof(void*)*2 + 1, x_15);
return x_1;
}
else
{
uint8_t x_24; lean_object* x_25; 
lean_dec(x_1);
x_24 = 1;
lean_ctor_set_uint8(x_4, sizeof(void*)*2, x_24);
lean_ctor_set_uint8(x_4, sizeof(void*)*2 + 1, x_15);
x_25 = lean_alloc_ctor(0, 6, 0);
lean_ctor_set(x_25, 0, x_6);
lean_ctor_set(x_25, 1, x_7);
lean_ctor_set(x_25, 2, x_2);
lean_ctor_set(x_25, 3, x_8);
lean_ctor_set(x_25, 4, x_9);
lean_ctor_set(x_25, 5, x_10);
return x_25;
}
}
}
else
{
lean_object* x_26; lean_object* x_27; lean_object* x_28; lean_object* x_29; lean_object* x_30; lean_object* x_31; uint8_t x_32; lean_object* x_33; uint8_t x_34; uint8_t x_35; 
x_26 = lean_ctor_get(x_1, 0);
x_27 = lean_ctor_get(x_1, 1);
x_28 = lean_ctor_get(x_1, 3);
x_29 = lean_ctor_get(x_1, 4);
x_30 = lean_ctor_get(x_1, 5);
x_31 = lean_ctor_get(x_4, 0);
x_32 = lean_ctor_get_uint8(x_4, sizeof(void*)*2);
x_33 = lean_ctor_get(x_4, 1);
lean_inc(x_33);
lean_inc(x_31);
lean_dec(x_4);
x_34 = 0;
x_35 = lp_padctl_instDecidableEqTapHoldPhase(x_32, x_34);
if (x_35 == 0)
{
lean_dec(x_33);
lean_dec(x_31);
lean_free_object(x_2);
return x_1;
}
else
{
lean_object* x_36; uint8_t x_37; lean_object* x_38; lean_object* x_39; 
lean_inc(x_30);
lean_inc(x_29);
lean_inc(x_28);
lean_inc(x_27);
lean_inc(x_26);
if (lean_is_exclusive(x_1)) {
 lean_ctor_release(x_1, 0);
 lean_ctor_release(x_1, 1);
 lean_ctor_release(x_1, 2);
 lean_ctor_release(x_1, 3);
 lean_ctor_release(x_1, 4);
 lean_ctor_release(x_1, 5);
 x_36 = x_1;
} else {
 lean_dec_ref(x_1);
 x_36 = lean_box(0);
}
x_37 = 1;
x_38 = lean_alloc_ctor(0, 2, 2);
lean_ctor_set(x_38, 0, x_31);
lean_ctor_set(x_38, 1, x_33);
lean_ctor_set_uint8(x_38, sizeof(void*)*2, x_37);
lean_ctor_set_uint8(x_38, sizeof(void*)*2 + 1, x_35);
lean_ctor_set(x_2, 0, x_38);
if (lean_is_scalar(x_36)) {
 x_39 = lean_alloc_ctor(0, 6, 0);
} else {
 x_39 = x_36;
}
lean_ctor_set(x_39, 0, x_26);
lean_ctor_set(x_39, 1, x_27);
lean_ctor_set(x_39, 2, x_2);
lean_ctor_set(x_39, 3, x_28);
lean_ctor_set(x_39, 4, x_29);
lean_ctor_set(x_39, 5, x_30);
return x_39;
}
}
}
else
{
lean_object* x_40; lean_object* x_41; lean_object* x_42; lean_object* x_43; lean_object* x_44; lean_object* x_45; lean_object* x_46; uint8_t x_47; lean_object* x_48; lean_object* x_49; uint8_t x_50; uint8_t x_51; 
x_40 = lean_ctor_get(x_2, 0);
lean_inc(x_40);
lean_dec(x_2);
x_41 = lean_ctor_get(x_1, 0);
x_42 = lean_ctor_get(x_1, 1);
x_43 = lean_ctor_get(x_1, 3);
x_44 = lean_ctor_get(x_1, 4);
x_45 = lean_ctor_get(x_1, 5);
x_46 = lean_ctor_get(x_40, 0);
lean_inc(x_46);
x_47 = lean_ctor_get_uint8(x_40, sizeof(void*)*2);
x_48 = lean_ctor_get(x_40, 1);
lean_inc(x_48);
if (lean_is_exclusive(x_40)) {
 lean_ctor_release(x_40, 0);
 lean_ctor_release(x_40, 1);
 x_49 = x_40;
} else {
 lean_dec_ref(x_40);
 x_49 = lean_box(0);
}
x_50 = 0;
x_51 = lp_padctl_instDecidableEqTapHoldPhase(x_47, x_50);
if (x_51 == 0)
{
lean_dec(x_49);
lean_dec(x_48);
lean_dec(x_46);
return x_1;
}
else
{
lean_object* x_52; uint8_t x_53; lean_object* x_54; lean_object* x_55; lean_object* x_56; 
lean_inc(x_45);
lean_inc(x_44);
lean_inc(x_43);
lean_inc(x_42);
lean_inc(x_41);
if (lean_is_exclusive(x_1)) {
 lean_ctor_release(x_1, 0);
 lean_ctor_release(x_1, 1);
 lean_ctor_release(x_1, 2);
 lean_ctor_release(x_1, 3);
 lean_ctor_release(x_1, 4);
 lean_ctor_release(x_1, 5);
 x_52 = x_1;
} else {
 lean_dec_ref(x_1);
 x_52 = lean_box(0);
}
x_53 = 1;
if (lean_is_scalar(x_49)) {
 x_54 = lean_alloc_ctor(0, 2, 2);
} else {
 x_54 = x_49;
}
lean_ctor_set(x_54, 0, x_46);
lean_ctor_set(x_54, 1, x_48);
lean_ctor_set_uint8(x_54, sizeof(void*)*2, x_53);
lean_ctor_set_uint8(x_54, sizeof(void*)*2 + 1, x_51);
x_55 = lean_alloc_ctor(1, 1, 0);
lean_ctor_set(x_55, 0, x_54);
if (lean_is_scalar(x_52)) {
 x_56 = lean_alloc_ctor(0, 6, 0);
} else {
 x_56 = x_52;
}
lean_ctor_set(x_56, 0, x_41);
lean_ctor_set(x_56, 1, x_42);
lean_ctor_set(x_56, 2, x_55);
lean_ctor_set(x_56, 3, x_43);
lean_ctor_set(x_56, 4, x_44);
lean_ctor_set(x_56, 5, x_45);
return x_56;
}
}
}
}
}
LEAN_EXPORT lean_object* lp_padctl_advanceTimer(lean_object* x_1, lean_object* x_2, lean_object* x_3) {
_start:
{
lean_object* x_4; 
x_4 = lean_ctor_get(x_1, 2);
lean_inc(x_4);
if (lean_obj_tag(x_4) == 0)
{
return x_1;
}
else
{
lean_object* x_5; lean_object* x_6; lean_object* x_7; lean_object* x_8; lean_object* x_9; lean_object* x_10; lean_object* x_11; lean_object* x_12; uint8_t x_13; uint8_t x_14; lean_object* x_15; lean_object* x_16; uint8_t x_17; uint8_t x_18; 
x_5 = lean_ctor_get(x_4, 0);
lean_inc(x_5);
if (lean_is_exclusive(x_4)) {
 lean_ctor_release(x_4, 0);
 x_6 = x_4;
} else {
 lean_dec_ref(x_4);
 x_6 = lean_box(0);
}
x_7 = lean_ctor_get(x_1, 0);
x_8 = lean_ctor_get(x_1, 1);
x_9 = lean_ctor_get(x_1, 3);
x_10 = lean_ctor_get(x_1, 4);
x_11 = lean_ctor_get(x_1, 5);
x_12 = lean_ctor_get(x_5, 0);
lean_inc(x_12);
x_13 = lean_ctor_get_uint8(x_5, sizeof(void*)*2);
x_14 = lean_ctor_get_uint8(x_5, sizeof(void*)*2 + 1);
x_15 = lean_ctor_get(x_5, 1);
lean_inc(x_15);
if (lean_is_exclusive(x_5)) {
 lean_ctor_release(x_5, 0);
 lean_ctor_release(x_5, 1);
 x_16 = x_5;
} else {
 lean_dec_ref(x_5);
 x_16 = lean_box(0);
}
x_17 = 0;
x_18 = lp_padctl_instDecidableEqTapHoldPhase(x_13, x_17);
if (x_18 == 0)
{
lean_dec(x_16);
lean_dec(x_15);
lean_dec(x_12);
lean_dec(x_6);
return x_1;
}
else
{
lean_object* x_19; lean_object* x_20; lean_object* x_21; lean_object* x_31; 
lean_inc(x_11);
lean_inc(x_10);
lean_inc(x_9);
lean_inc(x_8);
lean_inc(x_7);
if (lean_is_exclusive(x_1)) {
 lean_ctor_release(x_1, 0);
 lean_ctor_release(x_1, 1);
 lean_ctor_release(x_1, 2);
 lean_ctor_release(x_1, 3);
 lean_ctor_release(x_1, 4);
 lean_ctor_release(x_1, 5);
 x_19 = x_1;
} else {
 lean_dec_ref(x_1);
 x_19 = lean_box(0);
}
x_20 = lean_nat_add(x_15, x_2);
lean_dec(x_15);
lean_inc(x_12);
x_31 = l_List_get_x3fInternal___redArg(x_3, x_12);
if (lean_obj_tag(x_31) == 0)
{
lean_object* x_32; 
x_32 = lean_unsigned_to_nat(200u);
x_21 = x_32;
goto block_30;
}
else
{
lean_object* x_33; lean_object* x_34; 
x_33 = lean_ctor_get(x_31, 0);
lean_inc(x_33);
lean_dec_ref(x_31);
x_34 = lean_ctor_get(x_33, 1);
lean_inc(x_34);
lean_dec(x_33);
x_21 = x_34;
goto block_30;
}
block_30:
{
uint8_t x_22; 
x_22 = lean_nat_dec_le(x_21, x_20);
lean_dec(x_21);
if (x_22 == 0)
{
lean_object* x_23; lean_object* x_24; lean_object* x_25; 
if (lean_is_scalar(x_16)) {
 x_23 = lean_alloc_ctor(0, 2, 2);
} else {
 x_23 = x_16;
}
lean_ctor_set(x_23, 0, x_12);
lean_ctor_set(x_23, 1, x_20);
lean_ctor_set_uint8(x_23, sizeof(void*)*2, x_13);
lean_ctor_set_uint8(x_23, sizeof(void*)*2 + 1, x_14);
if (lean_is_scalar(x_6)) {
 x_24 = lean_alloc_ctor(1, 1, 0);
} else {
 x_24 = x_6;
}
lean_ctor_set(x_24, 0, x_23);
if (lean_is_scalar(x_19)) {
 x_25 = lean_alloc_ctor(0, 6, 0);
} else {
 x_25 = x_19;
}
lean_ctor_set(x_25, 0, x_7);
lean_ctor_set(x_25, 1, x_8);
lean_ctor_set(x_25, 2, x_24);
lean_ctor_set(x_25, 3, x_9);
lean_ctor_set(x_25, 4, x_10);
lean_ctor_set(x_25, 5, x_11);
return x_25;
}
else
{
uint8_t x_26; lean_object* x_27; lean_object* x_28; lean_object* x_29; 
x_26 = 1;
if (lean_is_scalar(x_16)) {
 x_27 = lean_alloc_ctor(0, 2, 2);
} else {
 x_27 = x_16;
}
lean_ctor_set(x_27, 0, x_12);
lean_ctor_set(x_27, 1, x_20);
lean_ctor_set_uint8(x_27, sizeof(void*)*2, x_26);
lean_ctor_set_uint8(x_27, sizeof(void*)*2 + 1, x_18);
if (lean_is_scalar(x_6)) {
 x_28 = lean_alloc_ctor(1, 1, 0);
} else {
 x_28 = x_6;
}
lean_ctor_set(x_28, 0, x_27);
if (lean_is_scalar(x_19)) {
 x_29 = lean_alloc_ctor(0, 6, 0);
} else {
 x_29 = x_19;
}
lean_ctor_set(x_29, 0, x_7);
lean_ctor_set(x_29, 1, x_8);
lean_ctor_set(x_29, 2, x_28);
lean_ctor_set(x_29, 3, x_9);
lean_ctor_set(x_29, 4, x_10);
lean_ctor_set(x_29, 5, x_11);
return x_29;
}
}
}
}
}
}
LEAN_EXPORT lean_object* lp_padctl_advanceTimer___boxed(lean_object* x_1, lean_object* x_2, lean_object* x_3) {
_start:
{
lean_object* x_4; 
x_4 = lp_padctl_advanceTimer(x_1, x_2, x_3);
lean_dec(x_3);
lean_dec(x_2);
return x_4;
}
}
LEAN_EXPORT uint8_t lp_padctl_instDecidableEqTapEvent_decEq(lean_object* x_1, lean_object* x_2) {
_start:
{
uint8_t x_3; 
x_3 = lean_nat_dec_eq(x_1, x_2);
return x_3;
}
}
LEAN_EXPORT lean_object* lp_padctl_instDecidableEqTapEvent_decEq___boxed(lean_object* x_1, lean_object* x_2) {
_start:
{
uint8_t x_3; lean_object* x_4; 
x_3 = lp_padctl_instDecidableEqTapEvent_decEq(x_1, x_2);
lean_dec(x_2);
lean_dec(x_1);
x_4 = lean_box(x_3);
return x_4;
}
}
LEAN_EXPORT uint8_t lp_padctl_instDecidableEqTapEvent(lean_object* x_1, lean_object* x_2) {
_start:
{
uint8_t x_3; 
x_3 = lean_nat_dec_eq(x_1, x_2);
return x_3;
}
}
LEAN_EXPORT lean_object* lp_padctl_instDecidableEqTapEvent___boxed(lean_object* x_1, lean_object* x_2) {
_start:
{
uint8_t x_3; lean_object* x_4; 
x_3 = lp_padctl_instDecidableEqTapEvent(x_1, x_2);
lean_dec(x_2);
lean_dec(x_1);
x_4 = lean_box(x_3);
return x_4;
}
}
LEAN_EXPORT lean_object* lp_padctl_instReprTapEvent_repr___redArg(lean_object* x_1) {
_start:
{
lean_object* x_2; lean_object* x_3; lean_object* x_4; lean_object* x_5; lean_object* x_6; uint8_t x_7; lean_object* x_8; lean_object* x_9; lean_object* x_10; lean_object* x_11; lean_object* x_12; lean_object* x_13; lean_object* x_14; lean_object* x_15; lean_object* x_16; 
x_2 = ((lean_object*)(lp_padctl_instReprTapEvent_repr___redArg___closed__3));
x_3 = lean_obj_once(&lp_padctl_instReprTapHoldState_repr___redArg___closed__13, &lp_padctl_instReprTapHoldState_repr___redArg___closed__13_once, _init_lp_padctl_instReprTapHoldState_repr___redArg___closed__13);
x_4 = l_Nat_reprFast(x_1);
x_5 = lean_alloc_ctor(3, 1, 0);
lean_ctor_set(x_5, 0, x_4);
x_6 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_6, 0, x_3);
lean_ctor_set(x_6, 1, x_5);
x_7 = 0;
x_8 = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(x_8, 0, x_6);
lean_ctor_set_uint8(x_8, sizeof(void*)*1, x_7);
x_9 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_9, 0, x_2);
lean_ctor_set(x_9, 1, x_8);
x_10 = lean_obj_once(&lp_padctl_instReprLayerConfig_repr___redArg___closed__18, &lp_padctl_instReprLayerConfig_repr___redArg___closed__18_once, _init_lp_padctl_instReprLayerConfig_repr___redArg___closed__18);
x_11 = ((lean_object*)(lp_padctl_instReprLayerConfig_repr___redArg___closed__19));
x_12 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_12, 0, x_11);
lean_ctor_set(x_12, 1, x_9);
x_13 = ((lean_object*)(lp_padctl_instReprLayerConfig_repr___redArg___closed__20));
x_14 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_14, 0, x_12);
lean_ctor_set(x_14, 1, x_13);
x_15 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_15, 0, x_10);
lean_ctor_set(x_15, 1, x_14);
x_16 = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(x_16, 0, x_15);
lean_ctor_set_uint8(x_16, sizeof(void*)*1, x_7);
return x_16;
}
}
LEAN_EXPORT lean_object* lp_padctl_instReprTapEvent_repr(lean_object* x_1, lean_object* x_2) {
_start:
{
lean_object* x_3; 
x_3 = lp_padctl_instReprTapEvent_repr___redArg(x_1);
return x_3;
}
}
LEAN_EXPORT lean_object* lp_padctl_instReprTapEvent_repr___boxed(lean_object* x_1, lean_object* x_2) {
_start:
{
lean_object* x_3; 
x_3 = lp_padctl_instReprTapEvent_repr(x_1, x_2);
lean_dec(x_2);
return x_3;
}
}
LEAN_EXPORT lean_object* lp_padctl_onTriggerRelease(lean_object* x_1) {
_start:
{
lean_object* x_2; 
x_2 = lean_ctor_get(x_1, 2);
lean_inc(x_2);
if (lean_obj_tag(x_2) == 0)
{
lean_object* x_3; lean_object* x_4; 
x_3 = lean_box(0);
x_4 = lean_alloc_ctor(0, 2, 0);
lean_ctor_set(x_4, 0, x_1);
lean_ctor_set(x_4, 1, x_3);
return x_4;
}
else
{
uint8_t x_5; 
x_5 = !lean_is_exclusive(x_2);
if (x_5 == 0)
{
uint8_t x_6; 
x_6 = !lean_is_exclusive(x_1);
if (x_6 == 0)
{
lean_object* x_7; lean_object* x_8; lean_object* x_9; uint8_t x_10; uint8_t x_11; uint8_t x_12; 
x_7 = lean_ctor_get(x_2, 0);
x_8 = lean_ctor_get(x_1, 2);
lean_dec(x_8);
x_9 = lean_ctor_get(x_7, 0);
lean_inc(x_9);
x_10 = lean_ctor_get_uint8(x_7, sizeof(void*)*2);
lean_dec(x_7);
x_11 = 0;
x_12 = lp_padctl_instDecidableEqTapHoldPhase(x_10, x_11);
if (x_12 == 0)
{
lean_object* x_13; lean_object* x_14; 
lean_dec(x_9);
lean_free_object(x_2);
x_13 = lean_box(0);
lean_ctor_set(x_1, 2, x_13);
x_14 = lean_alloc_ctor(0, 2, 0);
lean_ctor_set(x_14, 0, x_1);
lean_ctor_set(x_14, 1, x_13);
return x_14;
}
else
{
lean_object* x_15; lean_object* x_16; 
x_15 = lean_box(0);
lean_ctor_set(x_1, 2, x_15);
lean_ctor_set(x_2, 0, x_9);
x_16 = lean_alloc_ctor(0, 2, 0);
lean_ctor_set(x_16, 0, x_1);
lean_ctor_set(x_16, 1, x_2);
return x_16;
}
}
else
{
lean_object* x_17; lean_object* x_18; lean_object* x_19; lean_object* x_20; lean_object* x_21; lean_object* x_22; lean_object* x_23; uint8_t x_24; uint8_t x_25; uint8_t x_26; 
x_17 = lean_ctor_get(x_2, 0);
x_18 = lean_ctor_get(x_1, 0);
x_19 = lean_ctor_get(x_1, 1);
x_20 = lean_ctor_get(x_1, 3);
x_21 = lean_ctor_get(x_1, 4);
x_22 = lean_ctor_get(x_1, 5);
lean_inc(x_22);
lean_inc(x_21);
lean_inc(x_20);
lean_inc(x_19);
lean_inc(x_18);
lean_dec(x_1);
x_23 = lean_ctor_get(x_17, 0);
lean_inc(x_23);
x_24 = lean_ctor_get_uint8(x_17, sizeof(void*)*2);
lean_dec(x_17);
x_25 = 0;
x_26 = lp_padctl_instDecidableEqTapHoldPhase(x_24, x_25);
if (x_26 == 0)
{
lean_object* x_27; lean_object* x_28; lean_object* x_29; 
lean_dec(x_23);
lean_free_object(x_2);
x_27 = lean_box(0);
x_28 = lean_alloc_ctor(0, 6, 0);
lean_ctor_set(x_28, 0, x_18);
lean_ctor_set(x_28, 1, x_19);
lean_ctor_set(x_28, 2, x_27);
lean_ctor_set(x_28, 3, x_20);
lean_ctor_set(x_28, 4, x_21);
lean_ctor_set(x_28, 5, x_22);
x_29 = lean_alloc_ctor(0, 2, 0);
lean_ctor_set(x_29, 0, x_28);
lean_ctor_set(x_29, 1, x_27);
return x_29;
}
else
{
lean_object* x_30; lean_object* x_31; lean_object* x_32; 
x_30 = lean_box(0);
x_31 = lean_alloc_ctor(0, 6, 0);
lean_ctor_set(x_31, 0, x_18);
lean_ctor_set(x_31, 1, x_19);
lean_ctor_set(x_31, 2, x_30);
lean_ctor_set(x_31, 3, x_20);
lean_ctor_set(x_31, 4, x_21);
lean_ctor_set(x_31, 5, x_22);
lean_ctor_set(x_2, 0, x_23);
x_32 = lean_alloc_ctor(0, 2, 0);
lean_ctor_set(x_32, 0, x_31);
lean_ctor_set(x_32, 1, x_2);
return x_32;
}
}
}
else
{
lean_object* x_33; lean_object* x_34; lean_object* x_35; lean_object* x_36; lean_object* x_37; lean_object* x_38; lean_object* x_39; lean_object* x_40; uint8_t x_41; uint8_t x_42; uint8_t x_43; 
x_33 = lean_ctor_get(x_2, 0);
lean_inc(x_33);
lean_dec(x_2);
x_34 = lean_ctor_get(x_1, 0);
lean_inc(x_34);
x_35 = lean_ctor_get(x_1, 1);
lean_inc(x_35);
x_36 = lean_ctor_get(x_1, 3);
lean_inc(x_36);
x_37 = lean_ctor_get(x_1, 4);
lean_inc(x_37);
x_38 = lean_ctor_get(x_1, 5);
lean_inc(x_38);
if (lean_is_exclusive(x_1)) {
 lean_ctor_release(x_1, 0);
 lean_ctor_release(x_1, 1);
 lean_ctor_release(x_1, 2);
 lean_ctor_release(x_1, 3);
 lean_ctor_release(x_1, 4);
 lean_ctor_release(x_1, 5);
 x_39 = x_1;
} else {
 lean_dec_ref(x_1);
 x_39 = lean_box(0);
}
x_40 = lean_ctor_get(x_33, 0);
lean_inc(x_40);
x_41 = lean_ctor_get_uint8(x_33, sizeof(void*)*2);
lean_dec(x_33);
x_42 = 0;
x_43 = lp_padctl_instDecidableEqTapHoldPhase(x_41, x_42);
if (x_43 == 0)
{
lean_object* x_44; lean_object* x_45; lean_object* x_46; 
lean_dec(x_40);
x_44 = lean_box(0);
if (lean_is_scalar(x_39)) {
 x_45 = lean_alloc_ctor(0, 6, 0);
} else {
 x_45 = x_39;
}
lean_ctor_set(x_45, 0, x_34);
lean_ctor_set(x_45, 1, x_35);
lean_ctor_set(x_45, 2, x_44);
lean_ctor_set(x_45, 3, x_36);
lean_ctor_set(x_45, 4, x_37);
lean_ctor_set(x_45, 5, x_38);
x_46 = lean_alloc_ctor(0, 2, 0);
lean_ctor_set(x_46, 0, x_45);
lean_ctor_set(x_46, 1, x_44);
return x_46;
}
else
{
lean_object* x_47; lean_object* x_48; lean_object* x_49; lean_object* x_50; 
x_47 = lean_box(0);
if (lean_is_scalar(x_39)) {
 x_48 = lean_alloc_ctor(0, 6, 0);
} else {
 x_48 = x_39;
}
lean_ctor_set(x_48, 0, x_34);
lean_ctor_set(x_48, 1, x_35);
lean_ctor_set(x_48, 2, x_47);
lean_ctor_set(x_48, 3, x_36);
lean_ctor_set(x_48, 4, x_37);
lean_ctor_set(x_48, 5, x_38);
x_49 = lean_alloc_ctor(1, 1, 0);
lean_ctor_set(x_49, 0, x_40);
x_50 = lean_alloc_ctor(0, 2, 0);
lean_ctor_set(x_50, 0, x_48);
lean_ctor_set(x_50, 1, x_49);
return x_50;
}
}
}
}
}
LEAN_EXPORT lean_object* lp_padctl___private_Padctl_Mapper_0__firstToggled(lean_object* x_1, lean_object* x_2) {
_start:
{
if (lean_obj_tag(x_1) == 0)
{
lean_object* x_3; 
lean_dec(x_2);
x_3 = lean_box(0);
return x_3;
}
else
{
lean_object* x_4; uint8_t x_5; 
x_4 = lean_ctor_get(x_1, 0);
x_5 = lean_unbox(x_4);
if (x_5 == 0)
{
lean_object* x_6; lean_object* x_7; lean_object* x_8; 
x_6 = lean_ctor_get(x_1, 1);
x_7 = lean_unsigned_to_nat(1u);
x_8 = lean_nat_add(x_2, x_7);
lean_dec(x_2);
x_1 = x_6;
x_2 = x_8;
goto _start;
}
else
{
lean_object* x_10; 
x_10 = lean_alloc_ctor(1, 1, 0);
lean_ctor_set(x_10, 0, x_2);
return x_10;
}
}
}
}
LEAN_EXPORT lean_object* lp_padctl___private_Padctl_Mapper_0__firstToggled___boxed(lean_object* x_1, lean_object* x_2) {
_start:
{
lean_object* x_3; 
x_3 = lp_padctl___private_Padctl_Mapper_0__firstToggled(x_1, x_2);
lean_dec(x_1);
return x_3;
}
}
LEAN_EXPORT lean_object* lp_padctl_getActiveLayer(lean_object* x_1, lean_object* x_2) {
_start:
{
lean_object* x_3; lean_object* x_4; 
x_3 = lean_ctor_get(x_1, 2);
lean_inc(x_3);
x_4 = lean_ctor_get(x_1, 3);
lean_inc(x_4);
lean_dec_ref(x_1);
if (lean_obj_tag(x_3) == 0)
{
lean_object* x_8; lean_object* x_9; 
x_8 = lean_unsigned_to_nat(0u);
x_9 = lp_padctl___private_Padctl_Mapper_0__firstToggled(x_4, x_8);
lean_dec(x_4);
return x_9;
}
else
{
uint8_t x_10; 
x_10 = !lean_is_exclusive(x_3);
if (x_10 == 0)
{
lean_object* x_11; uint8_t x_12; 
x_11 = lean_ctor_get(x_3, 0);
x_12 = lean_ctor_get_uint8(x_11, sizeof(void*)*2 + 1);
if (x_12 == 0)
{
lean_free_object(x_3);
lean_dec(x_11);
goto block_7;
}
else
{
lean_object* x_13; lean_object* x_14; uint8_t x_15; 
x_13 = lean_ctor_get(x_11, 0);
lean_inc(x_13);
lean_dec(x_11);
x_14 = l_List_lengthTR___redArg(x_2);
x_15 = lean_nat_dec_lt(x_13, x_14);
lean_dec(x_14);
if (x_15 == 0)
{
lean_dec(x_13);
lean_free_object(x_3);
goto block_7;
}
else
{
lean_dec(x_4);
lean_ctor_set(x_3, 0, x_13);
return x_3;
}
}
}
else
{
lean_object* x_16; uint8_t x_17; 
x_16 = lean_ctor_get(x_3, 0);
lean_inc(x_16);
lean_dec(x_3);
x_17 = lean_ctor_get_uint8(x_16, sizeof(void*)*2 + 1);
if (x_17 == 0)
{
lean_dec(x_16);
goto block_7;
}
else
{
lean_object* x_18; lean_object* x_19; uint8_t x_20; 
x_18 = lean_ctor_get(x_16, 0);
lean_inc(x_18);
lean_dec(x_16);
x_19 = l_List_lengthTR___redArg(x_2);
x_20 = lean_nat_dec_lt(x_18, x_19);
lean_dec(x_19);
if (x_20 == 0)
{
lean_dec(x_18);
goto block_7;
}
else
{
lean_object* x_21; 
lean_dec(x_4);
x_21 = lean_alloc_ctor(1, 1, 0);
lean_ctor_set(x_21, 0, x_18);
return x_21;
}
}
}
}
block_7:
{
lean_object* x_5; lean_object* x_6; 
x_5 = lean_unsigned_to_nat(0u);
x_6 = lp_padctl___private_Padctl_Mapper_0__firstToggled(x_4, x_5);
lean_dec(x_4);
return x_6;
}
}
}
LEAN_EXPORT lean_object* lp_padctl_getActiveLayer___boxed(lean_object* x_1, lean_object* x_2) {
_start:
{
lean_object* x_3; 
x_3 = lp_padctl_getActiveLayer(x_1, x_2);
lean_dec(x_2);
return x_3;
}
}
static lean_object* _init_lp_padctl___private_Padctl_Mapper_0__processLayerTriggersAux___closed__0(void) {
_start:
{
lean_object* x_1; lean_object* x_2; 
x_1 = lean_unsigned_to_nat(0u);
x_2 = lean_mk_empty_array_with_capacity(x_1);
return x_2;
}
}
LEAN_EXPORT lean_object* lp_padctl___private_Padctl_Mapper_0__processLayerTriggersAux(lean_object* x_1, lean_object* x_2, lean_object* x_3) {
_start:
{
if (lean_obj_tag(x_1) == 0)
{
lean_dec(x_3);
return x_2;
}
else
{
lean_object* x_4; lean_object* x_5; lean_object* x_6; lean_object* x_11; lean_object* x_12; lean_object* x_13; lean_object* x_14; lean_object* x_15; lean_object* x_16; lean_object* x_17; uint8_t x_18; uint8_t x_19; uint8_t x_20; uint8_t x_47; uint8_t x_49; 
x_4 = lean_ctor_get(x_1, 0);
x_5 = lean_ctor_get(x_1, 1);
x_11 = lean_ctor_get(x_2, 0);
x_12 = lean_ctor_get(x_2, 1);
x_13 = lean_ctor_get(x_2, 2);
x_14 = lean_ctor_get(x_2, 3);
x_15 = lean_ctor_get(x_2, 4);
x_16 = lean_ctor_get(x_2, 5);
x_17 = lean_ctor_get(x_4, 0);
x_18 = lean_ctor_get_uint8(x_4, sizeof(void*)*2);
x_19 = lp_padctl_testBit(x_11, x_17);
x_20 = lp_padctl_testBit(x_12, x_17);
if (x_18 == 0)
{
if (x_19 == 0)
{
x_49 = x_19;
goto block_51;
}
else
{
if (x_20 == 0)
{
x_49 = x_19;
goto block_51;
}
else
{
uint8_t x_52; 
x_52 = 0;
x_47 = x_52;
goto block_48;
}
}
}
else
{
if (x_19 == 0)
{
if (x_20 == 0)
{
x_6 = x_2;
goto block_10;
}
else
{
lean_object* x_53; lean_object* x_54; uint8_t x_55; 
x_53 = lean_box(x_19);
lean_inc(x_3);
x_54 = l_List_getD___redArg(x_14, x_3, x_53);
lean_dec(x_53);
x_55 = lean_unbox(x_54);
if (x_55 == 0)
{
lean_object* x_56; 
lean_inc_ref(x_2);
x_56 = lp_padctl_getActiveLayer(x_2, x_1);
if (lean_obj_tag(x_56) == 0)
{
uint8_t x_57; 
x_57 = lean_unbox(x_54);
lean_dec(x_54);
if (x_57 == 0)
{
uint8_t x_58; 
lean_inc(x_16);
lean_inc(x_15);
lean_inc(x_14);
lean_inc(x_13);
lean_inc(x_12);
lean_inc(x_11);
x_58 = !lean_is_exclusive(x_2);
if (x_58 == 0)
{
lean_object* x_59; lean_object* x_60; lean_object* x_61; lean_object* x_62; lean_object* x_63; lean_object* x_64; lean_object* x_65; lean_object* x_66; lean_object* x_67; 
x_59 = lean_ctor_get(x_2, 5);
lean_dec(x_59);
x_60 = lean_ctor_get(x_2, 4);
lean_dec(x_60);
x_61 = lean_ctor_get(x_2, 3);
lean_dec(x_61);
x_62 = lean_ctor_get(x_2, 2);
lean_dec(x_62);
x_63 = lean_ctor_get(x_2, 1);
lean_dec(x_63);
x_64 = lean_ctor_get(x_2, 0);
lean_dec(x_64);
x_65 = lean_obj_once(&lp_padctl___private_Padctl_Mapper_0__processLayerTriggersAux___closed__0, &lp_padctl___private_Padctl_Mapper_0__processLayerTriggersAux___closed__0_once, _init_lp_padctl___private_Padctl_Mapper_0__processLayerTriggersAux___closed__0);
x_66 = lean_box(x_20);
lean_inc(x_3);
lean_inc(x_14);
x_67 = l___private_Init_Data_List_Impl_0__List_setTR_go___redArg(x_14, x_66, x_14, x_3, x_65);
lean_dec(x_14);
lean_ctor_set(x_2, 3, x_67);
x_6 = x_2;
goto block_10;
}
else
{
lean_object* x_68; lean_object* x_69; lean_object* x_70; lean_object* x_71; 
lean_dec(x_2);
x_68 = lean_obj_once(&lp_padctl___private_Padctl_Mapper_0__processLayerTriggersAux___closed__0, &lp_padctl___private_Padctl_Mapper_0__processLayerTriggersAux___closed__0_once, _init_lp_padctl___private_Padctl_Mapper_0__processLayerTriggersAux___closed__0);
x_69 = lean_box(x_20);
lean_inc(x_3);
lean_inc(x_14);
x_70 = l___private_Init_Data_List_Impl_0__List_setTR_go___redArg(x_14, x_69, x_14, x_3, x_68);
lean_dec(x_14);
x_71 = lean_alloc_ctor(0, 6, 0);
lean_ctor_set(x_71, 0, x_11);
lean_ctor_set(x_71, 1, x_12);
lean_ctor_set(x_71, 2, x_13);
lean_ctor_set(x_71, 3, x_70);
lean_ctor_set(x_71, 4, x_15);
lean_ctor_set(x_71, 5, x_16);
x_6 = x_71;
goto block_10;
}
}
else
{
x_6 = x_2;
goto block_10;
}
}
else
{
lean_dec_ref(x_56);
lean_dec(x_54);
x_6 = x_2;
goto block_10;
}
}
else
{
uint8_t x_72; 
lean_inc(x_16);
lean_inc(x_15);
lean_inc(x_14);
lean_inc(x_13);
lean_inc(x_12);
lean_inc(x_11);
lean_dec(x_54);
x_72 = !lean_is_exclusive(x_2);
if (x_72 == 0)
{
lean_object* x_73; lean_object* x_74; lean_object* x_75; lean_object* x_76; lean_object* x_77; lean_object* x_78; lean_object* x_79; lean_object* x_80; lean_object* x_81; 
x_73 = lean_ctor_get(x_2, 5);
lean_dec(x_73);
x_74 = lean_ctor_get(x_2, 4);
lean_dec(x_74);
x_75 = lean_ctor_get(x_2, 3);
lean_dec(x_75);
x_76 = lean_ctor_get(x_2, 2);
lean_dec(x_76);
x_77 = lean_ctor_get(x_2, 1);
lean_dec(x_77);
x_78 = lean_ctor_get(x_2, 0);
lean_dec(x_78);
x_79 = lean_obj_once(&lp_padctl___private_Padctl_Mapper_0__processLayerTriggersAux___closed__0, &lp_padctl___private_Padctl_Mapper_0__processLayerTriggersAux___closed__0_once, _init_lp_padctl___private_Padctl_Mapper_0__processLayerTriggersAux___closed__0);
x_80 = lean_box(x_19);
lean_inc(x_3);
lean_inc(x_14);
x_81 = l___private_Init_Data_List_Impl_0__List_setTR_go___redArg(x_14, x_80, x_14, x_3, x_79);
lean_dec(x_14);
lean_ctor_set(x_2, 3, x_81);
x_6 = x_2;
goto block_10;
}
else
{
lean_object* x_82; lean_object* x_83; lean_object* x_84; lean_object* x_85; 
lean_dec(x_2);
x_82 = lean_obj_once(&lp_padctl___private_Padctl_Mapper_0__processLayerTriggersAux___closed__0, &lp_padctl___private_Padctl_Mapper_0__processLayerTriggersAux___closed__0_once, _init_lp_padctl___private_Padctl_Mapper_0__processLayerTriggersAux___closed__0);
x_83 = lean_box(x_19);
lean_inc(x_3);
lean_inc(x_14);
x_84 = l___private_Init_Data_List_Impl_0__List_setTR_go___redArg(x_14, x_83, x_14, x_3, x_82);
lean_dec(x_14);
x_85 = lean_alloc_ctor(0, 6, 0);
lean_ctor_set(x_85, 0, x_11);
lean_ctor_set(x_85, 1, x_12);
lean_ctor_set(x_85, 2, x_13);
lean_ctor_set(x_85, 3, x_84);
lean_ctor_set(x_85, 4, x_15);
lean_ctor_set(x_85, 5, x_16);
x_6 = x_85;
goto block_10;
}
}
}
}
else
{
x_6 = x_2;
goto block_10;
}
}
block_10:
{
lean_object* x_7; lean_object* x_8; 
x_7 = lean_unsigned_to_nat(1u);
x_8 = lean_nat_add(x_3, x_7);
lean_dec(x_3);
x_1 = x_5;
x_2 = x_6;
x_3 = x_8;
goto _start;
}
block_46:
{
if (x_20 == 0)
{
x_6 = x_2;
goto block_10;
}
else
{
if (lean_obj_tag(x_13) == 0)
{
x_6 = x_2;
goto block_10;
}
else
{
lean_object* x_21; lean_object* x_22; uint8_t x_23; 
x_21 = lean_ctor_get(x_13, 0);
x_22 = lean_ctor_get(x_21, 0);
x_23 = lean_nat_dec_eq(x_22, x_3);
if (x_23 == 0)
{
x_6 = x_2;
goto block_10;
}
else
{
lean_object* x_24; lean_object* x_25; 
x_24 = lp_padctl_onTriggerRelease(x_2);
x_25 = lean_ctor_get(x_24, 1);
lean_inc(x_25);
if (lean_obj_tag(x_25) == 0)
{
lean_object* x_26; 
x_26 = lean_ctor_get(x_24, 0);
lean_inc(x_26);
lean_dec_ref(x_24);
x_6 = x_26;
goto block_10;
}
else
{
lean_object* x_27; uint8_t x_28; 
x_27 = lean_ctor_get(x_24, 0);
lean_inc(x_27);
lean_dec_ref(x_24);
x_28 = !lean_is_exclusive(x_25);
if (x_28 == 0)
{
uint8_t x_29; 
x_29 = !lean_is_exclusive(x_27);
if (x_29 == 0)
{
lean_object* x_30; 
x_30 = lean_ctor_get(x_27, 5);
lean_dec(x_30);
lean_ctor_set(x_27, 5, x_25);
x_6 = x_27;
goto block_10;
}
else
{
lean_object* x_31; lean_object* x_32; lean_object* x_33; lean_object* x_34; lean_object* x_35; lean_object* x_36; 
x_31 = lean_ctor_get(x_27, 0);
x_32 = lean_ctor_get(x_27, 1);
x_33 = lean_ctor_get(x_27, 2);
x_34 = lean_ctor_get(x_27, 3);
x_35 = lean_ctor_get(x_27, 4);
lean_inc(x_35);
lean_inc(x_34);
lean_inc(x_33);
lean_inc(x_32);
lean_inc(x_31);
lean_dec(x_27);
x_36 = lean_alloc_ctor(0, 6, 0);
lean_ctor_set(x_36, 0, x_31);
lean_ctor_set(x_36, 1, x_32);
lean_ctor_set(x_36, 2, x_33);
lean_ctor_set(x_36, 3, x_34);
lean_ctor_set(x_36, 4, x_35);
lean_ctor_set(x_36, 5, x_25);
x_6 = x_36;
goto block_10;
}
}
else
{
lean_object* x_37; lean_object* x_38; lean_object* x_39; lean_object* x_40; lean_object* x_41; lean_object* x_42; lean_object* x_43; lean_object* x_44; lean_object* x_45; 
x_37 = lean_ctor_get(x_25, 0);
lean_inc(x_37);
lean_dec(x_25);
x_38 = lean_ctor_get(x_27, 0);
lean_inc(x_38);
x_39 = lean_ctor_get(x_27, 1);
lean_inc(x_39);
x_40 = lean_ctor_get(x_27, 2);
lean_inc(x_40);
x_41 = lean_ctor_get(x_27, 3);
lean_inc(x_41);
x_42 = lean_ctor_get(x_27, 4);
lean_inc(x_42);
if (lean_is_exclusive(x_27)) {
 lean_ctor_release(x_27, 0);
 lean_ctor_release(x_27, 1);
 lean_ctor_release(x_27, 2);
 lean_ctor_release(x_27, 3);
 lean_ctor_release(x_27, 4);
 lean_ctor_release(x_27, 5);
 x_43 = x_27;
} else {
 lean_dec_ref(x_27);
 x_43 = lean_box(0);
}
x_44 = lean_alloc_ctor(1, 1, 0);
lean_ctor_set(x_44, 0, x_37);
if (lean_is_scalar(x_43)) {
 x_45 = lean_alloc_ctor(0, 6, 0);
} else {
 x_45 = x_43;
}
lean_ctor_set(x_45, 0, x_38);
lean_ctor_set(x_45, 1, x_39);
lean_ctor_set(x_45, 2, x_40);
lean_ctor_set(x_45, 3, x_41);
lean_ctor_set(x_45, 4, x_42);
lean_ctor_set(x_45, 5, x_44);
x_6 = x_45;
goto block_10;
}
}
}
}
}
}
block_48:
{
if (x_19 == 0)
{
goto block_46;
}
else
{
if (x_47 == 0)
{
x_6 = x_2;
goto block_10;
}
else
{
goto block_46;
}
}
}
block_51:
{
if (x_49 == 0)
{
x_47 = x_49;
goto block_48;
}
else
{
if (lean_obj_tag(x_13) == 0)
{
lean_object* x_50; 
lean_inc(x_3);
x_50 = lp_padctl_onTriggerPress(x_2, x_3);
x_6 = x_50;
goto block_10;
}
else
{
x_6 = x_2;
goto block_10;
}
}
}
}
}
}
LEAN_EXPORT lean_object* lp_padctl___private_Padctl_Mapper_0__processLayerTriggersAux___boxed(lean_object* x_1, lean_object* x_2, lean_object* x_3) {
_start:
{
lean_object* x_4; 
x_4 = lp_padctl___private_Padctl_Mapper_0__processLayerTriggersAux(x_1, x_2, x_3);
lean_dec(x_1);
return x_4;
}
}
LEAN_EXPORT lean_object* lp_padctl___private_Padctl_Mapper_0__padToggled(lean_object* x_1, lean_object* x_2) {
_start:
{
lean_object* x_3; uint8_t x_4; 
x_3 = l_List_lengthTR___redArg(x_1);
x_4 = lean_nat_dec_le(x_2, x_3);
if (x_4 == 0)
{
lean_object* x_5; lean_object* x_6; lean_object* x_7; lean_object* x_8; 
x_5 = lean_nat_sub(x_2, x_3);
lean_dec(x_3);
x_6 = lean_box(x_4);
x_7 = l_List_replicateTR___redArg(x_5, x_6);
x_8 = l_List_appendTR___redArg(x_1, x_7);
return x_8;
}
else
{
lean_dec(x_3);
return x_1;
}
}
}
LEAN_EXPORT lean_object* lp_padctl___private_Padctl_Mapper_0__padToggled___boxed(lean_object* x_1, lean_object* x_2) {
_start:
{
lean_object* x_3; 
x_3 = lp_padctl___private_Padctl_Mapper_0__padToggled(x_1, x_2);
lean_dec(x_2);
return x_3;
}
}
LEAN_EXPORT lean_object* lp_padctl_processLayerTriggers(lean_object* x_1, lean_object* x_2, lean_object* x_3) {
_start:
{
uint8_t x_4; 
x_4 = !lean_is_exclusive(x_1);
if (x_4 == 0)
{
lean_object* x_5; lean_object* x_6; lean_object* x_7; lean_object* x_8; lean_object* x_9; lean_object* x_10; lean_object* x_11; 
x_5 = lean_ctor_get(x_1, 0);
x_6 = lean_ctor_get(x_1, 3);
x_7 = lean_ctor_get(x_1, 1);
lean_dec(x_7);
x_8 = l_List_lengthTR___redArg(x_3);
x_9 = lp_padctl___private_Padctl_Mapper_0__padToggled(x_6, x_8);
lean_dec(x_8);
lean_ctor_set(x_1, 3, x_9);
lean_ctor_set(x_1, 1, x_5);
lean_ctor_set(x_1, 0, x_2);
x_10 = lean_unsigned_to_nat(0u);
x_11 = lp_padctl___private_Padctl_Mapper_0__processLayerTriggersAux(x_3, x_1, x_10);
return x_11;
}
else
{
lean_object* x_12; lean_object* x_13; lean_object* x_14; lean_object* x_15; lean_object* x_16; lean_object* x_17; lean_object* x_18; lean_object* x_19; lean_object* x_20; lean_object* x_21; 
x_12 = lean_ctor_get(x_1, 0);
x_13 = lean_ctor_get(x_1, 2);
x_14 = lean_ctor_get(x_1, 3);
x_15 = lean_ctor_get(x_1, 4);
x_16 = lean_ctor_get(x_1, 5);
lean_inc(x_16);
lean_inc(x_15);
lean_inc(x_14);
lean_inc(x_13);
lean_inc(x_12);
lean_dec(x_1);
x_17 = l_List_lengthTR___redArg(x_3);
x_18 = lp_padctl___private_Padctl_Mapper_0__padToggled(x_14, x_17);
lean_dec(x_17);
x_19 = lean_alloc_ctor(0, 6, 0);
lean_ctor_set(x_19, 0, x_2);
lean_ctor_set(x_19, 1, x_12);
lean_ctor_set(x_19, 2, x_13);
lean_ctor_set(x_19, 3, x_18);
lean_ctor_set(x_19, 4, x_15);
lean_ctor_set(x_19, 5, x_16);
x_20 = lean_unsigned_to_nat(0u);
x_21 = lp_padctl___private_Padctl_Mapper_0__processLayerTriggersAux(x_3, x_19, x_20);
return x_21;
}
}
}
LEAN_EXPORT lean_object* lp_padctl_processLayerTriggers___boxed(lean_object* x_1, lean_object* x_2, lean_object* x_3) {
_start:
{
lean_object* x_4; 
x_4 = lp_padctl_processLayerTriggers(x_1, x_2, x_3);
lean_dec(x_3);
return x_4;
}
}
LEAN_EXPORT lean_object* lp_padctl_RemapTarget_ctorIdx(lean_object* x_1) {
_start:
{
switch (lean_obj_tag(x_1)) {
case 0:
{
lean_object* x_2; 
x_2 = lean_unsigned_to_nat(0u);
return x_2;
}
case 1:
{
lean_object* x_3; 
x_3 = lean_unsigned_to_nat(1u);
return x_3;
}
case 2:
{
lean_object* x_4; 
x_4 = lean_unsigned_to_nat(2u);
return x_4;
}
case 3:
{
lean_object* x_5; 
x_5 = lean_unsigned_to_nat(3u);
return x_5;
}
default: 
{
lean_object* x_6; 
x_6 = lean_unsigned_to_nat(4u);
return x_6;
}
}
}
}
LEAN_EXPORT lean_object* lp_padctl_RemapTarget_ctorIdx___boxed(lean_object* x_1) {
_start:
{
lean_object* x_2; 
x_2 = lp_padctl_RemapTarget_ctorIdx(x_1);
lean_dec(x_1);
return x_2;
}
}
LEAN_EXPORT lean_object* lp_padctl_RemapTarget_ctorElim___redArg(lean_object* x_1, lean_object* x_2) {
_start:
{
switch (lean_obj_tag(x_1)) {
case 0:
{
lean_object* x_3; lean_object* x_4; 
x_3 = lean_ctor_get(x_1, 0);
lean_inc(x_3);
lean_dec_ref(x_1);
x_4 = lean_apply_1(x_2, x_3);
return x_4;
}
case 1:
{
lean_object* x_5; lean_object* x_6; 
x_5 = lean_ctor_get(x_1, 0);
lean_inc(x_5);
lean_dec_ref(x_1);
x_6 = lean_apply_1(x_2, x_5);
return x_6;
}
case 2:
{
lean_object* x_7; lean_object* x_8; 
x_7 = lean_ctor_get(x_1, 0);
lean_inc(x_7);
lean_dec_ref(x_1);
x_8 = lean_apply_1(x_2, x_7);
return x_8;
}
default: 
{
lean_dec(x_1);
return x_2;
}
}
}
}
LEAN_EXPORT lean_object* lp_padctl_RemapTarget_ctorElim(lean_object* x_1, lean_object* x_2, lean_object* x_3, lean_object* x_4, lean_object* x_5) {
_start:
{
lean_object* x_6; 
x_6 = lp_padctl_RemapTarget_ctorElim___redArg(x_3, x_5);
return x_6;
}
}
LEAN_EXPORT lean_object* lp_padctl_RemapTarget_ctorElim___boxed(lean_object* x_1, lean_object* x_2, lean_object* x_3, lean_object* x_4, lean_object* x_5) {
_start:
{
lean_object* x_6; 
x_6 = lp_padctl_RemapTarget_ctorElim(x_1, x_2, x_3, x_4, x_5);
lean_dec(x_2);
return x_6;
}
}
LEAN_EXPORT lean_object* lp_padctl_RemapTarget_gamepadButton_elim___redArg(lean_object* x_1, lean_object* x_2) {
_start:
{
lean_object* x_3; 
x_3 = lp_padctl_RemapTarget_ctorElim___redArg(x_1, x_2);
return x_3;
}
}
LEAN_EXPORT lean_object* lp_padctl_RemapTarget_gamepadButton_elim(lean_object* x_1, lean_object* x_2, lean_object* x_3, lean_object* x_4) {
_start:
{
lean_object* x_5; 
x_5 = lp_padctl_RemapTarget_ctorElim___redArg(x_2, x_4);
return x_5;
}
}
LEAN_EXPORT lean_object* lp_padctl_RemapTarget_key_elim___redArg(lean_object* x_1, lean_object* x_2) {
_start:
{
lean_object* x_3; 
x_3 = lp_padctl_RemapTarget_ctorElim___redArg(x_1, x_2);
return x_3;
}
}
LEAN_EXPORT lean_object* lp_padctl_RemapTarget_key_elim(lean_object* x_1, lean_object* x_2, lean_object* x_3, lean_object* x_4) {
_start:
{
lean_object* x_5; 
x_5 = lp_padctl_RemapTarget_ctorElim___redArg(x_2, x_4);
return x_5;
}
}
LEAN_EXPORT lean_object* lp_padctl_RemapTarget_mouseButton_elim___redArg(lean_object* x_1, lean_object* x_2) {
_start:
{
lean_object* x_3; 
x_3 = lp_padctl_RemapTarget_ctorElim___redArg(x_1, x_2);
return x_3;
}
}
LEAN_EXPORT lean_object* lp_padctl_RemapTarget_mouseButton_elim(lean_object* x_1, lean_object* x_2, lean_object* x_3, lean_object* x_4) {
_start:
{
lean_object* x_5; 
x_5 = lp_padctl_RemapTarget_ctorElim___redArg(x_2, x_4);
return x_5;
}
}
LEAN_EXPORT lean_object* lp_padctl_RemapTarget_disabled_elim___redArg(lean_object* x_1, lean_object* x_2) {
_start:
{
lean_object* x_3; 
x_3 = lp_padctl_RemapTarget_ctorElim___redArg(x_1, x_2);
return x_3;
}
}
LEAN_EXPORT lean_object* lp_padctl_RemapTarget_disabled_elim(lean_object* x_1, lean_object* x_2, lean_object* x_3, lean_object* x_4) {
_start:
{
lean_object* x_5; 
x_5 = lp_padctl_RemapTarget_ctorElim___redArg(x_2, x_4);
return x_5;
}
}
LEAN_EXPORT lean_object* lp_padctl_RemapTarget_macro_elim___redArg(lean_object* x_1, lean_object* x_2) {
_start:
{
lean_object* x_3; 
x_3 = lp_padctl_RemapTarget_ctorElim___redArg(x_1, x_2);
return x_3;
}
}
LEAN_EXPORT lean_object* lp_padctl_RemapTarget_macro_elim(lean_object* x_1, lean_object* x_2, lean_object* x_3, lean_object* x_4) {
_start:
{
lean_object* x_5; 
x_5 = lp_padctl_RemapTarget_ctorElim___redArg(x_2, x_4);
return x_5;
}
}
LEAN_EXPORT uint8_t lp_padctl_instDecidableEqRemapTarget_decEq(lean_object* x_1, lean_object* x_2) {
_start:
{
switch (lean_obj_tag(x_1)) {
case 0:
{
lean_object* x_3; uint8_t x_4; 
x_3 = lean_ctor_get(x_1, 0);
x_4 = 0;
switch (lean_obj_tag(x_2)) {
case 0:
{
lean_object* x_5; uint8_t x_6; 
x_5 = lean_ctor_get(x_2, 0);
x_6 = lean_nat_dec_eq(x_3, x_5);
if (x_6 == 0)
{
return x_4;
}
else
{
return x_6;
}
}
case 3:
{
return x_4;
}
case 4:
{
return x_4;
}
default: 
{
return x_4;
}
}
}
case 1:
{
lean_object* x_7; uint8_t x_8; 
x_7 = lean_ctor_get(x_1, 0);
x_8 = 0;
switch (lean_obj_tag(x_2)) {
case 1:
{
lean_object* x_9; uint8_t x_10; 
x_9 = lean_ctor_get(x_2, 0);
x_10 = lean_nat_dec_eq(x_7, x_9);
if (x_10 == 0)
{
return x_8;
}
else
{
return x_10;
}
}
case 3:
{
return x_8;
}
case 4:
{
return x_8;
}
default: 
{
return x_8;
}
}
}
case 2:
{
lean_object* x_11; uint8_t x_12; 
x_11 = lean_ctor_get(x_1, 0);
x_12 = 0;
switch (lean_obj_tag(x_2)) {
case 2:
{
lean_object* x_13; uint8_t x_14; 
x_13 = lean_ctor_get(x_2, 0);
x_14 = lean_nat_dec_eq(x_11, x_13);
if (x_14 == 0)
{
return x_12;
}
else
{
return x_14;
}
}
case 3:
{
return x_12;
}
case 4:
{
return x_12;
}
default: 
{
return x_12;
}
}
}
case 3:
{
switch (lean_obj_tag(x_2)) {
case 3:
{
uint8_t x_15; 
x_15 = 1;
return x_15;
}
case 4:
{
uint8_t x_16; 
x_16 = 0;
return x_16;
}
default: 
{
uint8_t x_17; 
x_17 = 0;
return x_17;
}
}
}
default: 
{
switch (lean_obj_tag(x_2)) {
case 3:
{
uint8_t x_18; 
x_18 = 0;
return x_18;
}
case 4:
{
uint8_t x_19; 
x_19 = 1;
return x_19;
}
default: 
{
uint8_t x_20; 
x_20 = 0;
return x_20;
}
}
}
}
}
}
LEAN_EXPORT lean_object* lp_padctl_instDecidableEqRemapTarget_decEq___boxed(lean_object* x_1, lean_object* x_2) {
_start:
{
uint8_t x_3; lean_object* x_4; 
x_3 = lp_padctl_instDecidableEqRemapTarget_decEq(x_1, x_2);
lean_dec(x_2);
lean_dec(x_1);
x_4 = lean_box(x_3);
return x_4;
}
}
LEAN_EXPORT uint8_t lp_padctl_instDecidableEqRemapTarget(lean_object* x_1, lean_object* x_2) {
_start:
{
uint8_t x_3; 
x_3 = lp_padctl_instDecidableEqRemapTarget_decEq(x_1, x_2);
return x_3;
}
}
LEAN_EXPORT lean_object* lp_padctl_instDecidableEqRemapTarget___boxed(lean_object* x_1, lean_object* x_2) {
_start:
{
uint8_t x_3; lean_object* x_4; 
x_3 = lp_padctl_instDecidableEqRemapTarget(x_1, x_2);
lean_dec(x_2);
lean_dec(x_1);
x_4 = lean_box(x_3);
return x_4;
}
}
LEAN_EXPORT lean_object* lp_padctl_instReprRemapTarget_repr(lean_object* x_1, lean_object* x_2) {
_start:
{
lean_object* x_3; lean_object* x_10; 
switch (lean_obj_tag(x_1)) {
case 0:
{
lean_object* x_17; lean_object* x_18; lean_object* x_19; lean_object* x_29; uint8_t x_30; 
x_17 = lean_ctor_get(x_1, 0);
lean_inc(x_17);
if (lean_is_exclusive(x_1)) {
 lean_ctor_release(x_1, 0);
 x_18 = x_1;
} else {
 lean_dec_ref(x_1);
 x_18 = lean_box(0);
}
x_29 = lean_unsigned_to_nat(1024u);
x_30 = lean_nat_dec_le(x_29, x_2);
if (x_30 == 0)
{
lean_object* x_31; 
x_31 = lean_obj_once(&lp_padctl_instReprAuxEvent_repr___closed__3, &lp_padctl_instReprAuxEvent_repr___closed__3_once, _init_lp_padctl_instReprAuxEvent_repr___closed__3);
x_19 = x_31;
goto block_28;
}
else
{
lean_object* x_32; 
x_32 = lean_obj_once(&lp_padctl_instReprAuxEvent_repr___closed__4, &lp_padctl_instReprAuxEvent_repr___closed__4_once, _init_lp_padctl_instReprAuxEvent_repr___closed__4);
x_19 = x_32;
goto block_28;
}
block_28:
{
lean_object* x_20; lean_object* x_21; lean_object* x_22; lean_object* x_23; lean_object* x_24; uint8_t x_25; lean_object* x_26; lean_object* x_27; 
x_20 = ((lean_object*)(lp_padctl_instReprRemapTarget_repr___closed__6));
x_21 = l_Nat_reprFast(x_17);
if (lean_is_scalar(x_18)) {
 x_22 = lean_alloc_ctor(3, 1, 0);
} else {
 x_22 = x_18;
 lean_ctor_set_tag(x_22, 3);
}
lean_ctor_set(x_22, 0, x_21);
x_23 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_23, 0, x_20);
lean_ctor_set(x_23, 1, x_22);
x_24 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_24, 0, x_19);
lean_ctor_set(x_24, 1, x_23);
x_25 = 0;
x_26 = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(x_26, 0, x_24);
lean_ctor_set_uint8(x_26, sizeof(void*)*1, x_25);
x_27 = l_Repr_addAppParen(x_26, x_2);
return x_27;
}
}
case 1:
{
lean_object* x_33; lean_object* x_34; lean_object* x_35; lean_object* x_45; uint8_t x_46; 
x_33 = lean_ctor_get(x_1, 0);
lean_inc(x_33);
if (lean_is_exclusive(x_1)) {
 lean_ctor_release(x_1, 0);
 x_34 = x_1;
} else {
 lean_dec_ref(x_1);
 x_34 = lean_box(0);
}
x_45 = lean_unsigned_to_nat(1024u);
x_46 = lean_nat_dec_le(x_45, x_2);
if (x_46 == 0)
{
lean_object* x_47; 
x_47 = lean_obj_once(&lp_padctl_instReprAuxEvent_repr___closed__3, &lp_padctl_instReprAuxEvent_repr___closed__3_once, _init_lp_padctl_instReprAuxEvent_repr___closed__3);
x_35 = x_47;
goto block_44;
}
else
{
lean_object* x_48; 
x_48 = lean_obj_once(&lp_padctl_instReprAuxEvent_repr___closed__4, &lp_padctl_instReprAuxEvent_repr___closed__4_once, _init_lp_padctl_instReprAuxEvent_repr___closed__4);
x_35 = x_48;
goto block_44;
}
block_44:
{
lean_object* x_36; lean_object* x_37; lean_object* x_38; lean_object* x_39; lean_object* x_40; uint8_t x_41; lean_object* x_42; lean_object* x_43; 
x_36 = ((lean_object*)(lp_padctl_instReprRemapTarget_repr___closed__9));
x_37 = l_Nat_reprFast(x_33);
if (lean_is_scalar(x_34)) {
 x_38 = lean_alloc_ctor(3, 1, 0);
} else {
 x_38 = x_34;
 lean_ctor_set_tag(x_38, 3);
}
lean_ctor_set(x_38, 0, x_37);
x_39 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_39, 0, x_36);
lean_ctor_set(x_39, 1, x_38);
x_40 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_40, 0, x_35);
lean_ctor_set(x_40, 1, x_39);
x_41 = 0;
x_42 = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(x_42, 0, x_40);
lean_ctor_set_uint8(x_42, sizeof(void*)*1, x_41);
x_43 = l_Repr_addAppParen(x_42, x_2);
return x_43;
}
}
case 2:
{
lean_object* x_49; lean_object* x_50; lean_object* x_51; lean_object* x_61; uint8_t x_62; 
x_49 = lean_ctor_get(x_1, 0);
lean_inc(x_49);
if (lean_is_exclusive(x_1)) {
 lean_ctor_release(x_1, 0);
 x_50 = x_1;
} else {
 lean_dec_ref(x_1);
 x_50 = lean_box(0);
}
x_61 = lean_unsigned_to_nat(1024u);
x_62 = lean_nat_dec_le(x_61, x_2);
if (x_62 == 0)
{
lean_object* x_63; 
x_63 = lean_obj_once(&lp_padctl_instReprAuxEvent_repr___closed__3, &lp_padctl_instReprAuxEvent_repr___closed__3_once, _init_lp_padctl_instReprAuxEvent_repr___closed__3);
x_51 = x_63;
goto block_60;
}
else
{
lean_object* x_64; 
x_64 = lean_obj_once(&lp_padctl_instReprAuxEvent_repr___closed__4, &lp_padctl_instReprAuxEvent_repr___closed__4_once, _init_lp_padctl_instReprAuxEvent_repr___closed__4);
x_51 = x_64;
goto block_60;
}
block_60:
{
lean_object* x_52; lean_object* x_53; lean_object* x_54; lean_object* x_55; lean_object* x_56; uint8_t x_57; lean_object* x_58; lean_object* x_59; 
x_52 = ((lean_object*)(lp_padctl_instReprRemapTarget_repr___closed__12));
x_53 = l_Nat_reprFast(x_49);
if (lean_is_scalar(x_50)) {
 x_54 = lean_alloc_ctor(3, 1, 0);
} else {
 x_54 = x_50;
 lean_ctor_set_tag(x_54, 3);
}
lean_ctor_set(x_54, 0, x_53);
x_55 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_55, 0, x_52);
lean_ctor_set(x_55, 1, x_54);
x_56 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_56, 0, x_51);
lean_ctor_set(x_56, 1, x_55);
x_57 = 0;
x_58 = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(x_58, 0, x_56);
lean_ctor_set_uint8(x_58, sizeof(void*)*1, x_57);
x_59 = l_Repr_addAppParen(x_58, x_2);
return x_59;
}
}
case 3:
{
lean_object* x_65; uint8_t x_66; 
x_65 = lean_unsigned_to_nat(1024u);
x_66 = lean_nat_dec_le(x_65, x_2);
if (x_66 == 0)
{
lean_object* x_67; 
x_67 = lean_obj_once(&lp_padctl_instReprAuxEvent_repr___closed__3, &lp_padctl_instReprAuxEvent_repr___closed__3_once, _init_lp_padctl_instReprAuxEvent_repr___closed__3);
x_3 = x_67;
goto block_9;
}
else
{
lean_object* x_68; 
x_68 = lean_obj_once(&lp_padctl_instReprAuxEvent_repr___closed__4, &lp_padctl_instReprAuxEvent_repr___closed__4_once, _init_lp_padctl_instReprAuxEvent_repr___closed__4);
x_3 = x_68;
goto block_9;
}
}
default: 
{
lean_object* x_69; uint8_t x_70; 
x_69 = lean_unsigned_to_nat(1024u);
x_70 = lean_nat_dec_le(x_69, x_2);
if (x_70 == 0)
{
lean_object* x_71; 
x_71 = lean_obj_once(&lp_padctl_instReprAuxEvent_repr___closed__3, &lp_padctl_instReprAuxEvent_repr___closed__3_once, _init_lp_padctl_instReprAuxEvent_repr___closed__3);
x_10 = x_71;
goto block_16;
}
else
{
lean_object* x_72; 
x_72 = lean_obj_once(&lp_padctl_instReprAuxEvent_repr___closed__4, &lp_padctl_instReprAuxEvent_repr___closed__4_once, _init_lp_padctl_instReprAuxEvent_repr___closed__4);
x_10 = x_72;
goto block_16;
}
}
}
block_9:
{
lean_object* x_4; lean_object* x_5; uint8_t x_6; lean_object* x_7; lean_object* x_8; 
x_4 = ((lean_object*)(lp_padctl_instReprRemapTarget_repr___closed__1));
x_5 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_5, 0, x_3);
lean_ctor_set(x_5, 1, x_4);
x_6 = 0;
x_7 = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(x_7, 0, x_5);
lean_ctor_set_uint8(x_7, sizeof(void*)*1, x_6);
x_8 = l_Repr_addAppParen(x_7, x_2);
return x_8;
}
block_16:
{
lean_object* x_11; lean_object* x_12; uint8_t x_13; lean_object* x_14; lean_object* x_15; 
x_11 = ((lean_object*)(lp_padctl_instReprRemapTarget_repr___closed__3));
x_12 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_12, 0, x_10);
lean_ctor_set(x_12, 1, x_11);
x_13 = 0;
x_14 = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(x_14, 0, x_12);
lean_ctor_set_uint8(x_14, sizeof(void*)*1, x_13);
x_15 = l_Repr_addAppParen(x_14, x_2);
return x_15;
}
}
}
LEAN_EXPORT lean_object* lp_padctl_instReprRemapTarget_repr___boxed(lean_object* x_1, lean_object* x_2) {
_start:
{
lean_object* x_3; 
x_3 = lp_padctl_instReprRemapTarget_repr(x_1, x_2);
lean_dec(x_2);
return x_3;
}
}
LEAN_EXPORT uint8_t lp_padctl_instDecidableEqRemapEntry_decEq(lean_object* x_1, lean_object* x_2) {
_start:
{
lean_object* x_3; lean_object* x_4; lean_object* x_5; lean_object* x_6; uint8_t x_7; 
x_3 = lean_ctor_get(x_1, 0);
x_4 = lean_ctor_get(x_1, 1);
x_5 = lean_ctor_get(x_2, 0);
x_6 = lean_ctor_get(x_2, 1);
x_7 = lean_nat_dec_eq(x_3, x_5);
if (x_7 == 0)
{
return x_7;
}
else
{
uint8_t x_8; 
x_8 = lp_padctl_instDecidableEqRemapTarget_decEq(x_4, x_6);
return x_8;
}
}
}
LEAN_EXPORT lean_object* lp_padctl_instDecidableEqRemapEntry_decEq___boxed(lean_object* x_1, lean_object* x_2) {
_start:
{
uint8_t x_3; lean_object* x_4; 
x_3 = lp_padctl_instDecidableEqRemapEntry_decEq(x_1, x_2);
lean_dec_ref(x_2);
lean_dec_ref(x_1);
x_4 = lean_box(x_3);
return x_4;
}
}
LEAN_EXPORT uint8_t lp_padctl_instDecidableEqRemapEntry(lean_object* x_1, lean_object* x_2) {
_start:
{
uint8_t x_3; 
x_3 = lp_padctl_instDecidableEqRemapEntry_decEq(x_1, x_2);
return x_3;
}
}
LEAN_EXPORT lean_object* lp_padctl_instDecidableEqRemapEntry___boxed(lean_object* x_1, lean_object* x_2) {
_start:
{
uint8_t x_3; lean_object* x_4; 
x_3 = lp_padctl_instDecidableEqRemapEntry(x_1, x_2);
lean_dec_ref(x_2);
lean_dec_ref(x_1);
x_4 = lean_box(x_3);
return x_4;
}
}
LEAN_EXPORT lean_object* lp_padctl_instReprRemapEntry_repr___redArg(lean_object* x_1) {
_start:
{
uint8_t x_2; 
x_2 = !lean_is_exclusive(x_1);
if (x_2 == 0)
{
lean_object* x_3; lean_object* x_4; lean_object* x_5; lean_object* x_6; lean_object* x_7; lean_object* x_8; lean_object* x_9; uint8_t x_10; lean_object* x_11; lean_object* x_12; lean_object* x_13; lean_object* x_14; lean_object* x_15; lean_object* x_16; lean_object* x_17; lean_object* x_18; lean_object* x_19; lean_object* x_20; lean_object* x_21; lean_object* x_22; lean_object* x_23; lean_object* x_24; lean_object* x_25; lean_object* x_26; lean_object* x_27; lean_object* x_28; lean_object* x_29; lean_object* x_30; lean_object* x_31; 
x_3 = lean_ctor_get(x_1, 0);
x_4 = lean_ctor_get(x_1, 1);
x_5 = ((lean_object*)(lp_padctl_instReprLayerConfig_repr___redArg___closed__5));
x_6 = ((lean_object*)(lp_padctl_instReprRemapEntry_repr___redArg___closed__3));
x_7 = lean_obj_once(&lp_padctl_instReprMacroState_repr___redArg___closed__4, &lp_padctl_instReprMacroState_repr___redArg___closed__4_once, _init_lp_padctl_instReprMacroState_repr___redArg___closed__4);
x_8 = l_Nat_reprFast(x_3);
x_9 = lean_alloc_ctor(3, 1, 0);
lean_ctor_set(x_9, 0, x_8);
lean_ctor_set_tag(x_1, 4);
lean_ctor_set(x_1, 1, x_9);
lean_ctor_set(x_1, 0, x_7);
x_10 = 0;
x_11 = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(x_11, 0, x_1);
lean_ctor_set_uint8(x_11, sizeof(void*)*1, x_10);
x_12 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_12, 0, x_6);
lean_ctor_set(x_12, 1, x_11);
x_13 = ((lean_object*)(lp_padctl_instReprLayerConfig_repr___redArg___closed__9));
x_14 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_14, 0, x_12);
lean_ctor_set(x_14, 1, x_13);
x_15 = lean_box(1);
x_16 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_16, 0, x_14);
lean_ctor_set(x_16, 1, x_15);
x_17 = ((lean_object*)(lp_padctl_instReprRemapEntry_repr___redArg___closed__5));
x_18 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_18, 0, x_16);
lean_ctor_set(x_18, 1, x_17);
x_19 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_19, 0, x_18);
lean_ctor_set(x_19, 1, x_5);
x_20 = lean_unsigned_to_nat(0u);
x_21 = lp_padctl_instReprRemapTarget_repr(x_4, x_20);
x_22 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_22, 0, x_7);
lean_ctor_set(x_22, 1, x_21);
x_23 = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(x_23, 0, x_22);
lean_ctor_set_uint8(x_23, sizeof(void*)*1, x_10);
x_24 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_24, 0, x_19);
lean_ctor_set(x_24, 1, x_23);
x_25 = lean_obj_once(&lp_padctl_instReprLayerConfig_repr___redArg___closed__18, &lp_padctl_instReprLayerConfig_repr___redArg___closed__18_once, _init_lp_padctl_instReprLayerConfig_repr___redArg___closed__18);
x_26 = ((lean_object*)(lp_padctl_instReprLayerConfig_repr___redArg___closed__19));
x_27 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_27, 0, x_26);
lean_ctor_set(x_27, 1, x_24);
x_28 = ((lean_object*)(lp_padctl_instReprLayerConfig_repr___redArg___closed__20));
x_29 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_29, 0, x_27);
lean_ctor_set(x_29, 1, x_28);
x_30 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_30, 0, x_25);
lean_ctor_set(x_30, 1, x_29);
x_31 = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(x_31, 0, x_30);
lean_ctor_set_uint8(x_31, sizeof(void*)*1, x_10);
return x_31;
}
else
{
lean_object* x_32; lean_object* x_33; lean_object* x_34; lean_object* x_35; lean_object* x_36; lean_object* x_37; lean_object* x_38; lean_object* x_39; uint8_t x_40; lean_object* x_41; lean_object* x_42; lean_object* x_43; lean_object* x_44; lean_object* x_45; lean_object* x_46; lean_object* x_47; lean_object* x_48; lean_object* x_49; lean_object* x_50; lean_object* x_51; lean_object* x_52; lean_object* x_53; lean_object* x_54; lean_object* x_55; lean_object* x_56; lean_object* x_57; lean_object* x_58; lean_object* x_59; lean_object* x_60; lean_object* x_61; 
x_32 = lean_ctor_get(x_1, 0);
x_33 = lean_ctor_get(x_1, 1);
lean_inc(x_33);
lean_inc(x_32);
lean_dec(x_1);
x_34 = ((lean_object*)(lp_padctl_instReprLayerConfig_repr___redArg___closed__5));
x_35 = ((lean_object*)(lp_padctl_instReprRemapEntry_repr___redArg___closed__3));
x_36 = lean_obj_once(&lp_padctl_instReprMacroState_repr___redArg___closed__4, &lp_padctl_instReprMacroState_repr___redArg___closed__4_once, _init_lp_padctl_instReprMacroState_repr___redArg___closed__4);
x_37 = l_Nat_reprFast(x_32);
x_38 = lean_alloc_ctor(3, 1, 0);
lean_ctor_set(x_38, 0, x_37);
x_39 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_39, 0, x_36);
lean_ctor_set(x_39, 1, x_38);
x_40 = 0;
x_41 = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(x_41, 0, x_39);
lean_ctor_set_uint8(x_41, sizeof(void*)*1, x_40);
x_42 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_42, 0, x_35);
lean_ctor_set(x_42, 1, x_41);
x_43 = ((lean_object*)(lp_padctl_instReprLayerConfig_repr___redArg___closed__9));
x_44 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_44, 0, x_42);
lean_ctor_set(x_44, 1, x_43);
x_45 = lean_box(1);
x_46 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_46, 0, x_44);
lean_ctor_set(x_46, 1, x_45);
x_47 = ((lean_object*)(lp_padctl_instReprRemapEntry_repr___redArg___closed__5));
x_48 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_48, 0, x_46);
lean_ctor_set(x_48, 1, x_47);
x_49 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_49, 0, x_48);
lean_ctor_set(x_49, 1, x_34);
x_50 = lean_unsigned_to_nat(0u);
x_51 = lp_padctl_instReprRemapTarget_repr(x_33, x_50);
x_52 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_52, 0, x_36);
lean_ctor_set(x_52, 1, x_51);
x_53 = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(x_53, 0, x_52);
lean_ctor_set_uint8(x_53, sizeof(void*)*1, x_40);
x_54 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_54, 0, x_49);
lean_ctor_set(x_54, 1, x_53);
x_55 = lean_obj_once(&lp_padctl_instReprLayerConfig_repr___redArg___closed__18, &lp_padctl_instReprLayerConfig_repr___redArg___closed__18_once, _init_lp_padctl_instReprLayerConfig_repr___redArg___closed__18);
x_56 = ((lean_object*)(lp_padctl_instReprLayerConfig_repr___redArg___closed__19));
x_57 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_57, 0, x_56);
lean_ctor_set(x_57, 1, x_54);
x_58 = ((lean_object*)(lp_padctl_instReprLayerConfig_repr___redArg___closed__20));
x_59 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_59, 0, x_57);
lean_ctor_set(x_59, 1, x_58);
x_60 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_60, 0, x_55);
lean_ctor_set(x_60, 1, x_59);
x_61 = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(x_61, 0, x_60);
lean_ctor_set_uint8(x_61, sizeof(void*)*1, x_40);
return x_61;
}
}
}
LEAN_EXPORT lean_object* lp_padctl_instReprRemapEntry_repr(lean_object* x_1, lean_object* x_2) {
_start:
{
lean_object* x_3; 
x_3 = lp_padctl_instReprRemapEntry_repr___redArg(x_1);
return x_3;
}
}
LEAN_EXPORT lean_object* lp_padctl_instReprRemapEntry_repr___boxed(lean_object* x_1, lean_object* x_2) {
_start:
{
lean_object* x_3; 
x_3 = lp_padctl_instReprRemapEntry_repr(x_1, x_2);
lean_dec(x_2);
return x_3;
}
}
LEAN_EXPORT lean_object* lp_padctl_List_foldl___at___00List_foldl___at___00Std_Format_joinSep___at___00List_repr___at___00instReprRemapResult_repr_spec__0_spec__0_spec__1_spec__2(lean_object* x_1, lean_object* x_2, lean_object* x_3) {
_start:
{
if (lean_obj_tag(x_3) == 0)
{
lean_dec(x_1);
return x_2;
}
else
{
uint8_t x_4; 
x_4 = !lean_is_exclusive(x_3);
if (x_4 == 0)
{
lean_object* x_5; lean_object* x_6; lean_object* x_7; lean_object* x_8; lean_object* x_9; 
x_5 = lean_ctor_get(x_3, 0);
x_6 = lean_ctor_get(x_3, 1);
lean_inc(x_1);
lean_ctor_set_tag(x_3, 5);
lean_ctor_set(x_3, 1, x_1);
lean_ctor_set(x_3, 0, x_2);
x_7 = lean_unsigned_to_nat(0u);
x_8 = lp_padctl_instReprAuxEvent_repr(x_5, x_7);
x_9 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_9, 0, x_3);
lean_ctor_set(x_9, 1, x_8);
x_2 = x_9;
x_3 = x_6;
goto _start;
}
else
{
lean_object* x_11; lean_object* x_12; lean_object* x_13; lean_object* x_14; lean_object* x_15; lean_object* x_16; 
x_11 = lean_ctor_get(x_3, 0);
x_12 = lean_ctor_get(x_3, 1);
lean_inc(x_12);
lean_inc(x_11);
lean_dec(x_3);
lean_inc(x_1);
x_13 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_13, 0, x_2);
lean_ctor_set(x_13, 1, x_1);
x_14 = lean_unsigned_to_nat(0u);
x_15 = lp_padctl_instReprAuxEvent_repr(x_11, x_14);
x_16 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_16, 0, x_13);
lean_ctor_set(x_16, 1, x_15);
x_2 = x_16;
x_3 = x_12;
goto _start;
}
}
}
}
LEAN_EXPORT lean_object* lp_padctl_List_foldl___at___00Std_Format_joinSep___at___00List_repr___at___00instReprRemapResult_repr_spec__0_spec__0_spec__1(lean_object* x_1, lean_object* x_2, lean_object* x_3) {
_start:
{
if (lean_obj_tag(x_3) == 0)
{
lean_dec(x_1);
return x_2;
}
else
{
uint8_t x_4; 
x_4 = !lean_is_exclusive(x_3);
if (x_4 == 0)
{
lean_object* x_5; lean_object* x_6; lean_object* x_7; lean_object* x_8; lean_object* x_9; lean_object* x_10; 
x_5 = lean_ctor_get(x_3, 0);
x_6 = lean_ctor_get(x_3, 1);
lean_inc(x_1);
lean_ctor_set_tag(x_3, 5);
lean_ctor_set(x_3, 1, x_1);
lean_ctor_set(x_3, 0, x_2);
x_7 = lean_unsigned_to_nat(0u);
x_8 = lp_padctl_instReprAuxEvent_repr(x_5, x_7);
x_9 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_9, 0, x_3);
lean_ctor_set(x_9, 1, x_8);
x_10 = lp_padctl_List_foldl___at___00List_foldl___at___00Std_Format_joinSep___at___00List_repr___at___00instReprRemapResult_repr_spec__0_spec__0_spec__1_spec__2(x_1, x_9, x_6);
return x_10;
}
else
{
lean_object* x_11; lean_object* x_12; lean_object* x_13; lean_object* x_14; lean_object* x_15; lean_object* x_16; lean_object* x_17; 
x_11 = lean_ctor_get(x_3, 0);
x_12 = lean_ctor_get(x_3, 1);
lean_inc(x_12);
lean_inc(x_11);
lean_dec(x_3);
lean_inc(x_1);
x_13 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_13, 0, x_2);
lean_ctor_set(x_13, 1, x_1);
x_14 = lean_unsigned_to_nat(0u);
x_15 = lp_padctl_instReprAuxEvent_repr(x_11, x_14);
x_16 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_16, 0, x_13);
lean_ctor_set(x_16, 1, x_15);
x_17 = lp_padctl_List_foldl___at___00List_foldl___at___00Std_Format_joinSep___at___00List_repr___at___00instReprRemapResult_repr_spec__0_spec__0_spec__1_spec__2(x_1, x_16, x_12);
return x_17;
}
}
}
}
LEAN_EXPORT lean_object* lp_padctl_Std_Format_joinSep___at___00List_repr___at___00instReprRemapResult_repr_spec__0_spec__0___lam__0(lean_object* x_1) {
_start:
{
lean_object* x_2; lean_object* x_3; 
x_2 = lean_unsigned_to_nat(0u);
x_3 = lp_padctl_instReprAuxEvent_repr(x_1, x_2);
return x_3;
}
}
LEAN_EXPORT lean_object* lp_padctl_Std_Format_joinSep___at___00List_repr___at___00instReprRemapResult_repr_spec__0_spec__0(lean_object* x_1, lean_object* x_2) {
_start:
{
if (lean_obj_tag(x_1) == 0)
{
lean_object* x_3; 
lean_dec(x_2);
x_3 = lean_box(0);
return x_3;
}
else
{
lean_object* x_4; 
x_4 = lean_ctor_get(x_1, 1);
if (lean_obj_tag(x_4) == 0)
{
lean_object* x_5; lean_object* x_6; 
lean_dec(x_2);
x_5 = lean_ctor_get(x_1, 0);
lean_inc(x_5);
lean_dec_ref(x_1);
x_6 = lp_padctl_Std_Format_joinSep___at___00List_repr___at___00instReprRemapResult_repr_spec__0_spec__0___lam__0(x_5);
return x_6;
}
else
{
lean_object* x_7; lean_object* x_8; lean_object* x_9; 
lean_inc(x_4);
x_7 = lean_ctor_get(x_1, 0);
lean_inc(x_7);
lean_dec_ref(x_1);
x_8 = lp_padctl_Std_Format_joinSep___at___00List_repr___at___00instReprRemapResult_repr_spec__0_spec__0___lam__0(x_7);
x_9 = lp_padctl_List_foldl___at___00Std_Format_joinSep___at___00List_repr___at___00instReprRemapResult_repr_spec__0_spec__0_spec__1(x_2, x_8, x_4);
return x_9;
}
}
}
}
LEAN_EXPORT lean_object* lp_padctl_List_repr___at___00instReprRemapResult_repr_spec__0___redArg(lean_object* x_1) {
_start:
{
if (lean_obj_tag(x_1) == 0)
{
lean_object* x_2; 
x_2 = ((lean_object*)(lp_padctl_List_repr___at___00instReprMacroState_repr_spec__1___redArg___closed__1));
return x_2;
}
else
{
lean_object* x_3; lean_object* x_4; lean_object* x_5; lean_object* x_6; lean_object* x_7; lean_object* x_8; lean_object* x_9; lean_object* x_10; uint8_t x_11; lean_object* x_12; 
x_3 = ((lean_object*)(lp_padctl_List_repr___at___00instReprMacroState_repr_spec__1___redArg___closed__3));
x_4 = lp_padctl_Std_Format_joinSep___at___00List_repr___at___00instReprRemapResult_repr_spec__0_spec__0(x_1, x_3);
x_5 = lean_obj_once(&lp_padctl_List_repr___at___00instReprMacroState_repr_spec__1___redArg___closed__6, &lp_padctl_List_repr___at___00instReprMacroState_repr_spec__1___redArg___closed__6_once, _init_lp_padctl_List_repr___at___00instReprMacroState_repr_spec__1___redArg___closed__6);
x_6 = ((lean_object*)(lp_padctl_List_repr___at___00instReprMacroState_repr_spec__1___redArg___closed__7));
x_7 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_7, 0, x_6);
lean_ctor_set(x_7, 1, x_4);
x_8 = ((lean_object*)(lp_padctl_List_repr___at___00instReprMacroState_repr_spec__1___redArg___closed__8));
x_9 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_9, 0, x_7);
lean_ctor_set(x_9, 1, x_8);
x_10 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_10, 0, x_5);
lean_ctor_set(x_10, 1, x_9);
x_11 = 0;
x_12 = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(x_12, 0, x_10);
lean_ctor_set_uint8(x_12, sizeof(void*)*1, x_11);
return x_12;
}
}
}
static lean_object* _init_lp_padctl_instReprRemapResult_repr___redArg___closed__4(void) {
_start:
{
lean_object* x_1; lean_object* x_2; 
x_1 = lean_unsigned_to_nat(16u);
x_2 = lean_nat_to_int(x_1);
return x_2;
}
}
LEAN_EXPORT lean_object* lp_padctl_instReprRemapResult_repr___redArg(lean_object* x_1) {
_start:
{
lean_object* x_2; lean_object* x_3; lean_object* x_4; lean_object* x_5; lean_object* x_6; lean_object* x_7; lean_object* x_8; lean_object* x_9; lean_object* x_10; uint8_t x_11; lean_object* x_12; lean_object* x_13; lean_object* x_14; lean_object* x_15; lean_object* x_16; lean_object* x_17; lean_object* x_18; lean_object* x_19; lean_object* x_20; lean_object* x_21; lean_object* x_22; lean_object* x_23; lean_object* x_24; lean_object* x_25; lean_object* x_26; lean_object* x_27; lean_object* x_28; lean_object* x_29; lean_object* x_30; lean_object* x_31; lean_object* x_32; lean_object* x_33; lean_object* x_34; lean_object* x_35; lean_object* x_36; lean_object* x_37; lean_object* x_38; lean_object* x_39; lean_object* x_40; lean_object* x_41; lean_object* x_42; lean_object* x_43; 
x_2 = lean_ctor_get(x_1, 0);
lean_inc(x_2);
x_3 = lean_ctor_get(x_1, 1);
lean_inc(x_3);
x_4 = lean_ctor_get(x_1, 2);
lean_inc(x_4);
lean_dec_ref(x_1);
x_5 = ((lean_object*)(lp_padctl_instReprLayerConfig_repr___redArg___closed__5));
x_6 = ((lean_object*)(lp_padctl_instReprRemapResult_repr___redArg___closed__3));
x_7 = lean_obj_once(&lp_padctl_instReprRemapResult_repr___redArg___closed__4, &lp_padctl_instReprRemapResult_repr___redArg___closed__4_once, _init_lp_padctl_instReprRemapResult_repr___redArg___closed__4);
x_8 = l_Nat_reprFast(x_2);
x_9 = lean_alloc_ctor(3, 1, 0);
lean_ctor_set(x_9, 0, x_8);
x_10 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_10, 0, x_7);
lean_ctor_set(x_10, 1, x_9);
x_11 = 0;
x_12 = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(x_12, 0, x_10);
lean_ctor_set_uint8(x_12, sizeof(void*)*1, x_11);
x_13 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_13, 0, x_6);
lean_ctor_set(x_13, 1, x_12);
x_14 = ((lean_object*)(lp_padctl_instReprLayerConfig_repr___redArg___closed__9));
x_15 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_15, 0, x_13);
lean_ctor_set(x_15, 1, x_14);
x_16 = lean_box(1);
x_17 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_17, 0, x_15);
lean_ctor_set(x_17, 1, x_16);
x_18 = ((lean_object*)(lp_padctl_instReprRemapResult_repr___redArg___closed__6));
x_19 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_19, 0, x_17);
lean_ctor_set(x_19, 1, x_18);
x_20 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_20, 0, x_19);
lean_ctor_set(x_20, 1, x_5);
x_21 = lean_obj_once(&lp_padctl_instReprMacroState_repr___redArg___closed__14, &lp_padctl_instReprMacroState_repr___redArg___closed__14_once, _init_lp_padctl_instReprMacroState_repr___redArg___closed__14);
x_22 = l_Nat_reprFast(x_3);
x_23 = lean_alloc_ctor(3, 1, 0);
lean_ctor_set(x_23, 0, x_22);
x_24 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_24, 0, x_21);
lean_ctor_set(x_24, 1, x_23);
x_25 = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(x_25, 0, x_24);
lean_ctor_set_uint8(x_25, sizeof(void*)*1, x_11);
x_26 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_26, 0, x_20);
lean_ctor_set(x_26, 1, x_25);
x_27 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_27, 0, x_26);
lean_ctor_set(x_27, 1, x_14);
x_28 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_28, 0, x_27);
lean_ctor_set(x_28, 1, x_16);
x_29 = ((lean_object*)(lp_padctl_instReprRemapResult_repr___redArg___closed__8));
x_30 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_30, 0, x_28);
lean_ctor_set(x_30, 1, x_29);
x_31 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_31, 0, x_30);
lean_ctor_set(x_31, 1, x_5);
x_32 = lean_obj_once(&lp_padctl_instReprTapHoldState_repr___redArg___closed__13, &lp_padctl_instReprTapHoldState_repr___redArg___closed__13_once, _init_lp_padctl_instReprTapHoldState_repr___redArg___closed__13);
x_33 = lp_padctl_List_repr___at___00instReprRemapResult_repr_spec__0___redArg(x_4);
x_34 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_34, 0, x_32);
lean_ctor_set(x_34, 1, x_33);
x_35 = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(x_35, 0, x_34);
lean_ctor_set_uint8(x_35, sizeof(void*)*1, x_11);
x_36 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_36, 0, x_31);
lean_ctor_set(x_36, 1, x_35);
x_37 = lean_obj_once(&lp_padctl_instReprLayerConfig_repr___redArg___closed__18, &lp_padctl_instReprLayerConfig_repr___redArg___closed__18_once, _init_lp_padctl_instReprLayerConfig_repr___redArg___closed__18);
x_38 = ((lean_object*)(lp_padctl_instReprLayerConfig_repr___redArg___closed__19));
x_39 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_39, 0, x_38);
lean_ctor_set(x_39, 1, x_36);
x_40 = ((lean_object*)(lp_padctl_instReprLayerConfig_repr___redArg___closed__20));
x_41 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_41, 0, x_39);
lean_ctor_set(x_41, 1, x_40);
x_42 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_42, 0, x_37);
lean_ctor_set(x_42, 1, x_41);
x_43 = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(x_43, 0, x_42);
lean_ctor_set_uint8(x_43, sizeof(void*)*1, x_11);
return x_43;
}
}
LEAN_EXPORT lean_object* lp_padctl_instReprRemapResult_repr(lean_object* x_1, lean_object* x_2) {
_start:
{
lean_object* x_3; 
x_3 = lp_padctl_instReprRemapResult_repr___redArg(x_1);
return x_3;
}
}
LEAN_EXPORT lean_object* lp_padctl_instReprRemapResult_repr___boxed(lean_object* x_1, lean_object* x_2) {
_start:
{
lean_object* x_3; 
x_3 = lp_padctl_instReprRemapResult_repr(x_1, x_2);
lean_dec(x_2);
return x_3;
}
}
LEAN_EXPORT lean_object* lp_padctl_List_repr___at___00instReprRemapResult_repr_spec__0(lean_object* x_1, lean_object* x_2) {
_start:
{
lean_object* x_3; 
x_3 = lp_padctl_List_repr___at___00instReprRemapResult_repr_spec__0___redArg(x_1);
return x_3;
}
}
LEAN_EXPORT lean_object* lp_padctl_List_repr___at___00instReprRemapResult_repr_spec__0___boxed(lean_object* x_1, lean_object* x_2) {
_start:
{
lean_object* x_3; 
x_3 = lp_padctl_List_repr___at___00instReprRemapResult_repr_spec__0(x_1, x_2);
lean_dec(x_2);
return x_3;
}
}
LEAN_EXPORT lean_object* lp_padctl_List_foldl___at___00applyRemaps_spec__0(lean_object* x_1, lean_object* x_2, lean_object* x_3, lean_object* x_4) {
_start:
{
if (lean_obj_tag(x_4) == 0)
{
return x_3;
}
else
{
lean_object* x_5; lean_object* x_6; lean_object* x_7; lean_object* x_8; lean_object* x_9; lean_object* x_10; lean_object* x_11; lean_object* x_12; lean_object* x_13; lean_object* x_14; lean_object* x_15; lean_object* x_16; lean_object* x_17; lean_object* x_21; lean_object* x_25; uint8_t x_29; uint8_t x_30; 
x_5 = lean_ctor_get(x_4, 0);
lean_inc(x_5);
x_6 = lean_ctor_get(x_4, 1);
lean_inc(x_6);
if (lean_is_exclusive(x_4)) {
 lean_ctor_release(x_4, 0);
 lean_ctor_release(x_4, 1);
 x_7 = x_4;
} else {
 lean_dec_ref(x_4);
 x_7 = lean_box(0);
}
x_8 = lean_ctor_get(x_3, 0);
lean_inc(x_8);
x_9 = lean_ctor_get(x_3, 1);
lean_inc(x_9);
x_10 = lean_ctor_get(x_3, 2);
lean_inc(x_10);
if (lean_is_exclusive(x_3)) {
 lean_ctor_release(x_3, 0);
 lean_ctor_release(x_3, 1);
 lean_ctor_release(x_3, 2);
 x_11 = x_3;
} else {
 lean_dec_ref(x_3);
 x_11 = lean_box(0);
}
x_12 = lean_ctor_get(x_5, 0);
lean_inc(x_12);
x_13 = lean_ctor_get(x_5, 1);
lean_inc(x_13);
lean_dec(x_5);
x_14 = lean_unsigned_to_nat(1u);
x_15 = lean_nat_shiftl(x_14, x_12);
x_16 = lean_nat_lor(x_8, x_15);
lean_dec(x_15);
lean_dec(x_8);
x_29 = lp_padctl_testBit(x_1, x_12);
x_30 = lp_padctl_testBit(x_2, x_12);
lean_dec(x_12);
switch (lean_obj_tag(x_13)) {
case 0:
{
lean_dec(x_11);
lean_dec(x_7);
if (x_29 == 0)
{
lean_dec_ref(x_13);
x_21 = x_9;
goto block_24;
}
else
{
lean_object* x_31; lean_object* x_32; lean_object* x_33; 
x_31 = lean_ctor_get(x_13, 0);
lean_inc(x_31);
lean_dec_ref(x_13);
x_32 = lean_nat_shiftl(x_14, x_31);
lean_dec(x_31);
x_33 = lean_nat_lor(x_9, x_32);
lean_dec(x_32);
lean_dec(x_9);
x_21 = x_33;
goto block_24;
}
}
case 1:
{
lean_object* x_34; uint8_t x_35; 
x_34 = lean_ctor_get(x_13, 0);
lean_inc(x_34);
lean_dec_ref(x_13);
if (x_29 == 0)
{
if (x_30 == 0)
{
lean_dec(x_34);
lean_dec(x_7);
x_17 = x_10;
goto block_20;
}
else
{
x_35 = x_29;
goto block_40;
}
}
else
{
x_35 = x_30;
goto block_40;
}
block_40:
{
if (x_35 == 0)
{
lean_object* x_36; lean_object* x_37; lean_object* x_38; lean_object* x_39; 
x_36 = lean_alloc_ctor(0, 1, 1);
lean_ctor_set(x_36, 0, x_34);
lean_ctor_set_uint8(x_36, sizeof(void*)*1, x_29);
x_37 = lean_box(0);
if (lean_is_scalar(x_7)) {
 x_38 = lean_alloc_ctor(1, 2, 0);
} else {
 x_38 = x_7;
}
lean_ctor_set(x_38, 0, x_36);
lean_ctor_set(x_38, 1, x_37);
x_39 = l_List_appendTR___redArg(x_10, x_38);
x_17 = x_39;
goto block_20;
}
else
{
lean_dec(x_34);
lean_dec(x_7);
x_17 = x_10;
goto block_20;
}
}
}
case 2:
{
lean_object* x_41; uint8_t x_42; 
lean_dec(x_11);
x_41 = lean_ctor_get(x_13, 0);
lean_inc(x_41);
lean_dec_ref(x_13);
if (x_29 == 0)
{
if (x_30 == 0)
{
lean_dec(x_41);
lean_dec(x_7);
x_25 = x_10;
goto block_28;
}
else
{
x_42 = x_29;
goto block_47;
}
}
else
{
x_42 = x_30;
goto block_47;
}
block_47:
{
if (x_42 == 0)
{
lean_object* x_43; lean_object* x_44; lean_object* x_45; lean_object* x_46; 
x_43 = lean_alloc_ctor(1, 1, 1);
lean_ctor_set(x_43, 0, x_41);
lean_ctor_set_uint8(x_43, sizeof(void*)*1, x_29);
x_44 = lean_box(0);
if (lean_is_scalar(x_7)) {
 x_45 = lean_alloc_ctor(1, 2, 0);
} else {
 x_45 = x_7;
}
lean_ctor_set(x_45, 0, x_43);
lean_ctor_set(x_45, 1, x_44);
x_46 = l_List_appendTR___redArg(x_10, x_45);
x_25 = x_46;
goto block_28;
}
else
{
lean_dec(x_41);
lean_dec(x_7);
x_25 = x_10;
goto block_28;
}
}
}
default: 
{
lean_object* x_48; 
lean_dec(x_13);
lean_dec(x_11);
lean_dec(x_7);
x_48 = lean_alloc_ctor(0, 3, 0);
lean_ctor_set(x_48, 0, x_16);
lean_ctor_set(x_48, 1, x_9);
lean_ctor_set(x_48, 2, x_10);
x_3 = x_48;
x_4 = x_6;
goto _start;
}
}
block_20:
{
lean_object* x_18; 
if (lean_is_scalar(x_11)) {
 x_18 = lean_alloc_ctor(0, 3, 0);
} else {
 x_18 = x_11;
}
lean_ctor_set(x_18, 0, x_16);
lean_ctor_set(x_18, 1, x_9);
lean_ctor_set(x_18, 2, x_17);
x_3 = x_18;
x_4 = x_6;
goto _start;
}
block_24:
{
lean_object* x_22; 
x_22 = lean_alloc_ctor(0, 3, 0);
lean_ctor_set(x_22, 0, x_16);
lean_ctor_set(x_22, 1, x_21);
lean_ctor_set(x_22, 2, x_10);
x_3 = x_22;
x_4 = x_6;
goto _start;
}
block_28:
{
lean_object* x_26; 
x_26 = lean_alloc_ctor(0, 3, 0);
lean_ctor_set(x_26, 0, x_16);
lean_ctor_set(x_26, 1, x_9);
lean_ctor_set(x_26, 2, x_25);
x_3 = x_26;
x_4 = x_6;
goto _start;
}
}
}
}
LEAN_EXPORT lean_object* lp_padctl_List_foldl___at___00applyRemaps_spec__0___boxed(lean_object* x_1, lean_object* x_2, lean_object* x_3, lean_object* x_4) {
_start:
{
lean_object* x_5; 
x_5 = lp_padctl_List_foldl___at___00applyRemaps_spec__0(x_1, x_2, x_3, x_4);
lean_dec(x_2);
lean_dec(x_1);
return x_5;
}
}
LEAN_EXPORT lean_object* lp_padctl_applyRemaps(lean_object* x_1, lean_object* x_2, lean_object* x_3) {
_start:
{
lean_object* x_4; lean_object* x_5; 
x_4 = ((lean_object*)(lp_padctl_RemapResult_empty));
x_5 = lp_padctl_List_foldl___at___00applyRemaps_spec__0(x_1, x_2, x_4, x_3);
return x_5;
}
}
LEAN_EXPORT lean_object* lp_padctl_applyRemaps___boxed(lean_object* x_1, lean_object* x_2, lean_object* x_3) {
_start:
{
lean_object* x_4; 
x_4 = lp_padctl_applyRemaps(x_1, x_2, x_3);
lean_dec(x_2);
lean_dec(x_1);
return x_4;
}
}
LEAN_EXPORT lean_object* lp_padctl_DpadMode_ctorIdx(uint8_t x_1) {
_start:
{
if (x_1 == 0)
{
lean_object* x_2; 
x_2 = lean_unsigned_to_nat(0u);
return x_2;
}
else
{
lean_object* x_3; 
x_3 = lean_unsigned_to_nat(1u);
return x_3;
}
}
}
LEAN_EXPORT lean_object* lp_padctl_DpadMode_ctorIdx___boxed(lean_object* x_1) {
_start:
{
uint8_t x_2; lean_object* x_3; 
x_2 = lean_unbox(x_1);
x_3 = lp_padctl_DpadMode_ctorIdx(x_2);
return x_3;
}
}
LEAN_EXPORT lean_object* lp_padctl_DpadMode_toCtorIdx(uint8_t x_1) {
_start:
{
lean_object* x_2; 
x_2 = lp_padctl_DpadMode_ctorIdx(x_1);
return x_2;
}
}
LEAN_EXPORT lean_object* lp_padctl_DpadMode_toCtorIdx___boxed(lean_object* x_1) {
_start:
{
uint8_t x_2; lean_object* x_3; 
x_2 = lean_unbox(x_1);
x_3 = lp_padctl_DpadMode_toCtorIdx(x_2);
return x_3;
}
}
LEAN_EXPORT lean_object* lp_padctl_DpadMode_ctorElim___redArg(lean_object* x_1) {
_start:
{
lean_inc(x_1);
return x_1;
}
}
LEAN_EXPORT lean_object* lp_padctl_DpadMode_ctorElim___redArg___boxed(lean_object* x_1) {
_start:
{
lean_object* x_2; 
x_2 = lp_padctl_DpadMode_ctorElim___redArg(x_1);
lean_dec(x_1);
return x_2;
}
}
LEAN_EXPORT lean_object* lp_padctl_DpadMode_ctorElim(lean_object* x_1, lean_object* x_2, uint8_t x_3, lean_object* x_4, lean_object* x_5) {
_start:
{
lean_inc(x_5);
return x_5;
}
}
LEAN_EXPORT lean_object* lp_padctl_DpadMode_ctorElim___boxed(lean_object* x_1, lean_object* x_2, lean_object* x_3, lean_object* x_4, lean_object* x_5) {
_start:
{
uint8_t x_6; lean_object* x_7; 
x_6 = lean_unbox(x_3);
x_7 = lp_padctl_DpadMode_ctorElim(x_1, x_2, x_6, x_4, x_5);
lean_dec(x_5);
lean_dec(x_2);
return x_7;
}
}
LEAN_EXPORT lean_object* lp_padctl_DpadMode_gamepad_elim___redArg(lean_object* x_1) {
_start:
{
lean_inc(x_1);
return x_1;
}
}
LEAN_EXPORT lean_object* lp_padctl_DpadMode_gamepad_elim___redArg___boxed(lean_object* x_1) {
_start:
{
lean_object* x_2; 
x_2 = lp_padctl_DpadMode_gamepad_elim___redArg(x_1);
lean_dec(x_1);
return x_2;
}
}
LEAN_EXPORT lean_object* lp_padctl_DpadMode_gamepad_elim(lean_object* x_1, uint8_t x_2, lean_object* x_3, lean_object* x_4) {
_start:
{
lean_inc(x_4);
return x_4;
}
}
LEAN_EXPORT lean_object* lp_padctl_DpadMode_gamepad_elim___boxed(lean_object* x_1, lean_object* x_2, lean_object* x_3, lean_object* x_4) {
_start:
{
uint8_t x_5; lean_object* x_6; 
x_5 = lean_unbox(x_2);
x_6 = lp_padctl_DpadMode_gamepad_elim(x_1, x_5, x_3, x_4);
lean_dec(x_4);
return x_6;
}
}
LEAN_EXPORT lean_object* lp_padctl_DpadMode_arrows_elim___redArg(lean_object* x_1) {
_start:
{
lean_inc(x_1);
return x_1;
}
}
LEAN_EXPORT lean_object* lp_padctl_DpadMode_arrows_elim___redArg___boxed(lean_object* x_1) {
_start:
{
lean_object* x_2; 
x_2 = lp_padctl_DpadMode_arrows_elim___redArg(x_1);
lean_dec(x_1);
return x_2;
}
}
LEAN_EXPORT lean_object* lp_padctl_DpadMode_arrows_elim(lean_object* x_1, uint8_t x_2, lean_object* x_3, lean_object* x_4) {
_start:
{
lean_inc(x_4);
return x_4;
}
}
LEAN_EXPORT lean_object* lp_padctl_DpadMode_arrows_elim___boxed(lean_object* x_1, lean_object* x_2, lean_object* x_3, lean_object* x_4) {
_start:
{
uint8_t x_5; lean_object* x_6; 
x_5 = lean_unbox(x_2);
x_6 = lp_padctl_DpadMode_arrows_elim(x_1, x_5, x_3, x_4);
lean_dec(x_4);
return x_6;
}
}
LEAN_EXPORT uint8_t lp_padctl_DpadMode_ofNat(lean_object* x_1) {
_start:
{
lean_object* x_2; uint8_t x_3; 
x_2 = lean_unsigned_to_nat(0u);
x_3 = lean_nat_dec_le(x_1, x_2);
if (x_3 == 0)
{
uint8_t x_4; 
x_4 = 1;
return x_4;
}
else
{
uint8_t x_5; 
x_5 = 0;
return x_5;
}
}
}
LEAN_EXPORT lean_object* lp_padctl_DpadMode_ofNat___boxed(lean_object* x_1) {
_start:
{
uint8_t x_2; lean_object* x_3; 
x_2 = lp_padctl_DpadMode_ofNat(x_1);
lean_dec(x_1);
x_3 = lean_box(x_2);
return x_3;
}
}
LEAN_EXPORT uint8_t lp_padctl_instDecidableEqDpadMode(uint8_t x_1, uint8_t x_2) {
_start:
{
lean_object* x_3; lean_object* x_4; uint8_t x_5; 
x_3 = lp_padctl_DpadMode_ctorIdx(x_1);
x_4 = lp_padctl_DpadMode_ctorIdx(x_2);
x_5 = lean_nat_dec_eq(x_3, x_4);
lean_dec(x_4);
lean_dec(x_3);
return x_5;
}
}
LEAN_EXPORT lean_object* lp_padctl_instDecidableEqDpadMode___boxed(lean_object* x_1, lean_object* x_2) {
_start:
{
uint8_t x_3; uint8_t x_4; uint8_t x_5; lean_object* x_6; 
x_3 = lean_unbox(x_1);
x_4 = lean_unbox(x_2);
x_5 = lp_padctl_instDecidableEqDpadMode(x_3, x_4);
x_6 = lean_box(x_5);
return x_6;
}
}
LEAN_EXPORT lean_object* lp_padctl_instReprDpadMode_repr(uint8_t x_1, lean_object* x_2) {
_start:
{
lean_object* x_3; lean_object* x_10; 
if (x_1 == 0)
{
lean_object* x_17; uint8_t x_18; 
x_17 = lean_unsigned_to_nat(1024u);
x_18 = lean_nat_dec_le(x_17, x_2);
if (x_18 == 0)
{
lean_object* x_19; 
x_19 = lean_obj_once(&lp_padctl_instReprAuxEvent_repr___closed__3, &lp_padctl_instReprAuxEvent_repr___closed__3_once, _init_lp_padctl_instReprAuxEvent_repr___closed__3);
x_3 = x_19;
goto block_9;
}
else
{
lean_object* x_20; 
x_20 = lean_obj_once(&lp_padctl_instReprAuxEvent_repr___closed__4, &lp_padctl_instReprAuxEvent_repr___closed__4_once, _init_lp_padctl_instReprAuxEvent_repr___closed__4);
x_3 = x_20;
goto block_9;
}
}
else
{
lean_object* x_21; uint8_t x_22; 
x_21 = lean_unsigned_to_nat(1024u);
x_22 = lean_nat_dec_le(x_21, x_2);
if (x_22 == 0)
{
lean_object* x_23; 
x_23 = lean_obj_once(&lp_padctl_instReprAuxEvent_repr___closed__3, &lp_padctl_instReprAuxEvent_repr___closed__3_once, _init_lp_padctl_instReprAuxEvent_repr___closed__3);
x_10 = x_23;
goto block_16;
}
else
{
lean_object* x_24; 
x_24 = lean_obj_once(&lp_padctl_instReprAuxEvent_repr___closed__4, &lp_padctl_instReprAuxEvent_repr___closed__4_once, _init_lp_padctl_instReprAuxEvent_repr___closed__4);
x_10 = x_24;
goto block_16;
}
}
block_9:
{
lean_object* x_4; lean_object* x_5; uint8_t x_6; lean_object* x_7; lean_object* x_8; 
x_4 = ((lean_object*)(lp_padctl_instReprDpadMode_repr___closed__1));
x_5 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_5, 0, x_3);
lean_ctor_set(x_5, 1, x_4);
x_6 = 0;
x_7 = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(x_7, 0, x_5);
lean_ctor_set_uint8(x_7, sizeof(void*)*1, x_6);
x_8 = l_Repr_addAppParen(x_7, x_2);
return x_8;
}
block_16:
{
lean_object* x_11; lean_object* x_12; uint8_t x_13; lean_object* x_14; lean_object* x_15; 
x_11 = ((lean_object*)(lp_padctl_instReprDpadMode_repr___closed__3));
x_12 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_12, 0, x_10);
lean_ctor_set(x_12, 1, x_11);
x_13 = 0;
x_14 = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(x_14, 0, x_12);
lean_ctor_set_uint8(x_14, sizeof(void*)*1, x_13);
x_15 = l_Repr_addAppParen(x_14, x_2);
return x_15;
}
}
}
LEAN_EXPORT lean_object* lp_padctl_instReprDpadMode_repr___boxed(lean_object* x_1, lean_object* x_2) {
_start:
{
uint8_t x_3; lean_object* x_4; 
x_3 = lean_unbox(x_1);
x_4 = lp_padctl_instReprDpadMode_repr(x_3, x_2);
lean_dec(x_2);
return x_4;
}
}
static lean_object* _init_lp_padctl_KEY__UP(void) {
_start:
{
lean_object* x_1; 
x_1 = lean_unsigned_to_nat(103u);
return x_1;
}
}
static lean_object* _init_lp_padctl_KEY__DOWN(void) {
_start:
{
lean_object* x_1; 
x_1 = lean_unsigned_to_nat(108u);
return x_1;
}
}
static lean_object* _init_lp_padctl_KEY__LEFT(void) {
_start:
{
lean_object* x_1; 
x_1 = lean_unsigned_to_nat(105u);
return x_1;
}
}
static lean_object* _init_lp_padctl_KEY__RIGHT(void) {
_start:
{
lean_object* x_1; 
x_1 = lean_unsigned_to_nat(106u);
return x_1;
}
}
LEAN_EXPORT lean_object* lp_padctl_instReprDpadResult_repr___redArg(lean_object* x_1) {
_start:
{
lean_object* x_2; lean_object* x_3; lean_object* x_4; uint8_t x_5; lean_object* x_6; lean_object* x_7; lean_object* x_8; lean_object* x_9; uint8_t x_10; lean_object* x_11; lean_object* x_12; lean_object* x_13; lean_object* x_14; lean_object* x_56; lean_object* x_77; lean_object* x_78; uint8_t x_79; 
x_2 = lean_ctor_get(x_1, 0);
lean_inc(x_2);
x_3 = lean_ctor_get(x_1, 1);
lean_inc(x_3);
x_4 = lean_ctor_get(x_1, 2);
lean_inc(x_4);
x_5 = lean_ctor_get_uint8(x_1, sizeof(void*)*4);
x_6 = lean_ctor_get(x_1, 3);
lean_inc(x_6);
lean_dec_ref(x_1);
x_7 = ((lean_object*)(lp_padctl_instReprLayerConfig_repr___redArg___closed__5));
x_8 = ((lean_object*)(lp_padctl_instReprDpadResult_repr___redArg___closed__3));
x_9 = lean_obj_once(&lp_padctl_instReprTapHoldState_repr___redArg___closed__7, &lp_padctl_instReprTapHoldState_repr___redArg___closed__7_once, _init_lp_padctl_instReprTapHoldState_repr___redArg___closed__7);
x_77 = lean_unsigned_to_nat(0u);
x_78 = lean_obj_once(&lp_padctl_instReprAuxEvent_repr___closed__11, &lp_padctl_instReprAuxEvent_repr___closed__11_once, _init_lp_padctl_instReprAuxEvent_repr___closed__11);
x_79 = lean_int_dec_lt(x_2, x_78);
if (x_79 == 0)
{
lean_object* x_80; lean_object* x_81; 
x_80 = l_Int_repr(x_2);
lean_dec(x_2);
x_81 = lean_alloc_ctor(3, 1, 0);
lean_ctor_set(x_81, 0, x_80);
x_56 = x_81;
goto block_76;
}
else
{
lean_object* x_82; lean_object* x_83; lean_object* x_84; 
x_82 = l_Int_repr(x_2);
lean_dec(x_2);
x_83 = lean_alloc_ctor(3, 1, 0);
lean_ctor_set(x_83, 0, x_82);
x_84 = l_Repr_addAppParen(x_83, x_77);
x_56 = x_84;
goto block_76;
}
block_55:
{
lean_object* x_15; lean_object* x_16; lean_object* x_17; lean_object* x_18; lean_object* x_19; lean_object* x_20; lean_object* x_21; lean_object* x_22; lean_object* x_23; lean_object* x_24; lean_object* x_25; lean_object* x_26; lean_object* x_27; lean_object* x_28; lean_object* x_29; lean_object* x_30; lean_object* x_31; lean_object* x_32; lean_object* x_33; lean_object* x_34; lean_object* x_35; lean_object* x_36; lean_object* x_37; lean_object* x_38; lean_object* x_39; lean_object* x_40; lean_object* x_41; lean_object* x_42; lean_object* x_43; lean_object* x_44; lean_object* x_45; lean_object* x_46; lean_object* x_47; lean_object* x_48; lean_object* x_49; lean_object* x_50; lean_object* x_51; lean_object* x_52; lean_object* x_53; lean_object* x_54; 
x_15 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_15, 0, x_9);
lean_ctor_set(x_15, 1, x_14);
x_16 = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(x_16, 0, x_15);
lean_ctor_set_uint8(x_16, sizeof(void*)*1, x_10);
x_17 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_17, 0, x_11);
lean_ctor_set(x_17, 1, x_16);
lean_inc(x_13);
x_18 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_18, 0, x_17);
lean_ctor_set(x_18, 1, x_13);
lean_inc(x_12);
x_19 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_19, 0, x_18);
lean_ctor_set(x_19, 1, x_12);
x_20 = ((lean_object*)(lp_padctl_instReprRemapResult_repr___redArg___closed__8));
x_21 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_21, 0, x_19);
lean_ctor_set(x_21, 1, x_20);
x_22 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_22, 0, x_21);
lean_ctor_set(x_22, 1, x_7);
x_23 = lean_obj_once(&lp_padctl_instReprTapHoldState_repr___redArg___closed__13, &lp_padctl_instReprTapHoldState_repr___redArg___closed__13_once, _init_lp_padctl_instReprTapHoldState_repr___redArg___closed__13);
x_24 = lp_padctl_List_repr___at___00instReprRemapResult_repr_spec__0___redArg(x_4);
x_25 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_25, 0, x_23);
lean_ctor_set(x_25, 1, x_24);
x_26 = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(x_26, 0, x_25);
lean_ctor_set_uint8(x_26, sizeof(void*)*1, x_10);
x_27 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_27, 0, x_22);
lean_ctor_set(x_27, 1, x_26);
lean_inc(x_13);
x_28 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_28, 0, x_27);
lean_ctor_set(x_28, 1, x_13);
lean_inc(x_12);
x_29 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_29, 0, x_28);
lean_ctor_set(x_29, 1, x_12);
x_30 = ((lean_object*)(lp_padctl_instReprDpadResult_repr___redArg___closed__5));
x_31 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_31, 0, x_29);
lean_ctor_set(x_31, 1, x_30);
x_32 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_32, 0, x_31);
lean_ctor_set(x_32, 1, x_7);
x_33 = lean_obj_once(&lp_padctl_instReprMacroState_repr___redArg___closed__7, &lp_padctl_instReprMacroState_repr___redArg___closed__7_once, _init_lp_padctl_instReprMacroState_repr___redArg___closed__7);
x_34 = l_Bool_repr___redArg(x_5);
x_35 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_35, 0, x_33);
lean_ctor_set(x_35, 1, x_34);
x_36 = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(x_36, 0, x_35);
lean_ctor_set_uint8(x_36, sizeof(void*)*1, x_10);
x_37 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_37, 0, x_32);
lean_ctor_set(x_37, 1, x_36);
x_38 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_38, 0, x_37);
lean_ctor_set(x_38, 1, x_13);
x_39 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_39, 0, x_38);
lean_ctor_set(x_39, 1, x_12);
x_40 = ((lean_object*)(lp_padctl_instReprDpadResult_repr___redArg___closed__7));
x_41 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_41, 0, x_39);
lean_ctor_set(x_41, 1, x_40);
x_42 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_42, 0, x_41);
lean_ctor_set(x_42, 1, x_7);
x_43 = l_Nat_reprFast(x_6);
x_44 = lean_alloc_ctor(3, 1, 0);
lean_ctor_set(x_44, 0, x_43);
x_45 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_45, 0, x_33);
lean_ctor_set(x_45, 1, x_44);
x_46 = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(x_46, 0, x_45);
lean_ctor_set_uint8(x_46, sizeof(void*)*1, x_10);
x_47 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_47, 0, x_42);
lean_ctor_set(x_47, 1, x_46);
x_48 = lean_obj_once(&lp_padctl_instReprLayerConfig_repr___redArg___closed__18, &lp_padctl_instReprLayerConfig_repr___redArg___closed__18_once, _init_lp_padctl_instReprLayerConfig_repr___redArg___closed__18);
x_49 = ((lean_object*)(lp_padctl_instReprLayerConfig_repr___redArg___closed__19));
x_50 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_50, 0, x_49);
lean_ctor_set(x_50, 1, x_47);
x_51 = ((lean_object*)(lp_padctl_instReprLayerConfig_repr___redArg___closed__20));
x_52 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_52, 0, x_50);
lean_ctor_set(x_52, 1, x_51);
x_53 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_53, 0, x_48);
lean_ctor_set(x_53, 1, x_52);
x_54 = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(x_54, 0, x_53);
lean_ctor_set_uint8(x_54, sizeof(void*)*1, x_10);
return x_54;
}
block_76:
{
lean_object* x_57; uint8_t x_58; lean_object* x_59; lean_object* x_60; lean_object* x_61; lean_object* x_62; lean_object* x_63; lean_object* x_64; lean_object* x_65; lean_object* x_66; lean_object* x_67; lean_object* x_68; lean_object* x_69; uint8_t x_70; 
x_57 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_57, 0, x_9);
lean_ctor_set(x_57, 1, x_56);
x_58 = 0;
x_59 = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(x_59, 0, x_57);
lean_ctor_set_uint8(x_59, sizeof(void*)*1, x_58);
x_60 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_60, 0, x_8);
lean_ctor_set(x_60, 1, x_59);
x_61 = ((lean_object*)(lp_padctl_instReprLayerConfig_repr___redArg___closed__9));
x_62 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_62, 0, x_60);
lean_ctor_set(x_62, 1, x_61);
x_63 = lean_box(1);
x_64 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_64, 0, x_62);
lean_ctor_set(x_64, 1, x_63);
x_65 = ((lean_object*)(lp_padctl_instReprDpadResult_repr___redArg___closed__9));
x_66 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_66, 0, x_64);
lean_ctor_set(x_66, 1, x_65);
x_67 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_67, 0, x_66);
lean_ctor_set(x_67, 1, x_7);
x_68 = lean_unsigned_to_nat(0u);
x_69 = lean_obj_once(&lp_padctl_instReprAuxEvent_repr___closed__11, &lp_padctl_instReprAuxEvent_repr___closed__11_once, _init_lp_padctl_instReprAuxEvent_repr___closed__11);
x_70 = lean_int_dec_lt(x_3, x_69);
if (x_70 == 0)
{
lean_object* x_71; lean_object* x_72; 
x_71 = l_Int_repr(x_3);
lean_dec(x_3);
x_72 = lean_alloc_ctor(3, 1, 0);
lean_ctor_set(x_72, 0, x_71);
x_10 = x_58;
x_11 = x_67;
x_12 = x_63;
x_13 = x_61;
x_14 = x_72;
goto block_55;
}
else
{
lean_object* x_73; lean_object* x_74; lean_object* x_75; 
x_73 = l_Int_repr(x_3);
lean_dec(x_3);
x_74 = lean_alloc_ctor(3, 1, 0);
lean_ctor_set(x_74, 0, x_73);
x_75 = l_Repr_addAppParen(x_74, x_68);
x_10 = x_58;
x_11 = x_67;
x_12 = x_63;
x_13 = x_61;
x_14 = x_75;
goto block_55;
}
}
}
}
LEAN_EXPORT lean_object* lp_padctl_instReprDpadResult_repr(lean_object* x_1, lean_object* x_2) {
_start:
{
lean_object* x_3; 
x_3 = lp_padctl_instReprDpadResult_repr___redArg(x_1);
return x_3;
}
}
LEAN_EXPORT lean_object* lp_padctl_instReprDpadResult_repr___boxed(lean_object* x_1, lean_object* x_2) {
_start:
{
lean_object* x_3; 
x_3 = lp_padctl_instReprDpadResult_repr(x_1, x_2);
lean_dec(x_2);
return x_3;
}
}
static lean_object* _init_lp_padctl___private_Padctl_Mapper_0__dpadButtonMask___closed__0(void) {
_start:
{
lean_object* x_1; lean_object* x_2; lean_object* x_3; 
x_1 = lp_padctl_dpadUpBit;
x_2 = lean_unsigned_to_nat(1u);
x_3 = lean_nat_shiftl(x_2, x_1);
return x_3;
}
}
static lean_object* _init_lp_padctl___private_Padctl_Mapper_0__dpadButtonMask___closed__1(void) {
_start:
{
lean_object* x_1; lean_object* x_2; lean_object* x_3; 
x_1 = lp_padctl_dpadDownBit;
x_2 = lean_unsigned_to_nat(1u);
x_3 = lean_nat_shiftl(x_2, x_1);
return x_3;
}
}
static lean_object* _init_lp_padctl___private_Padctl_Mapper_0__dpadButtonMask___closed__2(void) {
_start:
{
lean_object* x_1; lean_object* x_2; lean_object* x_3; 
x_1 = lean_obj_once(&lp_padctl___private_Padctl_Mapper_0__dpadButtonMask___closed__1, &lp_padctl___private_Padctl_Mapper_0__dpadButtonMask___closed__1_once, _init_lp_padctl___private_Padctl_Mapper_0__dpadButtonMask___closed__1);
x_2 = lean_obj_once(&lp_padctl___private_Padctl_Mapper_0__dpadButtonMask___closed__0, &lp_padctl___private_Padctl_Mapper_0__dpadButtonMask___closed__0_once, _init_lp_padctl___private_Padctl_Mapper_0__dpadButtonMask___closed__0);
x_3 = lean_nat_lor(x_2, x_1);
return x_3;
}
}
static lean_object* _init_lp_padctl___private_Padctl_Mapper_0__dpadButtonMask___closed__3(void) {
_start:
{
lean_object* x_1; lean_object* x_2; lean_object* x_3; 
x_1 = lp_padctl_dpadLeftBit;
x_2 = lean_unsigned_to_nat(1u);
x_3 = lean_nat_shiftl(x_2, x_1);
return x_3;
}
}
static lean_object* _init_lp_padctl___private_Padctl_Mapper_0__dpadButtonMask___closed__4(void) {
_start:
{
lean_object* x_1; lean_object* x_2; lean_object* x_3; 
x_1 = lean_obj_once(&lp_padctl___private_Padctl_Mapper_0__dpadButtonMask___closed__3, &lp_padctl___private_Padctl_Mapper_0__dpadButtonMask___closed__3_once, _init_lp_padctl___private_Padctl_Mapper_0__dpadButtonMask___closed__3);
x_2 = lean_obj_once(&lp_padctl___private_Padctl_Mapper_0__dpadButtonMask___closed__2, &lp_padctl___private_Padctl_Mapper_0__dpadButtonMask___closed__2_once, _init_lp_padctl___private_Padctl_Mapper_0__dpadButtonMask___closed__2);
x_3 = lean_nat_lor(x_2, x_1);
return x_3;
}
}
static lean_object* _init_lp_padctl___private_Padctl_Mapper_0__dpadButtonMask___closed__5(void) {
_start:
{
lean_object* x_1; lean_object* x_2; lean_object* x_3; 
x_1 = lp_padctl_dpadRightBit;
x_2 = lean_unsigned_to_nat(1u);
x_3 = lean_nat_shiftl(x_2, x_1);
return x_3;
}
}
static lean_object* _init_lp_padctl___private_Padctl_Mapper_0__dpadButtonMask___closed__6(void) {
_start:
{
lean_object* x_1; lean_object* x_2; lean_object* x_3; 
x_1 = lean_obj_once(&lp_padctl___private_Padctl_Mapper_0__dpadButtonMask___closed__5, &lp_padctl___private_Padctl_Mapper_0__dpadButtonMask___closed__5_once, _init_lp_padctl___private_Padctl_Mapper_0__dpadButtonMask___closed__5);
x_2 = lean_obj_once(&lp_padctl___private_Padctl_Mapper_0__dpadButtonMask___closed__4, &lp_padctl___private_Padctl_Mapper_0__dpadButtonMask___closed__4_once, _init_lp_padctl___private_Padctl_Mapper_0__dpadButtonMask___closed__4);
x_3 = lean_nat_lor(x_2, x_1);
return x_3;
}
}
static lean_object* _init_lp_padctl___private_Padctl_Mapper_0__dpadButtonMask(void) {
_start:
{
lean_object* x_1; 
x_1 = lean_obj_once(&lp_padctl___private_Padctl_Mapper_0__dpadButtonMask___closed__6, &lp_padctl___private_Padctl_Mapper_0__dpadButtonMask___closed__6_once, _init_lp_padctl___private_Padctl_Mapper_0__dpadButtonMask___closed__6);
return x_1;
}
}
LEAN_EXPORT lean_object* lp_padctl_processDpad(lean_object* x_1, lean_object* x_2, lean_object* x_3, lean_object* x_4, uint8_t x_5, uint8_t x_6) {
_start:
{
if (x_5 == 0)
{
lean_object* x_7; uint8_t x_8; lean_object* x_9; lean_object* x_10; 
x_7 = lean_box(0);
x_8 = 0;
x_9 = lean_unsigned_to_nat(0u);
x_10 = lean_alloc_ctor(0, 4, 1);
lean_ctor_set(x_10, 0, x_1);
lean_ctor_set(x_10, 1, x_2);
lean_ctor_set(x_10, 2, x_7);
lean_ctor_set(x_10, 3, x_9);
lean_ctor_set_uint8(x_10, sizeof(void*)*4, x_8);
return x_10;
}
else
{
lean_object* x_11; lean_object* x_12; lean_object* x_13; lean_object* x_14; lean_object* x_19; lean_object* x_20; lean_object* x_21; lean_object* x_23; lean_object* x_24; lean_object* x_27; uint8_t x_30; lean_object* x_31; uint8_t x_37; uint8_t x_38; lean_object* x_39; lean_object* x_40; uint8_t x_43; uint8_t x_44; lean_object* x_45; uint8_t x_48; uint8_t x_49; lean_object* x_50; uint8_t x_51; uint8_t x_57; uint8_t x_58; uint8_t x_59; lean_object* x_60; uint8_t x_61; lean_object* x_62; uint8_t x_65; uint8_t x_66; uint8_t x_67; lean_object* x_68; uint8_t x_69; uint8_t x_72; uint8_t x_73; uint8_t x_74; uint8_t x_75; lean_object* x_76; uint8_t x_77; uint8_t x_83; uint8_t x_84; uint8_t x_85; uint8_t x_86; uint8_t x_87; uint8_t x_88; lean_object* x_89; uint8_t x_91; uint8_t x_92; uint8_t x_107; uint8_t x_110; 
x_11 = lean_unsigned_to_nat(0u);
x_19 = lean_obj_once(&lp_padctl_instReprAuxEvent_repr___closed__11, &lp_padctl_instReprAuxEvent_repr___closed__11_once, _init_lp_padctl_instReprAuxEvent_repr___closed__11);
x_91 = lean_int_dec_lt(x_2, x_19);
x_110 = lean_int_dec_lt(x_4, x_19);
if (x_91 == 0)
{
if (x_110 == 0)
{
goto block_106;
}
else
{
x_107 = x_91;
goto block_109;
}
}
else
{
x_107 = x_110;
goto block_109;
}
block_18:
{
if (x_6 == 0)
{
lean_object* x_15; 
x_15 = lean_alloc_ctor(0, 4, 1);
lean_ctor_set(x_15, 0, x_13);
lean_ctor_set(x_15, 1, x_14);
lean_ctor_set(x_15, 2, x_12);
lean_ctor_set(x_15, 3, x_11);
lean_ctor_set_uint8(x_15, sizeof(void*)*4, x_6);
return x_15;
}
else
{
lean_object* x_16; lean_object* x_17; 
x_16 = lp_padctl___private_Padctl_Mapper_0__dpadButtonMask;
x_17 = lean_alloc_ctor(0, 4, 1);
lean_ctor_set(x_17, 0, x_13);
lean_ctor_set(x_17, 1, x_14);
lean_ctor_set(x_17, 2, x_12);
lean_ctor_set(x_17, 3, x_16);
lean_ctor_set_uint8(x_17, sizeof(void*)*4, x_6);
return x_17;
}
}
block_22:
{
if (x_6 == 0)
{
x_12 = x_20;
x_13 = x_21;
x_14 = x_2;
goto block_18;
}
else
{
lean_dec(x_2);
x_12 = x_20;
x_13 = x_21;
x_14 = x_19;
goto block_18;
}
}
block_26:
{
lean_object* x_25; 
x_25 = l_List_appendTR___redArg(x_23, x_24);
if (x_6 == 0)
{
x_20 = x_25;
x_21 = x_1;
goto block_22;
}
else
{
lean_dec(x_1);
x_20 = x_25;
x_21 = x_19;
goto block_22;
}
}
block_29:
{
lean_object* x_28; 
x_28 = lean_box(0);
x_23 = x_27;
x_24 = x_28;
goto block_26;
}
block_36:
{
lean_object* x_32; lean_object* x_33; lean_object* x_34; lean_object* x_35; 
x_32 = lean_unsigned_to_nat(106u);
x_33 = lean_alloc_ctor(0, 1, 1);
lean_ctor_set(x_33, 0, x_32);
lean_ctor_set_uint8(x_33, sizeof(void*)*1, x_30);
x_34 = lean_box(0);
x_35 = lean_alloc_ctor(1, 2, 0);
lean_ctor_set(x_35, 0, x_33);
lean_ctor_set(x_35, 1, x_34);
x_23 = x_31;
x_24 = x_35;
goto block_26;
}
block_42:
{
lean_object* x_41; 
x_41 = l_List_appendTR___redArg(x_39, x_40);
if (x_37 == 0)
{
if (x_38 == 0)
{
x_27 = x_41;
goto block_29;
}
else
{
x_30 = x_37;
x_31 = x_41;
goto block_36;
}
}
else
{
if (x_38 == 0)
{
x_30 = x_37;
x_31 = x_41;
goto block_36;
}
else
{
x_27 = x_41;
goto block_29;
}
}
}
block_47:
{
lean_object* x_46; 
x_46 = lean_box(0);
x_37 = x_43;
x_38 = x_44;
x_39 = x_45;
x_40 = x_46;
goto block_42;
}
block_56:
{
lean_object* x_52; lean_object* x_53; lean_object* x_54; lean_object* x_55; 
x_52 = lean_unsigned_to_nat(105u);
x_53 = lean_alloc_ctor(0, 1, 1);
lean_ctor_set(x_53, 0, x_52);
lean_ctor_set_uint8(x_53, sizeof(void*)*1, x_51);
x_54 = lean_box(0);
x_55 = lean_alloc_ctor(1, 2, 0);
lean_ctor_set(x_55, 0, x_53);
lean_ctor_set(x_55, 1, x_54);
x_37 = x_48;
x_38 = x_49;
x_39 = x_50;
x_40 = x_55;
goto block_42;
}
block_64:
{
lean_object* x_63; 
x_63 = l_List_appendTR___redArg(x_60, x_62);
if (x_61 == 0)
{
if (x_59 == 0)
{
x_43 = x_57;
x_44 = x_58;
x_45 = x_63;
goto block_47;
}
else
{
x_48 = x_57;
x_49 = x_58;
x_50 = x_63;
x_51 = x_61;
goto block_56;
}
}
else
{
if (x_59 == 0)
{
x_48 = x_57;
x_49 = x_58;
x_50 = x_63;
x_51 = x_61;
goto block_56;
}
else
{
x_43 = x_57;
x_44 = x_58;
x_45 = x_63;
goto block_47;
}
}
}
block_71:
{
lean_object* x_70; 
x_70 = lean_box(0);
x_57 = x_65;
x_58 = x_66;
x_59 = x_67;
x_60 = x_68;
x_61 = x_69;
x_62 = x_70;
goto block_64;
}
block_82:
{
lean_object* x_78; lean_object* x_79; lean_object* x_80; lean_object* x_81; 
x_78 = lean_unsigned_to_nat(108u);
x_79 = lean_alloc_ctor(0, 1, 1);
lean_ctor_set(x_79, 0, x_78);
lean_ctor_set_uint8(x_79, sizeof(void*)*1, x_73);
x_80 = lean_box(0);
x_81 = lean_alloc_ctor(1, 2, 0);
lean_ctor_set(x_81, 0, x_79);
lean_ctor_set(x_81, 1, x_80);
x_57 = x_72;
x_58 = x_74;
x_59 = x_75;
x_60 = x_76;
x_61 = x_77;
x_62 = x_81;
goto block_64;
}
block_90:
{
if (x_85 == 0)
{
if (x_84 == 0)
{
x_65 = x_83;
x_66 = x_86;
x_67 = x_87;
x_68 = x_89;
x_69 = x_88;
goto block_71;
}
else
{
x_72 = x_83;
x_73 = x_85;
x_74 = x_86;
x_75 = x_87;
x_76 = x_89;
x_77 = x_88;
goto block_82;
}
}
else
{
if (x_84 == 0)
{
x_72 = x_83;
x_73 = x_85;
x_74 = x_86;
x_75 = x_87;
x_76 = x_89;
x_77 = x_88;
goto block_82;
}
else
{
x_65 = x_83;
x_66 = x_86;
x_67 = x_87;
x_68 = x_89;
x_69 = x_88;
goto block_71;
}
}
}
block_104:
{
uint8_t x_93; uint8_t x_94; uint8_t x_95; uint8_t x_96; uint8_t x_97; uint8_t x_98; 
x_93 = lean_int_dec_lt(x_19, x_2);
x_94 = lean_int_dec_lt(x_19, x_4);
x_95 = lean_int_dec_lt(x_1, x_19);
x_96 = lean_int_dec_lt(x_3, x_19);
x_97 = lean_int_dec_lt(x_19, x_1);
x_98 = lean_int_dec_lt(x_19, x_3);
if (x_92 == 0)
{
lean_object* x_99; 
x_99 = lean_box(0);
x_83 = x_97;
x_84 = x_94;
x_85 = x_93;
x_86 = x_98;
x_87 = x_96;
x_88 = x_95;
x_89 = x_99;
goto block_90;
}
else
{
lean_object* x_100; lean_object* x_101; lean_object* x_102; lean_object* x_103; 
x_100 = lean_unsigned_to_nat(103u);
x_101 = lean_alloc_ctor(0, 1, 1);
lean_ctor_set(x_101, 0, x_100);
lean_ctor_set_uint8(x_101, sizeof(void*)*1, x_91);
x_102 = lean_box(0);
x_103 = lean_alloc_ctor(1, 2, 0);
lean_ctor_set(x_103, 0, x_101);
lean_ctor_set(x_103, 1, x_102);
x_83 = x_97;
x_84 = x_94;
x_85 = x_93;
x_86 = x_98;
x_87 = x_96;
x_88 = x_95;
x_89 = x_103;
goto block_90;
}
}
block_106:
{
uint8_t x_105; 
x_105 = 0;
x_92 = x_105;
goto block_104;
}
block_109:
{
if (x_107 == 0)
{
uint8_t x_108; 
x_108 = 1;
x_92 = x_108;
goto block_104;
}
else
{
goto block_106;
}
}
}
}
}
LEAN_EXPORT lean_object* lp_padctl_processDpad___boxed(lean_object* x_1, lean_object* x_2, lean_object* x_3, lean_object* x_4, lean_object* x_5, lean_object* x_6) {
_start:
{
uint8_t x_7; uint8_t x_8; lean_object* x_9; 
x_7 = lean_unbox(x_5);
x_8 = lean_unbox(x_6);
x_9 = lp_padctl_processDpad(x_1, x_2, x_3, x_4, x_7, x_8);
lean_dec(x_4);
lean_dec(x_3);
return x_9;
}
}
LEAN_EXPORT uint8_t lp_padctl_Nat_andNot___lam__0(uint8_t x_1, uint8_t x_2) {
_start:
{
if (x_1 == 0)
{
return x_1;
}
else
{
if (x_2 == 0)
{
return x_1;
}
else
{
uint8_t x_3; 
x_3 = 0;
return x_3;
}
}
}
}
LEAN_EXPORT lean_object* lp_padctl_Nat_andNot___lam__0___boxed(lean_object* x_1, lean_object* x_2) {
_start:
{
uint8_t x_3; uint8_t x_4; uint8_t x_5; lean_object* x_6; 
x_3 = lean_unbox(x_1);
x_4 = lean_unbox(x_2);
x_5 = lp_padctl_Nat_andNot___lam__0(x_3, x_4);
x_6 = lean_box(x_5);
return x_6;
}
}
LEAN_EXPORT lean_object* lp_padctl_Nat_andNot(lean_object* x_1, lean_object* x_2) {
_start:
{
lean_object* x_3; lean_object* x_4; 
x_3 = ((lean_object*)(lp_padctl_Nat_andNot___closed__0));
x_4 = l_Nat_bitwise(x_3, x_1, x_2);
return x_4;
}
}
LEAN_EXPORT lean_object* lp_padctl_Nat_andNot___boxed(lean_object* x_1, lean_object* x_2) {
_start:
{
lean_object* x_3; 
x_3 = lp_padctl_Nat_andNot(x_1, x_2);
lean_dec(x_2);
lean_dec(x_1);
return x_3;
}
}
LEAN_EXPORT lean_object* lp_padctl_assembleButtons(lean_object* x_1, lean_object* x_2, lean_object* x_3) {
_start:
{
lean_object* x_4; lean_object* x_5; 
x_4 = lp_padctl_Nat_andNot(x_1, x_2);
x_5 = lean_nat_lor(x_4, x_3);
lean_dec(x_4);
return x_5;
}
}
LEAN_EXPORT lean_object* lp_padctl_assembleButtons___boxed(lean_object* x_1, lean_object* x_2, lean_object* x_3) {
_start:
{
lean_object* x_4; 
x_4 = lp_padctl_assembleButtons(x_1, x_2, x_3);
lean_dec(x_3);
lean_dec(x_2);
lean_dec(x_1);
return x_4;
}
}
LEAN_EXPORT uint8_t lp_padctl_instDecidableEqLayerOverrides_decEq___lam__0(lean_object* x_1, lean_object* x_2) {
_start:
{
lean_object* x_3; uint8_t x_4; 
x_3 = lean_alloc_closure((void*)(l_instDecidableEqNat___boxed), 2, 0);
x_4 = l_Option_instDecidableEq___redArg(x_3, x_1, x_2);
return x_4;
}
}
LEAN_EXPORT lean_object* lp_padctl_instDecidableEqLayerOverrides_decEq___lam__0___boxed(lean_object* x_1, lean_object* x_2) {
_start:
{
uint8_t x_3; lean_object* x_4; 
x_3 = lp_padctl_instDecidableEqLayerOverrides_decEq___lam__0(x_1, x_2);
x_4 = lean_box(x_3);
return x_4;
}
}
LEAN_EXPORT uint8_t lp_padctl_instDecidableEqLayerOverrides_decEq(lean_object* x_1, lean_object* x_2) {
_start:
{
lean_object* x_3; lean_object* x_4; lean_object* x_5; lean_object* x_6; lean_object* x_7; lean_object* x_8; lean_object* x_9; lean_object* x_10; lean_object* x_11; lean_object* x_12; lean_object* x_13; uint8_t x_14; 
x_3 = lean_ctor_get(x_1, 0);
lean_inc(x_3);
x_4 = lean_ctor_get(x_1, 1);
lean_inc(x_4);
x_5 = lean_ctor_get(x_1, 2);
lean_inc(x_5);
x_6 = lean_ctor_get(x_1, 3);
lean_inc(x_6);
x_7 = lean_ctor_get(x_1, 4);
lean_inc(x_7);
lean_dec_ref(x_1);
x_8 = lean_ctor_get(x_2, 0);
lean_inc(x_8);
x_9 = lean_ctor_get(x_2, 1);
lean_inc(x_9);
x_10 = lean_ctor_get(x_2, 2);
lean_inc(x_10);
x_11 = lean_ctor_get(x_2, 3);
lean_inc(x_11);
x_12 = lean_ctor_get(x_2, 4);
lean_inc(x_12);
lean_dec_ref(x_2);
x_13 = lean_alloc_closure((void*)(lp_padctl_instDecidableEqDpadMode___boxed), 2, 0);
x_14 = l_Option_instDecidableEq___redArg(x_13, x_3, x_8);
if (x_14 == 0)
{
lean_dec(x_12);
lean_dec(x_11);
lean_dec(x_10);
lean_dec(x_9);
lean_dec(x_7);
lean_dec(x_6);
lean_dec(x_5);
lean_dec(x_4);
return x_14;
}
else
{
lean_object* x_15; uint8_t x_16; 
x_15 = lean_alloc_closure((void*)(lp_padctl_instDecidableEqStickMode___boxed), 2, 0);
lean_inc_ref(x_15);
x_16 = l_Option_instDecidableEq___redArg(x_15, x_4, x_9);
if (x_16 == 0)
{
lean_dec_ref(x_15);
lean_dec(x_12);
lean_dec(x_11);
lean_dec(x_10);
lean_dec(x_7);
lean_dec(x_6);
lean_dec(x_5);
return x_16;
}
else
{
uint8_t x_17; 
x_17 = l_Option_instDecidableEq___redArg(x_15, x_5, x_10);
if (x_17 == 0)
{
lean_dec(x_12);
lean_dec(x_11);
lean_dec(x_7);
lean_dec(x_6);
return x_17;
}
else
{
lean_object* x_18; uint8_t x_19; 
x_18 = ((lean_object*)(lp_padctl_instDecidableEqLayerOverrides_decEq___closed__0));
x_19 = l_Option_instDecidableEq___redArg(x_18, x_6, x_11);
if (x_19 == 0)
{
lean_dec(x_12);
lean_dec(x_7);
return x_19;
}
else
{
lean_object* x_20; uint8_t x_21; 
x_20 = lean_alloc_closure((void*)(lp_padctl_instDecidableEqGyroMode___boxed), 2, 0);
x_21 = l_Option_instDecidableEq___redArg(x_20, x_7, x_12);
return x_21;
}
}
}
}
}
}
LEAN_EXPORT lean_object* lp_padctl_instDecidableEqLayerOverrides_decEq___boxed(lean_object* x_1, lean_object* x_2) {
_start:
{
uint8_t x_3; lean_object* x_4; 
x_3 = lp_padctl_instDecidableEqLayerOverrides_decEq(x_1, x_2);
x_4 = lean_box(x_3);
return x_4;
}
}
LEAN_EXPORT uint8_t lp_padctl_instDecidableEqLayerOverrides(lean_object* x_1, lean_object* x_2) {
_start:
{
uint8_t x_3; 
x_3 = lp_padctl_instDecidableEqLayerOverrides_decEq(x_1, x_2);
return x_3;
}
}
LEAN_EXPORT lean_object* lp_padctl_instDecidableEqLayerOverrides___boxed(lean_object* x_1, lean_object* x_2) {
_start:
{
uint8_t x_3; lean_object* x_4; 
x_3 = lp_padctl_instDecidableEqLayerOverrides(x_1, x_2);
x_4 = lean_box(x_3);
return x_4;
}
}
LEAN_EXPORT lean_object* lp_padctl_Option_repr___at___00instReprLayerOverrides_repr_spec__0(lean_object* x_1, lean_object* x_2) {
_start:
{
if (lean_obj_tag(x_1) == 0)
{
lean_object* x_3; 
x_3 = ((lean_object*)(lp_padctl_Option_repr___at___00instReprMapperState_repr_spec__0___closed__1));
return x_3;
}
else
{
lean_object* x_4; lean_object* x_5; lean_object* x_6; uint8_t x_7; lean_object* x_8; lean_object* x_9; lean_object* x_10; 
x_4 = lean_ctor_get(x_1, 0);
x_5 = ((lean_object*)(lp_padctl_Option_repr___at___00instReprMapperState_repr_spec__0___closed__3));
x_6 = lean_unsigned_to_nat(1024u);
x_7 = lean_unbox(x_4);
x_8 = lp_padctl_instReprDpadMode_repr(x_7, x_6);
x_9 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_9, 0, x_5);
lean_ctor_set(x_9, 1, x_8);
x_10 = l_Repr_addAppParen(x_9, x_2);
return x_10;
}
}
}
LEAN_EXPORT lean_object* lp_padctl_Option_repr___at___00instReprLayerOverrides_repr_spec__0___boxed(lean_object* x_1, lean_object* x_2) {
_start:
{
lean_object* x_3; 
x_3 = lp_padctl_Option_repr___at___00instReprLayerOverrides_repr_spec__0(x_1, x_2);
lean_dec(x_2);
lean_dec(x_1);
return x_3;
}
}
LEAN_EXPORT lean_object* lp_padctl_Option_repr___at___00instReprLayerOverrides_repr_spec__1(lean_object* x_1, lean_object* x_2) {
_start:
{
if (lean_obj_tag(x_1) == 0)
{
lean_object* x_3; 
x_3 = ((lean_object*)(lp_padctl_Option_repr___at___00instReprMapperState_repr_spec__0___closed__1));
return x_3;
}
else
{
lean_object* x_4; lean_object* x_5; lean_object* x_6; uint8_t x_7; lean_object* x_8; lean_object* x_9; lean_object* x_10; 
x_4 = lean_ctor_get(x_1, 0);
x_5 = ((lean_object*)(lp_padctl_Option_repr___at___00instReprMapperState_repr_spec__0___closed__3));
x_6 = lean_unsigned_to_nat(1024u);
x_7 = lean_unbox(x_4);
x_8 = lp_padctl_instReprStickMode_repr(x_7, x_6);
x_9 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_9, 0, x_5);
lean_ctor_set(x_9, 1, x_8);
x_10 = l_Repr_addAppParen(x_9, x_2);
return x_10;
}
}
}
LEAN_EXPORT lean_object* lp_padctl_Option_repr___at___00instReprLayerOverrides_repr_spec__1___boxed(lean_object* x_1, lean_object* x_2) {
_start:
{
lean_object* x_3; 
x_3 = lp_padctl_Option_repr___at___00instReprLayerOverrides_repr_spec__1(x_1, x_2);
lean_dec(x_2);
lean_dec(x_1);
return x_3;
}
}
LEAN_EXPORT lean_object* lp_padctl_Option_repr___at___00instReprLayerOverrides_repr_spec__3(lean_object* x_1, lean_object* x_2) {
_start:
{
if (lean_obj_tag(x_1) == 0)
{
lean_object* x_3; 
x_3 = ((lean_object*)(lp_padctl_Option_repr___at___00instReprMapperState_repr_spec__0___closed__1));
return x_3;
}
else
{
lean_object* x_4; lean_object* x_5; lean_object* x_6; uint8_t x_7; lean_object* x_8; lean_object* x_9; lean_object* x_10; 
x_4 = lean_ctor_get(x_1, 0);
x_5 = ((lean_object*)(lp_padctl_Option_repr___at___00instReprMapperState_repr_spec__0___closed__3));
x_6 = lean_unsigned_to_nat(1024u);
x_7 = lean_unbox(x_4);
x_8 = lp_padctl_instReprGyroMode_repr(x_7, x_6);
x_9 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_9, 0, x_5);
lean_ctor_set(x_9, 1, x_8);
x_10 = l_Repr_addAppParen(x_9, x_2);
return x_10;
}
}
}
LEAN_EXPORT lean_object* lp_padctl_Option_repr___at___00instReprLayerOverrides_repr_spec__3___boxed(lean_object* x_1, lean_object* x_2) {
_start:
{
lean_object* x_3; 
x_3 = lp_padctl_Option_repr___at___00instReprLayerOverrides_repr_spec__3(x_1, x_2);
lean_dec(x_2);
lean_dec(x_1);
return x_3;
}
}
LEAN_EXPORT lean_object* lp_padctl_Option_repr___at___00instReprLayerOverrides_repr_spec__2(lean_object* x_1, lean_object* x_2) {
_start:
{
if (lean_obj_tag(x_1) == 0)
{
lean_object* x_3; 
x_3 = ((lean_object*)(lp_padctl_Option_repr___at___00instReprMapperState_repr_spec__0___closed__1));
return x_3;
}
else
{
lean_object* x_4; lean_object* x_5; lean_object* x_6; lean_object* x_7; lean_object* x_8; lean_object* x_9; 
x_4 = lean_ctor_get(x_1, 0);
lean_inc(x_4);
lean_dec_ref(x_1);
x_5 = ((lean_object*)(lp_padctl_Option_repr___at___00instReprMapperState_repr_spec__0___closed__3));
x_6 = lean_unsigned_to_nat(1024u);
x_7 = l_Option_repr___at___00Lean_Meta_instReprConfig__1_repr_spec__0(x_4, x_6);
x_8 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_8, 0, x_5);
lean_ctor_set(x_8, 1, x_7);
x_9 = l_Repr_addAppParen(x_8, x_2);
return x_9;
}
}
}
LEAN_EXPORT lean_object* lp_padctl_Option_repr___at___00instReprLayerOverrides_repr_spec__2___boxed(lean_object* x_1, lean_object* x_2) {
_start:
{
lean_object* x_3; 
x_3 = lp_padctl_Option_repr___at___00instReprLayerOverrides_repr_spec__2(x_1, x_2);
lean_dec(x_2);
return x_3;
}
}
static lean_object* _init_lp_padctl_instReprLayerOverrides_repr___redArg___closed__6(void) {
_start:
{
lean_object* x_1; lean_object* x_2; 
x_1 = lean_unsigned_to_nat(17u);
x_2 = lean_nat_to_int(x_1);
return x_2;
}
}
static lean_object* _init_lp_padctl_instReprLayerOverrides_repr___redArg___closed__11(void) {
_start:
{
lean_object* x_1; lean_object* x_2; 
x_1 = lean_unsigned_to_nat(24u);
x_2 = lean_nat_to_int(x_1);
return x_2;
}
}
LEAN_EXPORT lean_object* lp_padctl_instReprLayerOverrides_repr___redArg(lean_object* x_1) {
_start:
{
lean_object* x_2; lean_object* x_3; lean_object* x_4; lean_object* x_5; lean_object* x_6; lean_object* x_7; lean_object* x_8; lean_object* x_9; lean_object* x_10; lean_object* x_11; lean_object* x_12; uint8_t x_13; lean_object* x_14; lean_object* x_15; lean_object* x_16; lean_object* x_17; lean_object* x_18; lean_object* x_19; lean_object* x_20; lean_object* x_21; lean_object* x_22; lean_object* x_23; lean_object* x_24; lean_object* x_25; lean_object* x_26; lean_object* x_27; lean_object* x_28; lean_object* x_29; lean_object* x_30; lean_object* x_31; lean_object* x_32; lean_object* x_33; lean_object* x_34; lean_object* x_35; lean_object* x_36; lean_object* x_37; lean_object* x_38; lean_object* x_39; lean_object* x_40; lean_object* x_41; lean_object* x_42; lean_object* x_43; lean_object* x_44; lean_object* x_45; lean_object* x_46; lean_object* x_47; lean_object* x_48; lean_object* x_49; lean_object* x_50; lean_object* x_51; lean_object* x_52; lean_object* x_53; lean_object* x_54; lean_object* x_55; lean_object* x_56; lean_object* x_57; lean_object* x_58; lean_object* x_59; lean_object* x_60; lean_object* x_61; lean_object* x_62; lean_object* x_63; 
x_2 = lean_ctor_get(x_1, 0);
lean_inc(x_2);
x_3 = lean_ctor_get(x_1, 1);
lean_inc(x_3);
x_4 = lean_ctor_get(x_1, 2);
lean_inc(x_4);
x_5 = lean_ctor_get(x_1, 3);
lean_inc(x_5);
x_6 = lean_ctor_get(x_1, 4);
lean_inc(x_6);
lean_dec_ref(x_1);
x_7 = ((lean_object*)(lp_padctl_instReprLayerConfig_repr___redArg___closed__5));
x_8 = ((lean_object*)(lp_padctl_instReprLayerOverrides_repr___redArg___closed__3));
x_9 = lean_obj_once(&lp_padctl_instReprTapHoldState_repr___redArg___closed__4, &lp_padctl_instReprTapHoldState_repr___redArg___closed__4_once, _init_lp_padctl_instReprTapHoldState_repr___redArg___closed__4);
x_10 = lean_unsigned_to_nat(0u);
x_11 = lp_padctl_Option_repr___at___00instReprLayerOverrides_repr_spec__0(x_2, x_10);
lean_dec(x_2);
x_12 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_12, 0, x_9);
lean_ctor_set(x_12, 1, x_11);
x_13 = 0;
x_14 = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(x_14, 0, x_12);
lean_ctor_set_uint8(x_14, sizeof(void*)*1, x_13);
x_15 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_15, 0, x_8);
lean_ctor_set(x_15, 1, x_14);
x_16 = ((lean_object*)(lp_padctl_instReprLayerConfig_repr___redArg___closed__9));
x_17 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_17, 0, x_15);
lean_ctor_set(x_17, 1, x_16);
x_18 = lean_box(1);
x_19 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_19, 0, x_17);
lean_ctor_set(x_19, 1, x_18);
x_20 = ((lean_object*)(lp_padctl_instReprLayerOverrides_repr___redArg___closed__5));
x_21 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_21, 0, x_19);
lean_ctor_set(x_21, 1, x_20);
x_22 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_22, 0, x_21);
lean_ctor_set(x_22, 1, x_7);
x_23 = lean_obj_once(&lp_padctl_instReprLayerOverrides_repr___redArg___closed__6, &lp_padctl_instReprLayerOverrides_repr___redArg___closed__6_once, _init_lp_padctl_instReprLayerOverrides_repr___redArg___closed__6);
x_24 = lp_padctl_Option_repr___at___00instReprLayerOverrides_repr_spec__1(x_3, x_10);
lean_dec(x_3);
x_25 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_25, 0, x_23);
lean_ctor_set(x_25, 1, x_24);
x_26 = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(x_26, 0, x_25);
lean_ctor_set_uint8(x_26, sizeof(void*)*1, x_13);
x_27 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_27, 0, x_22);
lean_ctor_set(x_27, 1, x_26);
x_28 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_28, 0, x_27);
lean_ctor_set(x_28, 1, x_16);
x_29 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_29, 0, x_28);
lean_ctor_set(x_29, 1, x_18);
x_30 = ((lean_object*)(lp_padctl_instReprLayerOverrides_repr___redArg___closed__8));
x_31 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_31, 0, x_29);
lean_ctor_set(x_31, 1, x_30);
x_32 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_32, 0, x_31);
lean_ctor_set(x_32, 1, x_7);
x_33 = lean_obj_once(&lp_padctl_instReprTapHoldState_repr___redArg___closed__10, &lp_padctl_instReprTapHoldState_repr___redArg___closed__10_once, _init_lp_padctl_instReprTapHoldState_repr___redArg___closed__10);
x_34 = lp_padctl_Option_repr___at___00instReprLayerOverrides_repr_spec__1(x_4, x_10);
lean_dec(x_4);
x_35 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_35, 0, x_33);
lean_ctor_set(x_35, 1, x_34);
x_36 = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(x_36, 0, x_35);
lean_ctor_set_uint8(x_36, sizeof(void*)*1, x_13);
x_37 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_37, 0, x_32);
lean_ctor_set(x_37, 1, x_36);
x_38 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_38, 0, x_37);
lean_ctor_set(x_38, 1, x_16);
x_39 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_39, 0, x_38);
lean_ctor_set(x_39, 1, x_18);
x_40 = ((lean_object*)(lp_padctl_instReprLayerOverrides_repr___redArg___closed__10));
x_41 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_41, 0, x_39);
lean_ctor_set(x_41, 1, x_40);
x_42 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_42, 0, x_41);
lean_ctor_set(x_42, 1, x_7);
x_43 = lean_obj_once(&lp_padctl_instReprLayerOverrides_repr___redArg___closed__11, &lp_padctl_instReprLayerOverrides_repr___redArg___closed__11_once, _init_lp_padctl_instReprLayerOverrides_repr___redArg___closed__11);
x_44 = lp_padctl_Option_repr___at___00instReprLayerOverrides_repr_spec__2(x_5, x_10);
x_45 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_45, 0, x_43);
lean_ctor_set(x_45, 1, x_44);
x_46 = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(x_46, 0, x_45);
lean_ctor_set_uint8(x_46, sizeof(void*)*1, x_13);
x_47 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_47, 0, x_42);
lean_ctor_set(x_47, 1, x_46);
x_48 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_48, 0, x_47);
lean_ctor_set(x_48, 1, x_16);
x_49 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_49, 0, x_48);
lean_ctor_set(x_49, 1, x_18);
x_50 = ((lean_object*)(lp_padctl_instReprLayerOverrides_repr___redArg___closed__13));
x_51 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_51, 0, x_49);
lean_ctor_set(x_51, 1, x_50);
x_52 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_52, 0, x_51);
lean_ctor_set(x_52, 1, x_7);
x_53 = lp_padctl_Option_repr___at___00instReprLayerOverrides_repr_spec__3(x_6, x_10);
lean_dec(x_6);
x_54 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_54, 0, x_9);
lean_ctor_set(x_54, 1, x_53);
x_55 = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(x_55, 0, x_54);
lean_ctor_set_uint8(x_55, sizeof(void*)*1, x_13);
x_56 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_56, 0, x_52);
lean_ctor_set(x_56, 1, x_55);
x_57 = lean_obj_once(&lp_padctl_instReprLayerConfig_repr___redArg___closed__18, &lp_padctl_instReprLayerConfig_repr___redArg___closed__18_once, _init_lp_padctl_instReprLayerConfig_repr___redArg___closed__18);
x_58 = ((lean_object*)(lp_padctl_instReprLayerConfig_repr___redArg___closed__19));
x_59 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_59, 0, x_58);
lean_ctor_set(x_59, 1, x_56);
x_60 = ((lean_object*)(lp_padctl_instReprLayerConfig_repr___redArg___closed__20));
x_61 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_61, 0, x_59);
lean_ctor_set(x_61, 1, x_60);
x_62 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_62, 0, x_57);
lean_ctor_set(x_62, 1, x_61);
x_63 = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(x_63, 0, x_62);
lean_ctor_set_uint8(x_63, sizeof(void*)*1, x_13);
return x_63;
}
}
LEAN_EXPORT lean_object* lp_padctl_instReprLayerOverrides_repr(lean_object* x_1, lean_object* x_2) {
_start:
{
lean_object* x_3; 
x_3 = lp_padctl_instReprLayerOverrides_repr___redArg(x_1);
return x_3;
}
}
LEAN_EXPORT lean_object* lp_padctl_instReprLayerOverrides_repr___boxed(lean_object* x_1, lean_object* x_2) {
_start:
{
lean_object* x_3; 
x_3 = lp_padctl_instReprLayerOverrides_repr(x_1, x_2);
lean_dec(x_2);
return x_3;
}
}
LEAN_EXPORT lean_object* lp_padctl_List_foldl___at___00List_foldl___at___00Std_Format_joinSep___at___00List_repr___at___00instReprMapperConfig_repr_spec__1_spec__2_spec__4_spec__8(lean_object* x_1, lean_object* x_2, lean_object* x_3) {
_start:
{
if (lean_obj_tag(x_3) == 0)
{
lean_dec(x_1);
return x_2;
}
else
{
uint8_t x_4; 
x_4 = !lean_is_exclusive(x_3);
if (x_4 == 0)
{
lean_object* x_5; lean_object* x_6; lean_object* x_7; lean_object* x_8; 
x_5 = lean_ctor_get(x_3, 0);
x_6 = lean_ctor_get(x_3, 1);
lean_inc(x_1);
lean_ctor_set_tag(x_3, 5);
lean_ctor_set(x_3, 1, x_1);
lean_ctor_set(x_3, 0, x_2);
x_7 = lp_padctl_instReprRemapEntry_repr___redArg(x_5);
x_8 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_8, 0, x_3);
lean_ctor_set(x_8, 1, x_7);
x_2 = x_8;
x_3 = x_6;
goto _start;
}
else
{
lean_object* x_10; lean_object* x_11; lean_object* x_12; lean_object* x_13; lean_object* x_14; 
x_10 = lean_ctor_get(x_3, 0);
x_11 = lean_ctor_get(x_3, 1);
lean_inc(x_11);
lean_inc(x_10);
lean_dec(x_3);
lean_inc(x_1);
x_12 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_12, 0, x_2);
lean_ctor_set(x_12, 1, x_1);
x_13 = lp_padctl_instReprRemapEntry_repr___redArg(x_10);
x_14 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_14, 0, x_12);
lean_ctor_set(x_14, 1, x_13);
x_2 = x_14;
x_3 = x_11;
goto _start;
}
}
}
}
LEAN_EXPORT lean_object* lp_padctl_List_foldl___at___00Std_Format_joinSep___at___00List_repr___at___00instReprMapperConfig_repr_spec__1_spec__2_spec__4(lean_object* x_1, lean_object* x_2, lean_object* x_3) {
_start:
{
if (lean_obj_tag(x_3) == 0)
{
lean_dec(x_1);
return x_2;
}
else
{
uint8_t x_4; 
x_4 = !lean_is_exclusive(x_3);
if (x_4 == 0)
{
lean_object* x_5; lean_object* x_6; lean_object* x_7; lean_object* x_8; lean_object* x_9; 
x_5 = lean_ctor_get(x_3, 0);
x_6 = lean_ctor_get(x_3, 1);
lean_inc(x_1);
lean_ctor_set_tag(x_3, 5);
lean_ctor_set(x_3, 1, x_1);
lean_ctor_set(x_3, 0, x_2);
x_7 = lp_padctl_instReprRemapEntry_repr___redArg(x_5);
x_8 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_8, 0, x_3);
lean_ctor_set(x_8, 1, x_7);
x_9 = lp_padctl_List_foldl___at___00List_foldl___at___00Std_Format_joinSep___at___00List_repr___at___00instReprMapperConfig_repr_spec__1_spec__2_spec__4_spec__8(x_1, x_8, x_6);
return x_9;
}
else
{
lean_object* x_10; lean_object* x_11; lean_object* x_12; lean_object* x_13; lean_object* x_14; lean_object* x_15; 
x_10 = lean_ctor_get(x_3, 0);
x_11 = lean_ctor_get(x_3, 1);
lean_inc(x_11);
lean_inc(x_10);
lean_dec(x_3);
lean_inc(x_1);
x_12 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_12, 0, x_2);
lean_ctor_set(x_12, 1, x_1);
x_13 = lp_padctl_instReprRemapEntry_repr___redArg(x_10);
x_14 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_14, 0, x_12);
lean_ctor_set(x_14, 1, x_13);
x_15 = lp_padctl_List_foldl___at___00List_foldl___at___00Std_Format_joinSep___at___00List_repr___at___00instReprMapperConfig_repr_spec__1_spec__2_spec__4_spec__8(x_1, x_14, x_11);
return x_15;
}
}
}
}
LEAN_EXPORT lean_object* lp_padctl_Std_Format_joinSep___at___00List_repr___at___00instReprMapperConfig_repr_spec__1_spec__2(lean_object* x_1, lean_object* x_2) {
_start:
{
if (lean_obj_tag(x_1) == 0)
{
lean_object* x_3; 
lean_dec(x_2);
x_3 = lean_box(0);
return x_3;
}
else
{
lean_object* x_4; 
x_4 = lean_ctor_get(x_1, 1);
if (lean_obj_tag(x_4) == 0)
{
lean_object* x_5; lean_object* x_6; 
lean_dec(x_2);
x_5 = lean_ctor_get(x_1, 0);
lean_inc(x_5);
lean_dec_ref(x_1);
x_6 = lp_padctl_instReprRemapEntry_repr___redArg(x_5);
return x_6;
}
else
{
lean_object* x_7; lean_object* x_8; lean_object* x_9; 
lean_inc(x_4);
x_7 = lean_ctor_get(x_1, 0);
lean_inc(x_7);
lean_dec_ref(x_1);
x_8 = lp_padctl_instReprRemapEntry_repr___redArg(x_7);
x_9 = lp_padctl_List_foldl___at___00Std_Format_joinSep___at___00List_repr___at___00instReprMapperConfig_repr_spec__1_spec__2_spec__4(x_2, x_8, x_4);
return x_9;
}
}
}
}
LEAN_EXPORT lean_object* lp_padctl_List_repr___at___00instReprMapperConfig_repr_spec__1___redArg(lean_object* x_1) {
_start:
{
if (lean_obj_tag(x_1) == 0)
{
lean_object* x_2; 
x_2 = ((lean_object*)(lp_padctl_List_repr___at___00instReprMacroState_repr_spec__1___redArg___closed__1));
return x_2;
}
else
{
lean_object* x_3; lean_object* x_4; lean_object* x_5; lean_object* x_6; lean_object* x_7; lean_object* x_8; lean_object* x_9; lean_object* x_10; uint8_t x_11; lean_object* x_12; 
x_3 = ((lean_object*)(lp_padctl_List_repr___at___00instReprMacroState_repr_spec__1___redArg___closed__3));
x_4 = lp_padctl_Std_Format_joinSep___at___00List_repr___at___00instReprMapperConfig_repr_spec__1_spec__2(x_1, x_3);
x_5 = lean_obj_once(&lp_padctl_List_repr___at___00instReprMacroState_repr_spec__1___redArg___closed__6, &lp_padctl_List_repr___at___00instReprMacroState_repr_spec__1___redArg___closed__6_once, _init_lp_padctl_List_repr___at___00instReprMacroState_repr_spec__1___redArg___closed__6);
x_6 = ((lean_object*)(lp_padctl_List_repr___at___00instReprMacroState_repr_spec__1___redArg___closed__7));
x_7 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_7, 0, x_6);
lean_ctor_set(x_7, 1, x_4);
x_8 = ((lean_object*)(lp_padctl_List_repr___at___00instReprMacroState_repr_spec__1___redArg___closed__8));
x_9 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_9, 0, x_7);
lean_ctor_set(x_9, 1, x_8);
x_10 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_10, 0, x_5);
lean_ctor_set(x_10, 1, x_9);
x_11 = 0;
x_12 = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(x_12, 0, x_10);
lean_ctor_set_uint8(x_12, sizeof(void*)*1, x_11);
return x_12;
}
}
}
LEAN_EXPORT lean_object* lp_padctl_List_foldl___at___00List_foldl___at___00Std_Format_joinSep___at___00List_repr___at___00instReprMapperConfig_repr_spec__3_spec__6_spec__10_spec__14(lean_object* x_1, lean_object* x_2, lean_object* x_3) {
_start:
{
if (lean_obj_tag(x_3) == 0)
{
lean_dec(x_1);
return x_2;
}
else
{
uint8_t x_4; 
x_4 = !lean_is_exclusive(x_3);
if (x_4 == 0)
{
lean_object* x_5; lean_object* x_6; lean_object* x_7; lean_object* x_8; 
x_5 = lean_ctor_get(x_3, 0);
x_6 = lean_ctor_get(x_3, 1);
lean_inc(x_1);
lean_ctor_set_tag(x_3, 5);
lean_ctor_set(x_3, 1, x_1);
lean_ctor_set(x_3, 0, x_2);
x_7 = lp_padctl_instReprLayerOverrides_repr___redArg(x_5);
x_8 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_8, 0, x_3);
lean_ctor_set(x_8, 1, x_7);
x_2 = x_8;
x_3 = x_6;
goto _start;
}
else
{
lean_object* x_10; lean_object* x_11; lean_object* x_12; lean_object* x_13; lean_object* x_14; 
x_10 = lean_ctor_get(x_3, 0);
x_11 = lean_ctor_get(x_3, 1);
lean_inc(x_11);
lean_inc(x_10);
lean_dec(x_3);
lean_inc(x_1);
x_12 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_12, 0, x_2);
lean_ctor_set(x_12, 1, x_1);
x_13 = lp_padctl_instReprLayerOverrides_repr___redArg(x_10);
x_14 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_14, 0, x_12);
lean_ctor_set(x_14, 1, x_13);
x_2 = x_14;
x_3 = x_11;
goto _start;
}
}
}
}
LEAN_EXPORT lean_object* lp_padctl_List_foldl___at___00Std_Format_joinSep___at___00List_repr___at___00instReprMapperConfig_repr_spec__3_spec__6_spec__10(lean_object* x_1, lean_object* x_2, lean_object* x_3) {
_start:
{
if (lean_obj_tag(x_3) == 0)
{
lean_dec(x_1);
return x_2;
}
else
{
uint8_t x_4; 
x_4 = !lean_is_exclusive(x_3);
if (x_4 == 0)
{
lean_object* x_5; lean_object* x_6; lean_object* x_7; lean_object* x_8; lean_object* x_9; 
x_5 = lean_ctor_get(x_3, 0);
x_6 = lean_ctor_get(x_3, 1);
lean_inc(x_1);
lean_ctor_set_tag(x_3, 5);
lean_ctor_set(x_3, 1, x_1);
lean_ctor_set(x_3, 0, x_2);
x_7 = lp_padctl_instReprLayerOverrides_repr___redArg(x_5);
x_8 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_8, 0, x_3);
lean_ctor_set(x_8, 1, x_7);
x_9 = lp_padctl_List_foldl___at___00List_foldl___at___00Std_Format_joinSep___at___00List_repr___at___00instReprMapperConfig_repr_spec__3_spec__6_spec__10_spec__14(x_1, x_8, x_6);
return x_9;
}
else
{
lean_object* x_10; lean_object* x_11; lean_object* x_12; lean_object* x_13; lean_object* x_14; lean_object* x_15; 
x_10 = lean_ctor_get(x_3, 0);
x_11 = lean_ctor_get(x_3, 1);
lean_inc(x_11);
lean_inc(x_10);
lean_dec(x_3);
lean_inc(x_1);
x_12 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_12, 0, x_2);
lean_ctor_set(x_12, 1, x_1);
x_13 = lp_padctl_instReprLayerOverrides_repr___redArg(x_10);
x_14 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_14, 0, x_12);
lean_ctor_set(x_14, 1, x_13);
x_15 = lp_padctl_List_foldl___at___00List_foldl___at___00Std_Format_joinSep___at___00List_repr___at___00instReprMapperConfig_repr_spec__3_spec__6_spec__10_spec__14(x_1, x_14, x_11);
return x_15;
}
}
}
}
LEAN_EXPORT lean_object* lp_padctl_Std_Format_joinSep___at___00List_repr___at___00instReprMapperConfig_repr_spec__3_spec__6(lean_object* x_1, lean_object* x_2) {
_start:
{
if (lean_obj_tag(x_1) == 0)
{
lean_object* x_3; 
lean_dec(x_2);
x_3 = lean_box(0);
return x_3;
}
else
{
lean_object* x_4; 
x_4 = lean_ctor_get(x_1, 1);
if (lean_obj_tag(x_4) == 0)
{
lean_object* x_5; lean_object* x_6; 
lean_dec(x_2);
x_5 = lean_ctor_get(x_1, 0);
lean_inc(x_5);
lean_dec_ref(x_1);
x_6 = lp_padctl_instReprLayerOverrides_repr___redArg(x_5);
return x_6;
}
else
{
lean_object* x_7; lean_object* x_8; lean_object* x_9; 
lean_inc(x_4);
x_7 = lean_ctor_get(x_1, 0);
lean_inc(x_7);
lean_dec_ref(x_1);
x_8 = lp_padctl_instReprLayerOverrides_repr___redArg(x_7);
x_9 = lp_padctl_List_foldl___at___00Std_Format_joinSep___at___00List_repr___at___00instReprMapperConfig_repr_spec__3_spec__6_spec__10(x_2, x_8, x_4);
return x_9;
}
}
}
}
LEAN_EXPORT lean_object* lp_padctl_List_repr___at___00instReprMapperConfig_repr_spec__3___redArg(lean_object* x_1) {
_start:
{
if (lean_obj_tag(x_1) == 0)
{
lean_object* x_2; 
x_2 = ((lean_object*)(lp_padctl_List_repr___at___00instReprMacroState_repr_spec__1___redArg___closed__1));
return x_2;
}
else
{
lean_object* x_3; lean_object* x_4; lean_object* x_5; lean_object* x_6; lean_object* x_7; lean_object* x_8; lean_object* x_9; lean_object* x_10; uint8_t x_11; lean_object* x_12; 
x_3 = ((lean_object*)(lp_padctl_List_repr___at___00instReprMacroState_repr_spec__1___redArg___closed__3));
x_4 = lp_padctl_Std_Format_joinSep___at___00List_repr___at___00instReprMapperConfig_repr_spec__3_spec__6(x_1, x_3);
x_5 = lean_obj_once(&lp_padctl_List_repr___at___00instReprMacroState_repr_spec__1___redArg___closed__6, &lp_padctl_List_repr___at___00instReprMacroState_repr_spec__1___redArg___closed__6_once, _init_lp_padctl_List_repr___at___00instReprMacroState_repr_spec__1___redArg___closed__6);
x_6 = ((lean_object*)(lp_padctl_List_repr___at___00instReprMacroState_repr_spec__1___redArg___closed__7));
x_7 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_7, 0, x_6);
lean_ctor_set(x_7, 1, x_4);
x_8 = ((lean_object*)(lp_padctl_List_repr___at___00instReprMacroState_repr_spec__1___redArg___closed__8));
x_9 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_9, 0, x_7);
lean_ctor_set(x_9, 1, x_8);
x_10 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_10, 0, x_5);
lean_ctor_set(x_10, 1, x_9);
x_11 = 0;
x_12 = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(x_12, 0, x_10);
lean_ctor_set_uint8(x_12, sizeof(void*)*1, x_11);
return x_12;
}
}
}
LEAN_EXPORT lean_object* lp_padctl_List_foldl___at___00List_foldl___at___00Std_Format_joinSep___at___00List_repr___at___00instReprMapperConfig_repr_spec__0_spec__0_spec__1_spec__5(lean_object* x_1, lean_object* x_2, lean_object* x_3) {
_start:
{
if (lean_obj_tag(x_3) == 0)
{
lean_dec(x_1);
return x_2;
}
else
{
uint8_t x_4; 
x_4 = !lean_is_exclusive(x_3);
if (x_4 == 0)
{
lean_object* x_5; lean_object* x_6; lean_object* x_7; lean_object* x_8; 
x_5 = lean_ctor_get(x_3, 0);
x_6 = lean_ctor_get(x_3, 1);
lean_inc(x_1);
lean_ctor_set_tag(x_3, 5);
lean_ctor_set(x_3, 1, x_1);
lean_ctor_set(x_3, 0, x_2);
x_7 = lp_padctl_instReprLayerConfig_repr___redArg(x_5);
x_8 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_8, 0, x_3);
lean_ctor_set(x_8, 1, x_7);
x_2 = x_8;
x_3 = x_6;
goto _start;
}
else
{
lean_object* x_10; lean_object* x_11; lean_object* x_12; lean_object* x_13; lean_object* x_14; 
x_10 = lean_ctor_get(x_3, 0);
x_11 = lean_ctor_get(x_3, 1);
lean_inc(x_11);
lean_inc(x_10);
lean_dec(x_3);
lean_inc(x_1);
x_12 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_12, 0, x_2);
lean_ctor_set(x_12, 1, x_1);
x_13 = lp_padctl_instReprLayerConfig_repr___redArg(x_10);
x_14 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_14, 0, x_12);
lean_ctor_set(x_14, 1, x_13);
x_2 = x_14;
x_3 = x_11;
goto _start;
}
}
}
}
LEAN_EXPORT lean_object* lp_padctl_List_foldl___at___00Std_Format_joinSep___at___00List_repr___at___00instReprMapperConfig_repr_spec__0_spec__0_spec__1(lean_object* x_1, lean_object* x_2, lean_object* x_3) {
_start:
{
if (lean_obj_tag(x_3) == 0)
{
lean_dec(x_1);
return x_2;
}
else
{
uint8_t x_4; 
x_4 = !lean_is_exclusive(x_3);
if (x_4 == 0)
{
lean_object* x_5; lean_object* x_6; lean_object* x_7; lean_object* x_8; lean_object* x_9; 
x_5 = lean_ctor_get(x_3, 0);
x_6 = lean_ctor_get(x_3, 1);
lean_inc(x_1);
lean_ctor_set_tag(x_3, 5);
lean_ctor_set(x_3, 1, x_1);
lean_ctor_set(x_3, 0, x_2);
x_7 = lp_padctl_instReprLayerConfig_repr___redArg(x_5);
x_8 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_8, 0, x_3);
lean_ctor_set(x_8, 1, x_7);
x_9 = lp_padctl_List_foldl___at___00List_foldl___at___00Std_Format_joinSep___at___00List_repr___at___00instReprMapperConfig_repr_spec__0_spec__0_spec__1_spec__5(x_1, x_8, x_6);
return x_9;
}
else
{
lean_object* x_10; lean_object* x_11; lean_object* x_12; lean_object* x_13; lean_object* x_14; lean_object* x_15; 
x_10 = lean_ctor_get(x_3, 0);
x_11 = lean_ctor_get(x_3, 1);
lean_inc(x_11);
lean_inc(x_10);
lean_dec(x_3);
lean_inc(x_1);
x_12 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_12, 0, x_2);
lean_ctor_set(x_12, 1, x_1);
x_13 = lp_padctl_instReprLayerConfig_repr___redArg(x_10);
x_14 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_14, 0, x_12);
lean_ctor_set(x_14, 1, x_13);
x_15 = lp_padctl_List_foldl___at___00List_foldl___at___00Std_Format_joinSep___at___00List_repr___at___00instReprMapperConfig_repr_spec__0_spec__0_spec__1_spec__5(x_1, x_14, x_11);
return x_15;
}
}
}
}
LEAN_EXPORT lean_object* lp_padctl_Std_Format_joinSep___at___00List_repr___at___00instReprMapperConfig_repr_spec__0_spec__0(lean_object* x_1, lean_object* x_2) {
_start:
{
if (lean_obj_tag(x_1) == 0)
{
lean_object* x_3; 
lean_dec(x_2);
x_3 = lean_box(0);
return x_3;
}
else
{
lean_object* x_4; 
x_4 = lean_ctor_get(x_1, 1);
if (lean_obj_tag(x_4) == 0)
{
lean_object* x_5; lean_object* x_6; 
lean_dec(x_2);
x_5 = lean_ctor_get(x_1, 0);
lean_inc(x_5);
lean_dec_ref(x_1);
x_6 = lp_padctl_instReprLayerConfig_repr___redArg(x_5);
return x_6;
}
else
{
lean_object* x_7; lean_object* x_8; lean_object* x_9; 
lean_inc(x_4);
x_7 = lean_ctor_get(x_1, 0);
lean_inc(x_7);
lean_dec_ref(x_1);
x_8 = lp_padctl_instReprLayerConfig_repr___redArg(x_7);
x_9 = lp_padctl_List_foldl___at___00Std_Format_joinSep___at___00List_repr___at___00instReprMapperConfig_repr_spec__0_spec__0_spec__1(x_2, x_8, x_4);
return x_9;
}
}
}
}
LEAN_EXPORT lean_object* lp_padctl_List_repr___at___00instReprMapperConfig_repr_spec__0___redArg(lean_object* x_1) {
_start:
{
if (lean_obj_tag(x_1) == 0)
{
lean_object* x_2; 
x_2 = ((lean_object*)(lp_padctl_List_repr___at___00instReprMacroState_repr_spec__1___redArg___closed__1));
return x_2;
}
else
{
lean_object* x_3; lean_object* x_4; lean_object* x_5; lean_object* x_6; lean_object* x_7; lean_object* x_8; lean_object* x_9; lean_object* x_10; uint8_t x_11; lean_object* x_12; 
x_3 = ((lean_object*)(lp_padctl_List_repr___at___00instReprMacroState_repr_spec__1___redArg___closed__3));
x_4 = lp_padctl_Std_Format_joinSep___at___00List_repr___at___00instReprMapperConfig_repr_spec__0_spec__0(x_1, x_3);
x_5 = lean_obj_once(&lp_padctl_List_repr___at___00instReprMacroState_repr_spec__1___redArg___closed__6, &lp_padctl_List_repr___at___00instReprMacroState_repr_spec__1___redArg___closed__6_once, _init_lp_padctl_List_repr___at___00instReprMacroState_repr_spec__1___redArg___closed__6);
x_6 = ((lean_object*)(lp_padctl_List_repr___at___00instReprMacroState_repr_spec__1___redArg___closed__7));
x_7 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_7, 0, x_6);
lean_ctor_set(x_7, 1, x_4);
x_8 = ((lean_object*)(lp_padctl_List_repr___at___00instReprMacroState_repr_spec__1___redArg___closed__8));
x_9 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_9, 0, x_7);
lean_ctor_set(x_9, 1, x_8);
x_10 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_10, 0, x_5);
lean_ctor_set(x_10, 1, x_9);
x_11 = 0;
x_12 = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(x_12, 0, x_10);
lean_ctor_set_uint8(x_12, sizeof(void*)*1, x_11);
return x_12;
}
}
}
LEAN_EXPORT lean_object* lp_padctl_List_foldl___at___00List_foldl___at___00Std_Format_joinSep___at___00List_repr___at___00instReprMapperConfig_repr_spec__2_spec__4_spec__7_spec__11(lean_object* x_1, lean_object* x_2, lean_object* x_3) {
_start:
{
if (lean_obj_tag(x_3) == 0)
{
lean_dec(x_1);
return x_2;
}
else
{
uint8_t x_4; 
x_4 = !lean_is_exclusive(x_3);
if (x_4 == 0)
{
lean_object* x_5; lean_object* x_6; lean_object* x_7; lean_object* x_8; 
x_5 = lean_ctor_get(x_3, 0);
x_6 = lean_ctor_get(x_3, 1);
lean_inc(x_1);
lean_ctor_set_tag(x_3, 5);
lean_ctor_set(x_3, 1, x_1);
lean_ctor_set(x_3, 0, x_2);
x_7 = lp_padctl_List_repr___at___00instReprMapperConfig_repr_spec__1___redArg(x_5);
x_8 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_8, 0, x_3);
lean_ctor_set(x_8, 1, x_7);
x_2 = x_8;
x_3 = x_6;
goto _start;
}
else
{
lean_object* x_10; lean_object* x_11; lean_object* x_12; lean_object* x_13; lean_object* x_14; 
x_10 = lean_ctor_get(x_3, 0);
x_11 = lean_ctor_get(x_3, 1);
lean_inc(x_11);
lean_inc(x_10);
lean_dec(x_3);
lean_inc(x_1);
x_12 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_12, 0, x_2);
lean_ctor_set(x_12, 1, x_1);
x_13 = lp_padctl_List_repr___at___00instReprMapperConfig_repr_spec__1___redArg(x_10);
x_14 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_14, 0, x_12);
lean_ctor_set(x_14, 1, x_13);
x_2 = x_14;
x_3 = x_11;
goto _start;
}
}
}
}
LEAN_EXPORT lean_object* lp_padctl_List_foldl___at___00Std_Format_joinSep___at___00List_repr___at___00instReprMapperConfig_repr_spec__2_spec__4_spec__7(lean_object* x_1, lean_object* x_2, lean_object* x_3) {
_start:
{
if (lean_obj_tag(x_3) == 0)
{
lean_dec(x_1);
return x_2;
}
else
{
uint8_t x_4; 
x_4 = !lean_is_exclusive(x_3);
if (x_4 == 0)
{
lean_object* x_5; lean_object* x_6; lean_object* x_7; lean_object* x_8; lean_object* x_9; 
x_5 = lean_ctor_get(x_3, 0);
x_6 = lean_ctor_get(x_3, 1);
lean_inc(x_1);
lean_ctor_set_tag(x_3, 5);
lean_ctor_set(x_3, 1, x_1);
lean_ctor_set(x_3, 0, x_2);
x_7 = lp_padctl_List_repr___at___00instReprMapperConfig_repr_spec__1___redArg(x_5);
x_8 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_8, 0, x_3);
lean_ctor_set(x_8, 1, x_7);
x_9 = lp_padctl_List_foldl___at___00List_foldl___at___00Std_Format_joinSep___at___00List_repr___at___00instReprMapperConfig_repr_spec__2_spec__4_spec__7_spec__11(x_1, x_8, x_6);
return x_9;
}
else
{
lean_object* x_10; lean_object* x_11; lean_object* x_12; lean_object* x_13; lean_object* x_14; lean_object* x_15; 
x_10 = lean_ctor_get(x_3, 0);
x_11 = lean_ctor_get(x_3, 1);
lean_inc(x_11);
lean_inc(x_10);
lean_dec(x_3);
lean_inc(x_1);
x_12 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_12, 0, x_2);
lean_ctor_set(x_12, 1, x_1);
x_13 = lp_padctl_List_repr___at___00instReprMapperConfig_repr_spec__1___redArg(x_10);
x_14 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_14, 0, x_12);
lean_ctor_set(x_14, 1, x_13);
x_15 = lp_padctl_List_foldl___at___00List_foldl___at___00Std_Format_joinSep___at___00List_repr___at___00instReprMapperConfig_repr_spec__2_spec__4_spec__7_spec__11(x_1, x_14, x_11);
return x_15;
}
}
}
}
LEAN_EXPORT lean_object* lp_padctl_Std_Format_joinSep___at___00List_repr___at___00instReprMapperConfig_repr_spec__2_spec__4(lean_object* x_1, lean_object* x_2) {
_start:
{
if (lean_obj_tag(x_1) == 0)
{
lean_object* x_3; 
lean_dec(x_2);
x_3 = lean_box(0);
return x_3;
}
else
{
lean_object* x_4; 
x_4 = lean_ctor_get(x_1, 1);
if (lean_obj_tag(x_4) == 0)
{
lean_object* x_5; lean_object* x_6; 
lean_dec(x_2);
x_5 = lean_ctor_get(x_1, 0);
lean_inc(x_5);
lean_dec_ref(x_1);
x_6 = lp_padctl_List_repr___at___00instReprMapperConfig_repr_spec__1___redArg(x_5);
return x_6;
}
else
{
lean_object* x_7; lean_object* x_8; lean_object* x_9; 
lean_inc(x_4);
x_7 = lean_ctor_get(x_1, 0);
lean_inc(x_7);
lean_dec_ref(x_1);
x_8 = lp_padctl_List_repr___at___00instReprMapperConfig_repr_spec__1___redArg(x_7);
x_9 = lp_padctl_List_foldl___at___00Std_Format_joinSep___at___00List_repr___at___00instReprMapperConfig_repr_spec__2_spec__4_spec__7(x_2, x_8, x_4);
return x_9;
}
}
}
}
LEAN_EXPORT lean_object* lp_padctl_List_repr___at___00instReprMapperConfig_repr_spec__2___redArg(lean_object* x_1) {
_start:
{
if (lean_obj_tag(x_1) == 0)
{
lean_object* x_2; 
x_2 = ((lean_object*)(lp_padctl_List_repr___at___00instReprMacroState_repr_spec__1___redArg___closed__1));
return x_2;
}
else
{
lean_object* x_3; lean_object* x_4; lean_object* x_5; lean_object* x_6; lean_object* x_7; lean_object* x_8; lean_object* x_9; lean_object* x_10; uint8_t x_11; lean_object* x_12; 
x_3 = ((lean_object*)(lp_padctl_List_repr___at___00instReprMacroState_repr_spec__1___redArg___closed__3));
x_4 = lp_padctl_Std_Format_joinSep___at___00List_repr___at___00instReprMapperConfig_repr_spec__2_spec__4(x_1, x_3);
x_5 = lean_obj_once(&lp_padctl_List_repr___at___00instReprMacroState_repr_spec__1___redArg___closed__6, &lp_padctl_List_repr___at___00instReprMacroState_repr_spec__1___redArg___closed__6_once, _init_lp_padctl_List_repr___at___00instReprMacroState_repr_spec__1___redArg___closed__6);
x_6 = ((lean_object*)(lp_padctl_List_repr___at___00instReprMacroState_repr_spec__1___redArg___closed__7));
x_7 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_7, 0, x_6);
lean_ctor_set(x_7, 1, x_4);
x_8 = ((lean_object*)(lp_padctl_List_repr___at___00instReprMacroState_repr_spec__1___redArg___closed__8));
x_9 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_9, 0, x_7);
lean_ctor_set(x_9, 1, x_8);
x_10 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_10, 0, x_5);
lean_ctor_set(x_10, 1, x_9);
x_11 = 0;
x_12 = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(x_12, 0, x_10);
lean_ctor_set_uint8(x_12, sizeof(void*)*1, x_11);
return x_12;
}
}
}
static lean_object* _init_lp_padctl_instReprMapperConfig_repr___redArg___closed__10(void) {
_start:
{
lean_object* x_1; lean_object* x_2; 
x_1 = lean_unsigned_to_nat(23u);
x_2 = lean_nat_to_int(x_1);
return x_2;
}
}
LEAN_EXPORT lean_object* lp_padctl_instReprMapperConfig_repr___redArg(lean_object* x_1) {
_start:
{
lean_object* x_2; lean_object* x_3; lean_object* x_4; uint8_t x_5; uint8_t x_6; lean_object* x_7; uint8_t x_8; uint8_t x_9; uint8_t x_10; lean_object* x_11; lean_object* x_12; lean_object* x_13; lean_object* x_14; lean_object* x_15; lean_object* x_16; lean_object* x_17; uint8_t x_18; lean_object* x_19; lean_object* x_20; lean_object* x_21; lean_object* x_22; lean_object* x_23; lean_object* x_24; lean_object* x_25; lean_object* x_26; lean_object* x_27; lean_object* x_28; lean_object* x_29; lean_object* x_30; lean_object* x_31; lean_object* x_32; lean_object* x_33; lean_object* x_34; lean_object* x_35; lean_object* x_36; lean_object* x_37; lean_object* x_38; lean_object* x_39; lean_object* x_40; lean_object* x_41; lean_object* x_42; lean_object* x_43; lean_object* x_44; lean_object* x_45; lean_object* x_46; lean_object* x_47; lean_object* x_48; lean_object* x_49; lean_object* x_50; lean_object* x_51; lean_object* x_52; lean_object* x_53; lean_object* x_54; lean_object* x_55; lean_object* x_56; lean_object* x_57; lean_object* x_58; lean_object* x_59; lean_object* x_60; lean_object* x_61; lean_object* x_62; lean_object* x_63; lean_object* x_64; lean_object* x_65; lean_object* x_66; lean_object* x_67; lean_object* x_68; lean_object* x_69; lean_object* x_70; lean_object* x_71; lean_object* x_72; lean_object* x_73; lean_object* x_74; lean_object* x_75; lean_object* x_76; lean_object* x_77; lean_object* x_78; lean_object* x_79; lean_object* x_80; lean_object* x_81; lean_object* x_82; lean_object* x_83; lean_object* x_84; lean_object* x_85; lean_object* x_86; lean_object* x_87; lean_object* x_88; lean_object* x_89; lean_object* x_90; lean_object* x_91; lean_object* x_92; lean_object* x_93; lean_object* x_94; lean_object* x_95; lean_object* x_96; lean_object* x_97; lean_object* x_98; lean_object* x_99; lean_object* x_100; lean_object* x_101; lean_object* x_102; lean_object* x_103; lean_object* x_104; lean_object* x_105; lean_object* x_106; lean_object* x_107; lean_object* x_108; lean_object* x_109; lean_object* x_110; lean_object* x_111; lean_object* x_112; lean_object* x_113; lean_object* x_114; lean_object* x_115; lean_object* x_116; lean_object* x_117; 
x_2 = lean_ctor_get(x_1, 0);
lean_inc(x_2);
x_3 = lean_ctor_get(x_1, 1);
lean_inc(x_3);
x_4 = lean_ctor_get(x_1, 2);
lean_inc(x_4);
x_5 = lean_ctor_get_uint8(x_1, sizeof(void*)*5);
x_6 = lean_ctor_get_uint8(x_1, sizeof(void*)*5 + 1);
x_7 = lean_ctor_get(x_1, 3);
lean_inc(x_7);
x_8 = lean_ctor_get_uint8(x_1, sizeof(void*)*5 + 2);
x_9 = lean_ctor_get_uint8(x_1, sizeof(void*)*5 + 3);
x_10 = lean_ctor_get_uint8(x_1, sizeof(void*)*5 + 4);
x_11 = lean_ctor_get(x_1, 4);
lean_inc(x_11);
lean_dec_ref(x_1);
x_12 = ((lean_object*)(lp_padctl_instReprLayerConfig_repr___redArg___closed__5));
x_13 = ((lean_object*)(lp_padctl_instReprMapperConfig_repr___redArg___closed__3));
x_14 = lean_obj_once(&lp_padctl_instReprMacroState_repr___redArg___closed__4, &lp_padctl_instReprMacroState_repr___redArg___closed__4_once, _init_lp_padctl_instReprMacroState_repr___redArg___closed__4);
x_15 = lean_unsigned_to_nat(0u);
x_16 = lp_padctl_List_repr___at___00instReprMapperConfig_repr_spec__0___redArg(x_2);
x_17 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_17, 0, x_14);
lean_ctor_set(x_17, 1, x_16);
x_18 = 0;
x_19 = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(x_19, 0, x_17);
lean_ctor_set_uint8(x_19, sizeof(void*)*1, x_18);
x_20 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_20, 0, x_13);
lean_ctor_set(x_20, 1, x_19);
x_21 = ((lean_object*)(lp_padctl_instReprLayerConfig_repr___redArg___closed__9));
x_22 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_22, 0, x_20);
lean_ctor_set(x_22, 1, x_21);
x_23 = lean_box(1);
x_24 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_24, 0, x_22);
lean_ctor_set(x_24, 1, x_23);
x_25 = ((lean_object*)(lp_padctl_instReprMapperConfig_repr___redArg___closed__5));
x_26 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_26, 0, x_24);
lean_ctor_set(x_26, 1, x_25);
x_27 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_27, 0, x_26);
lean_ctor_set(x_27, 1, x_12);
x_28 = lean_obj_once(&lp_padctl_instReprMacroState_repr___redArg___closed__14, &lp_padctl_instReprMacroState_repr___redArg___closed__14_once, _init_lp_padctl_instReprMacroState_repr___redArg___closed__14);
x_29 = lp_padctl_List_repr___at___00instReprMapperConfig_repr_spec__1___redArg(x_3);
x_30 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_30, 0, x_28);
lean_ctor_set(x_30, 1, x_29);
x_31 = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(x_31, 0, x_30);
lean_ctor_set_uint8(x_31, sizeof(void*)*1, x_18);
x_32 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_32, 0, x_27);
lean_ctor_set(x_32, 1, x_31);
x_33 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_33, 0, x_32);
lean_ctor_set(x_33, 1, x_21);
x_34 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_34, 0, x_33);
lean_ctor_set(x_34, 1, x_23);
x_35 = ((lean_object*)(lp_padctl_instReprMapperConfig_repr___redArg___closed__7));
x_36 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_36, 0, x_34);
lean_ctor_set(x_36, 1, x_35);
x_37 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_37, 0, x_36);
lean_ctor_set(x_37, 1, x_12);
x_38 = lean_obj_once(&lp_padctl_instReprLayerConfig_repr___redArg___closed__15, &lp_padctl_instReprLayerConfig_repr___redArg___closed__15_once, _init_lp_padctl_instReprLayerConfig_repr___redArg___closed__15);
x_39 = lp_padctl_List_repr___at___00instReprMapperConfig_repr_spec__2___redArg(x_4);
x_40 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_40, 0, x_38);
lean_ctor_set(x_40, 1, x_39);
x_41 = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(x_41, 0, x_40);
lean_ctor_set_uint8(x_41, sizeof(void*)*1, x_18);
x_42 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_42, 0, x_37);
lean_ctor_set(x_42, 1, x_41);
x_43 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_43, 0, x_42);
lean_ctor_set(x_43, 1, x_21);
x_44 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_44, 0, x_43);
lean_ctor_set(x_44, 1, x_23);
x_45 = ((lean_object*)(lp_padctl_instReprLayerOverrides_repr___redArg___closed__1));
x_46 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_46, 0, x_44);
lean_ctor_set(x_46, 1, x_45);
x_47 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_47, 0, x_46);
lean_ctor_set(x_47, 1, x_12);
x_48 = lean_obj_once(&lp_padctl_instReprTapHoldState_repr___redArg___closed__4, &lp_padctl_instReprTapHoldState_repr___redArg___closed__4_once, _init_lp_padctl_instReprTapHoldState_repr___redArg___closed__4);
x_49 = lp_padctl_instReprDpadMode_repr(x_5, x_15);
x_50 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_50, 0, x_48);
lean_ctor_set(x_50, 1, x_49);
x_51 = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(x_51, 0, x_50);
lean_ctor_set_uint8(x_51, sizeof(void*)*1, x_18);
x_52 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_52, 0, x_47);
lean_ctor_set(x_52, 1, x_51);
x_53 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_53, 0, x_52);
lean_ctor_set(x_53, 1, x_21);
x_54 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_54, 0, x_53);
lean_ctor_set(x_54, 1, x_23);
x_55 = ((lean_object*)(lp_padctl_instReprMapperConfig_repr___redArg___closed__9));
x_56 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_56, 0, x_54);
lean_ctor_set(x_56, 1, x_55);
x_57 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_57, 0, x_56);
lean_ctor_set(x_57, 1, x_12);
x_58 = lean_obj_once(&lp_padctl_instReprMapperConfig_repr___redArg___closed__10, &lp_padctl_instReprMapperConfig_repr___redArg___closed__10_once, _init_lp_padctl_instReprMapperConfig_repr___redArg___closed__10);
x_59 = l_Bool_repr___redArg(x_6);
x_60 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_60, 0, x_58);
lean_ctor_set(x_60, 1, x_59);
x_61 = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(x_61, 0, x_60);
lean_ctor_set_uint8(x_61, sizeof(void*)*1, x_18);
x_62 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_62, 0, x_57);
lean_ctor_set(x_62, 1, x_61);
x_63 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_63, 0, x_62);
lean_ctor_set(x_63, 1, x_21);
x_64 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_64, 0, x_63);
lean_ctor_set(x_64, 1, x_23);
x_65 = ((lean_object*)(lp_padctl_instReprLayerOverrides_repr___redArg___closed__10));
x_66 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_66, 0, x_64);
lean_ctor_set(x_66, 1, x_65);
x_67 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_67, 0, x_66);
lean_ctor_set(x_67, 1, x_12);
x_68 = lean_obj_once(&lp_padctl_instReprLayerOverrides_repr___redArg___closed__11, &lp_padctl_instReprLayerOverrides_repr___redArg___closed__11_once, _init_lp_padctl_instReprLayerOverrides_repr___redArg___closed__11);
x_69 = l_Option_repr___at___00Lean_Meta_instReprConfig__1_repr_spec__0(x_7, x_15);
x_70 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_70, 0, x_68);
lean_ctor_set(x_70, 1, x_69);
x_71 = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(x_71, 0, x_70);
lean_ctor_set_uint8(x_71, sizeof(void*)*1, x_18);
x_72 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_72, 0, x_67);
lean_ctor_set(x_72, 1, x_71);
x_73 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_73, 0, x_72);
lean_ctor_set(x_73, 1, x_21);
x_74 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_74, 0, x_73);
lean_ctor_set(x_74, 1, x_23);
x_75 = ((lean_object*)(lp_padctl_instReprLayerOverrides_repr___redArg___closed__13));
x_76 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_76, 0, x_74);
lean_ctor_set(x_76, 1, x_75);
x_77 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_77, 0, x_76);
lean_ctor_set(x_77, 1, x_12);
x_78 = lp_padctl_instReprGyroMode_repr(x_8, x_15);
x_79 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_79, 0, x_48);
lean_ctor_set(x_79, 1, x_78);
x_80 = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(x_80, 0, x_79);
lean_ctor_set_uint8(x_80, sizeof(void*)*1, x_18);
x_81 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_81, 0, x_77);
lean_ctor_set(x_81, 1, x_80);
x_82 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_82, 0, x_81);
lean_ctor_set(x_82, 1, x_21);
x_83 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_83, 0, x_82);
lean_ctor_set(x_83, 1, x_23);
x_84 = ((lean_object*)(lp_padctl_instReprLayerOverrides_repr___redArg___closed__5));
x_85 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_85, 0, x_83);
lean_ctor_set(x_85, 1, x_84);
x_86 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_86, 0, x_85);
lean_ctor_set(x_86, 1, x_12);
x_87 = lean_obj_once(&lp_padctl_instReprLayerOverrides_repr___redArg___closed__6, &lp_padctl_instReprLayerOverrides_repr___redArg___closed__6_once, _init_lp_padctl_instReprLayerOverrides_repr___redArg___closed__6);
x_88 = lp_padctl_instReprStickMode_repr(x_9, x_15);
x_89 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_89, 0, x_87);
lean_ctor_set(x_89, 1, x_88);
x_90 = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(x_90, 0, x_89);
lean_ctor_set_uint8(x_90, sizeof(void*)*1, x_18);
x_91 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_91, 0, x_86);
lean_ctor_set(x_91, 1, x_90);
x_92 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_92, 0, x_91);
lean_ctor_set(x_92, 1, x_21);
x_93 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_93, 0, x_92);
lean_ctor_set(x_93, 1, x_23);
x_94 = ((lean_object*)(lp_padctl_instReprLayerOverrides_repr___redArg___closed__8));
x_95 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_95, 0, x_93);
lean_ctor_set(x_95, 1, x_94);
x_96 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_96, 0, x_95);
lean_ctor_set(x_96, 1, x_12);
x_97 = lean_obj_once(&lp_padctl_instReprTapHoldState_repr___redArg___closed__10, &lp_padctl_instReprTapHoldState_repr___redArg___closed__10_once, _init_lp_padctl_instReprTapHoldState_repr___redArg___closed__10);
x_98 = lp_padctl_instReprStickMode_repr(x_10, x_15);
x_99 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_99, 0, x_97);
lean_ctor_set(x_99, 1, x_98);
x_100 = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(x_100, 0, x_99);
lean_ctor_set_uint8(x_100, sizeof(void*)*1, x_18);
x_101 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_101, 0, x_96);
lean_ctor_set(x_101, 1, x_100);
x_102 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_102, 0, x_101);
lean_ctor_set(x_102, 1, x_21);
x_103 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_103, 0, x_102);
lean_ctor_set(x_103, 1, x_23);
x_104 = ((lean_object*)(lp_padctl_instReprMapperConfig_repr___redArg___closed__12));
x_105 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_105, 0, x_103);
lean_ctor_set(x_105, 1, x_104);
x_106 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_106, 0, x_105);
lean_ctor_set(x_106, 1, x_12);
x_107 = lp_padctl_List_repr___at___00instReprMapperConfig_repr_spec__3___redArg(x_11);
x_108 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_108, 0, x_97);
lean_ctor_set(x_108, 1, x_107);
x_109 = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(x_109, 0, x_108);
lean_ctor_set_uint8(x_109, sizeof(void*)*1, x_18);
x_110 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_110, 0, x_106);
lean_ctor_set(x_110, 1, x_109);
x_111 = lean_obj_once(&lp_padctl_instReprLayerConfig_repr___redArg___closed__18, &lp_padctl_instReprLayerConfig_repr___redArg___closed__18_once, _init_lp_padctl_instReprLayerConfig_repr___redArg___closed__18);
x_112 = ((lean_object*)(lp_padctl_instReprLayerConfig_repr___redArg___closed__19));
x_113 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_113, 0, x_112);
lean_ctor_set(x_113, 1, x_110);
x_114 = ((lean_object*)(lp_padctl_instReprLayerConfig_repr___redArg___closed__20));
x_115 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_115, 0, x_113);
lean_ctor_set(x_115, 1, x_114);
x_116 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_116, 0, x_111);
lean_ctor_set(x_116, 1, x_115);
x_117 = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(x_117, 0, x_116);
lean_ctor_set_uint8(x_117, sizeof(void*)*1, x_18);
return x_117;
}
}
LEAN_EXPORT lean_object* lp_padctl_instReprMapperConfig_repr(lean_object* x_1, lean_object* x_2) {
_start:
{
lean_object* x_3; 
x_3 = lp_padctl_instReprMapperConfig_repr___redArg(x_1);
return x_3;
}
}
LEAN_EXPORT lean_object* lp_padctl_instReprMapperConfig_repr___boxed(lean_object* x_1, lean_object* x_2) {
_start:
{
lean_object* x_3; 
x_3 = lp_padctl_instReprMapperConfig_repr(x_1, x_2);
lean_dec(x_2);
return x_3;
}
}
LEAN_EXPORT lean_object* lp_padctl_List_repr___at___00instReprMapperConfig_repr_spec__0(lean_object* x_1, lean_object* x_2) {
_start:
{
lean_object* x_3; 
x_3 = lp_padctl_List_repr___at___00instReprMapperConfig_repr_spec__0___redArg(x_1);
return x_3;
}
}
LEAN_EXPORT lean_object* lp_padctl_List_repr___at___00instReprMapperConfig_repr_spec__0___boxed(lean_object* x_1, lean_object* x_2) {
_start:
{
lean_object* x_3; 
x_3 = lp_padctl_List_repr___at___00instReprMapperConfig_repr_spec__0(x_1, x_2);
lean_dec(x_2);
return x_3;
}
}
LEAN_EXPORT lean_object* lp_padctl_List_repr___at___00instReprMapperConfig_repr_spec__1(lean_object* x_1, lean_object* x_2) {
_start:
{
lean_object* x_3; 
x_3 = lp_padctl_List_repr___at___00instReprMapperConfig_repr_spec__1___redArg(x_1);
return x_3;
}
}
LEAN_EXPORT lean_object* lp_padctl_List_repr___at___00instReprMapperConfig_repr_spec__1___boxed(lean_object* x_1, lean_object* x_2) {
_start:
{
lean_object* x_3; 
x_3 = lp_padctl_List_repr___at___00instReprMapperConfig_repr_spec__1(x_1, x_2);
lean_dec(x_2);
return x_3;
}
}
LEAN_EXPORT lean_object* lp_padctl_List_repr___at___00instReprMapperConfig_repr_spec__2(lean_object* x_1, lean_object* x_2) {
_start:
{
lean_object* x_3; 
x_3 = lp_padctl_List_repr___at___00instReprMapperConfig_repr_spec__2___redArg(x_1);
return x_3;
}
}
LEAN_EXPORT lean_object* lp_padctl_List_repr___at___00instReprMapperConfig_repr_spec__2___boxed(lean_object* x_1, lean_object* x_2) {
_start:
{
lean_object* x_3; 
x_3 = lp_padctl_List_repr___at___00instReprMapperConfig_repr_spec__2(x_1, x_2);
lean_dec(x_2);
return x_3;
}
}
LEAN_EXPORT lean_object* lp_padctl_List_repr___at___00instReprMapperConfig_repr_spec__3(lean_object* x_1, lean_object* x_2) {
_start:
{
lean_object* x_3; 
x_3 = lp_padctl_List_repr___at___00instReprMapperConfig_repr_spec__3___redArg(x_1);
return x_3;
}
}
LEAN_EXPORT lean_object* lp_padctl_List_repr___at___00instReprMapperConfig_repr_spec__3___boxed(lean_object* x_1, lean_object* x_2) {
_start:
{
lean_object* x_3; 
x_3 = lp_padctl_List_repr___at___00instReprMapperConfig_repr_spec__3(x_1, x_2);
lean_dec(x_2);
return x_3;
}
}
LEAN_EXPORT lean_object* lp_padctl_List_filterTR_loop___at___00mergeRemaps_spec__1(lean_object* x_1, lean_object* x_2, lean_object* x_3) {
_start:
{
if (lean_obj_tag(x_2) == 0)
{
lean_object* x_4; 
x_4 = l_List_reverse___redArg(x_3);
return x_4;
}
else
{
uint8_t x_5; 
x_5 = !lean_is_exclusive(x_2);
if (x_5 == 0)
{
lean_object* x_6; lean_object* x_7; lean_object* x_8; uint8_t x_9; 
x_6 = lean_ctor_get(x_2, 0);
x_7 = lean_ctor_get(x_2, 1);
x_8 = lean_ctor_get(x_6, 0);
x_9 = l_List_elem___at___00Lean_Meta_Occurrences_contains_spec__0(x_8, x_1);
if (x_9 == 0)
{
lean_ctor_set(x_2, 1, x_3);
{
lean_object* _tmp_1 = x_7;
lean_object* _tmp_2 = x_2;
x_2 = _tmp_1;
x_3 = _tmp_2;
}
goto _start;
}
else
{
lean_free_object(x_2);
lean_dec(x_6);
x_2 = x_7;
goto _start;
}
}
else
{
lean_object* x_12; lean_object* x_13; lean_object* x_14; uint8_t x_15; 
x_12 = lean_ctor_get(x_2, 0);
x_13 = lean_ctor_get(x_2, 1);
lean_inc(x_13);
lean_inc(x_12);
lean_dec(x_2);
x_14 = lean_ctor_get(x_12, 0);
x_15 = l_List_elem___at___00Lean_Meta_Occurrences_contains_spec__0(x_14, x_1);
if (x_15 == 0)
{
lean_object* x_16; 
x_16 = lean_alloc_ctor(1, 2, 0);
lean_ctor_set(x_16, 0, x_12);
lean_ctor_set(x_16, 1, x_3);
x_2 = x_13;
x_3 = x_16;
goto _start;
}
else
{
lean_dec(x_12);
x_2 = x_13;
goto _start;
}
}
}
}
}
LEAN_EXPORT lean_object* lp_padctl_List_filterTR_loop___at___00mergeRemaps_spec__1___boxed(lean_object* x_1, lean_object* x_2, lean_object* x_3) {
_start:
{
lean_object* x_4; 
x_4 = lp_padctl_List_filterTR_loop___at___00mergeRemaps_spec__1(x_1, x_2, x_3);
lean_dec(x_1);
return x_4;
}
}
LEAN_EXPORT lean_object* lp_padctl_List_mapTR_loop___at___00mergeRemaps_spec__0(lean_object* x_1, lean_object* x_2) {
_start:
{
if (lean_obj_tag(x_1) == 0)
{
lean_object* x_3; 
x_3 = l_List_reverse___redArg(x_2);
return x_3;
}
else
{
uint8_t x_4; 
x_4 = !lean_is_exclusive(x_1);
if (x_4 == 0)
{
lean_object* x_5; lean_object* x_6; lean_object* x_7; 
x_5 = lean_ctor_get(x_1, 0);
x_6 = lean_ctor_get(x_1, 1);
x_7 = lean_ctor_get(x_5, 0);
lean_inc(x_7);
lean_dec(x_5);
lean_ctor_set(x_1, 1, x_2);
lean_ctor_set(x_1, 0, x_7);
{
lean_object* _tmp_0 = x_6;
lean_object* _tmp_1 = x_1;
x_1 = _tmp_0;
x_2 = _tmp_1;
}
goto _start;
}
else
{
lean_object* x_9; lean_object* x_10; lean_object* x_11; lean_object* x_12; 
x_9 = lean_ctor_get(x_1, 0);
x_10 = lean_ctor_get(x_1, 1);
lean_inc(x_10);
lean_inc(x_9);
lean_dec(x_1);
x_11 = lean_ctor_get(x_9, 0);
lean_inc(x_11);
lean_dec(x_9);
x_12 = lean_alloc_ctor(1, 2, 0);
lean_ctor_set(x_12, 0, x_11);
lean_ctor_set(x_12, 1, x_2);
x_1 = x_10;
x_2 = x_12;
goto _start;
}
}
}
}
LEAN_EXPORT lean_object* lp_padctl_mergeRemaps(lean_object* x_1, lean_object* x_2) {
_start:
{
lean_object* x_3; lean_object* x_4; lean_object* x_5; lean_object* x_6; 
x_3 = lean_box(0);
lean_inc(x_2);
x_4 = lp_padctl_List_mapTR_loop___at___00mergeRemaps_spec__0(x_2, x_3);
x_5 = lp_padctl_List_filterTR_loop___at___00mergeRemaps_spec__1(x_4, x_1, x_3);
lean_dec(x_4);
x_6 = l_List_appendTR___redArg(x_5, x_2);
return x_6;
}
}
LEAN_EXPORT lean_object* lp_padctl_resolveConfig(lean_object* x_1, lean_object* x_2, lean_object* x_3) {
_start:
{
if (lean_obj_tag(x_2) == 0)
{
return x_1;
}
else
{
lean_object* x_4; lean_object* x_5; 
x_4 = lean_ctor_get(x_2, 0);
lean_inc(x_4);
lean_dec_ref(x_2);
x_5 = l_List_get_x3fInternal___redArg(x_3, x_4);
if (lean_obj_tag(x_5) == 0)
{
return x_1;
}
else
{
lean_object* x_6; lean_object* x_7; lean_object* x_8; lean_object* x_9; uint8_t x_10; uint8_t x_11; lean_object* x_12; uint8_t x_13; uint8_t x_14; uint8_t x_15; lean_object* x_16; lean_object* x_17; lean_object* x_18; lean_object* x_19; lean_object* x_20; lean_object* x_21; uint8_t x_22; lean_object* x_23; uint8_t x_24; uint8_t x_30; lean_object* x_31; uint8_t x_35; 
x_6 = lean_ctor_get(x_5, 0);
lean_inc(x_6);
lean_dec_ref(x_5);
x_7 = lean_ctor_get(x_1, 0);
lean_inc(x_7);
x_8 = lean_ctor_get(x_1, 1);
lean_inc(x_8);
x_9 = lean_ctor_get(x_1, 2);
lean_inc(x_9);
x_10 = lean_ctor_get_uint8(x_1, sizeof(void*)*5);
x_11 = lean_ctor_get_uint8(x_1, sizeof(void*)*5 + 1);
x_12 = lean_ctor_get(x_1, 3);
lean_inc(x_12);
x_13 = lean_ctor_get_uint8(x_1, sizeof(void*)*5 + 2);
x_14 = lean_ctor_get_uint8(x_1, sizeof(void*)*5 + 3);
x_15 = lean_ctor_get_uint8(x_1, sizeof(void*)*5 + 4);
x_16 = lean_ctor_get(x_1, 4);
lean_inc(x_16);
if (lean_is_exclusive(x_1)) {
 lean_ctor_release(x_1, 0);
 lean_ctor_release(x_1, 1);
 lean_ctor_release(x_1, 2);
 lean_ctor_release(x_1, 3);
 lean_ctor_release(x_1, 4);
 x_17 = x_1;
} else {
 lean_dec_ref(x_1);
 x_17 = lean_box(0);
}
x_18 = lean_ctor_get(x_6, 0);
lean_inc(x_18);
x_19 = lean_ctor_get(x_6, 1);
lean_inc(x_19);
x_20 = lean_ctor_get(x_6, 2);
lean_inc(x_20);
x_21 = lean_ctor_get(x_6, 3);
lean_inc(x_21);
lean_dec(x_6);
if (lean_obj_tag(x_18) == 0)
{
x_35 = x_10;
goto block_37;
}
else
{
lean_object* x_38; uint8_t x_39; 
x_38 = lean_ctor_get(x_18, 0);
lean_inc(x_38);
lean_dec_ref(x_18);
x_39 = lean_unbox(x_38);
lean_dec(x_38);
x_35 = x_39;
goto block_37;
}
block_29:
{
if (lean_obj_tag(x_20) == 0)
{
lean_object* x_25; 
if (lean_is_scalar(x_17)) {
 x_25 = lean_alloc_ctor(0, 5, 5);
} else {
 x_25 = x_17;
}
lean_ctor_set(x_25, 0, x_7);
lean_ctor_set(x_25, 1, x_8);
lean_ctor_set(x_25, 2, x_9);
lean_ctor_set(x_25, 3, x_23);
lean_ctor_set(x_25, 4, x_16);
lean_ctor_set_uint8(x_25, sizeof(void*)*5, x_22);
lean_ctor_set_uint8(x_25, sizeof(void*)*5 + 1, x_11);
lean_ctor_set_uint8(x_25, sizeof(void*)*5 + 2, x_13);
lean_ctor_set_uint8(x_25, sizeof(void*)*5 + 3, x_24);
lean_ctor_set_uint8(x_25, sizeof(void*)*5 + 4, x_15);
return x_25;
}
else
{
lean_object* x_26; lean_object* x_27; uint8_t x_28; 
x_26 = lean_ctor_get(x_20, 0);
lean_inc(x_26);
lean_dec_ref(x_20);
if (lean_is_scalar(x_17)) {
 x_27 = lean_alloc_ctor(0, 5, 5);
} else {
 x_27 = x_17;
}
lean_ctor_set(x_27, 0, x_7);
lean_ctor_set(x_27, 1, x_8);
lean_ctor_set(x_27, 2, x_9);
lean_ctor_set(x_27, 3, x_23);
lean_ctor_set(x_27, 4, x_16);
lean_ctor_set_uint8(x_27, sizeof(void*)*5, x_22);
lean_ctor_set_uint8(x_27, sizeof(void*)*5 + 1, x_11);
lean_ctor_set_uint8(x_27, sizeof(void*)*5 + 2, x_13);
lean_ctor_set_uint8(x_27, sizeof(void*)*5 + 3, x_24);
x_28 = lean_unbox(x_26);
lean_dec(x_26);
lean_ctor_set_uint8(x_27, sizeof(void*)*5 + 4, x_28);
return x_27;
}
}
block_34:
{
if (lean_obj_tag(x_19) == 0)
{
x_22 = x_30;
x_23 = x_31;
x_24 = x_14;
goto block_29;
}
else
{
lean_object* x_32; uint8_t x_33; 
x_32 = lean_ctor_get(x_19, 0);
lean_inc(x_32);
lean_dec_ref(x_19);
x_33 = lean_unbox(x_32);
lean_dec(x_32);
x_22 = x_30;
x_23 = x_31;
x_24 = x_33;
goto block_29;
}
}
block_37:
{
if (lean_obj_tag(x_21) == 0)
{
x_30 = x_35;
x_31 = x_12;
goto block_34;
}
else
{
lean_object* x_36; 
lean_dec(x_12);
x_36 = lean_ctor_get(x_21, 0);
lean_inc(x_36);
lean_dec_ref(x_21);
x_30 = x_35;
x_31 = x_36;
goto block_34;
}
}
}
}
}
}
LEAN_EXPORT lean_object* lp_padctl_resolveConfig___boxed(lean_object* x_1, lean_object* x_2, lean_object* x_3) {
_start:
{
lean_object* x_4; 
x_4 = lp_padctl_resolveConfig(x_1, x_2, x_3);
lean_dec(x_3);
return x_4;
}
}
LEAN_EXPORT lean_object* lp_padctl___private_Padctl_Mapper_0__triggerMacrosAux(lean_object* x_1, lean_object* x_2, lean_object* x_3, lean_object* x_4, lean_object* x_5) {
_start:
{
if (lean_obj_tag(x_3) == 0)
{
lean_object* x_6; 
lean_dec(x_5);
x_6 = lean_box(0);
return x_6;
}
else
{
lean_object* x_7; lean_object* x_8; lean_object* x_9; lean_object* x_10; lean_object* x_16; lean_object* x_17; lean_object* x_18; lean_object* x_19; 
x_7 = lean_ctor_get(x_3, 0);
lean_inc(x_7);
x_8 = lean_ctor_get(x_3, 1);
lean_inc(x_8);
if (lean_is_exclusive(x_3)) {
 lean_ctor_release(x_3, 0);
 lean_ctor_release(x_3, 1);
 x_9 = x_3;
} else {
 lean_dec_ref(x_3);
 x_9 = lean_box(0);
}
x_16 = ((lean_object*)(lp_padctl___private_Padctl_Mapper_0__triggerMacrosAux___closed__0));
x_17 = lean_ctor_get(x_7, 0);
lean_inc(x_17);
x_18 = lean_ctor_get(x_7, 1);
lean_inc(x_18);
lean_dec(x_7);
lean_inc(x_5);
x_19 = l_List_getD___redArg(x_4, x_5, x_16);
if (lean_obj_tag(x_18) == 4)
{
uint8_t x_20; 
x_20 = lp_padctl_testBit(x_1, x_17);
if (x_20 == 0)
{
lean_dec(x_17);
x_10 = x_19;
goto block_15;
}
else
{
uint8_t x_21; 
x_21 = lp_padctl_testBit(x_2, x_17);
lean_dec(x_17);
if (x_21 == 0)
{
if (x_20 == 0)
{
x_10 = x_19;
goto block_15;
}
else
{
uint8_t x_22; 
x_22 = !lean_is_exclusive(x_19);
if (x_22 == 0)
{
lean_ctor_set_uint8(x_19, sizeof(void*)*4, x_20);
x_10 = x_19;
goto block_15;
}
else
{
lean_object* x_23; lean_object* x_24; lean_object* x_25; lean_object* x_26; uint8_t x_27; lean_object* x_28; 
x_23 = lean_ctor_get(x_19, 0);
x_24 = lean_ctor_get(x_19, 1);
x_25 = lean_ctor_get(x_19, 2);
x_26 = lean_ctor_get(x_19, 3);
x_27 = lean_ctor_get_uint8(x_19, sizeof(void*)*4 + 1);
lean_inc(x_26);
lean_inc(x_25);
lean_inc(x_24);
lean_inc(x_23);
lean_dec(x_19);
x_28 = lean_alloc_ctor(0, 4, 2);
lean_ctor_set(x_28, 0, x_23);
lean_ctor_set(x_28, 1, x_24);
lean_ctor_set(x_28, 2, x_25);
lean_ctor_set(x_28, 3, x_26);
lean_ctor_set_uint8(x_28, sizeof(void*)*4, x_20);
lean_ctor_set_uint8(x_28, sizeof(void*)*4 + 1, x_27);
x_10 = x_28;
goto block_15;
}
}
}
else
{
x_10 = x_19;
goto block_15;
}
}
}
else
{
lean_dec(x_18);
lean_dec(x_17);
x_10 = x_19;
goto block_15;
}
block_15:
{
lean_object* x_11; lean_object* x_12; lean_object* x_13; lean_object* x_14; 
x_11 = lean_unsigned_to_nat(1u);
x_12 = lean_nat_add(x_5, x_11);
lean_dec(x_5);
x_13 = lp_padctl___private_Padctl_Mapper_0__triggerMacrosAux(x_1, x_2, x_8, x_4, x_12);
if (lean_is_scalar(x_9)) {
 x_14 = lean_alloc_ctor(1, 2, 0);
} else {
 x_14 = x_9;
}
lean_ctor_set(x_14, 0, x_10);
lean_ctor_set(x_14, 1, x_13);
return x_14;
}
}
}
}
LEAN_EXPORT lean_object* lp_padctl___private_Padctl_Mapper_0__triggerMacrosAux___boxed(lean_object* x_1, lean_object* x_2, lean_object* x_3, lean_object* x_4, lean_object* x_5) {
_start:
{
lean_object* x_6; 
x_6 = lp_padctl___private_Padctl_Mapper_0__triggerMacrosAux(x_1, x_2, x_3, x_4, x_5);
lean_dec(x_4);
lean_dec(x_2);
lean_dec(x_1);
return x_6;
}
}
LEAN_EXPORT lean_object* lp_padctl___private_Padctl_Mapper_0__triggerMacros(lean_object* x_1, lean_object* x_2, lean_object* x_3, lean_object* x_4) {
_start:
{
lean_object* x_5; lean_object* x_6; 
x_5 = lean_unsigned_to_nat(0u);
x_6 = lp_padctl___private_Padctl_Mapper_0__triggerMacrosAux(x_1, x_2, x_3, x_4, x_5);
return x_6;
}
}
LEAN_EXPORT lean_object* lp_padctl___private_Padctl_Mapper_0__triggerMacros___boxed(lean_object* x_1, lean_object* x_2, lean_object* x_3, lean_object* x_4) {
_start:
{
lean_object* x_5; 
x_5 = lp_padctl___private_Padctl_Mapper_0__triggerMacros(x_1, x_2, x_3, x_4);
lean_dec(x_4);
lean_dec(x_2);
lean_dec(x_1);
return x_5;
}
}
LEAN_EXPORT lean_object* lp_padctl_List_mapTR_loop___at___00__private_Padctl_Mapper_0__cancelMacros_spec__0(lean_object* x_1, lean_object* x_2) {
_start:
{
if (lean_obj_tag(x_1) == 0)
{
lean_object* x_3; 
x_3 = l_List_reverse___redArg(x_2);
return x_3;
}
else
{
uint8_t x_4; 
x_4 = !lean_is_exclusive(x_1);
if (x_4 == 0)
{
lean_object* x_5; lean_object* x_6; uint8_t x_7; lean_object* x_8; 
x_5 = lean_ctor_get(x_1, 0);
x_6 = lean_ctor_get(x_1, 1);
x_7 = 0;
x_8 = lean_alloc_ctor(0, 1, 1);
lean_ctor_set(x_8, 0, x_5);
lean_ctor_set_uint8(x_8, sizeof(void*)*1, x_7);
lean_ctor_set(x_1, 1, x_2);
lean_ctor_set(x_1, 0, x_8);
{
lean_object* _tmp_0 = x_6;
lean_object* _tmp_1 = x_1;
x_1 = _tmp_0;
x_2 = _tmp_1;
}
goto _start;
}
else
{
lean_object* x_10; lean_object* x_11; uint8_t x_12; lean_object* x_13; lean_object* x_14; 
x_10 = lean_ctor_get(x_1, 0);
x_11 = lean_ctor_get(x_1, 1);
lean_inc(x_11);
lean_inc(x_10);
lean_dec(x_1);
x_12 = 0;
x_13 = lean_alloc_ctor(0, 1, 1);
lean_ctor_set(x_13, 0, x_10);
lean_ctor_set_uint8(x_13, sizeof(void*)*1, x_12);
x_14 = lean_alloc_ctor(1, 2, 0);
lean_ctor_set(x_14, 0, x_13);
lean_ctor_set(x_14, 1, x_2);
x_1 = x_11;
x_2 = x_14;
goto _start;
}
}
}
}
LEAN_EXPORT lean_object* lp_padctl_List_foldl___at___00__private_Padctl_Mapper_0__cancelMacros_spec__1(lean_object* x_1, lean_object* x_2) {
_start:
{
if (lean_obj_tag(x_2) == 0)
{
return x_1;
}
else
{
lean_object* x_3; uint8_t x_4; 
x_3 = lean_ctor_get(x_2, 0);
lean_inc(x_3);
x_4 = lean_ctor_get_uint8(x_3, sizeof(void*)*4);
if (x_4 == 0)
{
uint8_t x_5; 
x_5 = !lean_is_exclusive(x_2);
if (x_5 == 0)
{
lean_object* x_6; lean_object* x_7; uint8_t x_8; 
x_6 = lean_ctor_get(x_2, 1);
x_7 = lean_ctor_get(x_2, 0);
lean_dec(x_7);
x_8 = !lean_is_exclusive(x_1);
if (x_8 == 0)
{
lean_object* x_9; lean_object* x_10; lean_object* x_11; 
x_9 = lean_ctor_get(x_1, 0);
x_10 = lean_box(0);
lean_ctor_set(x_2, 1, x_10);
x_11 = l_List_appendTR___redArg(x_9, x_2);
lean_ctor_set(x_1, 0, x_11);
x_2 = x_6;
goto _start;
}
else
{
lean_object* x_13; lean_object* x_14; lean_object* x_15; lean_object* x_16; lean_object* x_17; 
x_13 = lean_ctor_get(x_1, 0);
x_14 = lean_ctor_get(x_1, 1);
lean_inc(x_14);
lean_inc(x_13);
lean_dec(x_1);
x_15 = lean_box(0);
lean_ctor_set(x_2, 1, x_15);
x_16 = l_List_appendTR___redArg(x_13, x_2);
x_17 = lean_alloc_ctor(0, 2, 0);
lean_ctor_set(x_17, 0, x_16);
lean_ctor_set(x_17, 1, x_14);
x_1 = x_17;
x_2 = x_6;
goto _start;
}
}
else
{
lean_object* x_19; lean_object* x_20; lean_object* x_21; lean_object* x_22; lean_object* x_23; lean_object* x_24; lean_object* x_25; lean_object* x_26; 
x_19 = lean_ctor_get(x_2, 1);
lean_inc(x_19);
lean_dec(x_2);
x_20 = lean_ctor_get(x_1, 0);
lean_inc(x_20);
x_21 = lean_ctor_get(x_1, 1);
lean_inc(x_21);
if (lean_is_exclusive(x_1)) {
 lean_ctor_release(x_1, 0);
 lean_ctor_release(x_1, 1);
 x_22 = x_1;
} else {
 lean_dec_ref(x_1);
 x_22 = lean_box(0);
}
x_23 = lean_box(0);
x_24 = lean_alloc_ctor(1, 2, 0);
lean_ctor_set(x_24, 0, x_3);
lean_ctor_set(x_24, 1, x_23);
x_25 = l_List_appendTR___redArg(x_20, x_24);
if (lean_is_scalar(x_22)) {
 x_26 = lean_alloc_ctor(0, 2, 0);
} else {
 x_26 = x_22;
}
lean_ctor_set(x_26, 0, x_25);
lean_ctor_set(x_26, 1, x_21);
x_1 = x_26;
x_2 = x_19;
goto _start;
}
}
else
{
lean_object* x_28; lean_object* x_29; uint8_t x_30; 
x_28 = lean_ctor_get(x_2, 1);
lean_inc(x_28);
lean_dec_ref(x_2);
x_29 = lean_ctor_get(x_3, 0);
lean_inc(x_29);
lean_dec(x_3);
x_30 = !lean_is_exclusive(x_1);
if (x_30 == 0)
{
lean_object* x_31; lean_object* x_32; lean_object* x_33; lean_object* x_34; lean_object* x_35; lean_object* x_36; lean_object* x_37; 
x_31 = lean_ctor_get(x_1, 0);
x_32 = lean_ctor_get(x_1, 1);
x_33 = lean_box(0);
x_34 = lp_padctl_List_mapTR_loop___at___00__private_Padctl_Mapper_0__cancelMacros_spec__0(x_29, x_33);
x_35 = ((lean_object*)(lp_padctl_List_foldl___at___00__private_Padctl_Mapper_0__cancelMacros_spec__1___closed__1));
x_36 = l_List_appendTR___redArg(x_31, x_35);
x_37 = l_List_appendTR___redArg(x_32, x_34);
lean_ctor_set(x_1, 1, x_37);
lean_ctor_set(x_1, 0, x_36);
x_2 = x_28;
goto _start;
}
else
{
lean_object* x_39; lean_object* x_40; lean_object* x_41; lean_object* x_42; lean_object* x_43; lean_object* x_44; lean_object* x_45; lean_object* x_46; 
x_39 = lean_ctor_get(x_1, 0);
x_40 = lean_ctor_get(x_1, 1);
lean_inc(x_40);
lean_inc(x_39);
lean_dec(x_1);
x_41 = lean_box(0);
x_42 = lp_padctl_List_mapTR_loop___at___00__private_Padctl_Mapper_0__cancelMacros_spec__0(x_29, x_41);
x_43 = ((lean_object*)(lp_padctl_List_foldl___at___00__private_Padctl_Mapper_0__cancelMacros_spec__1___closed__1));
x_44 = l_List_appendTR___redArg(x_39, x_43);
x_45 = l_List_appendTR___redArg(x_40, x_42);
x_46 = lean_alloc_ctor(0, 2, 0);
lean_ctor_set(x_46, 0, x_44);
lean_ctor_set(x_46, 1, x_45);
x_1 = x_46;
x_2 = x_28;
goto _start;
}
}
}
}
}
LEAN_EXPORT lean_object* lp_padctl___private_Padctl_Mapper_0__cancelMacros(lean_object* x_1) {
_start:
{
lean_object* x_2; lean_object* x_3; 
x_2 = ((lean_object*)(lp_padctl___private_Padctl_Mapper_0__cancelMacros___closed__0));
x_3 = lp_padctl_List_foldl___at___00__private_Padctl_Mapper_0__cancelMacros_spec__1(x_2, x_1);
return x_3;
}
}
LEAN_EXPORT uint8_t lp_padctl_instDecidableEqMacroTimerEvent_decEq(lean_object* x_1, lean_object* x_2) {
_start:
{
uint8_t x_3; 
x_3 = lean_nat_dec_eq(x_1, x_2);
return x_3;
}
}
LEAN_EXPORT lean_object* lp_padctl_instDecidableEqMacroTimerEvent_decEq___boxed(lean_object* x_1, lean_object* x_2) {
_start:
{
uint8_t x_3; lean_object* x_4; 
x_3 = lp_padctl_instDecidableEqMacroTimerEvent_decEq(x_1, x_2);
lean_dec(x_2);
lean_dec(x_1);
x_4 = lean_box(x_3);
return x_4;
}
}
LEAN_EXPORT uint8_t lp_padctl_instDecidableEqMacroTimerEvent(lean_object* x_1, lean_object* x_2) {
_start:
{
uint8_t x_3; 
x_3 = lean_nat_dec_eq(x_1, x_2);
return x_3;
}
}
LEAN_EXPORT lean_object* lp_padctl_instDecidableEqMacroTimerEvent___boxed(lean_object* x_1, lean_object* x_2) {
_start:
{
uint8_t x_3; lean_object* x_4; 
x_3 = lp_padctl_instDecidableEqMacroTimerEvent(x_1, x_2);
lean_dec(x_2);
lean_dec(x_1);
x_4 = lean_box(x_3);
return x_4;
}
}
LEAN_EXPORT lean_object* lp_padctl_instReprMacroTimerEvent_repr(lean_object* x_1, lean_object* x_2) {
_start:
{
lean_object* x_3; lean_object* x_13; uint8_t x_14; 
x_13 = lean_unsigned_to_nat(1024u);
x_14 = lean_nat_dec_le(x_13, x_2);
if (x_14 == 0)
{
lean_object* x_15; 
x_15 = lean_obj_once(&lp_padctl_instReprAuxEvent_repr___closed__3, &lp_padctl_instReprAuxEvent_repr___closed__3_once, _init_lp_padctl_instReprAuxEvent_repr___closed__3);
x_3 = x_15;
goto block_12;
}
else
{
lean_object* x_16; 
x_16 = lean_obj_once(&lp_padctl_instReprAuxEvent_repr___closed__4, &lp_padctl_instReprAuxEvent_repr___closed__4_once, _init_lp_padctl_instReprAuxEvent_repr___closed__4);
x_3 = x_16;
goto block_12;
}
block_12:
{
lean_object* x_4; lean_object* x_5; lean_object* x_6; lean_object* x_7; lean_object* x_8; uint8_t x_9; lean_object* x_10; lean_object* x_11; 
x_4 = ((lean_object*)(lp_padctl_instReprMacroTimerEvent_repr___closed__2));
x_5 = l_Nat_reprFast(x_1);
x_6 = lean_alloc_ctor(3, 1, 0);
lean_ctor_set(x_6, 0, x_5);
x_7 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_7, 0, x_4);
lean_ctor_set(x_7, 1, x_6);
x_8 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_8, 0, x_3);
lean_ctor_set(x_8, 1, x_7);
x_9 = 0;
x_10 = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(x_10, 0, x_8);
lean_ctor_set_uint8(x_10, sizeof(void*)*1, x_9);
x_11 = l_Repr_addAppParen(x_10, x_2);
return x_11;
}
}
}
LEAN_EXPORT lean_object* lp_padctl_instReprMacroTimerEvent_repr___boxed(lean_object* x_1, lean_object* x_2) {
_start:
{
lean_object* x_3; 
x_3 = lp_padctl_instReprMacroTimerEvent_repr(x_1, x_2);
lean_dec(x_2);
return x_3;
}
}
LEAN_EXPORT lean_object* lp_padctl_List_filterTR_loop___at___00__private_Padctl_Mapper_0__stepMacro_spec__0(lean_object* x_1, lean_object* x_2, lean_object* x_3) {
_start:
{
if (lean_obj_tag(x_2) == 0)
{
lean_object* x_4; 
x_4 = l_List_reverse___redArg(x_3);
return x_4;
}
else
{
uint8_t x_5; 
x_5 = !lean_is_exclusive(x_2);
if (x_5 == 0)
{
lean_object* x_6; lean_object* x_7; uint8_t x_8; 
x_6 = lean_ctor_get(x_2, 0);
x_7 = lean_ctor_get(x_2, 1);
x_8 = lean_nat_dec_eq(x_6, x_1);
if (x_8 == 0)
{
lean_ctor_set(x_2, 1, x_3);
{
lean_object* _tmp_1 = x_7;
lean_object* _tmp_2 = x_2;
x_2 = _tmp_1;
x_3 = _tmp_2;
}
goto _start;
}
else
{
lean_free_object(x_2);
lean_dec(x_6);
x_2 = x_7;
goto _start;
}
}
else
{
lean_object* x_11; lean_object* x_12; uint8_t x_13; 
x_11 = lean_ctor_get(x_2, 0);
x_12 = lean_ctor_get(x_2, 1);
lean_inc(x_12);
lean_inc(x_11);
lean_dec(x_2);
x_13 = lean_nat_dec_eq(x_11, x_1);
if (x_13 == 0)
{
lean_object* x_14; 
x_14 = lean_alloc_ctor(1, 2, 0);
lean_ctor_set(x_14, 0, x_11);
lean_ctor_set(x_14, 1, x_3);
x_2 = x_12;
x_3 = x_14;
goto _start;
}
else
{
lean_dec(x_11);
x_2 = x_12;
goto _start;
}
}
}
}
}
LEAN_EXPORT lean_object* lp_padctl_List_filterTR_loop___at___00__private_Padctl_Mapper_0__stepMacro_spec__0___boxed(lean_object* x_1, lean_object* x_2, lean_object* x_3) {
_start:
{
lean_object* x_4; 
x_4 = lp_padctl_List_filterTR_loop___at___00__private_Padctl_Mapper_0__stepMacro_spec__0(x_1, x_2, x_3);
lean_dec(x_1);
return x_4;
}
}
LEAN_EXPORT lean_object* lp_padctl___private_Padctl_Mapper_0__stepMacro(lean_object* x_1) {
_start:
{
uint8_t x_2; 
x_2 = !lean_is_exclusive(x_1);
if (x_2 == 0)
{
uint8_t x_3; lean_object* x_4; lean_object* x_5; lean_object* x_6; lean_object* x_7; uint8_t x_8; lean_object* x_9; 
x_3 = lean_ctor_get_uint8(x_1, sizeof(void*)*4);
x_4 = lean_ctor_get(x_1, 0);
x_5 = lean_ctor_get(x_1, 1);
x_6 = lean_ctor_get(x_1, 2);
x_7 = lean_ctor_get(x_1, 3);
x_8 = lean_ctor_get_uint8(x_1, sizeof(void*)*4 + 1);
lean_inc(x_6);
x_9 = l_List_get_x3fInternal___redArg(x_5, x_6);
if (lean_obj_tag(x_9) == 0)
{
uint8_t x_10; lean_object* x_11; lean_object* x_12; 
x_10 = 0;
lean_ctor_set_uint8(x_1, sizeof(void*)*4, x_10);
x_11 = ((lean_object*)(lp_padctl___private_Padctl_Mapper_0__stepMacro___closed__0));
x_12 = lean_alloc_ctor(0, 2, 0);
lean_ctor_set(x_12, 0, x_1);
lean_ctor_set(x_12, 1, x_11);
return x_12;
}
else
{
uint8_t x_13; 
x_13 = !lean_is_exclusive(x_9);
if (x_13 == 0)
{
lean_object* x_14; lean_object* x_15; lean_object* x_16; 
x_14 = lean_ctor_get(x_9, 0);
x_15 = lean_unsigned_to_nat(1u);
x_16 = lean_nat_add(x_6, x_15);
lean_dec(x_6);
lean_inc(x_7);
lean_inc(x_16);
lean_inc(x_5);
lean_inc(x_4);
lean_ctor_set(x_1, 2, x_16);
switch (lean_obj_tag(x_14)) {
case 0:
{
lean_object* x_17; uint8_t x_18; lean_object* x_19; uint8_t x_20; lean_object* x_21; lean_object* x_22; lean_object* x_23; lean_object* x_24; lean_object* x_25; lean_object* x_26; lean_object* x_27; 
lean_dec(x_16);
lean_free_object(x_9);
lean_dec(x_7);
lean_dec(x_5);
lean_dec(x_4);
x_17 = lean_ctor_get(x_14, 0);
lean_inc(x_17);
lean_dec_ref(x_14);
x_18 = 1;
lean_inc(x_17);
x_19 = lean_alloc_ctor(0, 1, 1);
lean_ctor_set(x_19, 0, x_17);
lean_ctor_set_uint8(x_19, sizeof(void*)*1, x_18);
x_20 = 0;
x_21 = lean_alloc_ctor(0, 1, 1);
lean_ctor_set(x_21, 0, x_17);
lean_ctor_set_uint8(x_21, sizeof(void*)*1, x_20);
x_22 = lean_box(0);
x_23 = lean_alloc_ctor(1, 2, 0);
lean_ctor_set(x_23, 0, x_21);
lean_ctor_set(x_23, 1, x_22);
x_24 = lean_alloc_ctor(1, 2, 0);
lean_ctor_set(x_24, 0, x_19);
lean_ctor_set(x_24, 1, x_23);
x_25 = lean_box(0);
x_26 = lean_alloc_ctor(0, 2, 0);
lean_ctor_set(x_26, 0, x_24);
lean_ctor_set(x_26, 1, x_25);
x_27 = lean_alloc_ctor(0, 2, 0);
lean_ctor_set(x_27, 0, x_1);
lean_ctor_set(x_27, 1, x_26);
return x_27;
}
case 1:
{
lean_object* x_28; uint8_t x_29; lean_object* x_30; lean_object* x_31; lean_object* x_32; lean_object* x_33; lean_object* x_34; lean_object* x_35; lean_object* x_36; lean_object* x_37; lean_object* x_38; 
lean_dec_ref(x_1);
lean_free_object(x_9);
x_28 = lean_ctor_get(x_14, 0);
lean_inc(x_28);
lean_dec_ref(x_14);
x_29 = 1;
lean_inc(x_28);
x_30 = lean_alloc_ctor(0, 1, 1);
lean_ctor_set(x_30, 0, x_28);
lean_ctor_set_uint8(x_30, sizeof(void*)*1, x_29);
x_31 = lean_box(0);
x_32 = lean_alloc_ctor(1, 2, 0);
lean_ctor_set(x_32, 0, x_30);
lean_ctor_set(x_32, 1, x_31);
x_33 = lean_alloc_ctor(1, 2, 0);
lean_ctor_set(x_33, 0, x_28);
lean_ctor_set(x_33, 1, x_31);
x_34 = l_List_appendTR___redArg(x_4, x_33);
x_35 = lean_alloc_ctor(0, 4, 2);
lean_ctor_set(x_35, 0, x_34);
lean_ctor_set(x_35, 1, x_5);
lean_ctor_set(x_35, 2, x_16);
lean_ctor_set(x_35, 3, x_7);
lean_ctor_set_uint8(x_35, sizeof(void*)*4, x_3);
lean_ctor_set_uint8(x_35, sizeof(void*)*4 + 1, x_8);
x_36 = lean_box(0);
x_37 = lean_alloc_ctor(0, 2, 0);
lean_ctor_set(x_37, 0, x_32);
lean_ctor_set(x_37, 1, x_36);
x_38 = lean_alloc_ctor(0, 2, 0);
lean_ctor_set(x_38, 0, x_35);
lean_ctor_set(x_38, 1, x_37);
return x_38;
}
case 2:
{
lean_object* x_39; uint8_t x_40; lean_object* x_41; lean_object* x_42; lean_object* x_43; lean_object* x_44; lean_object* x_45; lean_object* x_46; lean_object* x_47; lean_object* x_48; 
lean_dec_ref(x_1);
lean_free_object(x_9);
x_39 = lean_ctor_get(x_14, 0);
lean_inc(x_39);
lean_dec_ref(x_14);
x_40 = 0;
lean_inc(x_39);
x_41 = lean_alloc_ctor(0, 1, 1);
lean_ctor_set(x_41, 0, x_39);
lean_ctor_set_uint8(x_41, sizeof(void*)*1, x_40);
x_42 = lean_box(0);
x_43 = lean_alloc_ctor(1, 2, 0);
lean_ctor_set(x_43, 0, x_41);
lean_ctor_set(x_43, 1, x_42);
x_44 = lp_padctl_List_filterTR_loop___at___00__private_Padctl_Mapper_0__stepMacro_spec__0(x_39, x_4, x_42);
lean_dec(x_39);
x_45 = lean_alloc_ctor(0, 4, 2);
lean_ctor_set(x_45, 0, x_44);
lean_ctor_set(x_45, 1, x_5);
lean_ctor_set(x_45, 2, x_16);
lean_ctor_set(x_45, 3, x_7);
lean_ctor_set_uint8(x_45, sizeof(void*)*4, x_3);
lean_ctor_set_uint8(x_45, sizeof(void*)*4 + 1, x_8);
x_46 = lean_box(0);
x_47 = lean_alloc_ctor(0, 2, 0);
lean_ctor_set(x_47, 0, x_43);
lean_ctor_set(x_47, 1, x_46);
x_48 = lean_alloc_ctor(0, 2, 0);
lean_ctor_set(x_48, 0, x_45);
lean_ctor_set(x_48, 1, x_47);
return x_48;
}
case 3:
{
lean_object* x_49; lean_object* x_50; lean_object* x_51; lean_object* x_52; 
lean_dec(x_16);
lean_dec(x_7);
lean_dec(x_5);
lean_dec(x_4);
x_49 = lean_ctor_get(x_14, 0);
lean_inc(x_49);
lean_dec_ref(x_14);
x_50 = lean_box(0);
lean_ctor_set(x_9, 0, x_49);
x_51 = lean_alloc_ctor(0, 2, 0);
lean_ctor_set(x_51, 0, x_50);
lean_ctor_set(x_51, 1, x_9);
x_52 = lean_alloc_ctor(0, 2, 0);
lean_ctor_set(x_52, 0, x_1);
lean_ctor_set(x_52, 1, x_51);
return x_52;
}
default: 
{
uint8_t x_53; lean_object* x_54; lean_object* x_55; lean_object* x_56; 
lean_dec_ref(x_1);
lean_free_object(x_9);
x_53 = 1;
x_54 = lean_alloc_ctor(0, 4, 2);
lean_ctor_set(x_54, 0, x_4);
lean_ctor_set(x_54, 1, x_5);
lean_ctor_set(x_54, 2, x_16);
lean_ctor_set(x_54, 3, x_7);
lean_ctor_set_uint8(x_54, sizeof(void*)*4, x_3);
lean_ctor_set_uint8(x_54, sizeof(void*)*4 + 1, x_53);
x_55 = ((lean_object*)(lp_padctl___private_Padctl_Mapper_0__stepMacro___closed__0));
x_56 = lean_alloc_ctor(0, 2, 0);
lean_ctor_set(x_56, 0, x_54);
lean_ctor_set(x_56, 1, x_55);
return x_56;
}
}
}
else
{
lean_object* x_57; lean_object* x_58; lean_object* x_59; 
x_57 = lean_ctor_get(x_9, 0);
lean_inc(x_57);
lean_dec(x_9);
x_58 = lean_unsigned_to_nat(1u);
x_59 = lean_nat_add(x_6, x_58);
lean_dec(x_6);
lean_inc(x_7);
lean_inc(x_59);
lean_inc(x_5);
lean_inc(x_4);
lean_ctor_set(x_1, 2, x_59);
switch (lean_obj_tag(x_57)) {
case 0:
{
lean_object* x_60; uint8_t x_61; lean_object* x_62; uint8_t x_63; lean_object* x_64; lean_object* x_65; lean_object* x_66; lean_object* x_67; lean_object* x_68; lean_object* x_69; lean_object* x_70; 
lean_dec(x_59);
lean_dec(x_7);
lean_dec(x_5);
lean_dec(x_4);
x_60 = lean_ctor_get(x_57, 0);
lean_inc(x_60);
lean_dec_ref(x_57);
x_61 = 1;
lean_inc(x_60);
x_62 = lean_alloc_ctor(0, 1, 1);
lean_ctor_set(x_62, 0, x_60);
lean_ctor_set_uint8(x_62, sizeof(void*)*1, x_61);
x_63 = 0;
x_64 = lean_alloc_ctor(0, 1, 1);
lean_ctor_set(x_64, 0, x_60);
lean_ctor_set_uint8(x_64, sizeof(void*)*1, x_63);
x_65 = lean_box(0);
x_66 = lean_alloc_ctor(1, 2, 0);
lean_ctor_set(x_66, 0, x_64);
lean_ctor_set(x_66, 1, x_65);
x_67 = lean_alloc_ctor(1, 2, 0);
lean_ctor_set(x_67, 0, x_62);
lean_ctor_set(x_67, 1, x_66);
x_68 = lean_box(0);
x_69 = lean_alloc_ctor(0, 2, 0);
lean_ctor_set(x_69, 0, x_67);
lean_ctor_set(x_69, 1, x_68);
x_70 = lean_alloc_ctor(0, 2, 0);
lean_ctor_set(x_70, 0, x_1);
lean_ctor_set(x_70, 1, x_69);
return x_70;
}
case 1:
{
lean_object* x_71; uint8_t x_72; lean_object* x_73; lean_object* x_74; lean_object* x_75; lean_object* x_76; lean_object* x_77; lean_object* x_78; lean_object* x_79; lean_object* x_80; lean_object* x_81; 
lean_dec_ref(x_1);
x_71 = lean_ctor_get(x_57, 0);
lean_inc(x_71);
lean_dec_ref(x_57);
x_72 = 1;
lean_inc(x_71);
x_73 = lean_alloc_ctor(0, 1, 1);
lean_ctor_set(x_73, 0, x_71);
lean_ctor_set_uint8(x_73, sizeof(void*)*1, x_72);
x_74 = lean_box(0);
x_75 = lean_alloc_ctor(1, 2, 0);
lean_ctor_set(x_75, 0, x_73);
lean_ctor_set(x_75, 1, x_74);
x_76 = lean_alloc_ctor(1, 2, 0);
lean_ctor_set(x_76, 0, x_71);
lean_ctor_set(x_76, 1, x_74);
x_77 = l_List_appendTR___redArg(x_4, x_76);
x_78 = lean_alloc_ctor(0, 4, 2);
lean_ctor_set(x_78, 0, x_77);
lean_ctor_set(x_78, 1, x_5);
lean_ctor_set(x_78, 2, x_59);
lean_ctor_set(x_78, 3, x_7);
lean_ctor_set_uint8(x_78, sizeof(void*)*4, x_3);
lean_ctor_set_uint8(x_78, sizeof(void*)*4 + 1, x_8);
x_79 = lean_box(0);
x_80 = lean_alloc_ctor(0, 2, 0);
lean_ctor_set(x_80, 0, x_75);
lean_ctor_set(x_80, 1, x_79);
x_81 = lean_alloc_ctor(0, 2, 0);
lean_ctor_set(x_81, 0, x_78);
lean_ctor_set(x_81, 1, x_80);
return x_81;
}
case 2:
{
lean_object* x_82; uint8_t x_83; lean_object* x_84; lean_object* x_85; lean_object* x_86; lean_object* x_87; lean_object* x_88; lean_object* x_89; lean_object* x_90; lean_object* x_91; 
lean_dec_ref(x_1);
x_82 = lean_ctor_get(x_57, 0);
lean_inc(x_82);
lean_dec_ref(x_57);
x_83 = 0;
lean_inc(x_82);
x_84 = lean_alloc_ctor(0, 1, 1);
lean_ctor_set(x_84, 0, x_82);
lean_ctor_set_uint8(x_84, sizeof(void*)*1, x_83);
x_85 = lean_box(0);
x_86 = lean_alloc_ctor(1, 2, 0);
lean_ctor_set(x_86, 0, x_84);
lean_ctor_set(x_86, 1, x_85);
x_87 = lp_padctl_List_filterTR_loop___at___00__private_Padctl_Mapper_0__stepMacro_spec__0(x_82, x_4, x_85);
lean_dec(x_82);
x_88 = lean_alloc_ctor(0, 4, 2);
lean_ctor_set(x_88, 0, x_87);
lean_ctor_set(x_88, 1, x_5);
lean_ctor_set(x_88, 2, x_59);
lean_ctor_set(x_88, 3, x_7);
lean_ctor_set_uint8(x_88, sizeof(void*)*4, x_3);
lean_ctor_set_uint8(x_88, sizeof(void*)*4 + 1, x_8);
x_89 = lean_box(0);
x_90 = lean_alloc_ctor(0, 2, 0);
lean_ctor_set(x_90, 0, x_86);
lean_ctor_set(x_90, 1, x_89);
x_91 = lean_alloc_ctor(0, 2, 0);
lean_ctor_set(x_91, 0, x_88);
lean_ctor_set(x_91, 1, x_90);
return x_91;
}
case 3:
{
lean_object* x_92; lean_object* x_93; lean_object* x_94; lean_object* x_95; lean_object* x_96; 
lean_dec(x_59);
lean_dec(x_7);
lean_dec(x_5);
lean_dec(x_4);
x_92 = lean_ctor_get(x_57, 0);
lean_inc(x_92);
lean_dec_ref(x_57);
x_93 = lean_box(0);
x_94 = lean_alloc_ctor(1, 1, 0);
lean_ctor_set(x_94, 0, x_92);
x_95 = lean_alloc_ctor(0, 2, 0);
lean_ctor_set(x_95, 0, x_93);
lean_ctor_set(x_95, 1, x_94);
x_96 = lean_alloc_ctor(0, 2, 0);
lean_ctor_set(x_96, 0, x_1);
lean_ctor_set(x_96, 1, x_95);
return x_96;
}
default: 
{
uint8_t x_97; lean_object* x_98; lean_object* x_99; lean_object* x_100; 
lean_dec_ref(x_1);
x_97 = 1;
x_98 = lean_alloc_ctor(0, 4, 2);
lean_ctor_set(x_98, 0, x_4);
lean_ctor_set(x_98, 1, x_5);
lean_ctor_set(x_98, 2, x_59);
lean_ctor_set(x_98, 3, x_7);
lean_ctor_set_uint8(x_98, sizeof(void*)*4, x_3);
lean_ctor_set_uint8(x_98, sizeof(void*)*4 + 1, x_97);
x_99 = ((lean_object*)(lp_padctl___private_Padctl_Mapper_0__stepMacro___closed__0));
x_100 = lean_alloc_ctor(0, 2, 0);
lean_ctor_set(x_100, 0, x_98);
lean_ctor_set(x_100, 1, x_99);
return x_100;
}
}
}
}
}
else
{
uint8_t x_101; lean_object* x_102; lean_object* x_103; lean_object* x_104; lean_object* x_105; uint8_t x_106; lean_object* x_107; 
x_101 = lean_ctor_get_uint8(x_1, sizeof(void*)*4);
x_102 = lean_ctor_get(x_1, 0);
x_103 = lean_ctor_get(x_1, 1);
x_104 = lean_ctor_get(x_1, 2);
x_105 = lean_ctor_get(x_1, 3);
x_106 = lean_ctor_get_uint8(x_1, sizeof(void*)*4 + 1);
lean_inc(x_105);
lean_inc(x_104);
lean_inc(x_103);
lean_inc(x_102);
lean_dec(x_1);
lean_inc(x_104);
x_107 = l_List_get_x3fInternal___redArg(x_103, x_104);
if (lean_obj_tag(x_107) == 0)
{
uint8_t x_108; lean_object* x_109; lean_object* x_110; lean_object* x_111; 
x_108 = 0;
x_109 = lean_alloc_ctor(0, 4, 2);
lean_ctor_set(x_109, 0, x_102);
lean_ctor_set(x_109, 1, x_103);
lean_ctor_set(x_109, 2, x_104);
lean_ctor_set(x_109, 3, x_105);
lean_ctor_set_uint8(x_109, sizeof(void*)*4, x_108);
lean_ctor_set_uint8(x_109, sizeof(void*)*4 + 1, x_106);
x_110 = ((lean_object*)(lp_padctl___private_Padctl_Mapper_0__stepMacro___closed__0));
x_111 = lean_alloc_ctor(0, 2, 0);
lean_ctor_set(x_111, 0, x_109);
lean_ctor_set(x_111, 1, x_110);
return x_111;
}
else
{
lean_object* x_112; lean_object* x_113; lean_object* x_114; lean_object* x_115; lean_object* x_116; 
x_112 = lean_ctor_get(x_107, 0);
lean_inc(x_112);
if (lean_is_exclusive(x_107)) {
 lean_ctor_release(x_107, 0);
 x_113 = x_107;
} else {
 lean_dec_ref(x_107);
 x_113 = lean_box(0);
}
x_114 = lean_unsigned_to_nat(1u);
x_115 = lean_nat_add(x_104, x_114);
lean_dec(x_104);
lean_inc(x_105);
lean_inc(x_115);
lean_inc(x_103);
lean_inc(x_102);
x_116 = lean_alloc_ctor(0, 4, 2);
lean_ctor_set(x_116, 0, x_102);
lean_ctor_set(x_116, 1, x_103);
lean_ctor_set(x_116, 2, x_115);
lean_ctor_set(x_116, 3, x_105);
lean_ctor_set_uint8(x_116, sizeof(void*)*4, x_101);
lean_ctor_set_uint8(x_116, sizeof(void*)*4 + 1, x_106);
switch (lean_obj_tag(x_112)) {
case 0:
{
lean_object* x_117; uint8_t x_118; lean_object* x_119; uint8_t x_120; lean_object* x_121; lean_object* x_122; lean_object* x_123; lean_object* x_124; lean_object* x_125; lean_object* x_126; lean_object* x_127; 
lean_dec(x_115);
lean_dec(x_113);
lean_dec(x_105);
lean_dec(x_103);
lean_dec(x_102);
x_117 = lean_ctor_get(x_112, 0);
lean_inc(x_117);
lean_dec_ref(x_112);
x_118 = 1;
lean_inc(x_117);
x_119 = lean_alloc_ctor(0, 1, 1);
lean_ctor_set(x_119, 0, x_117);
lean_ctor_set_uint8(x_119, sizeof(void*)*1, x_118);
x_120 = 0;
x_121 = lean_alloc_ctor(0, 1, 1);
lean_ctor_set(x_121, 0, x_117);
lean_ctor_set_uint8(x_121, sizeof(void*)*1, x_120);
x_122 = lean_box(0);
x_123 = lean_alloc_ctor(1, 2, 0);
lean_ctor_set(x_123, 0, x_121);
lean_ctor_set(x_123, 1, x_122);
x_124 = lean_alloc_ctor(1, 2, 0);
lean_ctor_set(x_124, 0, x_119);
lean_ctor_set(x_124, 1, x_123);
x_125 = lean_box(0);
x_126 = lean_alloc_ctor(0, 2, 0);
lean_ctor_set(x_126, 0, x_124);
lean_ctor_set(x_126, 1, x_125);
x_127 = lean_alloc_ctor(0, 2, 0);
lean_ctor_set(x_127, 0, x_116);
lean_ctor_set(x_127, 1, x_126);
return x_127;
}
case 1:
{
lean_object* x_128; uint8_t x_129; lean_object* x_130; lean_object* x_131; lean_object* x_132; lean_object* x_133; lean_object* x_134; lean_object* x_135; lean_object* x_136; lean_object* x_137; lean_object* x_138; 
lean_dec_ref(x_116);
lean_dec(x_113);
x_128 = lean_ctor_get(x_112, 0);
lean_inc(x_128);
lean_dec_ref(x_112);
x_129 = 1;
lean_inc(x_128);
x_130 = lean_alloc_ctor(0, 1, 1);
lean_ctor_set(x_130, 0, x_128);
lean_ctor_set_uint8(x_130, sizeof(void*)*1, x_129);
x_131 = lean_box(0);
x_132 = lean_alloc_ctor(1, 2, 0);
lean_ctor_set(x_132, 0, x_130);
lean_ctor_set(x_132, 1, x_131);
x_133 = lean_alloc_ctor(1, 2, 0);
lean_ctor_set(x_133, 0, x_128);
lean_ctor_set(x_133, 1, x_131);
x_134 = l_List_appendTR___redArg(x_102, x_133);
x_135 = lean_alloc_ctor(0, 4, 2);
lean_ctor_set(x_135, 0, x_134);
lean_ctor_set(x_135, 1, x_103);
lean_ctor_set(x_135, 2, x_115);
lean_ctor_set(x_135, 3, x_105);
lean_ctor_set_uint8(x_135, sizeof(void*)*4, x_101);
lean_ctor_set_uint8(x_135, sizeof(void*)*4 + 1, x_106);
x_136 = lean_box(0);
x_137 = lean_alloc_ctor(0, 2, 0);
lean_ctor_set(x_137, 0, x_132);
lean_ctor_set(x_137, 1, x_136);
x_138 = lean_alloc_ctor(0, 2, 0);
lean_ctor_set(x_138, 0, x_135);
lean_ctor_set(x_138, 1, x_137);
return x_138;
}
case 2:
{
lean_object* x_139; uint8_t x_140; lean_object* x_141; lean_object* x_142; lean_object* x_143; lean_object* x_144; lean_object* x_145; lean_object* x_146; lean_object* x_147; lean_object* x_148; 
lean_dec_ref(x_116);
lean_dec(x_113);
x_139 = lean_ctor_get(x_112, 0);
lean_inc(x_139);
lean_dec_ref(x_112);
x_140 = 0;
lean_inc(x_139);
x_141 = lean_alloc_ctor(0, 1, 1);
lean_ctor_set(x_141, 0, x_139);
lean_ctor_set_uint8(x_141, sizeof(void*)*1, x_140);
x_142 = lean_box(0);
x_143 = lean_alloc_ctor(1, 2, 0);
lean_ctor_set(x_143, 0, x_141);
lean_ctor_set(x_143, 1, x_142);
x_144 = lp_padctl_List_filterTR_loop___at___00__private_Padctl_Mapper_0__stepMacro_spec__0(x_139, x_102, x_142);
lean_dec(x_139);
x_145 = lean_alloc_ctor(0, 4, 2);
lean_ctor_set(x_145, 0, x_144);
lean_ctor_set(x_145, 1, x_103);
lean_ctor_set(x_145, 2, x_115);
lean_ctor_set(x_145, 3, x_105);
lean_ctor_set_uint8(x_145, sizeof(void*)*4, x_101);
lean_ctor_set_uint8(x_145, sizeof(void*)*4 + 1, x_106);
x_146 = lean_box(0);
x_147 = lean_alloc_ctor(0, 2, 0);
lean_ctor_set(x_147, 0, x_143);
lean_ctor_set(x_147, 1, x_146);
x_148 = lean_alloc_ctor(0, 2, 0);
lean_ctor_set(x_148, 0, x_145);
lean_ctor_set(x_148, 1, x_147);
return x_148;
}
case 3:
{
lean_object* x_149; lean_object* x_150; lean_object* x_151; lean_object* x_152; lean_object* x_153; 
lean_dec(x_115);
lean_dec(x_105);
lean_dec(x_103);
lean_dec(x_102);
x_149 = lean_ctor_get(x_112, 0);
lean_inc(x_149);
lean_dec_ref(x_112);
x_150 = lean_box(0);
if (lean_is_scalar(x_113)) {
 x_151 = lean_alloc_ctor(1, 1, 0);
} else {
 x_151 = x_113;
}
lean_ctor_set(x_151, 0, x_149);
x_152 = lean_alloc_ctor(0, 2, 0);
lean_ctor_set(x_152, 0, x_150);
lean_ctor_set(x_152, 1, x_151);
x_153 = lean_alloc_ctor(0, 2, 0);
lean_ctor_set(x_153, 0, x_116);
lean_ctor_set(x_153, 1, x_152);
return x_153;
}
default: 
{
uint8_t x_154; lean_object* x_155; lean_object* x_156; lean_object* x_157; 
lean_dec_ref(x_116);
lean_dec(x_113);
x_154 = 1;
x_155 = lean_alloc_ctor(0, 4, 2);
lean_ctor_set(x_155, 0, x_102);
lean_ctor_set(x_155, 1, x_103);
lean_ctor_set(x_155, 2, x_115);
lean_ctor_set(x_155, 3, x_105);
lean_ctor_set_uint8(x_155, sizeof(void*)*4, x_101);
lean_ctor_set_uint8(x_155, sizeof(void*)*4 + 1, x_154);
x_156 = ((lean_object*)(lp_padctl___private_Padctl_Mapper_0__stepMacro___closed__0));
x_157 = lean_alloc_ctor(0, 2, 0);
lean_ctor_set(x_157, 0, x_155);
lean_ctor_set(x_157, 1, x_156);
return x_157;
}
}
}
}
}
}
LEAN_EXPORT uint8_t lp_padctl_Option_instBEq_beq___at___00onMacroTimerExpired_spec__0(lean_object* x_1, lean_object* x_2) {
_start:
{
if (lean_obj_tag(x_1) == 0)
{
if (lean_obj_tag(x_2) == 0)
{
uint8_t x_3; 
x_3 = 1;
return x_3;
}
else
{
uint8_t x_4; 
x_4 = 0;
return x_4;
}
}
else
{
if (lean_obj_tag(x_2) == 0)
{
uint8_t x_5; 
x_5 = 0;
return x_5;
}
else
{
lean_object* x_6; lean_object* x_7; uint8_t x_8; 
x_6 = lean_ctor_get(x_1, 0);
x_7 = lean_ctor_get(x_2, 0);
x_8 = lean_nat_dec_eq(x_6, x_7);
return x_8;
}
}
}
}
LEAN_EXPORT lean_object* lp_padctl_Option_instBEq_beq___at___00onMacroTimerExpired_spec__0___boxed(lean_object* x_1, lean_object* x_2) {
_start:
{
uint8_t x_3; lean_object* x_4; 
x_3 = lp_padctl_Option_instBEq_beq___at___00onMacroTimerExpired_spec__0(x_1, x_2);
lean_dec(x_2);
lean_dec(x_1);
x_4 = lean_box(x_3);
return x_4;
}
}
LEAN_EXPORT lean_object* lp_padctl_List_foldl___at___00onMacroTimerExpired_spec__1(lean_object* x_1, lean_object* x_2, lean_object* x_3) {
_start:
{
if (lean_obj_tag(x_3) == 0)
{
lean_dec(x_1);
return x_2;
}
else
{
lean_object* x_4; lean_object* x_5; lean_object* x_6; uint8_t x_21; 
x_4 = lean_ctor_get(x_3, 0);
lean_inc(x_4);
x_5 = lean_ctor_get(x_3, 1);
lean_inc(x_5);
if (lean_is_exclusive(x_3)) {
 lean_ctor_release(x_3, 0);
 lean_ctor_release(x_3, 1);
 x_6 = x_3;
} else {
 lean_dec_ref(x_3);
 x_6 = lean_box(0);
}
x_21 = lean_ctor_get_uint8(x_4, sizeof(void*)*4);
if (x_21 == 0)
{
goto block_20;
}
else
{
lean_object* x_22; lean_object* x_23; uint8_t x_24; 
x_22 = lean_ctor_get(x_4, 3);
lean_inc(x_1);
x_23 = lean_alloc_ctor(1, 1, 0);
lean_ctor_set(x_23, 0, x_1);
x_24 = lp_padctl_Option_instBEq_beq___at___00onMacroTimerExpired_spec__0(x_22, x_23);
lean_dec_ref(x_23);
if (x_24 == 0)
{
goto block_20;
}
else
{
lean_object* x_25; lean_object* x_26; lean_object* x_27; uint8_t x_28; 
lean_dec(x_6);
x_25 = lp_padctl___private_Padctl_Mapper_0__stepMacro(x_4);
x_26 = lean_ctor_get(x_25, 1);
lean_inc(x_26);
x_27 = lean_ctor_get(x_25, 0);
lean_inc(x_27);
lean_dec_ref(x_25);
x_28 = !lean_is_exclusive(x_26);
if (x_28 == 0)
{
lean_object* x_29; lean_object* x_30; uint8_t x_31; 
x_29 = lean_ctor_get(x_26, 0);
x_30 = lean_ctor_get(x_26, 1);
lean_dec(x_30);
x_31 = !lean_is_exclusive(x_2);
if (x_31 == 0)
{
lean_object* x_32; lean_object* x_33; lean_object* x_34; lean_object* x_35; lean_object* x_36; 
x_32 = lean_ctor_get(x_2, 0);
x_33 = lean_ctor_get(x_2, 1);
x_34 = lean_box(0);
lean_ctor_set_tag(x_26, 1);
lean_ctor_set(x_26, 1, x_34);
lean_ctor_set(x_26, 0, x_27);
x_35 = l_List_appendTR___redArg(x_32, x_26);
x_36 = l_List_appendTR___redArg(x_33, x_29);
lean_ctor_set(x_2, 1, x_36);
lean_ctor_set(x_2, 0, x_35);
x_3 = x_5;
goto _start;
}
else
{
lean_object* x_38; lean_object* x_39; lean_object* x_40; lean_object* x_41; lean_object* x_42; lean_object* x_43; 
x_38 = lean_ctor_get(x_2, 0);
x_39 = lean_ctor_get(x_2, 1);
lean_inc(x_39);
lean_inc(x_38);
lean_dec(x_2);
x_40 = lean_box(0);
lean_ctor_set_tag(x_26, 1);
lean_ctor_set(x_26, 1, x_40);
lean_ctor_set(x_26, 0, x_27);
x_41 = l_List_appendTR___redArg(x_38, x_26);
x_42 = l_List_appendTR___redArg(x_39, x_29);
x_43 = lean_alloc_ctor(0, 2, 0);
lean_ctor_set(x_43, 0, x_41);
lean_ctor_set(x_43, 1, x_42);
x_2 = x_43;
x_3 = x_5;
goto _start;
}
}
else
{
lean_object* x_45; lean_object* x_46; lean_object* x_47; lean_object* x_48; lean_object* x_49; lean_object* x_50; lean_object* x_51; lean_object* x_52; lean_object* x_53; 
x_45 = lean_ctor_get(x_26, 0);
lean_inc(x_45);
lean_dec(x_26);
x_46 = lean_ctor_get(x_2, 0);
lean_inc(x_46);
x_47 = lean_ctor_get(x_2, 1);
lean_inc(x_47);
if (lean_is_exclusive(x_2)) {
 lean_ctor_release(x_2, 0);
 lean_ctor_release(x_2, 1);
 x_48 = x_2;
} else {
 lean_dec_ref(x_2);
 x_48 = lean_box(0);
}
x_49 = lean_box(0);
x_50 = lean_alloc_ctor(1, 2, 0);
lean_ctor_set(x_50, 0, x_27);
lean_ctor_set(x_50, 1, x_49);
x_51 = l_List_appendTR___redArg(x_46, x_50);
x_52 = l_List_appendTR___redArg(x_47, x_45);
if (lean_is_scalar(x_48)) {
 x_53 = lean_alloc_ctor(0, 2, 0);
} else {
 x_53 = x_48;
}
lean_ctor_set(x_53, 0, x_51);
lean_ctor_set(x_53, 1, x_52);
x_2 = x_53;
x_3 = x_5;
goto _start;
}
}
}
block_20:
{
uint8_t x_7; 
x_7 = !lean_is_exclusive(x_2);
if (x_7 == 0)
{
lean_object* x_8; lean_object* x_9; lean_object* x_10; lean_object* x_11; 
x_8 = lean_ctor_get(x_2, 0);
x_9 = lean_box(0);
if (lean_is_scalar(x_6)) {
 x_10 = lean_alloc_ctor(1, 2, 0);
} else {
 x_10 = x_6;
}
lean_ctor_set(x_10, 0, x_4);
lean_ctor_set(x_10, 1, x_9);
x_11 = l_List_appendTR___redArg(x_8, x_10);
lean_ctor_set(x_2, 0, x_11);
x_3 = x_5;
goto _start;
}
else
{
lean_object* x_13; lean_object* x_14; lean_object* x_15; lean_object* x_16; lean_object* x_17; lean_object* x_18; 
x_13 = lean_ctor_get(x_2, 0);
x_14 = lean_ctor_get(x_2, 1);
lean_inc(x_14);
lean_inc(x_13);
lean_dec(x_2);
x_15 = lean_box(0);
if (lean_is_scalar(x_6)) {
 x_16 = lean_alloc_ctor(1, 2, 0);
} else {
 x_16 = x_6;
}
lean_ctor_set(x_16, 0, x_4);
lean_ctor_set(x_16, 1, x_15);
x_17 = l_List_appendTR___redArg(x_13, x_16);
x_18 = lean_alloc_ctor(0, 2, 0);
lean_ctor_set(x_18, 0, x_17);
lean_ctor_set(x_18, 1, x_14);
x_2 = x_18;
x_3 = x_5;
goto _start;
}
}
}
}
}
LEAN_EXPORT lean_object* lp_padctl_onMacroTimerExpired(lean_object* x_1, lean_object* x_2) {
_start:
{
uint8_t x_3; 
x_3 = !lean_is_exclusive(x_1);
if (x_3 == 0)
{
lean_object* x_4; lean_object* x_5; lean_object* x_6; uint8_t x_7; 
x_4 = lean_ctor_get(x_1, 4);
x_5 = ((lean_object*)(lp_padctl___private_Padctl_Mapper_0__cancelMacros___closed__0));
x_6 = lp_padctl_List_foldl___at___00onMacroTimerExpired_spec__1(x_2, x_5, x_4);
x_7 = !lean_is_exclusive(x_6);
if (x_7 == 0)
{
lean_object* x_8; 
x_8 = lean_ctor_get(x_6, 0);
lean_ctor_set(x_1, 4, x_8);
lean_ctor_set(x_6, 0, x_1);
return x_6;
}
else
{
lean_object* x_9; lean_object* x_10; lean_object* x_11; 
x_9 = lean_ctor_get(x_6, 0);
x_10 = lean_ctor_get(x_6, 1);
lean_inc(x_10);
lean_inc(x_9);
lean_dec(x_6);
lean_ctor_set(x_1, 4, x_9);
x_11 = lean_alloc_ctor(0, 2, 0);
lean_ctor_set(x_11, 0, x_1);
lean_ctor_set(x_11, 1, x_10);
return x_11;
}
}
else
{
lean_object* x_12; lean_object* x_13; lean_object* x_14; lean_object* x_15; lean_object* x_16; lean_object* x_17; lean_object* x_18; lean_object* x_19; lean_object* x_20; lean_object* x_21; lean_object* x_22; lean_object* x_23; lean_object* x_24; 
x_12 = lean_ctor_get(x_1, 0);
x_13 = lean_ctor_get(x_1, 1);
x_14 = lean_ctor_get(x_1, 2);
x_15 = lean_ctor_get(x_1, 3);
x_16 = lean_ctor_get(x_1, 4);
x_17 = lean_ctor_get(x_1, 5);
lean_inc(x_17);
lean_inc(x_16);
lean_inc(x_15);
lean_inc(x_14);
lean_inc(x_13);
lean_inc(x_12);
lean_dec(x_1);
x_18 = ((lean_object*)(lp_padctl___private_Padctl_Mapper_0__cancelMacros___closed__0));
x_19 = lp_padctl_List_foldl___at___00onMacroTimerExpired_spec__1(x_2, x_18, x_16);
x_20 = lean_ctor_get(x_19, 0);
lean_inc(x_20);
x_21 = lean_ctor_get(x_19, 1);
lean_inc(x_21);
if (lean_is_exclusive(x_19)) {
 lean_ctor_release(x_19, 0);
 lean_ctor_release(x_19, 1);
 x_22 = x_19;
} else {
 lean_dec_ref(x_19);
 x_22 = lean_box(0);
}
x_23 = lean_alloc_ctor(0, 6, 0);
lean_ctor_set(x_23, 0, x_12);
lean_ctor_set(x_23, 1, x_13);
lean_ctor_set(x_23, 2, x_14);
lean_ctor_set(x_23, 3, x_15);
lean_ctor_set(x_23, 4, x_20);
lean_ctor_set(x_23, 5, x_17);
if (lean_is_scalar(x_22)) {
 x_24 = lean_alloc_ctor(0, 2, 0);
} else {
 x_24 = x_22;
}
lean_ctor_set(x_24, 0, x_23);
lean_ctor_set(x_24, 1, x_21);
return x_24;
}
}
}
LEAN_EXPORT lean_object* lp_padctl_List_foldl___at___00notifyTriggerReleased_spec__0(lean_object* x_1, lean_object* x_2) {
_start:
{
if (lean_obj_tag(x_2) == 0)
{
return x_1;
}
else
{
lean_object* x_3; lean_object* x_4; lean_object* x_5; uint8_t x_20; 
x_3 = lean_ctor_get(x_2, 0);
lean_inc(x_3);
x_4 = lean_ctor_get(x_2, 1);
lean_inc(x_4);
if (lean_is_exclusive(x_2)) {
 lean_ctor_release(x_2, 0);
 lean_ctor_release(x_2, 1);
 x_5 = x_2;
} else {
 lean_dec_ref(x_2);
 x_5 = lean_box(0);
}
x_20 = lean_ctor_get_uint8(x_3, sizeof(void*)*4);
if (x_20 == 0)
{
goto block_19;
}
else
{
uint8_t x_21; 
x_21 = lean_ctor_get_uint8(x_3, sizeof(void*)*4 + 1);
if (x_21 == 0)
{
goto block_19;
}
else
{
uint8_t x_22; 
lean_dec(x_5);
x_22 = !lean_is_exclusive(x_3);
if (x_22 == 0)
{
uint8_t x_23; lean_object* x_24; lean_object* x_25; lean_object* x_26; uint8_t x_27; 
x_23 = 0;
lean_ctor_set_uint8(x_3, sizeof(void*)*4 + 1, x_23);
x_24 = lp_padctl___private_Padctl_Mapper_0__stepMacro(x_3);
x_25 = lean_ctor_get(x_24, 1);
lean_inc(x_25);
x_26 = lean_ctor_get(x_24, 0);
lean_inc(x_26);
lean_dec_ref(x_24);
x_27 = !lean_is_exclusive(x_25);
if (x_27 == 0)
{
lean_object* x_28; lean_object* x_29; uint8_t x_30; 
x_28 = lean_ctor_get(x_25, 0);
x_29 = lean_ctor_get(x_25, 1);
lean_dec(x_29);
x_30 = !lean_is_exclusive(x_1);
if (x_30 == 0)
{
lean_object* x_31; lean_object* x_32; lean_object* x_33; lean_object* x_34; lean_object* x_35; 
x_31 = lean_ctor_get(x_1, 0);
x_32 = lean_ctor_get(x_1, 1);
x_33 = lean_box(0);
lean_ctor_set_tag(x_25, 1);
lean_ctor_set(x_25, 1, x_33);
lean_ctor_set(x_25, 0, x_26);
x_34 = l_List_appendTR___redArg(x_31, x_25);
x_35 = l_List_appendTR___redArg(x_32, x_28);
lean_ctor_set(x_1, 1, x_35);
lean_ctor_set(x_1, 0, x_34);
x_2 = x_4;
goto _start;
}
else
{
lean_object* x_37; lean_object* x_38; lean_object* x_39; lean_object* x_40; lean_object* x_41; lean_object* x_42; 
x_37 = lean_ctor_get(x_1, 0);
x_38 = lean_ctor_get(x_1, 1);
lean_inc(x_38);
lean_inc(x_37);
lean_dec(x_1);
x_39 = lean_box(0);
lean_ctor_set_tag(x_25, 1);
lean_ctor_set(x_25, 1, x_39);
lean_ctor_set(x_25, 0, x_26);
x_40 = l_List_appendTR___redArg(x_37, x_25);
x_41 = l_List_appendTR___redArg(x_38, x_28);
x_42 = lean_alloc_ctor(0, 2, 0);
lean_ctor_set(x_42, 0, x_40);
lean_ctor_set(x_42, 1, x_41);
x_1 = x_42;
x_2 = x_4;
goto _start;
}
}
else
{
lean_object* x_44; lean_object* x_45; lean_object* x_46; lean_object* x_47; lean_object* x_48; lean_object* x_49; lean_object* x_50; lean_object* x_51; lean_object* x_52; 
x_44 = lean_ctor_get(x_25, 0);
lean_inc(x_44);
lean_dec(x_25);
x_45 = lean_ctor_get(x_1, 0);
lean_inc(x_45);
x_46 = lean_ctor_get(x_1, 1);
lean_inc(x_46);
if (lean_is_exclusive(x_1)) {
 lean_ctor_release(x_1, 0);
 lean_ctor_release(x_1, 1);
 x_47 = x_1;
} else {
 lean_dec_ref(x_1);
 x_47 = lean_box(0);
}
x_48 = lean_box(0);
x_49 = lean_alloc_ctor(1, 2, 0);
lean_ctor_set(x_49, 0, x_26);
lean_ctor_set(x_49, 1, x_48);
x_50 = l_List_appendTR___redArg(x_45, x_49);
x_51 = l_List_appendTR___redArg(x_46, x_44);
if (lean_is_scalar(x_47)) {
 x_52 = lean_alloc_ctor(0, 2, 0);
} else {
 x_52 = x_47;
}
lean_ctor_set(x_52, 0, x_50);
lean_ctor_set(x_52, 1, x_51);
x_1 = x_52;
x_2 = x_4;
goto _start;
}
}
else
{
lean_object* x_54; lean_object* x_55; lean_object* x_56; lean_object* x_57; uint8_t x_58; lean_object* x_59; lean_object* x_60; lean_object* x_61; lean_object* x_62; lean_object* x_63; lean_object* x_64; lean_object* x_65; lean_object* x_66; lean_object* x_67; lean_object* x_68; lean_object* x_69; lean_object* x_70; lean_object* x_71; lean_object* x_72; 
x_54 = lean_ctor_get(x_3, 0);
x_55 = lean_ctor_get(x_3, 1);
x_56 = lean_ctor_get(x_3, 2);
x_57 = lean_ctor_get(x_3, 3);
lean_inc(x_57);
lean_inc(x_56);
lean_inc(x_55);
lean_inc(x_54);
lean_dec(x_3);
x_58 = 0;
x_59 = lean_alloc_ctor(0, 4, 2);
lean_ctor_set(x_59, 0, x_54);
lean_ctor_set(x_59, 1, x_55);
lean_ctor_set(x_59, 2, x_56);
lean_ctor_set(x_59, 3, x_57);
lean_ctor_set_uint8(x_59, sizeof(void*)*4, x_20);
lean_ctor_set_uint8(x_59, sizeof(void*)*4 + 1, x_58);
x_60 = lp_padctl___private_Padctl_Mapper_0__stepMacro(x_59);
x_61 = lean_ctor_get(x_60, 1);
lean_inc(x_61);
x_62 = lean_ctor_get(x_60, 0);
lean_inc(x_62);
lean_dec_ref(x_60);
x_63 = lean_ctor_get(x_61, 0);
lean_inc(x_63);
if (lean_is_exclusive(x_61)) {
 lean_ctor_release(x_61, 0);
 lean_ctor_release(x_61, 1);
 x_64 = x_61;
} else {
 lean_dec_ref(x_61);
 x_64 = lean_box(0);
}
x_65 = lean_ctor_get(x_1, 0);
lean_inc(x_65);
x_66 = lean_ctor_get(x_1, 1);
lean_inc(x_66);
if (lean_is_exclusive(x_1)) {
 lean_ctor_release(x_1, 0);
 lean_ctor_release(x_1, 1);
 x_67 = x_1;
} else {
 lean_dec_ref(x_1);
 x_67 = lean_box(0);
}
x_68 = lean_box(0);
if (lean_is_scalar(x_64)) {
 x_69 = lean_alloc_ctor(1, 2, 0);
} else {
 x_69 = x_64;
 lean_ctor_set_tag(x_69, 1);
}
lean_ctor_set(x_69, 0, x_62);
lean_ctor_set(x_69, 1, x_68);
x_70 = l_List_appendTR___redArg(x_65, x_69);
x_71 = l_List_appendTR___redArg(x_66, x_63);
if (lean_is_scalar(x_67)) {
 x_72 = lean_alloc_ctor(0, 2, 0);
} else {
 x_72 = x_67;
}
lean_ctor_set(x_72, 0, x_70);
lean_ctor_set(x_72, 1, x_71);
x_1 = x_72;
x_2 = x_4;
goto _start;
}
}
}
block_19:
{
uint8_t x_6; 
x_6 = !lean_is_exclusive(x_1);
if (x_6 == 0)
{
lean_object* x_7; lean_object* x_8; lean_object* x_9; lean_object* x_10; 
x_7 = lean_ctor_get(x_1, 0);
x_8 = lean_box(0);
if (lean_is_scalar(x_5)) {
 x_9 = lean_alloc_ctor(1, 2, 0);
} else {
 x_9 = x_5;
}
lean_ctor_set(x_9, 0, x_3);
lean_ctor_set(x_9, 1, x_8);
x_10 = l_List_appendTR___redArg(x_7, x_9);
lean_ctor_set(x_1, 0, x_10);
x_2 = x_4;
goto _start;
}
else
{
lean_object* x_12; lean_object* x_13; lean_object* x_14; lean_object* x_15; lean_object* x_16; lean_object* x_17; 
x_12 = lean_ctor_get(x_1, 0);
x_13 = lean_ctor_get(x_1, 1);
lean_inc(x_13);
lean_inc(x_12);
lean_dec(x_1);
x_14 = lean_box(0);
if (lean_is_scalar(x_5)) {
 x_15 = lean_alloc_ctor(1, 2, 0);
} else {
 x_15 = x_5;
}
lean_ctor_set(x_15, 0, x_3);
lean_ctor_set(x_15, 1, x_14);
x_16 = l_List_appendTR___redArg(x_12, x_15);
x_17 = lean_alloc_ctor(0, 2, 0);
lean_ctor_set(x_17, 0, x_16);
lean_ctor_set(x_17, 1, x_13);
x_1 = x_17;
x_2 = x_4;
goto _start;
}
}
}
}
}
LEAN_EXPORT lean_object* lp_padctl_notifyTriggerReleased(lean_object* x_1) {
_start:
{
uint8_t x_2; 
x_2 = !lean_is_exclusive(x_1);
if (x_2 == 0)
{
lean_object* x_3; lean_object* x_4; lean_object* x_5; uint8_t x_6; 
x_3 = lean_ctor_get(x_1, 4);
x_4 = ((lean_object*)(lp_padctl___private_Padctl_Mapper_0__cancelMacros___closed__0));
x_5 = lp_padctl_List_foldl___at___00notifyTriggerReleased_spec__0(x_4, x_3);
x_6 = !lean_is_exclusive(x_5);
if (x_6 == 0)
{
lean_object* x_7; 
x_7 = lean_ctor_get(x_5, 0);
lean_ctor_set(x_1, 4, x_7);
lean_ctor_set(x_5, 0, x_1);
return x_5;
}
else
{
lean_object* x_8; lean_object* x_9; lean_object* x_10; 
x_8 = lean_ctor_get(x_5, 0);
x_9 = lean_ctor_get(x_5, 1);
lean_inc(x_9);
lean_inc(x_8);
lean_dec(x_5);
lean_ctor_set(x_1, 4, x_8);
x_10 = lean_alloc_ctor(0, 2, 0);
lean_ctor_set(x_10, 0, x_1);
lean_ctor_set(x_10, 1, x_9);
return x_10;
}
}
else
{
lean_object* x_11; lean_object* x_12; lean_object* x_13; lean_object* x_14; lean_object* x_15; lean_object* x_16; lean_object* x_17; lean_object* x_18; lean_object* x_19; lean_object* x_20; lean_object* x_21; lean_object* x_22; lean_object* x_23; 
x_11 = lean_ctor_get(x_1, 0);
x_12 = lean_ctor_get(x_1, 1);
x_13 = lean_ctor_get(x_1, 2);
x_14 = lean_ctor_get(x_1, 3);
x_15 = lean_ctor_get(x_1, 4);
x_16 = lean_ctor_get(x_1, 5);
lean_inc(x_16);
lean_inc(x_15);
lean_inc(x_14);
lean_inc(x_13);
lean_inc(x_12);
lean_inc(x_11);
lean_dec(x_1);
x_17 = ((lean_object*)(lp_padctl___private_Padctl_Mapper_0__cancelMacros___closed__0));
x_18 = lp_padctl_List_foldl___at___00notifyTriggerReleased_spec__0(x_17, x_15);
x_19 = lean_ctor_get(x_18, 0);
lean_inc(x_19);
x_20 = lean_ctor_get(x_18, 1);
lean_inc(x_20);
if (lean_is_exclusive(x_18)) {
 lean_ctor_release(x_18, 0);
 lean_ctor_release(x_18, 1);
 x_21 = x_18;
} else {
 lean_dec_ref(x_18);
 x_21 = lean_box(0);
}
x_22 = lean_alloc_ctor(0, 6, 0);
lean_ctor_set(x_22, 0, x_11);
lean_ctor_set(x_22, 1, x_12);
lean_ctor_set(x_22, 2, x_13);
lean_ctor_set(x_22, 3, x_14);
lean_ctor_set(x_22, 4, x_19);
lean_ctor_set(x_22, 5, x_16);
if (lean_is_scalar(x_21)) {
 x_23 = lean_alloc_ctor(0, 2, 0);
} else {
 x_23 = x_21;
}
lean_ctor_set(x_23, 0, x_22);
lean_ctor_set(x_23, 1, x_20);
return x_23;
}
}
}
static lean_object* _init_lp_padctl_instReprApplyResult_repr___redArg___closed__14(void) {
_start:
{
lean_object* x_1; lean_object* x_2; 
x_1 = lean_unsigned_to_nat(26u);
x_2 = lean_nat_to_int(x_1);
return x_2;
}
}
LEAN_EXPORT lean_object* lp_padctl_instReprApplyResult_repr___redArg(lean_object* x_1) {
_start:
{
lean_object* x_2; lean_object* x_3; lean_object* x_4; lean_object* x_5; uint8_t x_6; uint8_t x_7; uint8_t x_8; lean_object* x_9; lean_object* x_10; lean_object* x_11; lean_object* x_12; lean_object* x_13; uint8_t x_14; lean_object* x_15; lean_object* x_16; lean_object* x_17; lean_object* x_18; lean_object* x_19; lean_object* x_20; lean_object* x_21; lean_object* x_22; lean_object* x_23; lean_object* x_24; lean_object* x_25; lean_object* x_26; lean_object* x_27; lean_object* x_28; lean_object* x_29; lean_object* x_30; lean_object* x_31; lean_object* x_32; lean_object* x_33; lean_object* x_34; lean_object* x_35; lean_object* x_36; lean_object* x_37; lean_object* x_38; lean_object* x_39; lean_object* x_40; lean_object* x_41; lean_object* x_42; lean_object* x_43; lean_object* x_44; lean_object* x_45; lean_object* x_46; lean_object* x_47; lean_object* x_48; lean_object* x_49; lean_object* x_50; lean_object* x_51; lean_object* x_52; lean_object* x_53; lean_object* x_54; lean_object* x_55; lean_object* x_56; lean_object* x_57; lean_object* x_58; lean_object* x_59; lean_object* x_60; lean_object* x_61; lean_object* x_62; lean_object* x_63; lean_object* x_64; lean_object* x_65; lean_object* x_66; lean_object* x_67; lean_object* x_68; lean_object* x_69; lean_object* x_70; lean_object* x_71; lean_object* x_72; lean_object* x_73; lean_object* x_74; lean_object* x_75; lean_object* x_76; lean_object* x_77; lean_object* x_78; lean_object* x_79; lean_object* x_80; lean_object* x_81; lean_object* x_82; lean_object* x_83; 
x_2 = lean_ctor_get(x_1, 0);
lean_inc_ref(x_2);
x_3 = lean_ctor_get(x_1, 1);
lean_inc_ref(x_3);
x_4 = lean_ctor_get(x_1, 2);
lean_inc(x_4);
x_5 = lean_ctor_get(x_1, 3);
lean_inc_ref(x_5);
x_6 = lean_ctor_get_uint8(x_1, sizeof(void*)*4);
x_7 = lean_ctor_get_uint8(x_1, sizeof(void*)*4 + 1);
x_8 = lean_ctor_get_uint8(x_1, sizeof(void*)*4 + 2);
lean_dec_ref(x_1);
x_9 = ((lean_object*)(lp_padctl_instReprLayerConfig_repr___redArg___closed__5));
x_10 = ((lean_object*)(lp_padctl_instReprApplyResult_repr___redArg___closed__3));
x_11 = lean_obj_once(&lp_padctl_instReprLayerConfig_repr___redArg___closed__15, &lp_padctl_instReprLayerConfig_repr___redArg___closed__15_once, _init_lp_padctl_instReprLayerConfig_repr___redArg___closed__15);
x_12 = lp_padctl_instReprMapperState_repr___redArg(x_2);
x_13 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_13, 0, x_11);
lean_ctor_set(x_13, 1, x_12);
x_14 = 0;
x_15 = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(x_15, 0, x_13);
lean_ctor_set_uint8(x_15, sizeof(void*)*1, x_14);
x_16 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_16, 0, x_10);
lean_ctor_set(x_16, 1, x_15);
x_17 = ((lean_object*)(lp_padctl_instReprLayerConfig_repr___redArg___closed__9));
x_18 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_18, 0, x_16);
lean_ctor_set(x_18, 1, x_17);
x_19 = lean_box(1);
x_20 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_20, 0, x_18);
lean_ctor_set(x_20, 1, x_19);
x_21 = ((lean_object*)(lp_padctl_instReprApplyResult_repr___redArg___closed__5));
x_22 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_22, 0, x_20);
lean_ctor_set(x_22, 1, x_21);
x_23 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_23, 0, x_22);
lean_ctor_set(x_23, 1, x_9);
x_24 = lean_obj_once(&lp_padctl_instReprLayerConfig_repr___redArg___closed__7, &lp_padctl_instReprLayerConfig_repr___redArg___closed__7_once, _init_lp_padctl_instReprLayerConfig_repr___redArg___closed__7);
x_25 = lp_padctl_instReprGamepadState_repr___redArg(x_3);
x_26 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_26, 0, x_24);
lean_ctor_set(x_26, 1, x_25);
x_27 = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(x_27, 0, x_26);
lean_ctor_set_uint8(x_27, sizeof(void*)*1, x_14);
x_28 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_28, 0, x_23);
lean_ctor_set(x_28, 1, x_27);
x_29 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_29, 0, x_28);
lean_ctor_set(x_29, 1, x_17);
x_30 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_30, 0, x_29);
lean_ctor_set(x_30, 1, x_19);
x_31 = ((lean_object*)(lp_padctl_instReprRemapResult_repr___redArg___closed__8));
x_32 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_32, 0, x_30);
lean_ctor_set(x_32, 1, x_31);
x_33 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_33, 0, x_32);
lean_ctor_set(x_33, 1, x_9);
x_34 = lean_obj_once(&lp_padctl_instReprTapHoldState_repr___redArg___closed__13, &lp_padctl_instReprTapHoldState_repr___redArg___closed__13_once, _init_lp_padctl_instReprTapHoldState_repr___redArg___closed__13);
x_35 = lp_padctl_List_repr___at___00instReprRemapResult_repr_spec__0___redArg(x_4);
x_36 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_36, 0, x_34);
lean_ctor_set(x_36, 1, x_35);
x_37 = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(x_37, 0, x_36);
lean_ctor_set_uint8(x_37, sizeof(void*)*1, x_14);
x_38 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_38, 0, x_33);
lean_ctor_set(x_38, 1, x_37);
x_39 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_39, 0, x_38);
lean_ctor_set(x_39, 1, x_17);
x_40 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_40, 0, x_39);
lean_ctor_set(x_40, 1, x_19);
x_41 = ((lean_object*)(lp_padctl_instReprApplyResult_repr___redArg___closed__7));
x_42 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_42, 0, x_40);
lean_ctor_set(x_42, 1, x_41);
x_43 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_43, 0, x_42);
lean_ctor_set(x_43, 1, x_9);
x_44 = lean_obj_once(&lp_padctl_instReprMacroState_repr___redArg___closed__14, &lp_padctl_instReprMacroState_repr___redArg___closed__14_once, _init_lp_padctl_instReprMacroState_repr___redArg___closed__14);
x_45 = lp_padctl_instReprGamepadState_repr___redArg(x_5);
x_46 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_46, 0, x_44);
lean_ctor_set(x_46, 1, x_45);
x_47 = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(x_47, 0, x_46);
lean_ctor_set_uint8(x_47, sizeof(void*)*1, x_14);
x_48 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_48, 0, x_43);
lean_ctor_set(x_48, 1, x_47);
x_49 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_49, 0, x_48);
lean_ctor_set(x_49, 1, x_17);
x_50 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_50, 0, x_49);
lean_ctor_set(x_50, 1, x_19);
x_51 = ((lean_object*)(lp_padctl_instReprApplyResult_repr___redArg___closed__9));
x_52 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_52, 0, x_50);
lean_ctor_set(x_52, 1, x_51);
x_53 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_53, 0, x_52);
lean_ctor_set(x_53, 1, x_9);
x_54 = l_Bool_repr___redArg(x_6);
x_55 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_55, 0, x_44);
lean_ctor_set(x_55, 1, x_54);
x_56 = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(x_56, 0, x_55);
lean_ctor_set_uint8(x_56, sizeof(void*)*1, x_14);
x_57 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_57, 0, x_53);
lean_ctor_set(x_57, 1, x_56);
x_58 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_58, 0, x_57);
lean_ctor_set(x_58, 1, x_17);
x_59 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_59, 0, x_58);
lean_ctor_set(x_59, 1, x_19);
x_60 = ((lean_object*)(lp_padctl_instReprApplyResult_repr___redArg___closed__11));
x_61 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_61, 0, x_59);
lean_ctor_set(x_61, 1, x_60);
x_62 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_62, 0, x_61);
lean_ctor_set(x_62, 1, x_9);
x_63 = l_Bool_repr___redArg(x_7);
x_64 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_64, 0, x_34);
lean_ctor_set(x_64, 1, x_63);
x_65 = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(x_65, 0, x_64);
lean_ctor_set_uint8(x_65, sizeof(void*)*1, x_14);
x_66 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_66, 0, x_62);
lean_ctor_set(x_66, 1, x_65);
x_67 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_67, 0, x_66);
lean_ctor_set(x_67, 1, x_17);
x_68 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_68, 0, x_67);
lean_ctor_set(x_68, 1, x_19);
x_69 = ((lean_object*)(lp_padctl_instReprApplyResult_repr___redArg___closed__13));
x_70 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_70, 0, x_68);
lean_ctor_set(x_70, 1, x_69);
x_71 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_71, 0, x_70);
lean_ctor_set(x_71, 1, x_9);
x_72 = lean_obj_once(&lp_padctl_instReprApplyResult_repr___redArg___closed__14, &lp_padctl_instReprApplyResult_repr___redArg___closed__14_once, _init_lp_padctl_instReprApplyResult_repr___redArg___closed__14);
x_73 = l_Bool_repr___redArg(x_8);
x_74 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_74, 0, x_72);
lean_ctor_set(x_74, 1, x_73);
x_75 = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(x_75, 0, x_74);
lean_ctor_set_uint8(x_75, sizeof(void*)*1, x_14);
x_76 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_76, 0, x_71);
lean_ctor_set(x_76, 1, x_75);
x_77 = lean_obj_once(&lp_padctl_instReprLayerConfig_repr___redArg___closed__18, &lp_padctl_instReprLayerConfig_repr___redArg___closed__18_once, _init_lp_padctl_instReprLayerConfig_repr___redArg___closed__18);
x_78 = ((lean_object*)(lp_padctl_instReprLayerConfig_repr___redArg___closed__19));
x_79 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_79, 0, x_78);
lean_ctor_set(x_79, 1, x_76);
x_80 = ((lean_object*)(lp_padctl_instReprLayerConfig_repr___redArg___closed__20));
x_81 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_81, 0, x_79);
lean_ctor_set(x_81, 1, x_80);
x_82 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_82, 0, x_77);
lean_ctor_set(x_82, 1, x_81);
x_83 = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(x_83, 0, x_82);
lean_ctor_set_uint8(x_83, sizeof(void*)*1, x_14);
return x_83;
}
}
LEAN_EXPORT lean_object* lp_padctl_instReprApplyResult_repr(lean_object* x_1, lean_object* x_2) {
_start:
{
lean_object* x_3; 
x_3 = lp_padctl_instReprApplyResult_repr___redArg(x_1);
return x_3;
}
}
LEAN_EXPORT lean_object* lp_padctl_instReprApplyResult_repr___boxed(lean_object* x_1, lean_object* x_2) {
_start:
{
lean_object* x_3; 
x_3 = lp_padctl_instReprApplyResult_repr(x_1, x_2);
lean_dec(x_2);
return x_3;
}
}
LEAN_EXPORT lean_object* lp_padctl_Mapper_apply(lean_object* x_1, lean_object* x_2, lean_object* x_3, lean_object* x_4, lean_object* x_5) {
_start:
{
lean_object* x_6; lean_object* x_7; lean_object* x_8; lean_object* x_9; uint8_t x_10; lean_object* x_11; lean_object* x_12; lean_object* x_13; lean_object* x_14; lean_object* x_15; lean_object* x_16; lean_object* x_17; lean_object* x_18; lean_object* x_19; lean_object* x_20; lean_object* x_21; lean_object* x_22; lean_object* x_23; lean_object* x_24; uint8_t x_25; lean_object* x_26; uint8_t x_27; lean_object* x_28; lean_object* x_29; lean_object* x_30; uint8_t x_31; uint8_t x_32; lean_object* x_33; lean_object* x_34; lean_object* x_35; lean_object* x_36; lean_object* x_37; lean_object* x_38; lean_object* x_43; lean_object* x_44; lean_object* x_45; lean_object* x_46; lean_object* x_47; lean_object* x_48; lean_object* x_49; lean_object* x_50; lean_object* x_51; lean_object* x_52; lean_object* x_53; lean_object* x_54; lean_object* x_55; lean_object* x_56; lean_object* x_57; lean_object* x_58; uint8_t x_59; lean_object* x_60; lean_object* x_61; lean_object* x_62; lean_object* x_63; uint8_t x_64; lean_object* x_65; lean_object* x_66; lean_object* x_67; lean_object* x_68; lean_object* x_69; lean_object* x_70; uint8_t x_71; uint8_t x_72; lean_object* x_73; lean_object* x_74; lean_object* x_75; lean_object* x_76; lean_object* x_77; lean_object* x_78; lean_object* x_79; lean_object* x_80; lean_object* x_81; lean_object* x_82; uint8_t x_83; lean_object* x_84; lean_object* x_85; lean_object* x_86; lean_object* x_87; lean_object* x_88; uint8_t x_89; lean_object* x_90; lean_object* x_91; lean_object* x_92; uint8_t x_93; lean_object* x_94; lean_object* x_95; uint8_t x_96; lean_object* x_97; lean_object* x_98; lean_object* x_103; lean_object* x_104; uint8_t x_105; lean_object* x_106; lean_object* x_107; lean_object* x_108; lean_object* x_109; lean_object* x_110; lean_object* x_111; lean_object* x_112; lean_object* x_113; lean_object* x_114; lean_object* x_115; lean_object* x_116; lean_object* x_117; lean_object* x_118; lean_object* x_119; uint8_t x_120; lean_object* x_121; lean_object* x_122; lean_object* x_123; lean_object* x_124; uint8_t x_125; lean_object* x_126; lean_object* x_127; lean_object* x_128; lean_object* x_129; lean_object* x_130; lean_object* x_131; lean_object* x_132; uint8_t x_133; uint8_t x_134; lean_object* x_135; lean_object* x_136; lean_object* x_137; lean_object* x_138; lean_object* x_139; lean_object* x_140; lean_object* x_141; lean_object* x_142; lean_object* x_143; lean_object* x_144; uint8_t x_145; lean_object* x_146; lean_object* x_147; lean_object* x_148; lean_object* x_149; uint8_t x_150; lean_object* x_151; lean_object* x_152; lean_object* x_153; uint8_t x_154; lean_object* x_155; lean_object* x_156; uint8_t x_157; lean_object* x_158; lean_object* x_159; lean_object* x_162; uint8_t x_163; lean_object* x_164; lean_object* x_165; lean_object* x_166; lean_object* x_167; lean_object* x_168; lean_object* x_169; uint8_t x_170; lean_object* x_171; lean_object* x_172; lean_object* x_173; lean_object* x_174; lean_object* x_175; lean_object* x_176; lean_object* x_177; lean_object* x_178; lean_object* x_179; lean_object* x_180; uint8_t x_181; lean_object* x_182; lean_object* x_183; lean_object* x_184; lean_object* x_185; uint8_t x_186; lean_object* x_187; lean_object* x_188; lean_object* x_189; lean_object* x_190; lean_object* x_191; lean_object* x_192; lean_object* x_193; uint8_t x_194; uint8_t x_195; lean_object* x_196; lean_object* x_197; lean_object* x_198; lean_object* x_199; lean_object* x_200; lean_object* x_201; lean_object* x_202; lean_object* x_203; lean_object* x_204; lean_object* x_205; lean_object* x_206; uint8_t x_207; lean_object* x_208; lean_object* x_209; lean_object* x_210; lean_object* x_211; uint8_t x_212; lean_object* x_213; lean_object* x_214; lean_object* x_215; lean_object* x_216; uint8_t x_217; lean_object* x_218; lean_object* x_219; lean_object* x_220; uint8_t x_221; lean_object* x_227; uint8_t x_228; lean_object* x_229; lean_object* x_230; lean_object* x_231; lean_object* x_232; lean_object* x_233; lean_object* x_234; uint8_t x_235; lean_object* x_236; lean_object* x_237; lean_object* x_238; lean_object* x_239; lean_object* x_240; lean_object* x_241; lean_object* x_242; lean_object* x_243; uint8_t x_244; lean_object* x_245; lean_object* x_246; lean_object* x_247; lean_object* x_248; lean_object* x_249; lean_object* x_250; uint8_t x_251; lean_object* x_252; lean_object* x_253; lean_object* x_254; lean_object* x_255; lean_object* x_256; lean_object* x_257; lean_object* x_258; uint8_t x_259; uint8_t x_260; lean_object* x_261; lean_object* x_262; lean_object* x_263; lean_object* x_264; lean_object* x_265; lean_object* x_266; lean_object* x_267; lean_object* x_268; uint8_t x_269; lean_object* x_270; lean_object* x_271; uint8_t x_272; lean_object* x_273; lean_object* x_274; lean_object* x_275; lean_object* x_276; lean_object* x_277; uint8_t x_278; lean_object* x_279; lean_object* x_280; lean_object* x_281; uint8_t x_282; lean_object* x_283; lean_object* x_284; lean_object* x_285; lean_object* x_286; lean_object* x_293; lean_object* x_294; lean_object* x_295; lean_object* x_296; lean_object* x_297; lean_object* x_298; lean_object* x_299; lean_object* x_300; uint8_t x_301; lean_object* x_302; lean_object* x_303; lean_object* x_304; lean_object* x_305; lean_object* x_306; uint8_t x_307; lean_object* x_308; lean_object* x_309; lean_object* x_310; lean_object* x_311; lean_object* x_312; lean_object* x_313; lean_object* x_314; lean_object* x_315; lean_object* x_316; lean_object* x_317; uint8_t x_318; lean_object* x_319; lean_object* x_320; lean_object* x_321; lean_object* x_322; uint8_t x_323; lean_object* x_324; lean_object* x_325; lean_object* x_326; lean_object* x_327; lean_object* x_328; lean_object* x_329; uint8_t x_330; uint8_t x_331; lean_object* x_332; lean_object* x_333; lean_object* x_334; lean_object* x_335; lean_object* x_336; uint8_t x_337; lean_object* x_338; uint8_t x_339; lean_object* x_340; lean_object* x_341; lean_object* x_342; lean_object* x_343; lean_object* x_344; lean_object* x_345; uint8_t x_346; lean_object* x_347; lean_object* x_348; lean_object* x_349; lean_object* x_350; lean_object* x_374; lean_object* x_375; lean_object* x_376; lean_object* x_377; lean_object* x_378; lean_object* x_379; lean_object* x_380; lean_object* x_381; lean_object* x_382; lean_object* x_383; lean_object* x_384; lean_object* x_385; uint8_t x_386; lean_object* x_387; lean_object* x_388; lean_object* x_389; lean_object* x_390; uint8_t x_391; lean_object* x_392; lean_object* x_393; lean_object* x_394; lean_object* x_395; lean_object* x_396; uint8_t x_397; lean_object* x_398; lean_object* x_399; uint8_t x_400; lean_object* x_401; lean_object* x_402; lean_object* x_403; lean_object* x_404; uint8_t x_405; uint8_t x_406; lean_object* x_407; lean_object* x_408; lean_object* x_409; lean_object* x_410; lean_object* x_411; uint8_t x_412; lean_object* x_413; lean_object* x_414; lean_object* x_415; lean_object* x_416; lean_object* x_417; lean_object* x_418; lean_object* x_419; lean_object* x_420; uint8_t x_421; lean_object* x_422; lean_object* x_423; lean_object* x_424; uint8_t x_425; lean_object* x_433; lean_object* x_434; lean_object* x_435; uint8_t x_436; lean_object* x_437; lean_object* x_438; lean_object* x_439; lean_object* x_440; lean_object* x_441; lean_object* x_442; lean_object* x_443; lean_object* x_444; lean_object* x_445; lean_object* x_446; lean_object* x_447; lean_object* x_448; lean_object* x_449; lean_object* x_450; lean_object* x_451; lean_object* x_452; lean_object* x_453; lean_object* x_454; lean_object* x_455; lean_object* x_456; lean_object* x_457; lean_object* x_458; uint8_t x_459; lean_object* x_460; uint8_t x_461; lean_object* x_495; 
x_293 = lean_ctor_get(x_1, 0);
lean_inc(x_293);
x_294 = lean_ctor_get(x_1, 1);
lean_inc(x_294);
x_295 = lean_ctor_get(x_1, 2);
lean_inc(x_295);
x_296 = lean_ctor_get(x_1, 3);
lean_inc(x_296);
x_297 = lean_ctor_get(x_1, 4);
lean_inc(x_297);
x_298 = lean_ctor_get(x_1, 5);
lean_inc(x_298);
if (lean_is_exclusive(x_1)) {
 lean_ctor_release(x_1, 0);
 lean_ctor_release(x_1, 1);
 lean_ctor_release(x_1, 2);
 lean_ctor_release(x_1, 3);
 lean_ctor_release(x_1, 4);
 lean_ctor_release(x_1, 5);
 x_299 = x_1;
} else {
 lean_dec_ref(x_1);
 x_299 = lean_box(0);
}
if (lean_obj_tag(x_298) == 0)
{
lean_object* x_533; 
x_533 = lean_unsigned_to_nat(0u);
x_495 = x_533;
goto block_532;
}
else
{
lean_object* x_534; lean_object* x_535; lean_object* x_536; 
x_534 = lean_ctor_get(x_298, 0);
x_535 = lean_unsigned_to_nat(1u);
x_536 = lean_nat_shiftl(x_535, x_534);
x_495 = x_536;
goto block_532;
}
block_42:
{
lean_object* x_39; lean_object* x_40; lean_object* x_41; 
x_39 = lean_alloc_ctor(0, 20, 2);
lean_ctor_set(x_39, 0, x_30);
lean_ctor_set(x_39, 1, x_12);
lean_ctor_set(x_39, 2, x_7);
lean_ctor_set(x_39, 3, x_11);
lean_ctor_set(x_39, 4, x_6);
lean_ctor_set(x_39, 5, x_23);
lean_ctor_set(x_39, 6, x_9);
lean_ctor_set(x_39, 7, x_14);
lean_ctor_set(x_39, 8, x_38);
lean_ctor_set(x_39, 9, x_34);
lean_ctor_set(x_39, 10, x_37);
lean_ctor_set(x_39, 11, x_29);
lean_ctor_set(x_39, 12, x_28);
lean_ctor_set(x_39, 13, x_22);
lean_ctor_set(x_39, 14, x_35);
lean_ctor_set(x_39, 15, x_18);
lean_ctor_set(x_39, 16, x_26);
lean_ctor_set(x_39, 17, x_8);
lean_ctor_set(x_39, 18, x_21);
lean_ctor_set(x_39, 19, x_17);
lean_ctor_set_uint8(x_39, sizeof(void*)*20, x_31);
lean_ctor_set_uint8(x_39, sizeof(void*)*20 + 1, x_27);
x_40 = lean_alloc_ctor(0, 6, 0);
lean_ctor_set(x_40, 0, x_33);
lean_ctor_set(x_40, 1, x_13);
lean_ctor_set(x_40, 2, x_16);
lean_ctor_set(x_40, 3, x_19);
lean_ctor_set(x_40, 4, x_15);
lean_ctor_set(x_40, 5, x_24);
x_41 = lean_alloc_ctor(0, 4, 3);
lean_ctor_set(x_41, 0, x_40);
lean_ctor_set(x_41, 1, x_20);
lean_ctor_set(x_41, 2, x_36);
lean_ctor_set(x_41, 3, x_39);
lean_ctor_set_uint8(x_41, sizeof(void*)*4, x_10);
lean_ctor_set_uint8(x_41, sizeof(void*)*4 + 1, x_32);
lean_ctor_set_uint8(x_41, sizeof(void*)*4 + 2, x_25);
return x_41;
}
block_102:
{
lean_object* x_99; lean_object* x_100; 
x_99 = lean_alloc_ctor(0, 20, 2);
lean_ctor_set(x_99, 0, x_44);
lean_ctor_set(x_99, 1, x_47);
lean_ctor_set(x_99, 2, x_87);
lean_ctor_set(x_99, 3, x_98);
lean_ctor_set(x_99, 4, x_73);
lean_ctor_set(x_99, 5, x_66);
lean_ctor_set(x_99, 6, x_90);
lean_ctor_set(x_99, 7, x_68);
lean_ctor_set(x_99, 8, x_51);
lean_ctor_set(x_99, 9, x_63);
lean_ctor_set(x_99, 10, x_52);
lean_ctor_set(x_99, 11, x_57);
lean_ctor_set(x_99, 12, x_61);
lean_ctor_set(x_99, 13, x_88);
lean_ctor_set(x_99, 14, x_45);
lean_ctor_set(x_99, 15, x_76);
lean_ctor_set(x_99, 16, x_85);
lean_ctor_set(x_99, 17, x_60);
lean_ctor_set(x_99, 18, x_62);
lean_ctor_set(x_99, 19, x_58);
lean_ctor_set_uint8(x_99, sizeof(void*)*20, x_96);
lean_ctor_set_uint8(x_99, sizeof(void*)*20 + 1, x_71);
x_100 = lp_padctl_assembleButtons(x_48, x_75, x_80);
lean_dec(x_80);
lean_dec(x_75);
if (x_89 == 0)
{
x_6 = x_43;
x_7 = x_70;
x_8 = x_69;
x_9 = x_100;
x_10 = x_72;
x_11 = x_46;
x_12 = x_49;
x_13 = x_48;
x_14 = x_82;
x_15 = x_78;
x_16 = x_77;
x_17 = x_50;
x_18 = x_79;
x_19 = x_81;
x_20 = x_99;
x_21 = x_53;
x_22 = x_54;
x_23 = x_55;
x_24 = x_56;
x_25 = x_83;
x_26 = x_84;
x_27 = x_59;
x_28 = x_86;
x_29 = x_91;
x_30 = x_92;
x_31 = x_64;
x_32 = x_93;
x_33 = x_94;
x_34 = x_65;
x_35 = x_95;
x_36 = x_67;
x_37 = x_97;
x_38 = x_74;
goto block_42;
}
else
{
lean_object* x_101; 
lean_dec(x_82);
lean_dec(x_74);
x_101 = lean_obj_once(&lp_padctl_instReprAuxEvent_repr___closed__11, &lp_padctl_instReprAuxEvent_repr___closed__11_once, _init_lp_padctl_instReprAuxEvent_repr___closed__11);
x_6 = x_43;
x_7 = x_70;
x_8 = x_69;
x_9 = x_100;
x_10 = x_72;
x_11 = x_46;
x_12 = x_49;
x_13 = x_48;
x_14 = x_101;
x_15 = x_78;
x_16 = x_77;
x_17 = x_50;
x_18 = x_79;
x_19 = x_81;
x_20 = x_99;
x_21 = x_53;
x_22 = x_54;
x_23 = x_55;
x_24 = x_56;
x_25 = x_83;
x_26 = x_84;
x_27 = x_59;
x_28 = x_86;
x_29 = x_91;
x_30 = x_92;
x_31 = x_64;
x_32 = x_93;
x_33 = x_94;
x_34 = x_65;
x_35 = x_95;
x_36 = x_67;
x_37 = x_97;
x_38 = x_101;
goto block_42;
}
}
block_161:
{
if (x_145 == 0)
{
if (x_105 == 0)
{
x_43 = x_103;
x_44 = x_104;
x_45 = x_106;
x_46 = x_107;
x_47 = x_159;
x_48 = x_109;
x_49 = x_110;
x_50 = x_111;
x_51 = x_112;
x_52 = x_113;
x_53 = x_114;
x_54 = x_115;
x_55 = x_116;
x_56 = x_117;
x_57 = x_118;
x_58 = x_119;
x_59 = x_120;
x_60 = x_121;
x_61 = x_122;
x_62 = x_123;
x_63 = x_124;
x_64 = x_125;
x_65 = x_126;
x_66 = x_127;
x_67 = x_128;
x_68 = x_129;
x_69 = x_130;
x_70 = x_131;
x_71 = x_133;
x_72 = x_134;
x_73 = x_135;
x_74 = x_136;
x_75 = x_137;
x_76 = x_138;
x_77 = x_139;
x_78 = x_140;
x_79 = x_141;
x_80 = x_142;
x_81 = x_143;
x_82 = x_144;
x_83 = x_145;
x_84 = x_146;
x_85 = x_147;
x_86 = x_148;
x_87 = x_132;
x_88 = x_149;
x_89 = x_150;
x_90 = x_151;
x_91 = x_152;
x_92 = x_153;
x_93 = x_154;
x_94 = x_155;
x_95 = x_156;
x_96 = x_157;
x_97 = x_158;
x_98 = x_108;
goto block_102;
}
else
{
lean_object* x_160; 
lean_dec(x_132);
lean_dec(x_108);
x_160 = lean_obj_once(&lp_padctl_instReprAuxEvent_repr___closed__11, &lp_padctl_instReprAuxEvent_repr___closed__11_once, _init_lp_padctl_instReprAuxEvent_repr___closed__11);
x_43 = x_103;
x_44 = x_104;
x_45 = x_106;
x_46 = x_107;
x_47 = x_159;
x_48 = x_109;
x_49 = x_110;
x_50 = x_111;
x_51 = x_112;
x_52 = x_113;
x_53 = x_114;
x_54 = x_115;
x_55 = x_116;
x_56 = x_117;
x_57 = x_118;
x_58 = x_119;
x_59 = x_120;
x_60 = x_121;
x_61 = x_122;
x_62 = x_123;
x_63 = x_124;
x_64 = x_125;
x_65 = x_126;
x_66 = x_127;
x_67 = x_128;
x_68 = x_129;
x_69 = x_130;
x_70 = x_131;
x_71 = x_133;
x_72 = x_134;
x_73 = x_135;
x_74 = x_136;
x_75 = x_137;
x_76 = x_138;
x_77 = x_139;
x_78 = x_140;
x_79 = x_141;
x_80 = x_142;
x_81 = x_143;
x_82 = x_144;
x_83 = x_145;
x_84 = x_146;
x_85 = x_147;
x_86 = x_148;
x_87 = x_160;
x_88 = x_149;
x_89 = x_150;
x_90 = x_151;
x_91 = x_152;
x_92 = x_153;
x_93 = x_154;
x_94 = x_155;
x_95 = x_156;
x_96 = x_157;
x_97 = x_158;
x_98 = x_160;
goto block_102;
}
}
else
{
x_43 = x_103;
x_44 = x_104;
x_45 = x_106;
x_46 = x_107;
x_47 = x_159;
x_48 = x_109;
x_49 = x_110;
x_50 = x_111;
x_51 = x_112;
x_52 = x_113;
x_53 = x_114;
x_54 = x_115;
x_55 = x_116;
x_56 = x_117;
x_57 = x_118;
x_58 = x_119;
x_59 = x_120;
x_60 = x_121;
x_61 = x_122;
x_62 = x_123;
x_63 = x_124;
x_64 = x_125;
x_65 = x_126;
x_66 = x_127;
x_67 = x_128;
x_68 = x_129;
x_69 = x_130;
x_70 = x_131;
x_71 = x_133;
x_72 = x_134;
x_73 = x_135;
x_74 = x_136;
x_75 = x_137;
x_76 = x_138;
x_77 = x_139;
x_78 = x_140;
x_79 = x_141;
x_80 = x_142;
x_81 = x_143;
x_82 = x_144;
x_83 = x_145;
x_84 = x_146;
x_85 = x_147;
x_86 = x_148;
x_87 = x_132;
x_88 = x_149;
x_89 = x_150;
x_90 = x_151;
x_91 = x_152;
x_92 = x_153;
x_93 = x_154;
x_94 = x_155;
x_95 = x_156;
x_96 = x_157;
x_97 = x_158;
x_98 = x_108;
goto block_102;
}
}
block_226:
{
lean_object* x_222; lean_object* x_223; lean_object* x_224; 
x_222 = l_List_appendTR___redArg(x_202, x_172);
x_223 = l_List_appendTR___redArg(x_222, x_220);
x_224 = lp_padctl_assembleButtons(x_200, x_198, x_204);
lean_dec(x_200);
if (x_170 == 0)
{
x_103 = x_162;
x_104 = x_193;
x_105 = x_163;
x_106 = x_164;
x_107 = x_165;
x_108 = x_166;
x_109 = x_167;
x_110 = x_168;
x_111 = x_169;
x_112 = x_171;
x_113 = x_173;
x_114 = x_174;
x_115 = x_175;
x_116 = x_176;
x_117 = x_177;
x_118 = x_178;
x_119 = x_180;
x_120 = x_181;
x_121 = x_182;
x_122 = x_183;
x_123 = x_184;
x_124 = x_185;
x_125 = x_186;
x_126 = x_187;
x_127 = x_188;
x_128 = x_223;
x_129 = x_189;
x_130 = x_190;
x_131 = x_191;
x_132 = x_192;
x_133 = x_194;
x_134 = x_195;
x_135 = x_196;
x_136 = x_197;
x_137 = x_198;
x_138 = x_199;
x_139 = x_201;
x_140 = x_219;
x_141 = x_203;
x_142 = x_204;
x_143 = x_205;
x_144 = x_206;
x_145 = x_207;
x_146 = x_208;
x_147 = x_209;
x_148 = x_210;
x_149 = x_211;
x_150 = x_212;
x_151 = x_224;
x_152 = x_213;
x_153 = x_214;
x_154 = x_221;
x_155 = x_215;
x_156 = x_216;
x_157 = x_217;
x_158 = x_218;
x_159 = x_179;
goto block_161;
}
else
{
lean_object* x_225; 
lean_dec(x_193);
lean_dec(x_179);
x_225 = lean_obj_once(&lp_padctl_instReprAuxEvent_repr___closed__11, &lp_padctl_instReprAuxEvent_repr___closed__11_once, _init_lp_padctl_instReprAuxEvent_repr___closed__11);
x_103 = x_162;
x_104 = x_225;
x_105 = x_163;
x_106 = x_164;
x_107 = x_165;
x_108 = x_166;
x_109 = x_167;
x_110 = x_168;
x_111 = x_169;
x_112 = x_171;
x_113 = x_173;
x_114 = x_174;
x_115 = x_175;
x_116 = x_176;
x_117 = x_177;
x_118 = x_178;
x_119 = x_180;
x_120 = x_181;
x_121 = x_182;
x_122 = x_183;
x_123 = x_184;
x_124 = x_185;
x_125 = x_186;
x_126 = x_187;
x_127 = x_188;
x_128 = x_223;
x_129 = x_189;
x_130 = x_190;
x_131 = x_191;
x_132 = x_192;
x_133 = x_194;
x_134 = x_195;
x_135 = x_196;
x_136 = x_197;
x_137 = x_198;
x_138 = x_199;
x_139 = x_201;
x_140 = x_219;
x_141 = x_203;
x_142 = x_204;
x_143 = x_205;
x_144 = x_206;
x_145 = x_207;
x_146 = x_208;
x_147 = x_209;
x_148 = x_210;
x_149 = x_211;
x_150 = x_212;
x_151 = x_224;
x_152 = x_213;
x_153 = x_214;
x_154 = x_221;
x_155 = x_215;
x_156 = x_216;
x_157 = x_217;
x_158 = x_218;
x_159 = x_225;
goto block_161;
}
}
block_292:
{
lean_object* x_287; 
x_287 = lp_padctl___private_Padctl_Mapper_0__triggerMacros(x_265, x_232, x_273, x_247);
lean_dec(x_247);
if (x_269 == 0)
{
lean_object* x_288; 
x_288 = lean_box(0);
x_162 = x_227;
x_163 = x_228;
x_164 = x_229;
x_165 = x_230;
x_166 = x_231;
x_167 = x_232;
x_168 = x_233;
x_169 = x_234;
x_170 = x_235;
x_171 = x_236;
x_172 = x_237;
x_173 = x_238;
x_174 = x_239;
x_175 = x_240;
x_176 = x_241;
x_177 = x_286;
x_178 = x_243;
x_179 = x_242;
x_180 = x_245;
x_181 = x_244;
x_182 = x_246;
x_183 = x_248;
x_184 = x_249;
x_185 = x_250;
x_186 = x_251;
x_187 = x_252;
x_188 = x_253;
x_189 = x_254;
x_190 = x_255;
x_191 = x_256;
x_192 = x_257;
x_193 = x_258;
x_194 = x_259;
x_195 = x_260;
x_196 = x_261;
x_197 = x_262;
x_198 = x_263;
x_199 = x_264;
x_200 = x_265;
x_201 = x_266;
x_202 = x_267;
x_203 = x_268;
x_204 = x_285;
x_205 = x_270;
x_206 = x_271;
x_207 = x_272;
x_208 = x_274;
x_209 = x_275;
x_210 = x_276;
x_211 = x_277;
x_212 = x_278;
x_213 = x_279;
x_214 = x_280;
x_215 = x_281;
x_216 = x_283;
x_217 = x_282;
x_218 = x_284;
x_219 = x_287;
x_220 = x_288;
x_221 = x_269;
goto block_226;
}
else
{
lean_object* x_289; lean_object* x_290; lean_object* x_291; 
x_289 = lp_padctl___private_Padctl_Mapper_0__cancelMacros(x_287);
x_290 = lean_ctor_get(x_289, 0);
lean_inc(x_290);
x_291 = lean_ctor_get(x_289, 1);
lean_inc(x_291);
lean_dec_ref(x_289);
x_162 = x_227;
x_163 = x_228;
x_164 = x_229;
x_165 = x_230;
x_166 = x_231;
x_167 = x_232;
x_168 = x_233;
x_169 = x_234;
x_170 = x_235;
x_171 = x_236;
x_172 = x_237;
x_173 = x_238;
x_174 = x_239;
x_175 = x_240;
x_176 = x_241;
x_177 = x_286;
x_178 = x_243;
x_179 = x_242;
x_180 = x_245;
x_181 = x_244;
x_182 = x_246;
x_183 = x_248;
x_184 = x_249;
x_185 = x_250;
x_186 = x_251;
x_187 = x_252;
x_188 = x_253;
x_189 = x_254;
x_190 = x_255;
x_191 = x_256;
x_192 = x_257;
x_193 = x_258;
x_194 = x_259;
x_195 = x_260;
x_196 = x_261;
x_197 = x_262;
x_198 = x_263;
x_199 = x_264;
x_200 = x_265;
x_201 = x_266;
x_202 = x_267;
x_203 = x_268;
x_204 = x_285;
x_205 = x_270;
x_206 = x_271;
x_207 = x_272;
x_208 = x_274;
x_209 = x_275;
x_210 = x_276;
x_211 = x_277;
x_212 = x_278;
x_213 = x_279;
x_214 = x_280;
x_215 = x_281;
x_216 = x_283;
x_217 = x_282;
x_218 = x_284;
x_219 = x_290;
x_220 = x_291;
x_221 = x_269;
goto block_226;
}
}
block_373:
{
lean_object* x_351; lean_object* x_352; lean_object* x_353; lean_object* x_354; lean_object* x_355; lean_object* x_356; lean_object* x_357; lean_object* x_358; lean_object* x_359; lean_object* x_360; lean_object* x_361; lean_object* x_362; lean_object* x_363; lean_object* x_364; uint8_t x_365; lean_object* x_366; lean_object* x_367; lean_object* x_368; 
x_351 = lean_ctor_get(x_309, 0);
lean_inc(x_351);
x_352 = lean_ctor_get(x_309, 1);
lean_inc(x_352);
x_353 = lean_ctor_get(x_309, 2);
lean_inc(x_353);
x_354 = lean_ctor_get(x_309, 3);
lean_inc(x_354);
x_355 = lean_ctor_get(x_309, 4);
lean_inc(x_355);
x_356 = lean_ctor_get(x_309, 5);
lean_inc(x_356);
lean_dec_ref(x_309);
x_357 = lp_padctl_mergeRemaps(x_308, x_350);
lean_inc(x_357);
x_358 = lp_padctl_applyRemaps(x_335, x_352, x_357);
x_359 = lean_ctor_get(x_358, 0);
lean_inc(x_359);
x_360 = lean_ctor_get(x_358, 1);
lean_inc(x_360);
x_361 = lean_ctor_get(x_358, 2);
lean_inc(x_361);
lean_dec_ref(x_358);
x_362 = lean_ctor_get(x_348, 0);
lean_inc(x_362);
x_363 = lean_ctor_get(x_348, 1);
lean_inc(x_363);
x_364 = lean_ctor_get(x_348, 2);
lean_inc(x_364);
x_365 = lean_ctor_get_uint8(x_348, sizeof(void*)*4);
x_366 = lean_ctor_get(x_348, 3);
lean_inc(x_366);
lean_dec_ref(x_348);
x_367 = lean_nat_lor(x_359, x_366);
lean_dec(x_366);
lean_dec(x_359);
x_368 = lean_nat_lor(x_367, x_316);
lean_dec(x_316);
lean_dec(x_367);
if (lean_obj_tag(x_298) == 0)
{
x_227 = x_300;
x_228 = x_301;
x_229 = x_302;
x_230 = x_303;
x_231 = x_304;
x_232 = x_352;
x_233 = x_305;
x_234 = x_306;
x_235 = x_307;
x_236 = x_363;
x_237 = x_361;
x_238 = x_310;
x_239 = x_311;
x_240 = x_312;
x_241 = x_313;
x_242 = x_315;
x_243 = x_314;
x_244 = x_318;
x_245 = x_317;
x_246 = x_319;
x_247 = x_355;
x_248 = x_320;
x_249 = x_321;
x_250 = x_322;
x_251 = x_323;
x_252 = x_324;
x_253 = x_325;
x_254 = x_362;
x_255 = x_326;
x_256 = x_327;
x_257 = x_328;
x_258 = x_329;
x_259 = x_330;
x_260 = x_331;
x_261 = x_332;
x_262 = x_333;
x_263 = x_368;
x_264 = x_334;
x_265 = x_335;
x_266 = x_353;
x_267 = x_364;
x_268 = x_336;
x_269 = x_337;
x_270 = x_354;
x_271 = x_338;
x_272 = x_339;
x_273 = x_357;
x_274 = x_340;
x_275 = x_341;
x_276 = x_342;
x_277 = x_343;
x_278 = x_365;
x_279 = x_344;
x_280 = x_345;
x_281 = x_351;
x_282 = x_346;
x_283 = x_347;
x_284 = x_349;
x_285 = x_360;
x_286 = x_356;
goto block_292;
}
else
{
lean_object* x_369; lean_object* x_370; lean_object* x_371; lean_object* x_372; 
x_369 = lean_ctor_get(x_298, 0);
lean_inc(x_369);
lean_dec_ref(x_298);
x_370 = lean_unsigned_to_nat(1u);
x_371 = lean_nat_shiftl(x_370, x_369);
lean_dec(x_369);
x_372 = lean_nat_lor(x_360, x_371);
lean_dec(x_371);
lean_dec(x_360);
x_227 = x_300;
x_228 = x_301;
x_229 = x_302;
x_230 = x_303;
x_231 = x_304;
x_232 = x_352;
x_233 = x_305;
x_234 = x_306;
x_235 = x_307;
x_236 = x_363;
x_237 = x_361;
x_238 = x_310;
x_239 = x_311;
x_240 = x_312;
x_241 = x_313;
x_242 = x_315;
x_243 = x_314;
x_244 = x_318;
x_245 = x_317;
x_246 = x_319;
x_247 = x_355;
x_248 = x_320;
x_249 = x_321;
x_250 = x_322;
x_251 = x_323;
x_252 = x_324;
x_253 = x_325;
x_254 = x_362;
x_255 = x_326;
x_256 = x_327;
x_257 = x_328;
x_258 = x_329;
x_259 = x_330;
x_260 = x_331;
x_261 = x_332;
x_262 = x_333;
x_263 = x_368;
x_264 = x_334;
x_265 = x_335;
x_266 = x_353;
x_267 = x_364;
x_268 = x_336;
x_269 = x_337;
x_270 = x_354;
x_271 = x_338;
x_272 = x_339;
x_273 = x_357;
x_274 = x_340;
x_275 = x_341;
x_276 = x_342;
x_277 = x_343;
x_278 = x_365;
x_279 = x_344;
x_280 = x_345;
x_281 = x_351;
x_282 = x_346;
x_283 = x_347;
x_284 = x_349;
x_285 = x_372;
x_286 = x_356;
goto block_292;
}
}
block_432:
{
uint8_t x_426; uint8_t x_427; 
x_426 = lp_padctl_checkStickSuppressGamepad(x_400);
x_427 = lp_padctl_checkStickSuppressGamepad(x_386);
if (lean_obj_tag(x_416) == 0)
{
lean_object* x_428; 
lean_dec(x_387);
x_428 = lean_box(0);
x_300 = x_374;
x_301 = x_427;
x_302 = x_375;
x_303 = x_376;
x_304 = x_377;
x_305 = x_378;
x_306 = x_379;
x_307 = x_426;
x_308 = x_380;
x_309 = x_381;
x_310 = x_382;
x_311 = x_383;
x_312 = x_384;
x_313 = x_385;
x_314 = x_389;
x_315 = x_388;
x_316 = x_390;
x_317 = x_392;
x_318 = x_391;
x_319 = x_393;
x_320 = x_394;
x_321 = x_395;
x_322 = x_396;
x_323 = x_397;
x_324 = x_398;
x_325 = x_399;
x_326 = x_401;
x_327 = x_402;
x_328 = x_403;
x_329 = x_404;
x_330 = x_405;
x_331 = x_406;
x_332 = x_407;
x_333 = x_408;
x_334 = x_409;
x_335 = x_410;
x_336 = x_411;
x_337 = x_412;
x_338 = x_413;
x_339 = x_425;
x_340 = x_414;
x_341 = x_415;
x_342 = x_417;
x_343 = x_418;
x_344 = x_419;
x_345 = x_420;
x_346 = x_421;
x_347 = x_422;
x_348 = x_423;
x_349 = x_424;
x_350 = x_428;
goto block_373;
}
else
{
lean_object* x_429; lean_object* x_430; lean_object* x_431; 
x_429 = lean_ctor_get(x_416, 0);
lean_inc(x_429);
lean_dec_ref(x_416);
x_430 = lean_box(0);
x_431 = l_List_getD___redArg(x_387, x_429, x_430);
lean_dec(x_387);
x_300 = x_374;
x_301 = x_427;
x_302 = x_375;
x_303 = x_376;
x_304 = x_377;
x_305 = x_378;
x_306 = x_379;
x_307 = x_426;
x_308 = x_380;
x_309 = x_381;
x_310 = x_382;
x_311 = x_383;
x_312 = x_384;
x_313 = x_385;
x_314 = x_389;
x_315 = x_388;
x_316 = x_390;
x_317 = x_392;
x_318 = x_391;
x_319 = x_393;
x_320 = x_394;
x_321 = x_395;
x_322 = x_396;
x_323 = x_397;
x_324 = x_398;
x_325 = x_399;
x_326 = x_401;
x_327 = x_402;
x_328 = x_403;
x_329 = x_404;
x_330 = x_405;
x_331 = x_406;
x_332 = x_407;
x_333 = x_408;
x_334 = x_409;
x_335 = x_410;
x_336 = x_411;
x_337 = x_412;
x_338 = x_413;
x_339 = x_425;
x_340 = x_414;
x_341 = x_415;
x_342 = x_417;
x_343 = x_418;
x_344 = x_419;
x_345 = x_420;
x_346 = x_421;
x_347 = x_422;
x_348 = x_423;
x_349 = x_424;
x_350 = x_431;
goto block_373;
}
}
block_494:
{
lean_object* x_462; lean_object* x_463; lean_object* x_464; lean_object* x_465; lean_object* x_466; lean_object* x_467; lean_object* x_468; lean_object* x_469; lean_object* x_470; lean_object* x_471; lean_object* x_472; lean_object* x_473; lean_object* x_474; lean_object* x_475; lean_object* x_476; lean_object* x_477; lean_object* x_478; lean_object* x_479; uint8_t x_480; uint8_t x_481; lean_object* x_482; lean_object* x_483; uint8_t x_484; uint8_t x_485; lean_object* x_486; uint8_t x_487; uint8_t x_488; uint8_t x_489; lean_object* x_490; uint8_t x_491; 
x_462 = lean_ctor_get(x_2, 0);
lean_inc(x_462);
x_463 = lean_ctor_get(x_2, 1);
lean_inc(x_463);
x_464 = lean_ctor_get(x_2, 2);
lean_inc(x_464);
x_465 = lean_ctor_get(x_2, 3);
lean_inc(x_465);
x_466 = lean_ctor_get(x_2, 4);
lean_inc(x_466);
x_467 = lean_ctor_get(x_2, 5);
lean_inc(x_467);
x_468 = lean_ctor_get(x_2, 7);
lean_inc(x_468);
x_469 = lean_ctor_get(x_2, 8);
lean_inc(x_469);
x_470 = lean_ctor_get(x_2, 9);
lean_inc(x_470);
x_471 = lean_ctor_get(x_2, 10);
lean_inc(x_471);
x_472 = lean_ctor_get(x_2, 11);
lean_inc(x_472);
x_473 = lean_ctor_get(x_2, 12);
lean_inc(x_473);
x_474 = lean_ctor_get(x_2, 13);
lean_inc(x_474);
x_475 = lean_ctor_get(x_2, 14);
lean_inc(x_475);
x_476 = lean_ctor_get(x_2, 15);
lean_inc(x_476);
x_477 = lean_ctor_get(x_2, 16);
lean_inc(x_477);
x_478 = lean_ctor_get(x_2, 17);
lean_inc(x_478);
x_479 = lean_ctor_get(x_2, 18);
lean_inc(x_479);
x_480 = lean_ctor_get_uint8(x_2, sizeof(void*)*20);
x_481 = lean_ctor_get_uint8(x_2, sizeof(void*)*20 + 1);
x_482 = lean_ctor_get(x_2, 19);
lean_inc(x_482);
lean_dec_ref(x_2);
lean_inc(x_451);
x_483 = lp_padctl_resolveConfig(x_4, x_451, x_455);
lean_dec(x_455);
x_484 = lean_ctor_get_uint8(x_483, sizeof(void*)*5);
x_485 = lean_ctor_get_uint8(x_483, sizeof(void*)*5 + 1);
x_486 = lean_ctor_get(x_483, 3);
lean_inc(x_486);
x_487 = lean_ctor_get_uint8(x_483, sizeof(void*)*5 + 2);
x_488 = lean_ctor_get_uint8(x_483, sizeof(void*)*5 + 3);
x_489 = lean_ctor_get_uint8(x_483, sizeof(void*)*5 + 4);
lean_dec_ref(x_483);
x_490 = lp_padctl_processDpad(x_458, x_447, x_468, x_469, x_484, x_485);
x_491 = lp_padctl_checkGyroActivate(x_440, x_486);
lean_dec(x_486);
if (x_491 == 0)
{
x_374 = x_466;
x_375 = x_433;
x_376 = x_465;
x_377 = x_438;
x_378 = x_463;
x_379 = x_482;
x_380 = x_441;
x_381 = x_442;
x_382 = x_443;
x_383 = x_479;
x_384 = x_474;
x_385 = x_467;
x_386 = x_489;
x_387 = x_444;
x_388 = x_446;
x_389 = x_445;
x_390 = x_448;
x_391 = x_481;
x_392 = x_450;
x_393 = x_452;
x_394 = x_454;
x_395 = x_456;
x_396 = x_457;
x_397 = x_480;
x_398 = x_470;
x_399 = x_460;
x_400 = x_488;
x_401 = x_478;
x_402 = x_464;
x_403 = x_434;
x_404 = x_435;
x_405 = x_436;
x_406 = x_491;
x_407 = x_437;
x_408 = x_469;
x_409 = x_439;
x_410 = x_440;
x_411 = x_476;
x_412 = x_461;
x_413 = x_468;
x_414 = x_477;
x_415 = x_449;
x_416 = x_451;
x_417 = x_473;
x_418 = x_453;
x_419 = x_472;
x_420 = x_462;
x_421 = x_459;
x_422 = x_475;
x_423 = x_490;
x_424 = x_471;
x_425 = x_491;
goto block_432;
}
else
{
uint8_t x_492; uint8_t x_493; 
x_492 = 1;
x_493 = lp_padctl_instDecidableEqGyroMode(x_487, x_492);
x_374 = x_466;
x_375 = x_433;
x_376 = x_465;
x_377 = x_438;
x_378 = x_463;
x_379 = x_482;
x_380 = x_441;
x_381 = x_442;
x_382 = x_443;
x_383 = x_479;
x_384 = x_474;
x_385 = x_467;
x_386 = x_489;
x_387 = x_444;
x_388 = x_446;
x_389 = x_445;
x_390 = x_448;
x_391 = x_481;
x_392 = x_450;
x_393 = x_452;
x_394 = x_454;
x_395 = x_456;
x_396 = x_457;
x_397 = x_480;
x_398 = x_470;
x_399 = x_460;
x_400 = x_488;
x_401 = x_478;
x_402 = x_464;
x_403 = x_434;
x_404 = x_435;
x_405 = x_436;
x_406 = x_491;
x_407 = x_437;
x_408 = x_469;
x_409 = x_439;
x_410 = x_440;
x_411 = x_476;
x_412 = x_461;
x_413 = x_468;
x_414 = x_477;
x_415 = x_449;
x_416 = x_451;
x_417 = x_473;
x_418 = x_453;
x_419 = x_472;
x_420 = x_462;
x_421 = x_459;
x_422 = x_475;
x_423 = x_490;
x_424 = x_471;
x_425 = x_493;
goto block_432;
}
}
block_532:
{
lean_object* x_496; lean_object* x_497; lean_object* x_498; lean_object* x_499; lean_object* x_500; lean_object* x_501; lean_object* x_502; lean_object* x_503; lean_object* x_504; lean_object* x_505; lean_object* x_506; lean_object* x_507; lean_object* x_508; lean_object* x_509; lean_object* x_510; lean_object* x_511; lean_object* x_512; lean_object* x_513; lean_object* x_514; lean_object* x_515; uint8_t x_516; uint8_t x_517; lean_object* x_518; lean_object* x_519; lean_object* x_520; lean_object* x_521; lean_object* x_522; lean_object* x_523; lean_object* x_524; lean_object* x_525; lean_object* x_526; lean_object* x_527; lean_object* x_528; uint8_t x_529; 
lean_inc_ref(x_2);
x_496 = lp_padctl_applyDelta(x_2, x_3);
x_497 = lean_ctor_get(x_496, 0);
lean_inc(x_497);
x_498 = lean_ctor_get(x_496, 1);
lean_inc(x_498);
x_499 = lean_ctor_get(x_496, 2);
lean_inc(x_499);
x_500 = lean_ctor_get(x_496, 3);
lean_inc(x_500);
x_501 = lean_ctor_get(x_496, 4);
lean_inc(x_501);
x_502 = lean_ctor_get(x_496, 5);
lean_inc(x_502);
x_503 = lean_ctor_get(x_496, 6);
lean_inc(x_503);
x_504 = lean_ctor_get(x_496, 7);
lean_inc(x_504);
x_505 = lean_ctor_get(x_496, 8);
lean_inc(x_505);
x_506 = lean_ctor_get(x_496, 9);
lean_inc(x_506);
x_507 = lean_ctor_get(x_496, 10);
lean_inc(x_507);
x_508 = lean_ctor_get(x_496, 11);
lean_inc(x_508);
x_509 = lean_ctor_get(x_496, 12);
lean_inc(x_509);
x_510 = lean_ctor_get(x_496, 13);
lean_inc(x_510);
x_511 = lean_ctor_get(x_496, 14);
lean_inc(x_511);
x_512 = lean_ctor_get(x_496, 15);
lean_inc(x_512);
x_513 = lean_ctor_get(x_496, 16);
lean_inc(x_513);
x_514 = lean_ctor_get(x_496, 17);
lean_inc(x_514);
x_515 = lean_ctor_get(x_496, 18);
lean_inc(x_515);
x_516 = lean_ctor_get_uint8(x_496, sizeof(void*)*20);
x_517 = lean_ctor_get_uint8(x_496, sizeof(void*)*20 + 1);
x_518 = lean_ctor_get(x_496, 19);
lean_inc(x_518);
lean_dec_ref(x_496);
x_519 = lean_ctor_get(x_4, 0);
x_520 = lean_ctor_get(x_4, 1);
x_521 = lean_ctor_get(x_4, 2);
x_522 = lean_ctor_get(x_4, 4);
x_523 = lean_box(0);
if (lean_is_scalar(x_299)) {
 x_524 = lean_alloc_ctor(0, 6, 0);
} else {
 x_524 = x_299;
}
lean_ctor_set(x_524, 0, x_293);
lean_ctor_set(x_524, 1, x_294);
lean_ctor_set(x_524, 2, x_295);
lean_ctor_set(x_524, 3, x_296);
lean_ctor_set(x_524, 4, x_297);
lean_ctor_set(x_524, 5, x_523);
lean_inc_ref(x_524);
x_525 = lp_padctl_getActiveLayer(x_524, x_519);
lean_inc(x_503);
x_526 = lp_padctl_processLayerTriggers(x_524, x_503, x_519);
x_527 = lp_padctl_advanceTimer(x_526, x_5, x_519);
lean_inc_ref(x_527);
x_528 = lp_padctl_getActiveLayer(x_527, x_519);
x_529 = lp_padctl_Option_instBEq_beq___at___00onMacroTimerExpired_spec__0(x_525, x_528);
lean_dec(x_525);
if (x_529 == 0)
{
uint8_t x_530; 
x_530 = 1;
lean_inc(x_522);
lean_inc(x_521);
lean_inc(x_520);
x_433 = x_511;
x_434 = x_499;
x_435 = x_497;
x_436 = x_517;
x_437 = x_501;
x_438 = x_500;
x_439 = x_512;
x_440 = x_503;
x_441 = x_520;
x_442 = x_527;
x_443 = x_507;
x_444 = x_521;
x_445 = x_508;
x_446 = x_498;
x_447 = x_505;
x_448 = x_495;
x_449 = x_513;
x_450 = x_518;
x_451 = x_528;
x_452 = x_514;
x_453 = x_510;
x_454 = x_509;
x_455 = x_522;
x_456 = x_515;
x_457 = x_506;
x_458 = x_504;
x_459 = x_516;
x_460 = x_502;
x_461 = x_530;
goto block_494;
}
else
{
uint8_t x_531; 
x_531 = 0;
lean_inc(x_522);
lean_inc(x_521);
lean_inc(x_520);
x_433 = x_511;
x_434 = x_499;
x_435 = x_497;
x_436 = x_517;
x_437 = x_501;
x_438 = x_500;
x_439 = x_512;
x_440 = x_503;
x_441 = x_520;
x_442 = x_527;
x_443 = x_507;
x_444 = x_521;
x_445 = x_508;
x_446 = x_498;
x_447 = x_505;
x_448 = x_495;
x_449 = x_513;
x_450 = x_518;
x_451 = x_528;
x_452 = x_514;
x_453 = x_510;
x_454 = x_509;
x_455 = x_522;
x_456 = x_515;
x_457 = x_506;
x_458 = x_504;
x_459 = x_516;
x_460 = x_502;
x_461 = x_531;
goto block_494;
}
}
}
}
LEAN_EXPORT lean_object* lp_padctl_Mapper_apply___boxed(lean_object* x_1, lean_object* x_2, lean_object* x_3, lean_object* x_4, lean_object* x_5) {
_start:
{
lean_object* x_6; 
x_6 = lp_padctl_Mapper_apply(x_1, x_2, x_3, x_4, x_5);
lean_dec(x_5);
return x_6;
}
}
lean_object* initialize_Init(uint8_t builtin);
lean_object* initialize_padctl_Padctl_State(uint8_t builtin);
static bool _G_initialized = false;
LEAN_EXPORT lean_object* initialize_padctl_Padctl_Mapper(uint8_t builtin) {
lean_object * res;
if (_G_initialized) return lean_io_result_mk_ok(lean_box(0));
_G_initialized = true;
res = initialize_Init(builtin);
if (lean_io_result_is_error(res)) return res;
lean_dec_ref(res);
res = initialize_padctl_Padctl_State(builtin);
if (lean_io_result_is_error(res)) return res;
lean_dec_ref(res);
lp_padctl_KEY__UP = _init_lp_padctl_KEY__UP();
lean_mark_persistent(lp_padctl_KEY__UP);
lp_padctl_KEY__DOWN = _init_lp_padctl_KEY__DOWN();
lean_mark_persistent(lp_padctl_KEY__DOWN);
lp_padctl_KEY__LEFT = _init_lp_padctl_KEY__LEFT();
lean_mark_persistent(lp_padctl_KEY__LEFT);
lp_padctl_KEY__RIGHT = _init_lp_padctl_KEY__RIGHT();
lean_mark_persistent(lp_padctl_KEY__RIGHT);
lp_padctl___private_Padctl_Mapper_0__dpadButtonMask = _init_lp_padctl___private_Padctl_Mapper_0__dpadButtonMask();
lean_mark_persistent(lp_padctl___private_Padctl_Mapper_0__dpadButtonMask);
return lean_io_result_mk_ok(lean_box(0));
}
#ifdef __cplusplus
}
#endif
