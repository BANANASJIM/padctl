// Lean compiler output
// Module: Padctl.State
// Imports: public import Init public import Padctl.Types
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
uint8_t lean_nat_dec_eq(lean_object*, lean_object*);
uint8_t lean_int_dec_eq(lean_object*, lean_object*);
LEAN_EXPORT uint8_t lp_padctl_instDecidableEqGamepadState_decEq(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_instDecidableEqGamepadState_decEq___boxed(lean_object*, lean_object*);
LEAN_EXPORT uint8_t lp_padctl_instDecidableEqGamepadState(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_instDecidableEqGamepadState___boxed(lean_object*, lean_object*);
static const lean_string_object lp_padctl_instReprGamepadState_repr___redArg___closed__0_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 3, .m_capacity = 3, .m_length = 2, .m_data = "{ "};
static const lean_object* lp_padctl_instReprGamepadState_repr___redArg___closed__0 = (const lean_object*)&lp_padctl_instReprGamepadState_repr___redArg___closed__0_value;
static const lean_string_object lp_padctl_instReprGamepadState_repr___redArg___closed__1_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 3, .m_capacity = 3, .m_length = 2, .m_data = "ax"};
static const lean_object* lp_padctl_instReprGamepadState_repr___redArg___closed__1 = (const lean_object*)&lp_padctl_instReprGamepadState_repr___redArg___closed__1_value;
static const lean_ctor_object lp_padctl_instReprGamepadState_repr___redArg___closed__2_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*1 + 0, .m_other = 1, .m_tag = 3}, .m_objs = {((lean_object*)&lp_padctl_instReprGamepadState_repr___redArg___closed__1_value)}};
static const lean_object* lp_padctl_instReprGamepadState_repr___redArg___closed__2 = (const lean_object*)&lp_padctl_instReprGamepadState_repr___redArg___closed__2_value;
static const lean_ctor_object lp_padctl_instReprGamepadState_repr___redArg___closed__3_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*2 + 0, .m_other = 2, .m_tag = 5}, .m_objs = {((lean_object*)(((size_t)(0) << 1) | 1)),((lean_object*)&lp_padctl_instReprGamepadState_repr___redArg___closed__2_value)}};
static const lean_object* lp_padctl_instReprGamepadState_repr___redArg___closed__3 = (const lean_object*)&lp_padctl_instReprGamepadState_repr___redArg___closed__3_value;
static const lean_string_object lp_padctl_instReprGamepadState_repr___redArg___closed__4_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 5, .m_capacity = 5, .m_length = 4, .m_data = " := "};
static const lean_object* lp_padctl_instReprGamepadState_repr___redArg___closed__4 = (const lean_object*)&lp_padctl_instReprGamepadState_repr___redArg___closed__4_value;
static const lean_ctor_object lp_padctl_instReprGamepadState_repr___redArg___closed__5_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*1 + 0, .m_other = 1, .m_tag = 3}, .m_objs = {((lean_object*)&lp_padctl_instReprGamepadState_repr___redArg___closed__4_value)}};
static const lean_object* lp_padctl_instReprGamepadState_repr___redArg___closed__5 = (const lean_object*)&lp_padctl_instReprGamepadState_repr___redArg___closed__5_value;
static const lean_string_object lp_padctl_instReprGamepadState_repr___redArg___closed__6_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 14, .m_capacity = 14, .m_length = 13, .m_data = "touch0_active"};
static const lean_object* lp_padctl_instReprGamepadState_repr___redArg___closed__6 = (const lean_object*)&lp_padctl_instReprGamepadState_repr___redArg___closed__6_value;
static const lean_ctor_object lp_padctl_instReprGamepadState_repr___redArg___closed__7_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*1 + 0, .m_other = 1, .m_tag = 3}, .m_objs = {((lean_object*)&lp_padctl_instReprGamepadState_repr___redArg___closed__6_value)}};
static const lean_object* lp_padctl_instReprGamepadState_repr___redArg___closed__7 = (const lean_object*)&lp_padctl_instReprGamepadState_repr___redArg___closed__7_value;
lean_object* lean_nat_to_int(lean_object*);
static lean_once_cell_t lp_padctl_instReprGamepadState_repr___redArg___closed__8_once = LEAN_ONCE_CELL_INITIALIZER;
static lean_object* lp_padctl_instReprGamepadState_repr___redArg___closed__8;
static const lean_string_object lp_padctl_instReprGamepadState_repr___redArg___closed__9_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 14, .m_capacity = 14, .m_length = 13, .m_data = "touch1_active"};
static const lean_object* lp_padctl_instReprGamepadState_repr___redArg___closed__9 = (const lean_object*)&lp_padctl_instReprGamepadState_repr___redArg___closed__9_value;
static const lean_ctor_object lp_padctl_instReprGamepadState_repr___redArg___closed__10_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*1 + 0, .m_other = 1, .m_tag = 3}, .m_objs = {((lean_object*)&lp_padctl_instReprGamepadState_repr___redArg___closed__9_value)}};
static const lean_object* lp_padctl_instReprGamepadState_repr___redArg___closed__10 = (const lean_object*)&lp_padctl_instReprGamepadState_repr___redArg___closed__10_value;
static const lean_string_object lp_padctl_instReprGamepadState_repr___redArg___closed__11_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 14, .m_capacity = 14, .m_length = 13, .m_data = "battery_level"};
static const lean_object* lp_padctl_instReprGamepadState_repr___redArg___closed__11 = (const lean_object*)&lp_padctl_instReprGamepadState_repr___redArg___closed__11_value;
static const lean_ctor_object lp_padctl_instReprGamepadState_repr___redArg___closed__12_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*1 + 0, .m_other = 1, .m_tag = 3}, .m_objs = {((lean_object*)&lp_padctl_instReprGamepadState_repr___redArg___closed__11_value)}};
static const lean_object* lp_padctl_instReprGamepadState_repr___redArg___closed__12 = (const lean_object*)&lp_padctl_instReprGamepadState_repr___redArg___closed__12_value;
static const lean_string_object lp_padctl_instReprGamepadState_repr___redArg___closed__13_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 3, .m_capacity = 3, .m_length = 2, .m_data = " }"};
static const lean_object* lp_padctl_instReprGamepadState_repr___redArg___closed__13 = (const lean_object*)&lp_padctl_instReprGamepadState_repr___redArg___closed__13_value;
lean_object* lean_string_length(lean_object*);
static lean_once_cell_t lp_padctl_instReprGamepadState_repr___redArg___closed__14_once = LEAN_ONCE_CELL_INITIALIZER;
static lean_object* lp_padctl_instReprGamepadState_repr___redArg___closed__14;
static lean_once_cell_t lp_padctl_instReprGamepadState_repr___redArg___closed__15_once = LEAN_ONCE_CELL_INITIALIZER;
static lean_object* lp_padctl_instReprGamepadState_repr___redArg___closed__15;
static const lean_ctor_object lp_padctl_instReprGamepadState_repr___redArg___closed__16_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*1 + 0, .m_other = 1, .m_tag = 3}, .m_objs = {((lean_object*)&lp_padctl_instReprGamepadState_repr___redArg___closed__0_value)}};
static const lean_object* lp_padctl_instReprGamepadState_repr___redArg___closed__16 = (const lean_object*)&lp_padctl_instReprGamepadState_repr___redArg___closed__16_value;
static const lean_ctor_object lp_padctl_instReprGamepadState_repr___redArg___closed__17_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*1 + 0, .m_other = 1, .m_tag = 3}, .m_objs = {((lean_object*)&lp_padctl_instReprGamepadState_repr___redArg___closed__13_value)}};
static const lean_object* lp_padctl_instReprGamepadState_repr___redArg___closed__17 = (const lean_object*)&lp_padctl_instReprGamepadState_repr___redArg___closed__17_value;
static const lean_string_object lp_padctl_instReprGamepadState_repr___redArg___closed__18_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 9, .m_capacity = 9, .m_length = 8, .m_data = "touch1_y"};
static const lean_object* lp_padctl_instReprGamepadState_repr___redArg___closed__18 = (const lean_object*)&lp_padctl_instReprGamepadState_repr___redArg___closed__18_value;
static const lean_ctor_object lp_padctl_instReprGamepadState_repr___redArg___closed__19_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*1 + 0, .m_other = 1, .m_tag = 3}, .m_objs = {((lean_object*)&lp_padctl_instReprGamepadState_repr___redArg___closed__18_value)}};
static const lean_object* lp_padctl_instReprGamepadState_repr___redArg___closed__19 = (const lean_object*)&lp_padctl_instReprGamepadState_repr___redArg___closed__19_value;
static lean_once_cell_t lp_padctl_instReprGamepadState_repr___redArg___closed__20_once = LEAN_ONCE_CELL_INITIALIZER;
static lean_object* lp_padctl_instReprGamepadState_repr___redArg___closed__20;
static const lean_string_object lp_padctl_instReprGamepadState_repr___redArg___closed__21_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 9, .m_capacity = 9, .m_length = 8, .m_data = "touch1_x"};
static const lean_object* lp_padctl_instReprGamepadState_repr___redArg___closed__21 = (const lean_object*)&lp_padctl_instReprGamepadState_repr___redArg___closed__21_value;
static const lean_ctor_object lp_padctl_instReprGamepadState_repr___redArg___closed__22_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*1 + 0, .m_other = 1, .m_tag = 3}, .m_objs = {((lean_object*)&lp_padctl_instReprGamepadState_repr___redArg___closed__21_value)}};
static const lean_object* lp_padctl_instReprGamepadState_repr___redArg___closed__22 = (const lean_object*)&lp_padctl_instReprGamepadState_repr___redArg___closed__22_value;
static const lean_string_object lp_padctl_instReprGamepadState_repr___redArg___closed__23_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 9, .m_capacity = 9, .m_length = 8, .m_data = "touch0_y"};
static const lean_object* lp_padctl_instReprGamepadState_repr___redArg___closed__23 = (const lean_object*)&lp_padctl_instReprGamepadState_repr___redArg___closed__23_value;
static const lean_ctor_object lp_padctl_instReprGamepadState_repr___redArg___closed__24_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*1 + 0, .m_other = 1, .m_tag = 3}, .m_objs = {((lean_object*)&lp_padctl_instReprGamepadState_repr___redArg___closed__23_value)}};
static const lean_object* lp_padctl_instReprGamepadState_repr___redArg___closed__24 = (const lean_object*)&lp_padctl_instReprGamepadState_repr___redArg___closed__24_value;
static const lean_string_object lp_padctl_instReprGamepadState_repr___redArg___closed__25_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 9, .m_capacity = 9, .m_length = 8, .m_data = "touch0_x"};
static const lean_object* lp_padctl_instReprGamepadState_repr___redArg___closed__25 = (const lean_object*)&lp_padctl_instReprGamepadState_repr___redArg___closed__25_value;
static const lean_ctor_object lp_padctl_instReprGamepadState_repr___redArg___closed__26_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*1 + 0, .m_other = 1, .m_tag = 3}, .m_objs = {((lean_object*)&lp_padctl_instReprGamepadState_repr___redArg___closed__25_value)}};
static const lean_object* lp_padctl_instReprGamepadState_repr___redArg___closed__26 = (const lean_object*)&lp_padctl_instReprGamepadState_repr___redArg___closed__26_value;
static lean_once_cell_t lp_padctl_instReprGamepadState_repr___redArg___closed__27_once = LEAN_ONCE_CELL_INITIALIZER;
static lean_object* lp_padctl_instReprGamepadState_repr___redArg___closed__27;
static const lean_string_object lp_padctl_instReprGamepadState_repr___redArg___closed__28_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 8, .m_capacity = 8, .m_length = 7, .m_data = "accel_z"};
static const lean_object* lp_padctl_instReprGamepadState_repr___redArg___closed__28 = (const lean_object*)&lp_padctl_instReprGamepadState_repr___redArg___closed__28_value;
static const lean_ctor_object lp_padctl_instReprGamepadState_repr___redArg___closed__29_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*1 + 0, .m_other = 1, .m_tag = 3}, .m_objs = {((lean_object*)&lp_padctl_instReprGamepadState_repr___redArg___closed__28_value)}};
static const lean_object* lp_padctl_instReprGamepadState_repr___redArg___closed__29 = (const lean_object*)&lp_padctl_instReprGamepadState_repr___redArg___closed__29_value;
static const lean_string_object lp_padctl_instReprGamepadState_repr___redArg___closed__30_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 8, .m_capacity = 8, .m_length = 7, .m_data = "accel_y"};
static const lean_object* lp_padctl_instReprGamepadState_repr___redArg___closed__30 = (const lean_object*)&lp_padctl_instReprGamepadState_repr___redArg___closed__30_value;
static const lean_ctor_object lp_padctl_instReprGamepadState_repr___redArg___closed__31_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*1 + 0, .m_other = 1, .m_tag = 3}, .m_objs = {((lean_object*)&lp_padctl_instReprGamepadState_repr___redArg___closed__30_value)}};
static const lean_object* lp_padctl_instReprGamepadState_repr___redArg___closed__31 = (const lean_object*)&lp_padctl_instReprGamepadState_repr___redArg___closed__31_value;
static const lean_string_object lp_padctl_instReprGamepadState_repr___redArg___closed__32_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 8, .m_capacity = 8, .m_length = 7, .m_data = "accel_x"};
static const lean_object* lp_padctl_instReprGamepadState_repr___redArg___closed__32 = (const lean_object*)&lp_padctl_instReprGamepadState_repr___redArg___closed__32_value;
static const lean_ctor_object lp_padctl_instReprGamepadState_repr___redArg___closed__33_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*1 + 0, .m_other = 1, .m_tag = 3}, .m_objs = {((lean_object*)&lp_padctl_instReprGamepadState_repr___redArg___closed__32_value)}};
static const lean_object* lp_padctl_instReprGamepadState_repr___redArg___closed__33 = (const lean_object*)&lp_padctl_instReprGamepadState_repr___redArg___closed__33_value;
static const lean_string_object lp_padctl_instReprGamepadState_repr___redArg___closed__34_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 7, .m_capacity = 7, .m_length = 6, .m_data = "gyro_z"};
static const lean_object* lp_padctl_instReprGamepadState_repr___redArg___closed__34 = (const lean_object*)&lp_padctl_instReprGamepadState_repr___redArg___closed__34_value;
static const lean_ctor_object lp_padctl_instReprGamepadState_repr___redArg___closed__35_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*1 + 0, .m_other = 1, .m_tag = 3}, .m_objs = {((lean_object*)&lp_padctl_instReprGamepadState_repr___redArg___closed__34_value)}};
static const lean_object* lp_padctl_instReprGamepadState_repr___redArg___closed__35 = (const lean_object*)&lp_padctl_instReprGamepadState_repr___redArg___closed__35_value;
static const lean_string_object lp_padctl_instReprGamepadState_repr___redArg___closed__36_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 7, .m_capacity = 7, .m_length = 6, .m_data = "gyro_y"};
static const lean_object* lp_padctl_instReprGamepadState_repr___redArg___closed__36 = (const lean_object*)&lp_padctl_instReprGamepadState_repr___redArg___closed__36_value;
static const lean_ctor_object lp_padctl_instReprGamepadState_repr___redArg___closed__37_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*1 + 0, .m_other = 1, .m_tag = 3}, .m_objs = {((lean_object*)&lp_padctl_instReprGamepadState_repr___redArg___closed__36_value)}};
static const lean_object* lp_padctl_instReprGamepadState_repr___redArg___closed__37 = (const lean_object*)&lp_padctl_instReprGamepadState_repr___redArg___closed__37_value;
static const lean_string_object lp_padctl_instReprGamepadState_repr___redArg___closed__38_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 7, .m_capacity = 7, .m_length = 6, .m_data = "gyro_x"};
static const lean_object* lp_padctl_instReprGamepadState_repr___redArg___closed__38 = (const lean_object*)&lp_padctl_instReprGamepadState_repr___redArg___closed__38_value;
static const lean_ctor_object lp_padctl_instReprGamepadState_repr___redArg___closed__39_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*1 + 0, .m_other = 1, .m_tag = 3}, .m_objs = {((lean_object*)&lp_padctl_instReprGamepadState_repr___redArg___closed__38_value)}};
static const lean_object* lp_padctl_instReprGamepadState_repr___redArg___closed__39 = (const lean_object*)&lp_padctl_instReprGamepadState_repr___redArg___closed__39_value;
static const lean_string_object lp_padctl_instReprGamepadState_repr___redArg___closed__40_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 7, .m_capacity = 7, .m_length = 6, .m_data = "dpad_y"};
static const lean_object* lp_padctl_instReprGamepadState_repr___redArg___closed__40 = (const lean_object*)&lp_padctl_instReprGamepadState_repr___redArg___closed__40_value;
static const lean_ctor_object lp_padctl_instReprGamepadState_repr___redArg___closed__41_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*1 + 0, .m_other = 1, .m_tag = 3}, .m_objs = {((lean_object*)&lp_padctl_instReprGamepadState_repr___redArg___closed__40_value)}};
static const lean_object* lp_padctl_instReprGamepadState_repr___redArg___closed__41 = (const lean_object*)&lp_padctl_instReprGamepadState_repr___redArg___closed__41_value;
static const lean_ctor_object lp_padctl_instReprGamepadState_repr___redArg___closed__42_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*2 + 0, .m_other = 2, .m_tag = 5}, .m_objs = {((lean_object*)&lp_padctl_instReprGamepadState_repr___redArg___closed__3_value),((lean_object*)&lp_padctl_instReprGamepadState_repr___redArg___closed__5_value)}};
static const lean_object* lp_padctl_instReprGamepadState_repr___redArg___closed__42 = (const lean_object*)&lp_padctl_instReprGamepadState_repr___redArg___closed__42_value;
static lean_once_cell_t lp_padctl_instReprGamepadState_repr___redArg___closed__43_once = LEAN_ONCE_CELL_INITIALIZER;
static lean_object* lp_padctl_instReprGamepadState_repr___redArg___closed__43;
static const lean_string_object lp_padctl_instReprGamepadState_repr___redArg___closed__44_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 3, .m_capacity = 3, .m_length = 2, .m_data = "lt"};
static const lean_object* lp_padctl_instReprGamepadState_repr___redArg___closed__44 = (const lean_object*)&lp_padctl_instReprGamepadState_repr___redArg___closed__44_value;
static const lean_ctor_object lp_padctl_instReprGamepadState_repr___redArg___closed__45_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*1 + 0, .m_other = 1, .m_tag = 3}, .m_objs = {((lean_object*)&lp_padctl_instReprGamepadState_repr___redArg___closed__44_value)}};
static const lean_object* lp_padctl_instReprGamepadState_repr___redArg___closed__45 = (const lean_object*)&lp_padctl_instReprGamepadState_repr___redArg___closed__45_value;
static const lean_string_object lp_padctl_instReprGamepadState_repr___redArg___closed__46_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 3, .m_capacity = 3, .m_length = 2, .m_data = "rt"};
static const lean_object* lp_padctl_instReprGamepadState_repr___redArg___closed__46 = (const lean_object*)&lp_padctl_instReprGamepadState_repr___redArg___closed__46_value;
static const lean_ctor_object lp_padctl_instReprGamepadState_repr___redArg___closed__47_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*1 + 0, .m_other = 1, .m_tag = 3}, .m_objs = {((lean_object*)&lp_padctl_instReprGamepadState_repr___redArg___closed__46_value)}};
static const lean_object* lp_padctl_instReprGamepadState_repr___redArg___closed__47 = (const lean_object*)&lp_padctl_instReprGamepadState_repr___redArg___closed__47_value;
static const lean_string_object lp_padctl_instReprGamepadState_repr___redArg___closed__48_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 8, .m_capacity = 8, .m_length = 7, .m_data = "buttons"};
static const lean_object* lp_padctl_instReprGamepadState_repr___redArg___closed__48 = (const lean_object*)&lp_padctl_instReprGamepadState_repr___redArg___closed__48_value;
static const lean_ctor_object lp_padctl_instReprGamepadState_repr___redArg___closed__49_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*1 + 0, .m_other = 1, .m_tag = 3}, .m_objs = {((lean_object*)&lp_padctl_instReprGamepadState_repr___redArg___closed__48_value)}};
static const lean_object* lp_padctl_instReprGamepadState_repr___redArg___closed__49 = (const lean_object*)&lp_padctl_instReprGamepadState_repr___redArg___closed__49_value;
static lean_once_cell_t lp_padctl_instReprGamepadState_repr___redArg___closed__50_once = LEAN_ONCE_CELL_INITIALIZER;
static lean_object* lp_padctl_instReprGamepadState_repr___redArg___closed__50;
static const lean_string_object lp_padctl_instReprGamepadState_repr___redArg___closed__51_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 7, .m_capacity = 7, .m_length = 6, .m_data = "dpad_x"};
static const lean_object* lp_padctl_instReprGamepadState_repr___redArg___closed__51 = (const lean_object*)&lp_padctl_instReprGamepadState_repr___redArg___closed__51_value;
static const lean_ctor_object lp_padctl_instReprGamepadState_repr___redArg___closed__52_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*1 + 0, .m_other = 1, .m_tag = 3}, .m_objs = {((lean_object*)&lp_padctl_instReprGamepadState_repr___redArg___closed__51_value)}};
static const lean_object* lp_padctl_instReprGamepadState_repr___redArg___closed__52 = (const lean_object*)&lp_padctl_instReprGamepadState_repr___redArg___closed__52_value;
static lean_once_cell_t lp_padctl_instReprGamepadState_repr___redArg___closed__53_once = LEAN_ONCE_CELL_INITIALIZER;
static lean_object* lp_padctl_instReprGamepadState_repr___redArg___closed__53;
static const lean_string_object lp_padctl_instReprGamepadState_repr___redArg___closed__54_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 3, .m_capacity = 3, .m_length = 2, .m_data = "ry"};
static const lean_object* lp_padctl_instReprGamepadState_repr___redArg___closed__54 = (const lean_object*)&lp_padctl_instReprGamepadState_repr___redArg___closed__54_value;
static const lean_ctor_object lp_padctl_instReprGamepadState_repr___redArg___closed__55_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*1 + 0, .m_other = 1, .m_tag = 3}, .m_objs = {((lean_object*)&lp_padctl_instReprGamepadState_repr___redArg___closed__54_value)}};
static const lean_object* lp_padctl_instReprGamepadState_repr___redArg___closed__55 = (const lean_object*)&lp_padctl_instReprGamepadState_repr___redArg___closed__55_value;
static const lean_string_object lp_padctl_instReprGamepadState_repr___redArg___closed__56_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 3, .m_capacity = 3, .m_length = 2, .m_data = "rx"};
static const lean_object* lp_padctl_instReprGamepadState_repr___redArg___closed__56 = (const lean_object*)&lp_padctl_instReprGamepadState_repr___redArg___closed__56_value;
static const lean_ctor_object lp_padctl_instReprGamepadState_repr___redArg___closed__57_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*1 + 0, .m_other = 1, .m_tag = 3}, .m_objs = {((lean_object*)&lp_padctl_instReprGamepadState_repr___redArg___closed__56_value)}};
static const lean_object* lp_padctl_instReprGamepadState_repr___redArg___closed__57 = (const lean_object*)&lp_padctl_instReprGamepadState_repr___redArg___closed__57_value;
static const lean_string_object lp_padctl_instReprGamepadState_repr___redArg___closed__58_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 2, .m_capacity = 2, .m_length = 1, .m_data = ","};
static const lean_object* lp_padctl_instReprGamepadState_repr___redArg___closed__58 = (const lean_object*)&lp_padctl_instReprGamepadState_repr___redArg___closed__58_value;
static const lean_ctor_object lp_padctl_instReprGamepadState_repr___redArg___closed__59_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*1 + 0, .m_other = 1, .m_tag = 3}, .m_objs = {((lean_object*)&lp_padctl_instReprGamepadState_repr___redArg___closed__58_value)}};
static const lean_object* lp_padctl_instReprGamepadState_repr___redArg___closed__59 = (const lean_object*)&lp_padctl_instReprGamepadState_repr___redArg___closed__59_value;
static const lean_string_object lp_padctl_instReprGamepadState_repr___redArg___closed__60_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 3, .m_capacity = 3, .m_length = 2, .m_data = "ay"};
static const lean_object* lp_padctl_instReprGamepadState_repr___redArg___closed__60 = (const lean_object*)&lp_padctl_instReprGamepadState_repr___redArg___closed__60_value;
static const lean_ctor_object lp_padctl_instReprGamepadState_repr___redArg___closed__61_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*1 + 0, .m_other = 1, .m_tag = 3}, .m_objs = {((lean_object*)&lp_padctl_instReprGamepadState_repr___redArg___closed__60_value)}};
static const lean_object* lp_padctl_instReprGamepadState_repr___redArg___closed__61 = (const lean_object*)&lp_padctl_instReprGamepadState_repr___redArg___closed__61_value;
lean_object* l_Bool_repr___redArg(uint8_t);
lean_object* l_Nat_reprFast(lean_object*);
uint8_t lean_int_dec_lt(lean_object*, lean_object*);
lean_object* l_Int_repr(lean_object*);
lean_object* l_Repr_addAppParen(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_instReprGamepadState_repr___redArg(lean_object*);
LEAN_EXPORT lean_object* lp_padctl_instReprGamepadState_repr(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_instReprGamepadState_repr___boxed(lean_object*, lean_object*);
static const lean_closure_object lp_padctl_instReprGamepadState___closed__0_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_closure_object) + sizeof(void*)*0, .m_other = 0, .m_tag = 245}, .m_fun = (void*)lp_padctl_instReprGamepadState_repr___boxed, .m_arity = 2, .m_num_fixed = 0, .m_objs = {} };
static const lean_object* lp_padctl_instReprGamepadState___closed__0 = (const lean_object*)&lp_padctl_instReprGamepadState___closed__0_value;
LEAN_EXPORT const lean_object* lp_padctl_instReprGamepadState = (const lean_object*)&lp_padctl_instReprGamepadState___closed__0_value;
LEAN_EXPORT uint8_t lp_padctl_instDecidableEqGamepadStateDelta_decEq___lam__0(uint8_t, uint8_t, uint8_t);
LEAN_EXPORT lean_object* lp_padctl_instDecidableEqGamepadStateDelta_decEq___lam__0___boxed(lean_object*, lean_object*, lean_object*);
lean_object* l_Int_instDecidableEq___boxed(lean_object*, lean_object*);
uint8_t l_Option_instDecidableEq___redArg(lean_object*, lean_object*, lean_object*);
lean_object* l_instDecidableEqNat___boxed(lean_object*, lean_object*);
LEAN_EXPORT uint8_t lp_padctl_instDecidableEqGamepadStateDelta_decEq(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_instDecidableEqGamepadStateDelta_decEq___boxed(lean_object*, lean_object*);
LEAN_EXPORT uint8_t lp_padctl_instDecidableEqGamepadStateDelta(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_instDecidableEqGamepadStateDelta___boxed(lean_object*, lean_object*);
static const lean_string_object lp_padctl_Option_repr___at___00instReprGamepadStateDelta_repr_spec__0___closed__0_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 5, .m_capacity = 5, .m_length = 4, .m_data = "none"};
static const lean_object* lp_padctl_Option_repr___at___00instReprGamepadStateDelta_repr_spec__0___closed__0 = (const lean_object*)&lp_padctl_Option_repr___at___00instReprGamepadStateDelta_repr_spec__0___closed__0_value;
static const lean_ctor_object lp_padctl_Option_repr___at___00instReprGamepadStateDelta_repr_spec__0___closed__1_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*1 + 0, .m_other = 1, .m_tag = 3}, .m_objs = {((lean_object*)&lp_padctl_Option_repr___at___00instReprGamepadStateDelta_repr_spec__0___closed__0_value)}};
static const lean_object* lp_padctl_Option_repr___at___00instReprGamepadStateDelta_repr_spec__0___closed__1 = (const lean_object*)&lp_padctl_Option_repr___at___00instReprGamepadStateDelta_repr_spec__0___closed__1_value;
static const lean_string_object lp_padctl_Option_repr___at___00instReprGamepadStateDelta_repr_spec__0___closed__2_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 6, .m_capacity = 6, .m_length = 5, .m_data = "some "};
static const lean_object* lp_padctl_Option_repr___at___00instReprGamepadStateDelta_repr_spec__0___closed__2 = (const lean_object*)&lp_padctl_Option_repr___at___00instReprGamepadStateDelta_repr_spec__0___closed__2_value;
static const lean_ctor_object lp_padctl_Option_repr___at___00instReprGamepadStateDelta_repr_spec__0___closed__3_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*1 + 0, .m_other = 1, .m_tag = 3}, .m_objs = {((lean_object*)&lp_padctl_Option_repr___at___00instReprGamepadStateDelta_repr_spec__0___closed__2_value)}};
static const lean_object* lp_padctl_Option_repr___at___00instReprGamepadStateDelta_repr_spec__0___closed__3 = (const lean_object*)&lp_padctl_Option_repr___at___00instReprGamepadStateDelta_repr_spec__0___closed__3_value;
LEAN_EXPORT lean_object* lp_padctl_Option_repr___at___00instReprGamepadStateDelta_repr_spec__0(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_Option_repr___at___00instReprGamepadStateDelta_repr_spec__0___boxed(lean_object*, lean_object*);
lean_object* l_Option_repr___at___00Lean_Omega_instReprConstraint_repr_spec__0(lean_object*, lean_object*);
lean_object* l_Option_repr___at___00Lean_Meta_instReprConfig__1_repr_spec__0(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_instReprGamepadStateDelta_repr___redArg(lean_object*);
LEAN_EXPORT lean_object* lp_padctl_instReprGamepadStateDelta_repr(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_instReprGamepadStateDelta_repr___boxed(lean_object*, lean_object*);
static const lean_closure_object lp_padctl_instReprGamepadStateDelta___closed__0_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_closure_object) + sizeof(void*)*0, .m_other = 0, .m_tag = 245}, .m_fun = (void*)lp_padctl_instReprGamepadStateDelta_repr___boxed, .m_arity = 2, .m_num_fixed = 0, .m_objs = {} };
static const lean_object* lp_padctl_instReprGamepadStateDelta___closed__0 = (const lean_object*)&lp_padctl_instReprGamepadStateDelta___closed__0_value;
LEAN_EXPORT const lean_object* lp_padctl_instReprGamepadStateDelta = (const lean_object*)&lp_padctl_instReprGamepadStateDelta___closed__0_value;
LEAN_EXPORT lean_object* lp_padctl_applyDelta(lean_object*, lean_object*);
static const lean_ctor_object lp_padctl_emptyDelta___closed__0_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*22 + 0, .m_other = 22, .m_tag = 0}, .m_objs = {((lean_object*)(((size_t)(0) << 1) | 1)),((lean_object*)(((size_t)(0) << 1) | 1)),((lean_object*)(((size_t)(0) << 1) | 1)),((lean_object*)(((size_t)(0) << 1) | 1)),((lean_object*)(((size_t)(0) << 1) | 1)),((lean_object*)(((size_t)(0) << 1) | 1)),((lean_object*)(((size_t)(0) << 1) | 1)),((lean_object*)(((size_t)(0) << 1) | 1)),((lean_object*)(((size_t)(0) << 1) | 1)),((lean_object*)(((size_t)(0) << 1) | 1)),((lean_object*)(((size_t)(0) << 1) | 1)),((lean_object*)(((size_t)(0) << 1) | 1)),((lean_object*)(((size_t)(0) << 1) | 1)),((lean_object*)(((size_t)(0) << 1) | 1)),((lean_object*)(((size_t)(0) << 1) | 1)),((lean_object*)(((size_t)(0) << 1) | 1)),((lean_object*)(((size_t)(0) << 1) | 1)),((lean_object*)(((size_t)(0) << 1) | 1)),((lean_object*)(((size_t)(0) << 1) | 1)),((lean_object*)(((size_t)(0) << 1) | 1)),((lean_object*)(((size_t)(0) << 1) | 1)),((lean_object*)(((size_t)(0) << 1) | 1))}};
static const lean_object* lp_padctl_emptyDelta___closed__0 = (const lean_object*)&lp_padctl_emptyDelta___closed__0_value;
LEAN_EXPORT const lean_object* lp_padctl_emptyDelta = (const lean_object*)&lp_padctl_emptyDelta___closed__0_value;
LEAN_EXPORT lean_object* lp_padctl_diff(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_diff___boxed(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_ButtonId_ctorIdx(uint8_t);
LEAN_EXPORT lean_object* lp_padctl_ButtonId_ctorIdx___boxed(lean_object*);
LEAN_EXPORT lean_object* lp_padctl_ButtonId_toCtorIdx(uint8_t);
LEAN_EXPORT lean_object* lp_padctl_ButtonId_toCtorIdx___boxed(lean_object*);
LEAN_EXPORT lean_object* lp_padctl_ButtonId_ctorElim___redArg(lean_object*);
LEAN_EXPORT lean_object* lp_padctl_ButtonId_ctorElim___redArg___boxed(lean_object*);
LEAN_EXPORT lean_object* lp_padctl_ButtonId_ctorElim(lean_object*, lean_object*, uint8_t, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_ButtonId_ctorElim___boxed(lean_object*, lean_object*, lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_ButtonId_south_elim___redArg(lean_object*);
LEAN_EXPORT lean_object* lp_padctl_ButtonId_south_elim___redArg___boxed(lean_object*);
LEAN_EXPORT lean_object* lp_padctl_ButtonId_south_elim(lean_object*, uint8_t, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_ButtonId_south_elim___boxed(lean_object*, lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_ButtonId_east_elim___redArg(lean_object*);
LEAN_EXPORT lean_object* lp_padctl_ButtonId_east_elim___redArg___boxed(lean_object*);
LEAN_EXPORT lean_object* lp_padctl_ButtonId_east_elim(lean_object*, uint8_t, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_ButtonId_east_elim___boxed(lean_object*, lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_ButtonId_north_elim___redArg(lean_object*);
LEAN_EXPORT lean_object* lp_padctl_ButtonId_north_elim___redArg___boxed(lean_object*);
LEAN_EXPORT lean_object* lp_padctl_ButtonId_north_elim(lean_object*, uint8_t, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_ButtonId_north_elim___boxed(lean_object*, lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_ButtonId_west_elim___redArg(lean_object*);
LEAN_EXPORT lean_object* lp_padctl_ButtonId_west_elim___redArg___boxed(lean_object*);
LEAN_EXPORT lean_object* lp_padctl_ButtonId_west_elim(lean_object*, uint8_t, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_ButtonId_west_elim___boxed(lean_object*, lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_ButtonId_lsb_elim___redArg(lean_object*);
LEAN_EXPORT lean_object* lp_padctl_ButtonId_lsb_elim___redArg___boxed(lean_object*);
LEAN_EXPORT lean_object* lp_padctl_ButtonId_lsb_elim(lean_object*, uint8_t, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_ButtonId_lsb_elim___boxed(lean_object*, lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_ButtonId_rsb_elim___redArg(lean_object*);
LEAN_EXPORT lean_object* lp_padctl_ButtonId_rsb_elim___redArg___boxed(lean_object*);
LEAN_EXPORT lean_object* lp_padctl_ButtonId_rsb_elim(lean_object*, uint8_t, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_ButtonId_rsb_elim___boxed(lean_object*, lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_ButtonId_back_elim___redArg(lean_object*);
LEAN_EXPORT lean_object* lp_padctl_ButtonId_back_elim___redArg___boxed(lean_object*);
LEAN_EXPORT lean_object* lp_padctl_ButtonId_back_elim(lean_object*, uint8_t, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_ButtonId_back_elim___boxed(lean_object*, lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_ButtonId_start_elim___redArg(lean_object*);
LEAN_EXPORT lean_object* lp_padctl_ButtonId_start_elim___redArg___boxed(lean_object*);
LEAN_EXPORT lean_object* lp_padctl_ButtonId_start_elim(lean_object*, uint8_t, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_ButtonId_start_elim___boxed(lean_object*, lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_ButtonId_guide_elim___redArg(lean_object*);
LEAN_EXPORT lean_object* lp_padctl_ButtonId_guide_elim___redArg___boxed(lean_object*);
LEAN_EXPORT lean_object* lp_padctl_ButtonId_guide_elim(lean_object*, uint8_t, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_ButtonId_guide_elim___boxed(lean_object*, lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_ButtonId_misc_elim___redArg(lean_object*);
LEAN_EXPORT lean_object* lp_padctl_ButtonId_misc_elim___redArg___boxed(lean_object*);
LEAN_EXPORT lean_object* lp_padctl_ButtonId_misc_elim(lean_object*, uint8_t, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_ButtonId_misc_elim___boxed(lean_object*, lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_ButtonId_lt_elim___redArg(lean_object*);
LEAN_EXPORT lean_object* lp_padctl_ButtonId_lt_elim___redArg___boxed(lean_object*);
LEAN_EXPORT lean_object* lp_padctl_ButtonId_lt_elim(lean_object*, uint8_t, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_ButtonId_lt_elim___boxed(lean_object*, lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_ButtonId_rt_elim___redArg(lean_object*);
LEAN_EXPORT lean_object* lp_padctl_ButtonId_rt_elim___redArg___boxed(lean_object*);
LEAN_EXPORT lean_object* lp_padctl_ButtonId_rt_elim(lean_object*, uint8_t, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_ButtonId_rt_elim___boxed(lean_object*, lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_ButtonId_lb_elim___redArg(lean_object*);
LEAN_EXPORT lean_object* lp_padctl_ButtonId_lb_elim___redArg___boxed(lean_object*);
LEAN_EXPORT lean_object* lp_padctl_ButtonId_lb_elim(lean_object*, uint8_t, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_ButtonId_lb_elim___boxed(lean_object*, lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_ButtonId_rb_elim___redArg(lean_object*);
LEAN_EXPORT lean_object* lp_padctl_ButtonId_rb_elim___redArg___boxed(lean_object*);
LEAN_EXPORT lean_object* lp_padctl_ButtonId_rb_elim(lean_object*, uint8_t, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_ButtonId_rb_elim___boxed(lean_object*, lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_ButtonId_dpadUp_elim___redArg(lean_object*);
LEAN_EXPORT lean_object* lp_padctl_ButtonId_dpadUp_elim___redArg___boxed(lean_object*);
LEAN_EXPORT lean_object* lp_padctl_ButtonId_dpadUp_elim(lean_object*, uint8_t, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_ButtonId_dpadUp_elim___boxed(lean_object*, lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_ButtonId_dpadDown_elim___redArg(lean_object*);
LEAN_EXPORT lean_object* lp_padctl_ButtonId_dpadDown_elim___redArg___boxed(lean_object*);
LEAN_EXPORT lean_object* lp_padctl_ButtonId_dpadDown_elim(lean_object*, uint8_t, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_ButtonId_dpadDown_elim___boxed(lean_object*, lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_ButtonId_dpadLeft_elim___redArg(lean_object*);
LEAN_EXPORT lean_object* lp_padctl_ButtonId_dpadLeft_elim___redArg___boxed(lean_object*);
LEAN_EXPORT lean_object* lp_padctl_ButtonId_dpadLeft_elim(lean_object*, uint8_t, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_ButtonId_dpadLeft_elim___boxed(lean_object*, lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_ButtonId_dpadRight_elim___redArg(lean_object*);
LEAN_EXPORT lean_object* lp_padctl_ButtonId_dpadRight_elim___redArg___boxed(lean_object*);
LEAN_EXPORT lean_object* lp_padctl_ButtonId_dpadRight_elim(lean_object*, uint8_t, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_ButtonId_dpadRight_elim___boxed(lean_object*, lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_ButtonId_lt2_elim___redArg(lean_object*);
LEAN_EXPORT lean_object* lp_padctl_ButtonId_lt2_elim___redArg___boxed(lean_object*);
LEAN_EXPORT lean_object* lp_padctl_ButtonId_lt2_elim(lean_object*, uint8_t, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_ButtonId_lt2_elim___boxed(lean_object*, lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_ButtonId_rt2_elim___redArg(lean_object*);
LEAN_EXPORT lean_object* lp_padctl_ButtonId_rt2_elim___redArg___boxed(lean_object*);
LEAN_EXPORT lean_object* lp_padctl_ButtonId_rt2_elim(lean_object*, uint8_t, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_ButtonId_rt2_elim___boxed(lean_object*, lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_ButtonId_paddle1_elim___redArg(lean_object*);
LEAN_EXPORT lean_object* lp_padctl_ButtonId_paddle1_elim___redArg___boxed(lean_object*);
LEAN_EXPORT lean_object* lp_padctl_ButtonId_paddle1_elim(lean_object*, uint8_t, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_ButtonId_paddle1_elim___boxed(lean_object*, lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_ButtonId_paddle2_elim___redArg(lean_object*);
LEAN_EXPORT lean_object* lp_padctl_ButtonId_paddle2_elim___redArg___boxed(lean_object*);
LEAN_EXPORT lean_object* lp_padctl_ButtonId_paddle2_elim(lean_object*, uint8_t, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_ButtonId_paddle2_elim___boxed(lean_object*, lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_ButtonId_paddle3_elim___redArg(lean_object*);
LEAN_EXPORT lean_object* lp_padctl_ButtonId_paddle3_elim___redArg___boxed(lean_object*);
LEAN_EXPORT lean_object* lp_padctl_ButtonId_paddle3_elim(lean_object*, uint8_t, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_ButtonId_paddle3_elim___boxed(lean_object*, lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_ButtonId_paddle4_elim___redArg(lean_object*);
LEAN_EXPORT lean_object* lp_padctl_ButtonId_paddle4_elim___redArg___boxed(lean_object*);
LEAN_EXPORT lean_object* lp_padctl_ButtonId_paddle4_elim(lean_object*, uint8_t, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_ButtonId_paddle4_elim___boxed(lean_object*, lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_ButtonId_touchpadButton_elim___redArg(lean_object*);
LEAN_EXPORT lean_object* lp_padctl_ButtonId_touchpadButton_elim___redArg___boxed(lean_object*);
LEAN_EXPORT lean_object* lp_padctl_ButtonId_touchpadButton_elim(lean_object*, uint8_t, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_ButtonId_touchpadButton_elim___boxed(lean_object*, lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_ButtonId_misc2_elim___redArg(lean_object*);
LEAN_EXPORT lean_object* lp_padctl_ButtonId_misc2_elim___redArg___boxed(lean_object*);
LEAN_EXPORT lean_object* lp_padctl_ButtonId_misc2_elim(lean_object*, uint8_t, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_ButtonId_misc2_elim___boxed(lean_object*, lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_ButtonId_misc3_elim___redArg(lean_object*);
LEAN_EXPORT lean_object* lp_padctl_ButtonId_misc3_elim___redArg___boxed(lean_object*);
LEAN_EXPORT lean_object* lp_padctl_ButtonId_misc3_elim(lean_object*, uint8_t, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_ButtonId_misc3_elim___boxed(lean_object*, lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_ButtonId_misc4_elim___redArg(lean_object*);
LEAN_EXPORT lean_object* lp_padctl_ButtonId_misc4_elim___redArg___boxed(lean_object*);
LEAN_EXPORT lean_object* lp_padctl_ButtonId_misc4_elim(lean_object*, uint8_t, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_ButtonId_misc4_elim___boxed(lean_object*, lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_ButtonId_misc5_elim___redArg(lean_object*);
LEAN_EXPORT lean_object* lp_padctl_ButtonId_misc5_elim___redArg___boxed(lean_object*);
LEAN_EXPORT lean_object* lp_padctl_ButtonId_misc5_elim(lean_object*, uint8_t, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_ButtonId_misc5_elim___boxed(lean_object*, lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_ButtonId_misc6_elim___redArg(lean_object*);
LEAN_EXPORT lean_object* lp_padctl_ButtonId_misc6_elim___redArg___boxed(lean_object*);
LEAN_EXPORT lean_object* lp_padctl_ButtonId_misc6_elim(lean_object*, uint8_t, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_ButtonId_misc6_elim___boxed(lean_object*, lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_ButtonId_misc7_elim___redArg(lean_object*);
LEAN_EXPORT lean_object* lp_padctl_ButtonId_misc7_elim___redArg___boxed(lean_object*);
LEAN_EXPORT lean_object* lp_padctl_ButtonId_misc7_elim(lean_object*, uint8_t, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_ButtonId_misc7_elim___boxed(lean_object*, lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_ButtonId_misc8_elim___redArg(lean_object*);
LEAN_EXPORT lean_object* lp_padctl_ButtonId_misc8_elim___redArg___boxed(lean_object*);
LEAN_EXPORT lean_object* lp_padctl_ButtonId_misc8_elim(lean_object*, uint8_t, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_ButtonId_misc8_elim___boxed(lean_object*, lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_ButtonId_misc9_elim___redArg(lean_object*);
LEAN_EXPORT lean_object* lp_padctl_ButtonId_misc9_elim___redArg___boxed(lean_object*);
LEAN_EXPORT lean_object* lp_padctl_ButtonId_misc9_elim(lean_object*, uint8_t, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_ButtonId_misc9_elim___boxed(lean_object*, lean_object*, lean_object*, lean_object*);
uint8_t lean_nat_dec_le(lean_object*, lean_object*);
LEAN_EXPORT uint8_t lp_padctl_ButtonId_ofNat(lean_object*);
LEAN_EXPORT lean_object* lp_padctl_ButtonId_ofNat___boxed(lean_object*);
LEAN_EXPORT uint8_t lp_padctl_instDecidableEqButtonId(uint8_t, uint8_t);
LEAN_EXPORT lean_object* lp_padctl_instDecidableEqButtonId___boxed(lean_object*, lean_object*);
static const lean_string_object lp_padctl_instReprButtonId_repr___closed__0_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 15, .m_capacity = 15, .m_length = 14, .m_data = "ButtonId.south"};
static const lean_object* lp_padctl_instReprButtonId_repr___closed__0 = (const lean_object*)&lp_padctl_instReprButtonId_repr___closed__0_value;
static const lean_ctor_object lp_padctl_instReprButtonId_repr___closed__1_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*1 + 0, .m_other = 1, .m_tag = 3}, .m_objs = {((lean_object*)&lp_padctl_instReprButtonId_repr___closed__0_value)}};
static const lean_object* lp_padctl_instReprButtonId_repr___closed__1 = (const lean_object*)&lp_padctl_instReprButtonId_repr___closed__1_value;
static const lean_string_object lp_padctl_instReprButtonId_repr___closed__2_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 14, .m_capacity = 14, .m_length = 13, .m_data = "ButtonId.east"};
static const lean_object* lp_padctl_instReprButtonId_repr___closed__2 = (const lean_object*)&lp_padctl_instReprButtonId_repr___closed__2_value;
static const lean_ctor_object lp_padctl_instReprButtonId_repr___closed__3_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*1 + 0, .m_other = 1, .m_tag = 3}, .m_objs = {((lean_object*)&lp_padctl_instReprButtonId_repr___closed__2_value)}};
static const lean_object* lp_padctl_instReprButtonId_repr___closed__3 = (const lean_object*)&lp_padctl_instReprButtonId_repr___closed__3_value;
static const lean_string_object lp_padctl_instReprButtonId_repr___closed__4_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 15, .m_capacity = 15, .m_length = 14, .m_data = "ButtonId.north"};
static const lean_object* lp_padctl_instReprButtonId_repr___closed__4 = (const lean_object*)&lp_padctl_instReprButtonId_repr___closed__4_value;
static const lean_ctor_object lp_padctl_instReprButtonId_repr___closed__5_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*1 + 0, .m_other = 1, .m_tag = 3}, .m_objs = {((lean_object*)&lp_padctl_instReprButtonId_repr___closed__4_value)}};
static const lean_object* lp_padctl_instReprButtonId_repr___closed__5 = (const lean_object*)&lp_padctl_instReprButtonId_repr___closed__5_value;
static const lean_string_object lp_padctl_instReprButtonId_repr___closed__6_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 14, .m_capacity = 14, .m_length = 13, .m_data = "ButtonId.west"};
static const lean_object* lp_padctl_instReprButtonId_repr___closed__6 = (const lean_object*)&lp_padctl_instReprButtonId_repr___closed__6_value;
static const lean_ctor_object lp_padctl_instReprButtonId_repr___closed__7_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*1 + 0, .m_other = 1, .m_tag = 3}, .m_objs = {((lean_object*)&lp_padctl_instReprButtonId_repr___closed__6_value)}};
static const lean_object* lp_padctl_instReprButtonId_repr___closed__7 = (const lean_object*)&lp_padctl_instReprButtonId_repr___closed__7_value;
static const lean_string_object lp_padctl_instReprButtonId_repr___closed__8_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 13, .m_capacity = 13, .m_length = 12, .m_data = "ButtonId.lsb"};
static const lean_object* lp_padctl_instReprButtonId_repr___closed__8 = (const lean_object*)&lp_padctl_instReprButtonId_repr___closed__8_value;
static const lean_ctor_object lp_padctl_instReprButtonId_repr___closed__9_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*1 + 0, .m_other = 1, .m_tag = 3}, .m_objs = {((lean_object*)&lp_padctl_instReprButtonId_repr___closed__8_value)}};
static const lean_object* lp_padctl_instReprButtonId_repr___closed__9 = (const lean_object*)&lp_padctl_instReprButtonId_repr___closed__9_value;
static const lean_string_object lp_padctl_instReprButtonId_repr___closed__10_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 13, .m_capacity = 13, .m_length = 12, .m_data = "ButtonId.rsb"};
static const lean_object* lp_padctl_instReprButtonId_repr___closed__10 = (const lean_object*)&lp_padctl_instReprButtonId_repr___closed__10_value;
static const lean_ctor_object lp_padctl_instReprButtonId_repr___closed__11_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*1 + 0, .m_other = 1, .m_tag = 3}, .m_objs = {((lean_object*)&lp_padctl_instReprButtonId_repr___closed__10_value)}};
static const lean_object* lp_padctl_instReprButtonId_repr___closed__11 = (const lean_object*)&lp_padctl_instReprButtonId_repr___closed__11_value;
static const lean_string_object lp_padctl_instReprButtonId_repr___closed__12_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 14, .m_capacity = 14, .m_length = 13, .m_data = "ButtonId.back"};
static const lean_object* lp_padctl_instReprButtonId_repr___closed__12 = (const lean_object*)&lp_padctl_instReprButtonId_repr___closed__12_value;
static const lean_ctor_object lp_padctl_instReprButtonId_repr___closed__13_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*1 + 0, .m_other = 1, .m_tag = 3}, .m_objs = {((lean_object*)&lp_padctl_instReprButtonId_repr___closed__12_value)}};
static const lean_object* lp_padctl_instReprButtonId_repr___closed__13 = (const lean_object*)&lp_padctl_instReprButtonId_repr___closed__13_value;
static const lean_string_object lp_padctl_instReprButtonId_repr___closed__14_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 15, .m_capacity = 15, .m_length = 14, .m_data = "ButtonId.start"};
static const lean_object* lp_padctl_instReprButtonId_repr___closed__14 = (const lean_object*)&lp_padctl_instReprButtonId_repr___closed__14_value;
static const lean_ctor_object lp_padctl_instReprButtonId_repr___closed__15_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*1 + 0, .m_other = 1, .m_tag = 3}, .m_objs = {((lean_object*)&lp_padctl_instReprButtonId_repr___closed__14_value)}};
static const lean_object* lp_padctl_instReprButtonId_repr___closed__15 = (const lean_object*)&lp_padctl_instReprButtonId_repr___closed__15_value;
static const lean_string_object lp_padctl_instReprButtonId_repr___closed__16_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 15, .m_capacity = 15, .m_length = 14, .m_data = "ButtonId.guide"};
static const lean_object* lp_padctl_instReprButtonId_repr___closed__16 = (const lean_object*)&lp_padctl_instReprButtonId_repr___closed__16_value;
static const lean_ctor_object lp_padctl_instReprButtonId_repr___closed__17_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*1 + 0, .m_other = 1, .m_tag = 3}, .m_objs = {((lean_object*)&lp_padctl_instReprButtonId_repr___closed__16_value)}};
static const lean_object* lp_padctl_instReprButtonId_repr___closed__17 = (const lean_object*)&lp_padctl_instReprButtonId_repr___closed__17_value;
static const lean_string_object lp_padctl_instReprButtonId_repr___closed__18_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 14, .m_capacity = 14, .m_length = 13, .m_data = "ButtonId.misc"};
static const lean_object* lp_padctl_instReprButtonId_repr___closed__18 = (const lean_object*)&lp_padctl_instReprButtonId_repr___closed__18_value;
static const lean_ctor_object lp_padctl_instReprButtonId_repr___closed__19_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*1 + 0, .m_other = 1, .m_tag = 3}, .m_objs = {((lean_object*)&lp_padctl_instReprButtonId_repr___closed__18_value)}};
static const lean_object* lp_padctl_instReprButtonId_repr___closed__19 = (const lean_object*)&lp_padctl_instReprButtonId_repr___closed__19_value;
static const lean_string_object lp_padctl_instReprButtonId_repr___closed__20_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 12, .m_capacity = 12, .m_length = 11, .m_data = "ButtonId.lt"};
static const lean_object* lp_padctl_instReprButtonId_repr___closed__20 = (const lean_object*)&lp_padctl_instReprButtonId_repr___closed__20_value;
static const lean_ctor_object lp_padctl_instReprButtonId_repr___closed__21_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*1 + 0, .m_other = 1, .m_tag = 3}, .m_objs = {((lean_object*)&lp_padctl_instReprButtonId_repr___closed__20_value)}};
static const lean_object* lp_padctl_instReprButtonId_repr___closed__21 = (const lean_object*)&lp_padctl_instReprButtonId_repr___closed__21_value;
static const lean_string_object lp_padctl_instReprButtonId_repr___closed__22_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 12, .m_capacity = 12, .m_length = 11, .m_data = "ButtonId.rt"};
static const lean_object* lp_padctl_instReprButtonId_repr___closed__22 = (const lean_object*)&lp_padctl_instReprButtonId_repr___closed__22_value;
static const lean_ctor_object lp_padctl_instReprButtonId_repr___closed__23_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*1 + 0, .m_other = 1, .m_tag = 3}, .m_objs = {((lean_object*)&lp_padctl_instReprButtonId_repr___closed__22_value)}};
static const lean_object* lp_padctl_instReprButtonId_repr___closed__23 = (const lean_object*)&lp_padctl_instReprButtonId_repr___closed__23_value;
static const lean_string_object lp_padctl_instReprButtonId_repr___closed__24_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 12, .m_capacity = 12, .m_length = 11, .m_data = "ButtonId.lb"};
static const lean_object* lp_padctl_instReprButtonId_repr___closed__24 = (const lean_object*)&lp_padctl_instReprButtonId_repr___closed__24_value;
static const lean_ctor_object lp_padctl_instReprButtonId_repr___closed__25_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*1 + 0, .m_other = 1, .m_tag = 3}, .m_objs = {((lean_object*)&lp_padctl_instReprButtonId_repr___closed__24_value)}};
static const lean_object* lp_padctl_instReprButtonId_repr___closed__25 = (const lean_object*)&lp_padctl_instReprButtonId_repr___closed__25_value;
static const lean_string_object lp_padctl_instReprButtonId_repr___closed__26_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 12, .m_capacity = 12, .m_length = 11, .m_data = "ButtonId.rb"};
static const lean_object* lp_padctl_instReprButtonId_repr___closed__26 = (const lean_object*)&lp_padctl_instReprButtonId_repr___closed__26_value;
static const lean_ctor_object lp_padctl_instReprButtonId_repr___closed__27_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*1 + 0, .m_other = 1, .m_tag = 3}, .m_objs = {((lean_object*)&lp_padctl_instReprButtonId_repr___closed__26_value)}};
static const lean_object* lp_padctl_instReprButtonId_repr___closed__27 = (const lean_object*)&lp_padctl_instReprButtonId_repr___closed__27_value;
static const lean_string_object lp_padctl_instReprButtonId_repr___closed__28_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 16, .m_capacity = 16, .m_length = 15, .m_data = "ButtonId.dpadUp"};
static const lean_object* lp_padctl_instReprButtonId_repr___closed__28 = (const lean_object*)&lp_padctl_instReprButtonId_repr___closed__28_value;
static const lean_ctor_object lp_padctl_instReprButtonId_repr___closed__29_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*1 + 0, .m_other = 1, .m_tag = 3}, .m_objs = {((lean_object*)&lp_padctl_instReprButtonId_repr___closed__28_value)}};
static const lean_object* lp_padctl_instReprButtonId_repr___closed__29 = (const lean_object*)&lp_padctl_instReprButtonId_repr___closed__29_value;
static const lean_string_object lp_padctl_instReprButtonId_repr___closed__30_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 18, .m_capacity = 18, .m_length = 17, .m_data = "ButtonId.dpadDown"};
static const lean_object* lp_padctl_instReprButtonId_repr___closed__30 = (const lean_object*)&lp_padctl_instReprButtonId_repr___closed__30_value;
static const lean_ctor_object lp_padctl_instReprButtonId_repr___closed__31_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*1 + 0, .m_other = 1, .m_tag = 3}, .m_objs = {((lean_object*)&lp_padctl_instReprButtonId_repr___closed__30_value)}};
static const lean_object* lp_padctl_instReprButtonId_repr___closed__31 = (const lean_object*)&lp_padctl_instReprButtonId_repr___closed__31_value;
static const lean_string_object lp_padctl_instReprButtonId_repr___closed__32_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 18, .m_capacity = 18, .m_length = 17, .m_data = "ButtonId.dpadLeft"};
static const lean_object* lp_padctl_instReprButtonId_repr___closed__32 = (const lean_object*)&lp_padctl_instReprButtonId_repr___closed__32_value;
static const lean_ctor_object lp_padctl_instReprButtonId_repr___closed__33_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*1 + 0, .m_other = 1, .m_tag = 3}, .m_objs = {((lean_object*)&lp_padctl_instReprButtonId_repr___closed__32_value)}};
static const lean_object* lp_padctl_instReprButtonId_repr___closed__33 = (const lean_object*)&lp_padctl_instReprButtonId_repr___closed__33_value;
static const lean_string_object lp_padctl_instReprButtonId_repr___closed__34_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 19, .m_capacity = 19, .m_length = 18, .m_data = "ButtonId.dpadRight"};
static const lean_object* lp_padctl_instReprButtonId_repr___closed__34 = (const lean_object*)&lp_padctl_instReprButtonId_repr___closed__34_value;
static const lean_ctor_object lp_padctl_instReprButtonId_repr___closed__35_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*1 + 0, .m_other = 1, .m_tag = 3}, .m_objs = {((lean_object*)&lp_padctl_instReprButtonId_repr___closed__34_value)}};
static const lean_object* lp_padctl_instReprButtonId_repr___closed__35 = (const lean_object*)&lp_padctl_instReprButtonId_repr___closed__35_value;
static const lean_string_object lp_padctl_instReprButtonId_repr___closed__36_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 13, .m_capacity = 13, .m_length = 12, .m_data = "ButtonId.lt2"};
static const lean_object* lp_padctl_instReprButtonId_repr___closed__36 = (const lean_object*)&lp_padctl_instReprButtonId_repr___closed__36_value;
static const lean_ctor_object lp_padctl_instReprButtonId_repr___closed__37_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*1 + 0, .m_other = 1, .m_tag = 3}, .m_objs = {((lean_object*)&lp_padctl_instReprButtonId_repr___closed__36_value)}};
static const lean_object* lp_padctl_instReprButtonId_repr___closed__37 = (const lean_object*)&lp_padctl_instReprButtonId_repr___closed__37_value;
static const lean_string_object lp_padctl_instReprButtonId_repr___closed__38_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 13, .m_capacity = 13, .m_length = 12, .m_data = "ButtonId.rt2"};
static const lean_object* lp_padctl_instReprButtonId_repr___closed__38 = (const lean_object*)&lp_padctl_instReprButtonId_repr___closed__38_value;
static const lean_ctor_object lp_padctl_instReprButtonId_repr___closed__39_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*1 + 0, .m_other = 1, .m_tag = 3}, .m_objs = {((lean_object*)&lp_padctl_instReprButtonId_repr___closed__38_value)}};
static const lean_object* lp_padctl_instReprButtonId_repr___closed__39 = (const lean_object*)&lp_padctl_instReprButtonId_repr___closed__39_value;
static const lean_string_object lp_padctl_instReprButtonId_repr___closed__40_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 17, .m_capacity = 17, .m_length = 16, .m_data = "ButtonId.paddle1"};
static const lean_object* lp_padctl_instReprButtonId_repr___closed__40 = (const lean_object*)&lp_padctl_instReprButtonId_repr___closed__40_value;
static const lean_ctor_object lp_padctl_instReprButtonId_repr___closed__41_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*1 + 0, .m_other = 1, .m_tag = 3}, .m_objs = {((lean_object*)&lp_padctl_instReprButtonId_repr___closed__40_value)}};
static const lean_object* lp_padctl_instReprButtonId_repr___closed__41 = (const lean_object*)&lp_padctl_instReprButtonId_repr___closed__41_value;
static const lean_string_object lp_padctl_instReprButtonId_repr___closed__42_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 17, .m_capacity = 17, .m_length = 16, .m_data = "ButtonId.paddle2"};
static const lean_object* lp_padctl_instReprButtonId_repr___closed__42 = (const lean_object*)&lp_padctl_instReprButtonId_repr___closed__42_value;
static const lean_ctor_object lp_padctl_instReprButtonId_repr___closed__43_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*1 + 0, .m_other = 1, .m_tag = 3}, .m_objs = {((lean_object*)&lp_padctl_instReprButtonId_repr___closed__42_value)}};
static const lean_object* lp_padctl_instReprButtonId_repr___closed__43 = (const lean_object*)&lp_padctl_instReprButtonId_repr___closed__43_value;
static const lean_string_object lp_padctl_instReprButtonId_repr___closed__44_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 17, .m_capacity = 17, .m_length = 16, .m_data = "ButtonId.paddle3"};
static const lean_object* lp_padctl_instReprButtonId_repr___closed__44 = (const lean_object*)&lp_padctl_instReprButtonId_repr___closed__44_value;
static const lean_ctor_object lp_padctl_instReprButtonId_repr___closed__45_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*1 + 0, .m_other = 1, .m_tag = 3}, .m_objs = {((lean_object*)&lp_padctl_instReprButtonId_repr___closed__44_value)}};
static const lean_object* lp_padctl_instReprButtonId_repr___closed__45 = (const lean_object*)&lp_padctl_instReprButtonId_repr___closed__45_value;
static const lean_string_object lp_padctl_instReprButtonId_repr___closed__46_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 17, .m_capacity = 17, .m_length = 16, .m_data = "ButtonId.paddle4"};
static const lean_object* lp_padctl_instReprButtonId_repr___closed__46 = (const lean_object*)&lp_padctl_instReprButtonId_repr___closed__46_value;
static const lean_ctor_object lp_padctl_instReprButtonId_repr___closed__47_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*1 + 0, .m_other = 1, .m_tag = 3}, .m_objs = {((lean_object*)&lp_padctl_instReprButtonId_repr___closed__46_value)}};
static const lean_object* lp_padctl_instReprButtonId_repr___closed__47 = (const lean_object*)&lp_padctl_instReprButtonId_repr___closed__47_value;
static const lean_string_object lp_padctl_instReprButtonId_repr___closed__48_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 24, .m_capacity = 24, .m_length = 23, .m_data = "ButtonId.touchpadButton"};
static const lean_object* lp_padctl_instReprButtonId_repr___closed__48 = (const lean_object*)&lp_padctl_instReprButtonId_repr___closed__48_value;
static const lean_ctor_object lp_padctl_instReprButtonId_repr___closed__49_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*1 + 0, .m_other = 1, .m_tag = 3}, .m_objs = {((lean_object*)&lp_padctl_instReprButtonId_repr___closed__48_value)}};
static const lean_object* lp_padctl_instReprButtonId_repr___closed__49 = (const lean_object*)&lp_padctl_instReprButtonId_repr___closed__49_value;
static const lean_string_object lp_padctl_instReprButtonId_repr___closed__50_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 15, .m_capacity = 15, .m_length = 14, .m_data = "ButtonId.misc2"};
static const lean_object* lp_padctl_instReprButtonId_repr___closed__50 = (const lean_object*)&lp_padctl_instReprButtonId_repr___closed__50_value;
static const lean_ctor_object lp_padctl_instReprButtonId_repr___closed__51_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*1 + 0, .m_other = 1, .m_tag = 3}, .m_objs = {((lean_object*)&lp_padctl_instReprButtonId_repr___closed__50_value)}};
static const lean_object* lp_padctl_instReprButtonId_repr___closed__51 = (const lean_object*)&lp_padctl_instReprButtonId_repr___closed__51_value;
static const lean_string_object lp_padctl_instReprButtonId_repr___closed__52_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 15, .m_capacity = 15, .m_length = 14, .m_data = "ButtonId.misc3"};
static const lean_object* lp_padctl_instReprButtonId_repr___closed__52 = (const lean_object*)&lp_padctl_instReprButtonId_repr___closed__52_value;
static const lean_ctor_object lp_padctl_instReprButtonId_repr___closed__53_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*1 + 0, .m_other = 1, .m_tag = 3}, .m_objs = {((lean_object*)&lp_padctl_instReprButtonId_repr___closed__52_value)}};
static const lean_object* lp_padctl_instReprButtonId_repr___closed__53 = (const lean_object*)&lp_padctl_instReprButtonId_repr___closed__53_value;
static const lean_string_object lp_padctl_instReprButtonId_repr___closed__54_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 15, .m_capacity = 15, .m_length = 14, .m_data = "ButtonId.misc4"};
static const lean_object* lp_padctl_instReprButtonId_repr___closed__54 = (const lean_object*)&lp_padctl_instReprButtonId_repr___closed__54_value;
static const lean_ctor_object lp_padctl_instReprButtonId_repr___closed__55_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*1 + 0, .m_other = 1, .m_tag = 3}, .m_objs = {((lean_object*)&lp_padctl_instReprButtonId_repr___closed__54_value)}};
static const lean_object* lp_padctl_instReprButtonId_repr___closed__55 = (const lean_object*)&lp_padctl_instReprButtonId_repr___closed__55_value;
static const lean_string_object lp_padctl_instReprButtonId_repr___closed__56_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 15, .m_capacity = 15, .m_length = 14, .m_data = "ButtonId.misc5"};
static const lean_object* lp_padctl_instReprButtonId_repr___closed__56 = (const lean_object*)&lp_padctl_instReprButtonId_repr___closed__56_value;
static const lean_ctor_object lp_padctl_instReprButtonId_repr___closed__57_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*1 + 0, .m_other = 1, .m_tag = 3}, .m_objs = {((lean_object*)&lp_padctl_instReprButtonId_repr___closed__56_value)}};
static const lean_object* lp_padctl_instReprButtonId_repr___closed__57 = (const lean_object*)&lp_padctl_instReprButtonId_repr___closed__57_value;
static const lean_string_object lp_padctl_instReprButtonId_repr___closed__58_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 15, .m_capacity = 15, .m_length = 14, .m_data = "ButtonId.misc6"};
static const lean_object* lp_padctl_instReprButtonId_repr___closed__58 = (const lean_object*)&lp_padctl_instReprButtonId_repr___closed__58_value;
static const lean_ctor_object lp_padctl_instReprButtonId_repr___closed__59_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*1 + 0, .m_other = 1, .m_tag = 3}, .m_objs = {((lean_object*)&lp_padctl_instReprButtonId_repr___closed__58_value)}};
static const lean_object* lp_padctl_instReprButtonId_repr___closed__59 = (const lean_object*)&lp_padctl_instReprButtonId_repr___closed__59_value;
static const lean_string_object lp_padctl_instReprButtonId_repr___closed__60_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 15, .m_capacity = 15, .m_length = 14, .m_data = "ButtonId.misc7"};
static const lean_object* lp_padctl_instReprButtonId_repr___closed__60 = (const lean_object*)&lp_padctl_instReprButtonId_repr___closed__60_value;
static const lean_ctor_object lp_padctl_instReprButtonId_repr___closed__61_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*1 + 0, .m_other = 1, .m_tag = 3}, .m_objs = {((lean_object*)&lp_padctl_instReprButtonId_repr___closed__60_value)}};
static const lean_object* lp_padctl_instReprButtonId_repr___closed__61 = (const lean_object*)&lp_padctl_instReprButtonId_repr___closed__61_value;
static const lean_string_object lp_padctl_instReprButtonId_repr___closed__62_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 15, .m_capacity = 15, .m_length = 14, .m_data = "ButtonId.misc8"};
static const lean_object* lp_padctl_instReprButtonId_repr___closed__62 = (const lean_object*)&lp_padctl_instReprButtonId_repr___closed__62_value;
static const lean_ctor_object lp_padctl_instReprButtonId_repr___closed__63_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*1 + 0, .m_other = 1, .m_tag = 3}, .m_objs = {((lean_object*)&lp_padctl_instReprButtonId_repr___closed__62_value)}};
static const lean_object* lp_padctl_instReprButtonId_repr___closed__63 = (const lean_object*)&lp_padctl_instReprButtonId_repr___closed__63_value;
static const lean_string_object lp_padctl_instReprButtonId_repr___closed__64_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 15, .m_capacity = 15, .m_length = 14, .m_data = "ButtonId.misc9"};
static const lean_object* lp_padctl_instReprButtonId_repr___closed__64 = (const lean_object*)&lp_padctl_instReprButtonId_repr___closed__64_value;
static const lean_ctor_object lp_padctl_instReprButtonId_repr___closed__65_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*1 + 0, .m_other = 1, .m_tag = 3}, .m_objs = {((lean_object*)&lp_padctl_instReprButtonId_repr___closed__64_value)}};
static const lean_object* lp_padctl_instReprButtonId_repr___closed__65 = (const lean_object*)&lp_padctl_instReprButtonId_repr___closed__65_value;
static lean_once_cell_t lp_padctl_instReprButtonId_repr___closed__66_once = LEAN_ONCE_CELL_INITIALIZER;
static lean_object* lp_padctl_instReprButtonId_repr___closed__66;
static lean_once_cell_t lp_padctl_instReprButtonId_repr___closed__67_once = LEAN_ONCE_CELL_INITIALIZER;
static lean_object* lp_padctl_instReprButtonId_repr___closed__67;
uint8_t lean_nat_dec_le(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_instReprButtonId_repr(uint8_t, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_instReprButtonId_repr___boxed(lean_object*, lean_object*);
static const lean_closure_object lp_padctl_instReprButtonId___closed__0_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_closure_object) + sizeof(void*)*0, .m_other = 0, .m_tag = 245}, .m_fun = (void*)lp_padctl_instReprButtonId_repr___boxed, .m_arity = 2, .m_num_fixed = 0, .m_objs = {} };
static const lean_object* lp_padctl_instReprButtonId___closed__0 = (const lean_object*)&lp_padctl_instReprButtonId___closed__0_value;
LEAN_EXPORT const lean_object* lp_padctl_instReprButtonId = (const lean_object*)&lp_padctl_instReprButtonId___closed__0_value;
LEAN_EXPORT lean_object* lp_padctl_ButtonId_toNat(uint8_t);
LEAN_EXPORT lean_object* lp_padctl_ButtonId_toNat___boxed(lean_object*);
static lean_once_cell_t lp_padctl_dpadUpBit___closed__0_once = LEAN_ONCE_CELL_INITIALIZER;
static lean_object* lp_padctl_dpadUpBit___closed__0;
LEAN_EXPORT lean_object* lp_padctl_dpadUpBit;
static lean_once_cell_t lp_padctl_dpadDownBit___closed__0_once = LEAN_ONCE_CELL_INITIALIZER;
static lean_object* lp_padctl_dpadDownBit___closed__0;
LEAN_EXPORT lean_object* lp_padctl_dpadDownBit;
static lean_once_cell_t lp_padctl_dpadLeftBit___closed__0_once = LEAN_ONCE_CELL_INITIALIZER;
static lean_object* lp_padctl_dpadLeftBit___closed__0;
LEAN_EXPORT lean_object* lp_padctl_dpadLeftBit;
static lean_once_cell_t lp_padctl_dpadRightBit___closed__0_once = LEAN_ONCE_CELL_INITIALIZER;
static lean_object* lp_padctl_dpadRightBit___closed__0;
LEAN_EXPORT lean_object* lp_padctl_dpadRightBit;
lean_object* lean_nat_pow(lean_object*, lean_object*);
lean_object* lean_nat_div(lean_object*, lean_object*);
lean_object* lean_nat_mod(lean_object*, lean_object*);
LEAN_EXPORT uint8_t lp_padctl_testBit(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_testBit___boxed(lean_object*, lean_object*);
lean_object* lean_int_sub(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_synthesizeDpadAxes(lean_object*);
LEAN_EXPORT lean_object* lp_padctl_synthesizeDpadAxes___boxed(lean_object*);
LEAN_EXPORT uint8_t lp_padctl_instDecidableEqGamepadState_decEq(lean_object* x_1, lean_object* x_2) {
_start:
{
lean_object* x_3; lean_object* x_4; lean_object* x_5; lean_object* x_6; lean_object* x_7; lean_object* x_8; lean_object* x_9; lean_object* x_10; lean_object* x_11; lean_object* x_12; lean_object* x_13; lean_object* x_14; lean_object* x_15; lean_object* x_16; lean_object* x_17; lean_object* x_18; lean_object* x_19; lean_object* x_20; lean_object* x_21; uint8_t x_22; uint8_t x_23; lean_object* x_24; lean_object* x_25; lean_object* x_26; lean_object* x_27; lean_object* x_28; lean_object* x_29; lean_object* x_30; lean_object* x_31; lean_object* x_32; lean_object* x_33; lean_object* x_34; lean_object* x_35; lean_object* x_36; lean_object* x_37; lean_object* x_38; lean_object* x_39; lean_object* x_40; lean_object* x_41; lean_object* x_42; lean_object* x_43; uint8_t x_44; uint8_t x_45; lean_object* x_46; uint8_t x_50; 
x_3 = lean_ctor_get(x_1, 0);
x_4 = lean_ctor_get(x_1, 1);
x_5 = lean_ctor_get(x_1, 2);
x_6 = lean_ctor_get(x_1, 3);
x_7 = lean_ctor_get(x_1, 4);
x_8 = lean_ctor_get(x_1, 5);
x_9 = lean_ctor_get(x_1, 6);
x_10 = lean_ctor_get(x_1, 7);
x_11 = lean_ctor_get(x_1, 8);
x_12 = lean_ctor_get(x_1, 9);
x_13 = lean_ctor_get(x_1, 10);
x_14 = lean_ctor_get(x_1, 11);
x_15 = lean_ctor_get(x_1, 12);
x_16 = lean_ctor_get(x_1, 13);
x_17 = lean_ctor_get(x_1, 14);
x_18 = lean_ctor_get(x_1, 15);
x_19 = lean_ctor_get(x_1, 16);
x_20 = lean_ctor_get(x_1, 17);
x_21 = lean_ctor_get(x_1, 18);
x_22 = lean_ctor_get_uint8(x_1, sizeof(void*)*20);
x_23 = lean_ctor_get_uint8(x_1, sizeof(void*)*20 + 1);
x_24 = lean_ctor_get(x_1, 19);
x_25 = lean_ctor_get(x_2, 0);
x_26 = lean_ctor_get(x_2, 1);
x_27 = lean_ctor_get(x_2, 2);
x_28 = lean_ctor_get(x_2, 3);
x_29 = lean_ctor_get(x_2, 4);
x_30 = lean_ctor_get(x_2, 5);
x_31 = lean_ctor_get(x_2, 6);
x_32 = lean_ctor_get(x_2, 7);
x_33 = lean_ctor_get(x_2, 8);
x_34 = lean_ctor_get(x_2, 9);
x_35 = lean_ctor_get(x_2, 10);
x_36 = lean_ctor_get(x_2, 11);
x_37 = lean_ctor_get(x_2, 12);
x_38 = lean_ctor_get(x_2, 13);
x_39 = lean_ctor_get(x_2, 14);
x_40 = lean_ctor_get(x_2, 15);
x_41 = lean_ctor_get(x_2, 16);
x_42 = lean_ctor_get(x_2, 17);
x_43 = lean_ctor_get(x_2, 18);
x_44 = lean_ctor_get_uint8(x_2, sizeof(void*)*20);
x_45 = lean_ctor_get_uint8(x_2, sizeof(void*)*20 + 1);
x_46 = lean_ctor_get(x_2, 19);
x_50 = lean_int_dec_eq(x_3, x_25);
if (x_50 == 0)
{
return x_50;
}
else
{
uint8_t x_51; 
x_51 = lean_int_dec_eq(x_4, x_26);
if (x_51 == 0)
{
return x_51;
}
else
{
uint8_t x_52; 
x_52 = lean_int_dec_eq(x_5, x_27);
if (x_52 == 0)
{
return x_52;
}
else
{
uint8_t x_53; 
x_53 = lean_int_dec_eq(x_6, x_28);
if (x_53 == 0)
{
return x_53;
}
else
{
uint8_t x_54; 
x_54 = lean_nat_dec_eq(x_7, x_29);
if (x_54 == 0)
{
return x_54;
}
else
{
uint8_t x_55; 
x_55 = lean_nat_dec_eq(x_8, x_30);
if (x_55 == 0)
{
return x_55;
}
else
{
uint8_t x_56; 
x_56 = lean_nat_dec_eq(x_9, x_31);
if (x_56 == 0)
{
return x_56;
}
else
{
uint8_t x_57; 
x_57 = lean_int_dec_eq(x_10, x_32);
if (x_57 == 0)
{
return x_57;
}
else
{
uint8_t x_58; 
x_58 = lean_int_dec_eq(x_11, x_33);
if (x_58 == 0)
{
return x_58;
}
else
{
uint8_t x_59; 
x_59 = lean_int_dec_eq(x_12, x_34);
if (x_59 == 0)
{
return x_59;
}
else
{
uint8_t x_60; 
x_60 = lean_int_dec_eq(x_13, x_35);
if (x_60 == 0)
{
return x_60;
}
else
{
uint8_t x_61; 
x_61 = lean_int_dec_eq(x_14, x_36);
if (x_61 == 0)
{
return x_61;
}
else
{
uint8_t x_62; 
x_62 = lean_int_dec_eq(x_15, x_37);
if (x_62 == 0)
{
return x_62;
}
else
{
uint8_t x_63; 
x_63 = lean_int_dec_eq(x_16, x_38);
if (x_63 == 0)
{
return x_63;
}
else
{
uint8_t x_64; 
x_64 = lean_int_dec_eq(x_17, x_39);
if (x_64 == 0)
{
return x_64;
}
else
{
uint8_t x_65; 
x_65 = lean_int_dec_eq(x_18, x_40);
if (x_65 == 0)
{
return x_65;
}
else
{
uint8_t x_66; 
x_66 = lean_int_dec_eq(x_19, x_41);
if (x_66 == 0)
{
return x_66;
}
else
{
uint8_t x_67; 
x_67 = lean_int_dec_eq(x_20, x_42);
if (x_67 == 0)
{
return x_67;
}
else
{
uint8_t x_68; 
x_68 = lean_int_dec_eq(x_21, x_43);
if (x_68 == 0)
{
return x_68;
}
else
{
if (x_22 == 0)
{
if (x_44 == 0)
{
goto block_49;
}
else
{
return x_22;
}
}
else
{
if (x_44 == 0)
{
return x_44;
}
else
{
goto block_49;
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
block_49:
{
if (x_23 == 0)
{
if (x_45 == 0)
{
uint8_t x_47; 
x_47 = lean_nat_dec_eq(x_24, x_46);
return x_47;
}
else
{
return x_23;
}
}
else
{
if (x_45 == 0)
{
return x_45;
}
else
{
uint8_t x_48; 
x_48 = lean_nat_dec_eq(x_24, x_46);
return x_48;
}
}
}
}
}
LEAN_EXPORT lean_object* lp_padctl_instDecidableEqGamepadState_decEq___boxed(lean_object* x_1, lean_object* x_2) {
_start:
{
uint8_t x_3; lean_object* x_4; 
x_3 = lp_padctl_instDecidableEqGamepadState_decEq(x_1, x_2);
lean_dec_ref(x_2);
lean_dec_ref(x_1);
x_4 = lean_box(x_3);
return x_4;
}
}
LEAN_EXPORT uint8_t lp_padctl_instDecidableEqGamepadState(lean_object* x_1, lean_object* x_2) {
_start:
{
uint8_t x_3; 
x_3 = lp_padctl_instDecidableEqGamepadState_decEq(x_1, x_2);
return x_3;
}
}
LEAN_EXPORT lean_object* lp_padctl_instDecidableEqGamepadState___boxed(lean_object* x_1, lean_object* x_2) {
_start:
{
uint8_t x_3; lean_object* x_4; 
x_3 = lp_padctl_instDecidableEqGamepadState(x_1, x_2);
lean_dec_ref(x_2);
lean_dec_ref(x_1);
x_4 = lean_box(x_3);
return x_4;
}
}
static lean_object* _init_lp_padctl_instReprGamepadState_repr___redArg___closed__8(void) {
_start:
{
lean_object* x_1; lean_object* x_2; 
x_1 = lean_unsigned_to_nat(17u);
x_2 = lean_nat_to_int(x_1);
return x_2;
}
}
static lean_object* _init_lp_padctl_instReprGamepadState_repr___redArg___closed__14(void) {
_start:
{
lean_object* x_1; lean_object* x_2; 
x_1 = ((lean_object*)(lp_padctl_instReprGamepadState_repr___redArg___closed__0));
x_2 = lean_string_length(x_1);
return x_2;
}
}
static lean_object* _init_lp_padctl_instReprGamepadState_repr___redArg___closed__15(void) {
_start:
{
lean_object* x_1; lean_object* x_2; 
x_1 = lean_obj_once(&lp_padctl_instReprGamepadState_repr___redArg___closed__14, &lp_padctl_instReprGamepadState_repr___redArg___closed__14_once, _init_lp_padctl_instReprGamepadState_repr___redArg___closed__14);
x_2 = lean_nat_to_int(x_1);
return x_2;
}
}
static lean_object* _init_lp_padctl_instReprGamepadState_repr___redArg___closed__20(void) {
_start:
{
lean_object* x_1; lean_object* x_2; 
x_1 = lean_unsigned_to_nat(0u);
x_2 = lean_nat_to_int(x_1);
return x_2;
}
}
static lean_object* _init_lp_padctl_instReprGamepadState_repr___redArg___closed__27(void) {
_start:
{
lean_object* x_1; lean_object* x_2; 
x_1 = lean_unsigned_to_nat(12u);
x_2 = lean_nat_to_int(x_1);
return x_2;
}
}
static lean_object* _init_lp_padctl_instReprGamepadState_repr___redArg___closed__43(void) {
_start:
{
lean_object* x_1; lean_object* x_2; 
x_1 = lean_unsigned_to_nat(6u);
x_2 = lean_nat_to_int(x_1);
return x_2;
}
}
static lean_object* _init_lp_padctl_instReprGamepadState_repr___redArg___closed__50(void) {
_start:
{
lean_object* x_1; lean_object* x_2; 
x_1 = lean_unsigned_to_nat(11u);
x_2 = lean_nat_to_int(x_1);
return x_2;
}
}
static lean_object* _init_lp_padctl_instReprGamepadState_repr___redArg___closed__53(void) {
_start:
{
lean_object* x_1; lean_object* x_2; 
x_1 = lean_unsigned_to_nat(10u);
x_2 = lean_nat_to_int(x_1);
return x_2;
}
}
LEAN_EXPORT lean_object* lp_padctl_instReprGamepadState_repr___redArg(lean_object* x_1) {
_start:
{
lean_object* x_2; lean_object* x_3; lean_object* x_4; lean_object* x_5; lean_object* x_6; lean_object* x_7; lean_object* x_8; lean_object* x_9; lean_object* x_10; lean_object* x_11; lean_object* x_12; lean_object* x_13; lean_object* x_14; lean_object* x_15; lean_object* x_16; lean_object* x_17; lean_object* x_18; lean_object* x_19; lean_object* x_20; uint8_t x_21; uint8_t x_22; lean_object* x_23; lean_object* x_24; lean_object* x_25; lean_object* x_26; uint8_t x_27; uint8_t x_28; uint8_t x_29; lean_object* x_30; lean_object* x_31; lean_object* x_32; lean_object* x_33; lean_object* x_74; lean_object* x_75; lean_object* x_76; lean_object* x_77; uint8_t x_78; uint8_t x_79; uint8_t x_80; lean_object* x_81; lean_object* x_82; lean_object* x_83; lean_object* x_101; lean_object* x_102; lean_object* x_103; uint8_t x_104; lean_object* x_105; uint8_t x_106; uint8_t x_107; lean_object* x_108; lean_object* x_109; lean_object* x_110; lean_object* x_111; lean_object* x_129; lean_object* x_130; lean_object* x_131; uint8_t x_132; lean_object* x_133; uint8_t x_134; lean_object* x_135; uint8_t x_136; lean_object* x_137; lean_object* x_138; lean_object* x_139; lean_object* x_140; lean_object* x_158; lean_object* x_159; lean_object* x_160; lean_object* x_161; uint8_t x_162; lean_object* x_163; uint8_t x_164; uint8_t x_165; lean_object* x_166; lean_object* x_167; lean_object* x_168; lean_object* x_169; lean_object* x_170; lean_object* x_189; lean_object* x_190; lean_object* x_191; lean_object* x_192; lean_object* x_193; uint8_t x_194; lean_object* x_195; lean_object* x_196; uint8_t x_197; uint8_t x_198; lean_object* x_199; lean_object* x_200; lean_object* x_201; lean_object* x_202; lean_object* x_220; lean_object* x_221; lean_object* x_222; lean_object* x_223; lean_object* x_224; uint8_t x_225; lean_object* x_226; lean_object* x_227; uint8_t x_228; lean_object* x_229; uint8_t x_230; lean_object* x_231; lean_object* x_232; lean_object* x_233; lean_object* x_234; lean_object* x_252; lean_object* x_253; lean_object* x_254; lean_object* x_255; lean_object* x_256; lean_object* x_257; lean_object* x_258; uint8_t x_259; lean_object* x_260; lean_object* x_261; uint8_t x_262; lean_object* x_263; lean_object* x_264; uint8_t x_265; lean_object* x_266; lean_object* x_267; lean_object* x_268; lean_object* x_286; lean_object* x_287; lean_object* x_288; lean_object* x_289; lean_object* x_290; lean_object* x_291; lean_object* x_292; uint8_t x_293; lean_object* x_294; lean_object* x_295; uint8_t x_296; lean_object* x_297; lean_object* x_298; uint8_t x_299; lean_object* x_300; lean_object* x_301; lean_object* x_302; lean_object* x_303; lean_object* x_321; lean_object* x_322; lean_object* x_323; lean_object* x_324; lean_object* x_325; lean_object* x_326; lean_object* x_327; lean_object* x_328; lean_object* x_329; uint8_t x_330; lean_object* x_331; lean_object* x_332; uint8_t x_333; lean_object* x_334; lean_object* x_335; uint8_t x_336; lean_object* x_337; lean_object* x_338; lean_object* x_339; lean_object* x_357; lean_object* x_358; lean_object* x_359; lean_object* x_360; lean_object* x_361; lean_object* x_362; lean_object* x_363; lean_object* x_364; uint8_t x_365; lean_object* x_366; lean_object* x_367; uint8_t x_368; lean_object* x_369; lean_object* x_370; uint8_t x_371; lean_object* x_372; lean_object* x_373; lean_object* x_374; lean_object* x_375; lean_object* x_376; lean_object* x_394; lean_object* x_395; lean_object* x_396; lean_object* x_397; lean_object* x_398; lean_object* x_399; lean_object* x_400; lean_object* x_401; lean_object* x_402; uint8_t x_403; lean_object* x_404; lean_object* x_405; uint8_t x_406; lean_object* x_407; lean_object* x_408; lean_object* x_409; uint8_t x_410; lean_object* x_411; lean_object* x_412; lean_object* x_413; lean_object* x_414; lean_object* x_432; lean_object* x_433; lean_object* x_434; uint8_t x_435; lean_object* x_436; lean_object* x_437; lean_object* x_438; lean_object* x_488; uint8_t x_489; lean_object* x_490; lean_object* x_491; lean_object* x_492; lean_object* x_510; lean_object* x_511; uint8_t x_512; lean_object* x_513; lean_object* x_514; lean_object* x_532; lean_object* x_553; lean_object* x_554; uint8_t x_555; 
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
x_8 = lean_ctor_get(x_1, 6);
lean_inc(x_8);
x_9 = lean_ctor_get(x_1, 7);
lean_inc(x_9);
x_10 = lean_ctor_get(x_1, 8);
lean_inc(x_10);
x_11 = lean_ctor_get(x_1, 9);
lean_inc(x_11);
x_12 = lean_ctor_get(x_1, 10);
lean_inc(x_12);
x_13 = lean_ctor_get(x_1, 11);
lean_inc(x_13);
x_14 = lean_ctor_get(x_1, 12);
lean_inc(x_14);
x_15 = lean_ctor_get(x_1, 13);
lean_inc(x_15);
x_16 = lean_ctor_get(x_1, 14);
lean_inc(x_16);
x_17 = lean_ctor_get(x_1, 15);
lean_inc(x_17);
x_18 = lean_ctor_get(x_1, 16);
lean_inc(x_18);
x_19 = lean_ctor_get(x_1, 17);
lean_inc(x_19);
x_20 = lean_ctor_get(x_1, 18);
lean_inc(x_20);
x_21 = lean_ctor_get_uint8(x_1, sizeof(void*)*20);
x_22 = lean_ctor_get_uint8(x_1, sizeof(void*)*20 + 1);
x_23 = lean_ctor_get(x_1, 19);
lean_inc(x_23);
lean_dec_ref(x_1);
x_24 = ((lean_object*)(lp_padctl_instReprGamepadState_repr___redArg___closed__5));
x_432 = ((lean_object*)(lp_padctl_instReprGamepadState_repr___redArg___closed__42));
x_433 = lean_obj_once(&lp_padctl_instReprGamepadState_repr___redArg___closed__43, &lp_padctl_instReprGamepadState_repr___redArg___closed__43_once, _init_lp_padctl_instReprGamepadState_repr___redArg___closed__43);
x_553 = lean_unsigned_to_nat(0u);
x_554 = lean_obj_once(&lp_padctl_instReprGamepadState_repr___redArg___closed__20, &lp_padctl_instReprGamepadState_repr___redArg___closed__20_once, _init_lp_padctl_instReprGamepadState_repr___redArg___closed__20);
x_555 = lean_int_dec_lt(x_2, x_554);
if (x_555 == 0)
{
lean_object* x_556; lean_object* x_557; 
x_556 = l_Int_repr(x_2);
lean_dec(x_2);
x_557 = lean_alloc_ctor(3, 1, 0);
lean_ctor_set(x_557, 0, x_556);
x_532 = x_557;
goto block_552;
}
else
{
lean_object* x_558; lean_object* x_559; lean_object* x_560; 
x_558 = l_Int_repr(x_2);
lean_dec(x_2);
x_559 = lean_alloc_ctor(3, 1, 0);
lean_ctor_set(x_559, 0, x_558);
x_560 = l_Repr_addAppParen(x_559, x_553);
x_532 = x_560;
goto block_552;
}
block_73:
{
lean_object* x_34; lean_object* x_35; lean_object* x_36; lean_object* x_37; lean_object* x_38; lean_object* x_39; lean_object* x_40; lean_object* x_41; lean_object* x_42; lean_object* x_43; lean_object* x_44; lean_object* x_45; lean_object* x_46; lean_object* x_47; lean_object* x_48; lean_object* x_49; lean_object* x_50; lean_object* x_51; lean_object* x_52; lean_object* x_53; lean_object* x_54; lean_object* x_55; lean_object* x_56; lean_object* x_57; lean_object* x_58; lean_object* x_59; lean_object* x_60; lean_object* x_61; lean_object* x_62; lean_object* x_63; lean_object* x_64; lean_object* x_65; lean_object* x_66; lean_object* x_67; lean_object* x_68; lean_object* x_69; lean_object* x_70; lean_object* x_71; lean_object* x_72; 
x_34 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_34, 0, x_31);
lean_ctor_set(x_34, 1, x_33);
x_35 = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(x_35, 0, x_34);
lean_ctor_set_uint8(x_35, sizeof(void*)*1, x_27);
x_36 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_36, 0, x_32);
lean_ctor_set(x_36, 1, x_35);
lean_inc(x_25);
x_37 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_37, 0, x_36);
lean_ctor_set(x_37, 1, x_25);
lean_inc(x_30);
x_38 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_38, 0, x_37);
lean_ctor_set(x_38, 1, x_30);
x_39 = ((lean_object*)(lp_padctl_instReprGamepadState_repr___redArg___closed__7));
x_40 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_40, 0, x_38);
lean_ctor_set(x_40, 1, x_39);
x_41 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_41, 0, x_40);
lean_ctor_set(x_41, 1, x_24);
x_42 = lean_obj_once(&lp_padctl_instReprGamepadState_repr___redArg___closed__8, &lp_padctl_instReprGamepadState_repr___redArg___closed__8_once, _init_lp_padctl_instReprGamepadState_repr___redArg___closed__8);
x_43 = l_Bool_repr___redArg(x_29);
x_44 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_44, 0, x_42);
lean_ctor_set(x_44, 1, x_43);
x_45 = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(x_45, 0, x_44);
lean_ctor_set_uint8(x_45, sizeof(void*)*1, x_27);
x_46 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_46, 0, x_41);
lean_ctor_set(x_46, 1, x_45);
lean_inc(x_25);
x_47 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_47, 0, x_46);
lean_ctor_set(x_47, 1, x_25);
lean_inc(x_30);
x_48 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_48, 0, x_47);
lean_ctor_set(x_48, 1, x_30);
x_49 = ((lean_object*)(lp_padctl_instReprGamepadState_repr___redArg___closed__10));
x_50 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_50, 0, x_48);
lean_ctor_set(x_50, 1, x_49);
x_51 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_51, 0, x_50);
lean_ctor_set(x_51, 1, x_24);
x_52 = l_Bool_repr___redArg(x_28);
x_53 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_53, 0, x_42);
lean_ctor_set(x_53, 1, x_52);
x_54 = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(x_54, 0, x_53);
lean_ctor_set_uint8(x_54, sizeof(void*)*1, x_27);
x_55 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_55, 0, x_51);
lean_ctor_set(x_55, 1, x_54);
x_56 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_56, 0, x_55);
lean_ctor_set(x_56, 1, x_25);
x_57 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_57, 0, x_56);
lean_ctor_set(x_57, 1, x_30);
x_58 = ((lean_object*)(lp_padctl_instReprGamepadState_repr___redArg___closed__12));
x_59 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_59, 0, x_57);
lean_ctor_set(x_59, 1, x_58);
x_60 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_60, 0, x_59);
lean_ctor_set(x_60, 1, x_24);
x_61 = l_Nat_reprFast(x_26);
x_62 = lean_alloc_ctor(3, 1, 0);
lean_ctor_set(x_62, 0, x_61);
x_63 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_63, 0, x_42);
lean_ctor_set(x_63, 1, x_62);
x_64 = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(x_64, 0, x_63);
lean_ctor_set_uint8(x_64, sizeof(void*)*1, x_27);
x_65 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_65, 0, x_60);
lean_ctor_set(x_65, 1, x_64);
x_66 = lean_obj_once(&lp_padctl_instReprGamepadState_repr___redArg___closed__15, &lp_padctl_instReprGamepadState_repr___redArg___closed__15_once, _init_lp_padctl_instReprGamepadState_repr___redArg___closed__15);
x_67 = ((lean_object*)(lp_padctl_instReprGamepadState_repr___redArg___closed__16));
x_68 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_68, 0, x_67);
lean_ctor_set(x_68, 1, x_65);
x_69 = ((lean_object*)(lp_padctl_instReprGamepadState_repr___redArg___closed__17));
x_70 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_70, 0, x_68);
lean_ctor_set(x_70, 1, x_69);
x_71 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_71, 0, x_66);
lean_ctor_set(x_71, 1, x_70);
x_72 = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(x_72, 0, x_71);
lean_ctor_set_uint8(x_72, sizeof(void*)*1, x_27);
return x_72;
}
block_100:
{
lean_object* x_84; lean_object* x_85; lean_object* x_86; lean_object* x_87; lean_object* x_88; lean_object* x_89; lean_object* x_90; lean_object* x_91; lean_object* x_92; lean_object* x_93; uint8_t x_94; 
lean_inc(x_82);
x_84 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_84, 0, x_82);
lean_ctor_set(x_84, 1, x_83);
x_85 = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(x_85, 0, x_84);
lean_ctor_set_uint8(x_85, sizeof(void*)*1, x_78);
x_86 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_86, 0, x_77);
lean_ctor_set(x_86, 1, x_85);
lean_inc(x_74);
x_87 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_87, 0, x_86);
lean_ctor_set(x_87, 1, x_74);
lean_inc(x_81);
x_88 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_88, 0, x_87);
lean_ctor_set(x_88, 1, x_81);
x_89 = ((lean_object*)(lp_padctl_instReprGamepadState_repr___redArg___closed__19));
x_90 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_90, 0, x_88);
lean_ctor_set(x_90, 1, x_89);
x_91 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_91, 0, x_90);
lean_ctor_set(x_91, 1, x_24);
x_92 = lean_unsigned_to_nat(0u);
x_93 = lean_obj_once(&lp_padctl_instReprGamepadState_repr___redArg___closed__20, &lp_padctl_instReprGamepadState_repr___redArg___closed__20_once, _init_lp_padctl_instReprGamepadState_repr___redArg___closed__20);
x_94 = lean_int_dec_lt(x_75, x_93);
if (x_94 == 0)
{
lean_object* x_95; lean_object* x_96; 
x_95 = l_Int_repr(x_75);
lean_dec(x_75);
x_96 = lean_alloc_ctor(3, 1, 0);
lean_ctor_set(x_96, 0, x_95);
x_25 = x_74;
x_26 = x_76;
x_27 = x_78;
x_28 = x_79;
x_29 = x_80;
x_30 = x_81;
x_31 = x_82;
x_32 = x_91;
x_33 = x_96;
goto block_73;
}
else
{
lean_object* x_97; lean_object* x_98; lean_object* x_99; 
x_97 = l_Int_repr(x_75);
lean_dec(x_75);
x_98 = lean_alloc_ctor(3, 1, 0);
lean_ctor_set(x_98, 0, x_97);
x_99 = l_Repr_addAppParen(x_98, x_92);
x_25 = x_74;
x_26 = x_76;
x_27 = x_78;
x_28 = x_79;
x_29 = x_80;
x_30 = x_81;
x_31 = x_82;
x_32 = x_91;
x_33 = x_99;
goto block_73;
}
}
block_128:
{
lean_object* x_112; lean_object* x_113; lean_object* x_114; lean_object* x_115; lean_object* x_116; lean_object* x_117; lean_object* x_118; lean_object* x_119; lean_object* x_120; lean_object* x_121; uint8_t x_122; 
lean_inc(x_109);
x_112 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_112, 0, x_109);
lean_ctor_set(x_112, 1, x_111);
x_113 = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(x_113, 0, x_112);
lean_ctor_set_uint8(x_113, sizeof(void*)*1, x_104);
x_114 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_114, 0, x_110);
lean_ctor_set(x_114, 1, x_113);
lean_inc(x_101);
x_115 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_115, 0, x_114);
lean_ctor_set(x_115, 1, x_101);
lean_inc(x_108);
x_116 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_116, 0, x_115);
lean_ctor_set(x_116, 1, x_108);
x_117 = ((lean_object*)(lp_padctl_instReprGamepadState_repr___redArg___closed__22));
x_118 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_118, 0, x_116);
lean_ctor_set(x_118, 1, x_117);
x_119 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_119, 0, x_118);
lean_ctor_set(x_119, 1, x_24);
x_120 = lean_unsigned_to_nat(0u);
x_121 = lean_obj_once(&lp_padctl_instReprGamepadState_repr___redArg___closed__20, &lp_padctl_instReprGamepadState_repr___redArg___closed__20_once, _init_lp_padctl_instReprGamepadState_repr___redArg___closed__20);
x_122 = lean_int_dec_lt(x_105, x_121);
if (x_122 == 0)
{
lean_object* x_123; lean_object* x_124; 
x_123 = l_Int_repr(x_105);
lean_dec(x_105);
x_124 = lean_alloc_ctor(3, 1, 0);
lean_ctor_set(x_124, 0, x_123);
x_74 = x_101;
x_75 = x_103;
x_76 = x_102;
x_77 = x_119;
x_78 = x_104;
x_79 = x_106;
x_80 = x_107;
x_81 = x_108;
x_82 = x_109;
x_83 = x_124;
goto block_100;
}
else
{
lean_object* x_125; lean_object* x_126; lean_object* x_127; 
x_125 = l_Int_repr(x_105);
lean_dec(x_105);
x_126 = lean_alloc_ctor(3, 1, 0);
lean_ctor_set(x_126, 0, x_125);
x_127 = l_Repr_addAppParen(x_126, x_120);
x_74 = x_101;
x_75 = x_103;
x_76 = x_102;
x_77 = x_119;
x_78 = x_104;
x_79 = x_106;
x_80 = x_107;
x_81 = x_108;
x_82 = x_109;
x_83 = x_127;
goto block_100;
}
}
block_157:
{
lean_object* x_141; lean_object* x_142; lean_object* x_143; lean_object* x_144; lean_object* x_145; lean_object* x_146; lean_object* x_147; lean_object* x_148; lean_object* x_149; lean_object* x_150; uint8_t x_151; 
lean_inc(x_138);
x_141 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_141, 0, x_138);
lean_ctor_set(x_141, 1, x_140);
x_142 = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(x_142, 0, x_141);
lean_ctor_set_uint8(x_142, sizeof(void*)*1, x_132);
x_143 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_143, 0, x_139);
lean_ctor_set(x_143, 1, x_142);
lean_inc(x_129);
x_144 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_144, 0, x_143);
lean_ctor_set(x_144, 1, x_129);
lean_inc(x_137);
x_145 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_145, 0, x_144);
lean_ctor_set(x_145, 1, x_137);
x_146 = ((lean_object*)(lp_padctl_instReprGamepadState_repr___redArg___closed__24));
x_147 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_147, 0, x_145);
lean_ctor_set(x_147, 1, x_146);
x_148 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_148, 0, x_147);
lean_ctor_set(x_148, 1, x_24);
x_149 = lean_unsigned_to_nat(0u);
x_150 = lean_obj_once(&lp_padctl_instReprGamepadState_repr___redArg___closed__20, &lp_padctl_instReprGamepadState_repr___redArg___closed__20_once, _init_lp_padctl_instReprGamepadState_repr___redArg___closed__20);
x_151 = lean_int_dec_lt(x_135, x_150);
if (x_151 == 0)
{
lean_object* x_152; lean_object* x_153; 
x_152 = l_Int_repr(x_135);
lean_dec(x_135);
x_153 = lean_alloc_ctor(3, 1, 0);
lean_ctor_set(x_153, 0, x_152);
x_101 = x_129;
x_102 = x_131;
x_103 = x_130;
x_104 = x_132;
x_105 = x_133;
x_106 = x_134;
x_107 = x_136;
x_108 = x_137;
x_109 = x_138;
x_110 = x_148;
x_111 = x_153;
goto block_128;
}
else
{
lean_object* x_154; lean_object* x_155; lean_object* x_156; 
x_154 = l_Int_repr(x_135);
lean_dec(x_135);
x_155 = lean_alloc_ctor(3, 1, 0);
lean_ctor_set(x_155, 0, x_154);
x_156 = l_Repr_addAppParen(x_155, x_149);
x_101 = x_129;
x_102 = x_131;
x_103 = x_130;
x_104 = x_132;
x_105 = x_133;
x_106 = x_134;
x_107 = x_136;
x_108 = x_137;
x_109 = x_138;
x_110 = x_148;
x_111 = x_156;
goto block_128;
}
}
block_188:
{
lean_object* x_171; lean_object* x_172; lean_object* x_173; lean_object* x_174; lean_object* x_175; lean_object* x_176; lean_object* x_177; lean_object* x_178; lean_object* x_179; lean_object* x_180; lean_object* x_181; uint8_t x_182; 
x_171 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_171, 0, x_168);
lean_ctor_set(x_171, 1, x_170);
x_172 = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(x_172, 0, x_171);
lean_ctor_set_uint8(x_172, sizeof(void*)*1, x_162);
x_173 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_173, 0, x_169);
lean_ctor_set(x_173, 1, x_172);
lean_inc(x_158);
x_174 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_174, 0, x_173);
lean_ctor_set(x_174, 1, x_158);
lean_inc(x_167);
x_175 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_175, 0, x_174);
lean_ctor_set(x_175, 1, x_167);
x_176 = ((lean_object*)(lp_padctl_instReprGamepadState_repr___redArg___closed__26));
x_177 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_177, 0, x_175);
lean_ctor_set(x_177, 1, x_176);
x_178 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_178, 0, x_177);
lean_ctor_set(x_178, 1, x_24);
x_179 = lean_obj_once(&lp_padctl_instReprGamepadState_repr___redArg___closed__27, &lp_padctl_instReprGamepadState_repr___redArg___closed__27_once, _init_lp_padctl_instReprGamepadState_repr___redArg___closed__27);
x_180 = lean_unsigned_to_nat(0u);
x_181 = lean_obj_once(&lp_padctl_instReprGamepadState_repr___redArg___closed__20, &lp_padctl_instReprGamepadState_repr___redArg___closed__20_once, _init_lp_padctl_instReprGamepadState_repr___redArg___closed__20);
x_182 = lean_int_dec_lt(x_159, x_181);
if (x_182 == 0)
{
lean_object* x_183; lean_object* x_184; 
x_183 = l_Int_repr(x_159);
lean_dec(x_159);
x_184 = lean_alloc_ctor(3, 1, 0);
lean_ctor_set(x_184, 0, x_183);
x_129 = x_158;
x_130 = x_161;
x_131 = x_160;
x_132 = x_162;
x_133 = x_163;
x_134 = x_164;
x_135 = x_166;
x_136 = x_165;
x_137 = x_167;
x_138 = x_179;
x_139 = x_178;
x_140 = x_184;
goto block_157;
}
else
{
lean_object* x_185; lean_object* x_186; lean_object* x_187; 
x_185 = l_Int_repr(x_159);
lean_dec(x_159);
x_186 = lean_alloc_ctor(3, 1, 0);
lean_ctor_set(x_186, 0, x_185);
x_187 = l_Repr_addAppParen(x_186, x_180);
x_129 = x_158;
x_130 = x_161;
x_131 = x_160;
x_132 = x_162;
x_133 = x_163;
x_134 = x_164;
x_135 = x_166;
x_136 = x_165;
x_137 = x_167;
x_138 = x_179;
x_139 = x_178;
x_140 = x_187;
goto block_157;
}
}
block_219:
{
lean_object* x_203; lean_object* x_204; lean_object* x_205; lean_object* x_206; lean_object* x_207; lean_object* x_208; lean_object* x_209; lean_object* x_210; lean_object* x_211; lean_object* x_212; uint8_t x_213; 
lean_inc(x_193);
x_203 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_203, 0, x_193);
lean_ctor_set(x_203, 1, x_202);
x_204 = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(x_204, 0, x_203);
lean_ctor_set_uint8(x_204, sizeof(void*)*1, x_194);
x_205 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_205, 0, x_192);
lean_ctor_set(x_205, 1, x_204);
lean_inc(x_189);
x_206 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_206, 0, x_205);
lean_ctor_set(x_206, 1, x_189);
lean_inc(x_200);
x_207 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_207, 0, x_206);
lean_ctor_set(x_207, 1, x_200);
x_208 = ((lean_object*)(lp_padctl_instReprGamepadState_repr___redArg___closed__29));
x_209 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_209, 0, x_207);
lean_ctor_set(x_209, 1, x_208);
x_210 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_210, 0, x_209);
lean_ctor_set(x_210, 1, x_24);
x_211 = lean_unsigned_to_nat(0u);
x_212 = lean_obj_once(&lp_padctl_instReprGamepadState_repr___redArg___closed__20, &lp_padctl_instReprGamepadState_repr___redArg___closed__20_once, _init_lp_padctl_instReprGamepadState_repr___redArg___closed__20);
x_213 = lean_int_dec_lt(x_201, x_212);
if (x_213 == 0)
{
lean_object* x_214; lean_object* x_215; 
x_214 = l_Int_repr(x_201);
lean_dec(x_201);
x_215 = lean_alloc_ctor(3, 1, 0);
lean_ctor_set(x_215, 0, x_214);
x_158 = x_189;
x_159 = x_190;
x_160 = x_195;
x_161 = x_191;
x_162 = x_194;
x_163 = x_196;
x_164 = x_197;
x_165 = x_198;
x_166 = x_199;
x_167 = x_200;
x_168 = x_193;
x_169 = x_210;
x_170 = x_215;
goto block_188;
}
else
{
lean_object* x_216; lean_object* x_217; lean_object* x_218; 
x_216 = l_Int_repr(x_201);
lean_dec(x_201);
x_217 = lean_alloc_ctor(3, 1, 0);
lean_ctor_set(x_217, 0, x_216);
x_218 = l_Repr_addAppParen(x_217, x_211);
x_158 = x_189;
x_159 = x_190;
x_160 = x_195;
x_161 = x_191;
x_162 = x_194;
x_163 = x_196;
x_164 = x_197;
x_165 = x_198;
x_166 = x_199;
x_167 = x_200;
x_168 = x_193;
x_169 = x_210;
x_170 = x_218;
goto block_188;
}
}
block_251:
{
lean_object* x_235; lean_object* x_236; lean_object* x_237; lean_object* x_238; lean_object* x_239; lean_object* x_240; lean_object* x_241; lean_object* x_242; lean_object* x_243; lean_object* x_244; uint8_t x_245; 
lean_inc(x_224);
x_235 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_235, 0, x_224);
lean_ctor_set(x_235, 1, x_234);
x_236 = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(x_236, 0, x_235);
lean_ctor_set_uint8(x_236, sizeof(void*)*1, x_225);
x_237 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_237, 0, x_223);
lean_ctor_set(x_237, 1, x_236);
lean_inc(x_220);
x_238 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_238, 0, x_237);
lean_ctor_set(x_238, 1, x_220);
lean_inc(x_232);
x_239 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_239, 0, x_238);
lean_ctor_set(x_239, 1, x_232);
x_240 = ((lean_object*)(lp_padctl_instReprGamepadState_repr___redArg___closed__31));
x_241 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_241, 0, x_239);
lean_ctor_set(x_241, 1, x_240);
x_242 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_242, 0, x_241);
lean_ctor_set(x_242, 1, x_24);
x_243 = lean_unsigned_to_nat(0u);
x_244 = lean_obj_once(&lp_padctl_instReprGamepadState_repr___redArg___closed__20, &lp_padctl_instReprGamepadState_repr___redArg___closed__20_once, _init_lp_padctl_instReprGamepadState_repr___redArg___closed__20);
x_245 = lean_int_dec_lt(x_229, x_244);
if (x_245 == 0)
{
lean_object* x_246; lean_object* x_247; 
x_246 = l_Int_repr(x_229);
lean_dec(x_229);
x_247 = lean_alloc_ctor(3, 1, 0);
lean_ctor_set(x_247, 0, x_246);
x_189 = x_220;
x_190 = x_221;
x_191 = x_222;
x_192 = x_242;
x_193 = x_224;
x_194 = x_225;
x_195 = x_226;
x_196 = x_227;
x_197 = x_228;
x_198 = x_230;
x_199 = x_231;
x_200 = x_232;
x_201 = x_233;
x_202 = x_247;
goto block_219;
}
else
{
lean_object* x_248; lean_object* x_249; lean_object* x_250; 
x_248 = l_Int_repr(x_229);
lean_dec(x_229);
x_249 = lean_alloc_ctor(3, 1, 0);
lean_ctor_set(x_249, 0, x_248);
x_250 = l_Repr_addAppParen(x_249, x_243);
x_189 = x_220;
x_190 = x_221;
x_191 = x_222;
x_192 = x_242;
x_193 = x_224;
x_194 = x_225;
x_195 = x_226;
x_196 = x_227;
x_197 = x_228;
x_198 = x_230;
x_199 = x_231;
x_200 = x_232;
x_201 = x_233;
x_202 = x_250;
goto block_219;
}
}
block_285:
{
lean_object* x_269; lean_object* x_270; lean_object* x_271; lean_object* x_272; lean_object* x_273; lean_object* x_274; lean_object* x_275; lean_object* x_276; lean_object* x_277; lean_object* x_278; uint8_t x_279; 
x_269 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_269, 0, x_257);
lean_ctor_set(x_269, 1, x_268);
x_270 = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(x_270, 0, x_269);
lean_ctor_set_uint8(x_270, sizeof(void*)*1, x_259);
x_271 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_271, 0, x_252);
lean_ctor_set(x_271, 1, x_270);
lean_inc(x_253);
x_272 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_272, 0, x_271);
lean_ctor_set(x_272, 1, x_253);
lean_inc(x_266);
x_273 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_273, 0, x_272);
lean_ctor_set(x_273, 1, x_266);
x_274 = ((lean_object*)(lp_padctl_instReprGamepadState_repr___redArg___closed__33));
x_275 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_275, 0, x_273);
lean_ctor_set(x_275, 1, x_274);
x_276 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_276, 0, x_275);
lean_ctor_set(x_276, 1, x_24);
x_277 = lean_unsigned_to_nat(0u);
x_278 = lean_obj_once(&lp_padctl_instReprGamepadState_repr___redArg___closed__20, &lp_padctl_instReprGamepadState_repr___redArg___closed__20_once, _init_lp_padctl_instReprGamepadState_repr___redArg___closed__20);
x_279 = lean_int_dec_lt(x_254, x_278);
if (x_279 == 0)
{
lean_object* x_280; lean_object* x_281; 
x_280 = l_Int_repr(x_254);
lean_dec(x_254);
x_281 = lean_alloc_ctor(3, 1, 0);
lean_ctor_set(x_281, 0, x_280);
x_220 = x_253;
x_221 = x_255;
x_222 = x_256;
x_223 = x_276;
x_224 = x_258;
x_225 = x_259;
x_226 = x_260;
x_227 = x_261;
x_228 = x_262;
x_229 = x_263;
x_230 = x_265;
x_231 = x_264;
x_232 = x_266;
x_233 = x_267;
x_234 = x_281;
goto block_251;
}
else
{
lean_object* x_282; lean_object* x_283; lean_object* x_284; 
x_282 = l_Int_repr(x_254);
lean_dec(x_254);
x_283 = lean_alloc_ctor(3, 1, 0);
lean_ctor_set(x_283, 0, x_282);
x_284 = l_Repr_addAppParen(x_283, x_277);
x_220 = x_253;
x_221 = x_255;
x_222 = x_256;
x_223 = x_276;
x_224 = x_258;
x_225 = x_259;
x_226 = x_260;
x_227 = x_261;
x_228 = x_262;
x_229 = x_263;
x_230 = x_265;
x_231 = x_264;
x_232 = x_266;
x_233 = x_267;
x_234 = x_284;
goto block_251;
}
}
block_320:
{
lean_object* x_304; lean_object* x_305; lean_object* x_306; lean_object* x_307; lean_object* x_308; lean_object* x_309; lean_object* x_310; lean_object* x_311; lean_object* x_312; lean_object* x_313; uint8_t x_314; 
lean_inc(x_290);
x_304 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_304, 0, x_290);
lean_ctor_set(x_304, 1, x_303);
x_305 = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(x_305, 0, x_304);
lean_ctor_set_uint8(x_305, sizeof(void*)*1, x_293);
x_306 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_306, 0, x_297);
lean_ctor_set(x_306, 1, x_305);
lean_inc(x_286);
x_307 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_307, 0, x_306);
lean_ctor_set(x_307, 1, x_286);
lean_inc(x_301);
x_308 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_308, 0, x_307);
lean_ctor_set(x_308, 1, x_301);
x_309 = ((lean_object*)(lp_padctl_instReprGamepadState_repr___redArg___closed__35));
x_310 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_310, 0, x_308);
lean_ctor_set(x_310, 1, x_309);
x_311 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_311, 0, x_310);
lean_ctor_set(x_311, 1, x_24);
x_312 = lean_unsigned_to_nat(0u);
x_313 = lean_obj_once(&lp_padctl_instReprGamepadState_repr___redArg___closed__20, &lp_padctl_instReprGamepadState_repr___redArg___closed__20_once, _init_lp_padctl_instReprGamepadState_repr___redArg___closed__20);
x_314 = lean_int_dec_lt(x_292, x_313);
if (x_314 == 0)
{
lean_object* x_315; lean_object* x_316; 
x_315 = l_Int_repr(x_292);
lean_dec(x_292);
x_316 = lean_alloc_ctor(3, 1, 0);
lean_ctor_set(x_316, 0, x_315);
x_252 = x_311;
x_253 = x_286;
x_254 = x_287;
x_255 = x_288;
x_256 = x_289;
x_257 = x_290;
x_258 = x_291;
x_259 = x_293;
x_260 = x_294;
x_261 = x_295;
x_262 = x_296;
x_263 = x_298;
x_264 = x_300;
x_265 = x_299;
x_266 = x_301;
x_267 = x_302;
x_268 = x_316;
goto block_285;
}
else
{
lean_object* x_317; lean_object* x_318; lean_object* x_319; 
x_317 = l_Int_repr(x_292);
lean_dec(x_292);
x_318 = lean_alloc_ctor(3, 1, 0);
lean_ctor_set(x_318, 0, x_317);
x_319 = l_Repr_addAppParen(x_318, x_312);
x_252 = x_311;
x_253 = x_286;
x_254 = x_287;
x_255 = x_288;
x_256 = x_289;
x_257 = x_290;
x_258 = x_291;
x_259 = x_293;
x_260 = x_294;
x_261 = x_295;
x_262 = x_296;
x_263 = x_298;
x_264 = x_300;
x_265 = x_299;
x_266 = x_301;
x_267 = x_302;
x_268 = x_319;
goto block_285;
}
}
block_356:
{
lean_object* x_340; lean_object* x_341; lean_object* x_342; lean_object* x_343; lean_object* x_344; lean_object* x_345; lean_object* x_346; lean_object* x_347; lean_object* x_348; lean_object* x_349; uint8_t x_350; 
lean_inc(x_326);
x_340 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_340, 0, x_326);
lean_ctor_set(x_340, 1, x_339);
x_341 = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(x_341, 0, x_340);
lean_ctor_set_uint8(x_341, sizeof(void*)*1, x_330);
x_342 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_342, 0, x_328);
lean_ctor_set(x_342, 1, x_341);
lean_inc(x_321);
x_343 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_343, 0, x_342);
lean_ctor_set(x_343, 1, x_321);
lean_inc(x_337);
x_344 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_344, 0, x_343);
lean_ctor_set(x_344, 1, x_337);
x_345 = ((lean_object*)(lp_padctl_instReprGamepadState_repr___redArg___closed__37));
x_346 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_346, 0, x_344);
lean_ctor_set(x_346, 1, x_345);
x_347 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_347, 0, x_346);
lean_ctor_set(x_347, 1, x_24);
x_348 = lean_unsigned_to_nat(0u);
x_349 = lean_obj_once(&lp_padctl_instReprGamepadState_repr___redArg___closed__20, &lp_padctl_instReprGamepadState_repr___redArg___closed__20_once, _init_lp_padctl_instReprGamepadState_repr___redArg___closed__20);
x_350 = lean_int_dec_lt(x_325, x_349);
if (x_350 == 0)
{
lean_object* x_351; lean_object* x_352; 
x_351 = l_Int_repr(x_325);
lean_dec(x_325);
x_352 = lean_alloc_ctor(3, 1, 0);
lean_ctor_set(x_352, 0, x_351);
x_286 = x_321;
x_287 = x_322;
x_288 = x_323;
x_289 = x_324;
x_290 = x_326;
x_291 = x_327;
x_292 = x_329;
x_293 = x_330;
x_294 = x_331;
x_295 = x_332;
x_296 = x_333;
x_297 = x_347;
x_298 = x_334;
x_299 = x_336;
x_300 = x_335;
x_301 = x_337;
x_302 = x_338;
x_303 = x_352;
goto block_320;
}
else
{
lean_object* x_353; lean_object* x_354; lean_object* x_355; 
x_353 = l_Int_repr(x_325);
lean_dec(x_325);
x_354 = lean_alloc_ctor(3, 1, 0);
lean_ctor_set(x_354, 0, x_353);
x_355 = l_Repr_addAppParen(x_354, x_348);
x_286 = x_321;
x_287 = x_322;
x_288 = x_323;
x_289 = x_324;
x_290 = x_326;
x_291 = x_327;
x_292 = x_329;
x_293 = x_330;
x_294 = x_331;
x_295 = x_332;
x_296 = x_333;
x_297 = x_347;
x_298 = x_334;
x_299 = x_336;
x_300 = x_335;
x_301 = x_337;
x_302 = x_338;
x_303 = x_355;
goto block_320;
}
}
block_393:
{
lean_object* x_377; lean_object* x_378; lean_object* x_379; lean_object* x_380; lean_object* x_381; lean_object* x_382; lean_object* x_383; lean_object* x_384; lean_object* x_385; lean_object* x_386; uint8_t x_387; 
lean_inc(x_361);
x_377 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_377, 0, x_361);
lean_ctor_set(x_377, 1, x_376);
x_378 = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(x_378, 0, x_377);
lean_ctor_set_uint8(x_378, sizeof(void*)*1, x_365);
x_379 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_379, 0, x_373);
lean_ctor_set(x_379, 1, x_378);
lean_inc(x_357);
x_380 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_380, 0, x_379);
lean_ctor_set(x_380, 1, x_357);
lean_inc(x_374);
x_381 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_381, 0, x_380);
lean_ctor_set(x_381, 1, x_374);
x_382 = ((lean_object*)(lp_padctl_instReprGamepadState_repr___redArg___closed__39));
x_383 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_383, 0, x_381);
lean_ctor_set(x_383, 1, x_382);
x_384 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_384, 0, x_383);
lean_ctor_set(x_384, 1, x_24);
x_385 = lean_unsigned_to_nat(0u);
x_386 = lean_obj_once(&lp_padctl_instReprGamepadState_repr___redArg___closed__20, &lp_padctl_instReprGamepadState_repr___redArg___closed__20_once, _init_lp_padctl_instReprGamepadState_repr___redArg___closed__20);
x_387 = lean_int_dec_lt(x_370, x_386);
if (x_387 == 0)
{
lean_object* x_388; lean_object* x_389; 
x_388 = l_Int_repr(x_370);
lean_dec(x_370);
x_389 = lean_alloc_ctor(3, 1, 0);
lean_ctor_set(x_389, 0, x_388);
x_321 = x_357;
x_322 = x_358;
x_323 = x_359;
x_324 = x_360;
x_325 = x_362;
x_326 = x_361;
x_327 = x_363;
x_328 = x_384;
x_329 = x_364;
x_330 = x_365;
x_331 = x_366;
x_332 = x_367;
x_333 = x_368;
x_334 = x_369;
x_335 = x_372;
x_336 = x_371;
x_337 = x_374;
x_338 = x_375;
x_339 = x_389;
goto block_356;
}
else
{
lean_object* x_390; lean_object* x_391; lean_object* x_392; 
x_390 = l_Int_repr(x_370);
lean_dec(x_370);
x_391 = lean_alloc_ctor(3, 1, 0);
lean_ctor_set(x_391, 0, x_390);
x_392 = l_Repr_addAppParen(x_391, x_385);
x_321 = x_357;
x_322 = x_358;
x_323 = x_359;
x_324 = x_360;
x_325 = x_362;
x_326 = x_361;
x_327 = x_363;
x_328 = x_384;
x_329 = x_364;
x_330 = x_365;
x_331 = x_366;
x_332 = x_367;
x_333 = x_368;
x_334 = x_369;
x_335 = x_372;
x_336 = x_371;
x_337 = x_374;
x_338 = x_375;
x_339 = x_392;
goto block_356;
}
}
block_431:
{
lean_object* x_415; lean_object* x_416; lean_object* x_417; lean_object* x_418; lean_object* x_419; lean_object* x_420; lean_object* x_421; lean_object* x_422; lean_object* x_423; lean_object* x_424; uint8_t x_425; 
lean_inc(x_399);
x_415 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_415, 0, x_399);
lean_ctor_set(x_415, 1, x_414);
x_416 = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(x_416, 0, x_415);
lean_ctor_set_uint8(x_416, sizeof(void*)*1, x_403);
x_417 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_417, 0, x_398);
lean_ctor_set(x_417, 1, x_416);
lean_inc(x_394);
x_418 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_418, 0, x_417);
lean_ctor_set(x_418, 1, x_394);
lean_inc(x_411);
x_419 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_419, 0, x_418);
lean_ctor_set(x_419, 1, x_411);
x_420 = ((lean_object*)(lp_padctl_instReprGamepadState_repr___redArg___closed__41));
x_421 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_421, 0, x_419);
lean_ctor_set(x_421, 1, x_420);
x_422 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_422, 0, x_421);
lean_ctor_set(x_422, 1, x_24);
x_423 = lean_unsigned_to_nat(0u);
x_424 = lean_obj_once(&lp_padctl_instReprGamepadState_repr___redArg___closed__20, &lp_padctl_instReprGamepadState_repr___redArg___closed__20_once, _init_lp_padctl_instReprGamepadState_repr___redArg___closed__20);
x_425 = lean_int_dec_lt(x_413, x_424);
if (x_425 == 0)
{
lean_object* x_426; lean_object* x_427; 
x_426 = l_Int_repr(x_413);
lean_dec(x_413);
x_427 = lean_alloc_ctor(3, 1, 0);
lean_ctor_set(x_427, 0, x_426);
x_357 = x_394;
x_358 = x_395;
x_359 = x_396;
x_360 = x_397;
x_361 = x_399;
x_362 = x_400;
x_363 = x_401;
x_364 = x_402;
x_365 = x_403;
x_366 = x_404;
x_367 = x_405;
x_368 = x_406;
x_369 = x_407;
x_370 = x_408;
x_371 = x_410;
x_372 = x_409;
x_373 = x_422;
x_374 = x_411;
x_375 = x_412;
x_376 = x_427;
goto block_393;
}
else
{
lean_object* x_428; lean_object* x_429; lean_object* x_430; 
x_428 = l_Int_repr(x_413);
lean_dec(x_413);
x_429 = lean_alloc_ctor(3, 1, 0);
lean_ctor_set(x_429, 0, x_428);
x_430 = l_Repr_addAppParen(x_429, x_423);
x_357 = x_394;
x_358 = x_395;
x_359 = x_396;
x_360 = x_397;
x_361 = x_399;
x_362 = x_400;
x_363 = x_401;
x_364 = x_402;
x_365 = x_403;
x_366 = x_404;
x_367 = x_405;
x_368 = x_406;
x_369 = x_407;
x_370 = x_408;
x_371 = x_410;
x_372 = x_409;
x_373 = x_422;
x_374 = x_411;
x_375 = x_412;
x_376 = x_430;
goto block_393;
}
}
block_487:
{
lean_object* x_439; lean_object* x_440; lean_object* x_441; lean_object* x_442; lean_object* x_443; lean_object* x_444; lean_object* x_445; lean_object* x_446; lean_object* x_447; lean_object* x_448; lean_object* x_449; lean_object* x_450; lean_object* x_451; lean_object* x_452; lean_object* x_453; lean_object* x_454; lean_object* x_455; lean_object* x_456; lean_object* x_457; lean_object* x_458; lean_object* x_459; lean_object* x_460; lean_object* x_461; lean_object* x_462; lean_object* x_463; lean_object* x_464; lean_object* x_465; lean_object* x_466; lean_object* x_467; lean_object* x_468; lean_object* x_469; lean_object* x_470; lean_object* x_471; lean_object* x_472; lean_object* x_473; lean_object* x_474; lean_object* x_475; lean_object* x_476; lean_object* x_477; lean_object* x_478; lean_object* x_479; lean_object* x_480; uint8_t x_481; 
x_439 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_439, 0, x_433);
lean_ctor_set(x_439, 1, x_438);
x_440 = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(x_440, 0, x_439);
lean_ctor_set_uint8(x_440, sizeof(void*)*1, x_435);
x_441 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_441, 0, x_437);
lean_ctor_set(x_441, 1, x_440);
lean_inc(x_434);
x_442 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_442, 0, x_441);
lean_ctor_set(x_442, 1, x_434);
lean_inc(x_436);
x_443 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_443, 0, x_442);
lean_ctor_set(x_443, 1, x_436);
x_444 = ((lean_object*)(lp_padctl_instReprGamepadState_repr___redArg___closed__45));
x_445 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_445, 0, x_443);
lean_ctor_set(x_445, 1, x_444);
x_446 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_446, 0, x_445);
lean_ctor_set(x_446, 1, x_24);
x_447 = l_Nat_reprFast(x_6);
x_448 = lean_alloc_ctor(3, 1, 0);
lean_ctor_set(x_448, 0, x_447);
x_449 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_449, 0, x_433);
lean_ctor_set(x_449, 1, x_448);
x_450 = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(x_450, 0, x_449);
lean_ctor_set_uint8(x_450, sizeof(void*)*1, x_435);
x_451 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_451, 0, x_446);
lean_ctor_set(x_451, 1, x_450);
lean_inc(x_434);
x_452 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_452, 0, x_451);
lean_ctor_set(x_452, 1, x_434);
lean_inc(x_436);
x_453 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_453, 0, x_452);
lean_ctor_set(x_453, 1, x_436);
x_454 = ((lean_object*)(lp_padctl_instReprGamepadState_repr___redArg___closed__47));
x_455 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_455, 0, x_453);
lean_ctor_set(x_455, 1, x_454);
x_456 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_456, 0, x_455);
lean_ctor_set(x_456, 1, x_24);
x_457 = l_Nat_reprFast(x_7);
x_458 = lean_alloc_ctor(3, 1, 0);
lean_ctor_set(x_458, 0, x_457);
x_459 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_459, 0, x_433);
lean_ctor_set(x_459, 1, x_458);
x_460 = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(x_460, 0, x_459);
lean_ctor_set_uint8(x_460, sizeof(void*)*1, x_435);
x_461 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_461, 0, x_456);
lean_ctor_set(x_461, 1, x_460);
lean_inc(x_434);
x_462 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_462, 0, x_461);
lean_ctor_set(x_462, 1, x_434);
lean_inc(x_436);
x_463 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_463, 0, x_462);
lean_ctor_set(x_463, 1, x_436);
x_464 = ((lean_object*)(lp_padctl_instReprGamepadState_repr___redArg___closed__49));
x_465 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_465, 0, x_463);
lean_ctor_set(x_465, 1, x_464);
x_466 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_466, 0, x_465);
lean_ctor_set(x_466, 1, x_24);
x_467 = lean_obj_once(&lp_padctl_instReprGamepadState_repr___redArg___closed__50, &lp_padctl_instReprGamepadState_repr___redArg___closed__50_once, _init_lp_padctl_instReprGamepadState_repr___redArg___closed__50);
x_468 = l_Nat_reprFast(x_8);
x_469 = lean_alloc_ctor(3, 1, 0);
lean_ctor_set(x_469, 0, x_468);
x_470 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_470, 0, x_467);
lean_ctor_set(x_470, 1, x_469);
x_471 = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(x_471, 0, x_470);
lean_ctor_set_uint8(x_471, sizeof(void*)*1, x_435);
x_472 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_472, 0, x_466);
lean_ctor_set(x_472, 1, x_471);
lean_inc(x_434);
x_473 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_473, 0, x_472);
lean_ctor_set(x_473, 1, x_434);
lean_inc(x_436);
x_474 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_474, 0, x_473);
lean_ctor_set(x_474, 1, x_436);
x_475 = ((lean_object*)(lp_padctl_instReprGamepadState_repr___redArg___closed__52));
x_476 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_476, 0, x_474);
lean_ctor_set(x_476, 1, x_475);
x_477 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_477, 0, x_476);
lean_ctor_set(x_477, 1, x_24);
x_478 = lean_obj_once(&lp_padctl_instReprGamepadState_repr___redArg___closed__53, &lp_padctl_instReprGamepadState_repr___redArg___closed__53_once, _init_lp_padctl_instReprGamepadState_repr___redArg___closed__53);
x_479 = lean_unsigned_to_nat(0u);
x_480 = lean_obj_once(&lp_padctl_instReprGamepadState_repr___redArg___closed__20, &lp_padctl_instReprGamepadState_repr___redArg___closed__20_once, _init_lp_padctl_instReprGamepadState_repr___redArg___closed__20);
x_481 = lean_int_dec_lt(x_9, x_480);
if (x_481 == 0)
{
lean_object* x_482; lean_object* x_483; 
x_482 = l_Int_repr(x_9);
lean_dec(x_9);
x_483 = lean_alloc_ctor(3, 1, 0);
lean_ctor_set(x_483, 0, x_482);
x_394 = x_434;
x_395 = x_14;
x_396 = x_17;
x_397 = x_20;
x_398 = x_477;
x_399 = x_478;
x_400 = x_12;
x_401 = x_467;
x_402 = x_13;
x_403 = x_435;
x_404 = x_23;
x_405 = x_19;
x_406 = x_22;
x_407 = x_15;
x_408 = x_11;
x_409 = x_18;
x_410 = x_21;
x_411 = x_436;
x_412 = x_16;
x_413 = x_10;
x_414 = x_483;
goto block_431;
}
else
{
lean_object* x_484; lean_object* x_485; lean_object* x_486; 
x_484 = l_Int_repr(x_9);
lean_dec(x_9);
x_485 = lean_alloc_ctor(3, 1, 0);
lean_ctor_set(x_485, 0, x_484);
x_486 = l_Repr_addAppParen(x_485, x_479);
x_394 = x_434;
x_395 = x_14;
x_396 = x_17;
x_397 = x_20;
x_398 = x_477;
x_399 = x_478;
x_400 = x_12;
x_401 = x_467;
x_402 = x_13;
x_403 = x_435;
x_404 = x_23;
x_405 = x_19;
x_406 = x_22;
x_407 = x_15;
x_408 = x_11;
x_409 = x_18;
x_410 = x_21;
x_411 = x_436;
x_412 = x_16;
x_413 = x_10;
x_414 = x_486;
goto block_431;
}
}
block_509:
{
lean_object* x_493; lean_object* x_494; lean_object* x_495; lean_object* x_496; lean_object* x_497; lean_object* x_498; lean_object* x_499; lean_object* x_500; lean_object* x_501; lean_object* x_502; uint8_t x_503; 
x_493 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_493, 0, x_433);
lean_ctor_set(x_493, 1, x_492);
x_494 = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(x_494, 0, x_493);
lean_ctor_set_uint8(x_494, sizeof(void*)*1, x_489);
x_495 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_495, 0, x_490);
lean_ctor_set(x_495, 1, x_494);
lean_inc(x_488);
x_496 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_496, 0, x_495);
lean_ctor_set(x_496, 1, x_488);
lean_inc(x_491);
x_497 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_497, 0, x_496);
lean_ctor_set(x_497, 1, x_491);
x_498 = ((lean_object*)(lp_padctl_instReprGamepadState_repr___redArg___closed__55));
x_499 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_499, 0, x_497);
lean_ctor_set(x_499, 1, x_498);
x_500 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_500, 0, x_499);
lean_ctor_set(x_500, 1, x_24);
x_501 = lean_unsigned_to_nat(0u);
x_502 = lean_obj_once(&lp_padctl_instReprGamepadState_repr___redArg___closed__20, &lp_padctl_instReprGamepadState_repr___redArg___closed__20_once, _init_lp_padctl_instReprGamepadState_repr___redArg___closed__20);
x_503 = lean_int_dec_lt(x_5, x_502);
if (x_503 == 0)
{
lean_object* x_504; lean_object* x_505; 
x_504 = l_Int_repr(x_5);
lean_dec(x_5);
x_505 = lean_alloc_ctor(3, 1, 0);
lean_ctor_set(x_505, 0, x_504);
x_434 = x_488;
x_435 = x_489;
x_436 = x_491;
x_437 = x_500;
x_438 = x_505;
goto block_487;
}
else
{
lean_object* x_506; lean_object* x_507; lean_object* x_508; 
x_506 = l_Int_repr(x_5);
lean_dec(x_5);
x_507 = lean_alloc_ctor(3, 1, 0);
lean_ctor_set(x_507, 0, x_506);
x_508 = l_Repr_addAppParen(x_507, x_501);
x_434 = x_488;
x_435 = x_489;
x_436 = x_491;
x_437 = x_500;
x_438 = x_508;
goto block_487;
}
}
block_531:
{
lean_object* x_515; lean_object* x_516; lean_object* x_517; lean_object* x_518; lean_object* x_519; lean_object* x_520; lean_object* x_521; lean_object* x_522; lean_object* x_523; lean_object* x_524; uint8_t x_525; 
x_515 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_515, 0, x_433);
lean_ctor_set(x_515, 1, x_514);
x_516 = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(x_516, 0, x_515);
lean_ctor_set_uint8(x_516, sizeof(void*)*1, x_512);
x_517 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_517, 0, x_511);
lean_ctor_set(x_517, 1, x_516);
lean_inc(x_510);
x_518 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_518, 0, x_517);
lean_ctor_set(x_518, 1, x_510);
lean_inc(x_513);
x_519 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_519, 0, x_518);
lean_ctor_set(x_519, 1, x_513);
x_520 = ((lean_object*)(lp_padctl_instReprGamepadState_repr___redArg___closed__57));
x_521 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_521, 0, x_519);
lean_ctor_set(x_521, 1, x_520);
x_522 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_522, 0, x_521);
lean_ctor_set(x_522, 1, x_24);
x_523 = lean_unsigned_to_nat(0u);
x_524 = lean_obj_once(&lp_padctl_instReprGamepadState_repr___redArg___closed__20, &lp_padctl_instReprGamepadState_repr___redArg___closed__20_once, _init_lp_padctl_instReprGamepadState_repr___redArg___closed__20);
x_525 = lean_int_dec_lt(x_4, x_524);
if (x_525 == 0)
{
lean_object* x_526; lean_object* x_527; 
x_526 = l_Int_repr(x_4);
lean_dec(x_4);
x_527 = lean_alloc_ctor(3, 1, 0);
lean_ctor_set(x_527, 0, x_526);
x_488 = x_510;
x_489 = x_512;
x_490 = x_522;
x_491 = x_513;
x_492 = x_527;
goto block_509;
}
else
{
lean_object* x_528; lean_object* x_529; lean_object* x_530; 
x_528 = l_Int_repr(x_4);
lean_dec(x_4);
x_529 = lean_alloc_ctor(3, 1, 0);
lean_ctor_set(x_529, 0, x_528);
x_530 = l_Repr_addAppParen(x_529, x_523);
x_488 = x_510;
x_489 = x_512;
x_490 = x_522;
x_491 = x_513;
x_492 = x_530;
goto block_509;
}
}
block_552:
{
lean_object* x_533; uint8_t x_534; lean_object* x_535; lean_object* x_536; lean_object* x_537; lean_object* x_538; lean_object* x_539; lean_object* x_540; lean_object* x_541; lean_object* x_542; lean_object* x_543; lean_object* x_544; lean_object* x_545; uint8_t x_546; 
x_533 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_533, 0, x_433);
lean_ctor_set(x_533, 1, x_532);
x_534 = 0;
x_535 = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(x_535, 0, x_533);
lean_ctor_set_uint8(x_535, sizeof(void*)*1, x_534);
x_536 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_536, 0, x_432);
lean_ctor_set(x_536, 1, x_535);
x_537 = ((lean_object*)(lp_padctl_instReprGamepadState_repr___redArg___closed__59));
x_538 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_538, 0, x_536);
lean_ctor_set(x_538, 1, x_537);
x_539 = lean_box(1);
x_540 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_540, 0, x_538);
lean_ctor_set(x_540, 1, x_539);
x_541 = ((lean_object*)(lp_padctl_instReprGamepadState_repr___redArg___closed__61));
x_542 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_542, 0, x_540);
lean_ctor_set(x_542, 1, x_541);
x_543 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_543, 0, x_542);
lean_ctor_set(x_543, 1, x_24);
x_544 = lean_unsigned_to_nat(0u);
x_545 = lean_obj_once(&lp_padctl_instReprGamepadState_repr___redArg___closed__20, &lp_padctl_instReprGamepadState_repr___redArg___closed__20_once, _init_lp_padctl_instReprGamepadState_repr___redArg___closed__20);
x_546 = lean_int_dec_lt(x_3, x_545);
if (x_546 == 0)
{
lean_object* x_547; lean_object* x_548; 
x_547 = l_Int_repr(x_3);
lean_dec(x_3);
x_548 = lean_alloc_ctor(3, 1, 0);
lean_ctor_set(x_548, 0, x_547);
x_510 = x_537;
x_511 = x_543;
x_512 = x_534;
x_513 = x_539;
x_514 = x_548;
goto block_531;
}
else
{
lean_object* x_549; lean_object* x_550; lean_object* x_551; 
x_549 = l_Int_repr(x_3);
lean_dec(x_3);
x_550 = lean_alloc_ctor(3, 1, 0);
lean_ctor_set(x_550, 0, x_549);
x_551 = l_Repr_addAppParen(x_550, x_544);
x_510 = x_537;
x_511 = x_543;
x_512 = x_534;
x_513 = x_539;
x_514 = x_551;
goto block_531;
}
}
}
}
LEAN_EXPORT lean_object* lp_padctl_instReprGamepadState_repr(lean_object* x_1, lean_object* x_2) {
_start:
{
lean_object* x_3; 
x_3 = lp_padctl_instReprGamepadState_repr___redArg(x_1);
return x_3;
}
}
LEAN_EXPORT lean_object* lp_padctl_instReprGamepadState_repr___boxed(lean_object* x_1, lean_object* x_2) {
_start:
{
lean_object* x_3; 
x_3 = lp_padctl_instReprGamepadState_repr(x_1, x_2);
lean_dec(x_2);
return x_3;
}
}
LEAN_EXPORT uint8_t lp_padctl_instDecidableEqGamepadStateDelta_decEq___lam__0(uint8_t x_1, uint8_t x_2, uint8_t x_3) {
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
LEAN_EXPORT lean_object* lp_padctl_instDecidableEqGamepadStateDelta_decEq___lam__0___boxed(lean_object* x_1, lean_object* x_2, lean_object* x_3) {
_start:
{
uint8_t x_4; uint8_t x_5; uint8_t x_6; uint8_t x_7; lean_object* x_8; 
x_4 = lean_unbox(x_1);
x_5 = lean_unbox(x_2);
x_6 = lean_unbox(x_3);
x_7 = lp_padctl_instDecidableEqGamepadStateDelta_decEq___lam__0(x_4, x_5, x_6);
x_8 = lean_box(x_7);
return x_8;
}
}
LEAN_EXPORT uint8_t lp_padctl_instDecidableEqGamepadStateDelta_decEq(lean_object* x_1, lean_object* x_2) {
_start:
{
lean_object* x_3; lean_object* x_4; lean_object* x_5; lean_object* x_6; lean_object* x_7; lean_object* x_8; lean_object* x_9; lean_object* x_10; lean_object* x_11; lean_object* x_12; lean_object* x_13; lean_object* x_14; lean_object* x_15; lean_object* x_16; lean_object* x_17; lean_object* x_18; lean_object* x_19; lean_object* x_20; lean_object* x_21; lean_object* x_22; lean_object* x_23; lean_object* x_24; lean_object* x_25; lean_object* x_26; lean_object* x_27; lean_object* x_28; lean_object* x_29; lean_object* x_30; lean_object* x_31; lean_object* x_32; lean_object* x_33; lean_object* x_34; lean_object* x_35; lean_object* x_36; lean_object* x_37; lean_object* x_38; lean_object* x_39; lean_object* x_40; lean_object* x_41; lean_object* x_42; lean_object* x_43; lean_object* x_44; lean_object* x_45; lean_object* x_46; lean_object* x_47; uint8_t x_48; 
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
x_9 = lean_ctor_get(x_1, 6);
lean_inc(x_9);
x_10 = lean_ctor_get(x_1, 7);
lean_inc(x_10);
x_11 = lean_ctor_get(x_1, 8);
lean_inc(x_11);
x_12 = lean_ctor_get(x_1, 9);
lean_inc(x_12);
x_13 = lean_ctor_get(x_1, 10);
lean_inc(x_13);
x_14 = lean_ctor_get(x_1, 11);
lean_inc(x_14);
x_15 = lean_ctor_get(x_1, 12);
lean_inc(x_15);
x_16 = lean_ctor_get(x_1, 13);
lean_inc(x_16);
x_17 = lean_ctor_get(x_1, 14);
lean_inc(x_17);
x_18 = lean_ctor_get(x_1, 15);
lean_inc(x_18);
x_19 = lean_ctor_get(x_1, 16);
lean_inc(x_19);
x_20 = lean_ctor_get(x_1, 17);
lean_inc(x_20);
x_21 = lean_ctor_get(x_1, 18);
lean_inc(x_21);
x_22 = lean_ctor_get(x_1, 19);
lean_inc(x_22);
x_23 = lean_ctor_get(x_1, 20);
lean_inc(x_23);
x_24 = lean_ctor_get(x_1, 21);
lean_inc(x_24);
lean_dec_ref(x_1);
x_25 = lean_ctor_get(x_2, 0);
lean_inc(x_25);
x_26 = lean_ctor_get(x_2, 1);
lean_inc(x_26);
x_27 = lean_ctor_get(x_2, 2);
lean_inc(x_27);
x_28 = lean_ctor_get(x_2, 3);
lean_inc(x_28);
x_29 = lean_ctor_get(x_2, 4);
lean_inc(x_29);
x_30 = lean_ctor_get(x_2, 5);
lean_inc(x_30);
x_31 = lean_ctor_get(x_2, 6);
lean_inc(x_31);
x_32 = lean_ctor_get(x_2, 7);
lean_inc(x_32);
x_33 = lean_ctor_get(x_2, 8);
lean_inc(x_33);
x_34 = lean_ctor_get(x_2, 9);
lean_inc(x_34);
x_35 = lean_ctor_get(x_2, 10);
lean_inc(x_35);
x_36 = lean_ctor_get(x_2, 11);
lean_inc(x_36);
x_37 = lean_ctor_get(x_2, 12);
lean_inc(x_37);
x_38 = lean_ctor_get(x_2, 13);
lean_inc(x_38);
x_39 = lean_ctor_get(x_2, 14);
lean_inc(x_39);
x_40 = lean_ctor_get(x_2, 15);
lean_inc(x_40);
x_41 = lean_ctor_get(x_2, 16);
lean_inc(x_41);
x_42 = lean_ctor_get(x_2, 17);
lean_inc(x_42);
x_43 = lean_ctor_get(x_2, 18);
lean_inc(x_43);
x_44 = lean_ctor_get(x_2, 19);
lean_inc(x_44);
x_45 = lean_ctor_get(x_2, 20);
lean_inc(x_45);
x_46 = lean_ctor_get(x_2, 21);
lean_inc(x_46);
lean_dec_ref(x_2);
x_47 = lean_alloc_closure((void*)(l_Int_instDecidableEq___boxed), 2, 0);
lean_inc_ref(x_47);
x_48 = l_Option_instDecidableEq___redArg(x_47, x_3, x_25);
if (x_48 == 0)
{
lean_dec_ref(x_47);
lean_dec(x_46);
lean_dec(x_45);
lean_dec(x_44);
lean_dec(x_43);
lean_dec(x_42);
lean_dec(x_41);
lean_dec(x_40);
lean_dec(x_39);
lean_dec(x_38);
lean_dec(x_37);
lean_dec(x_36);
lean_dec(x_35);
lean_dec(x_34);
lean_dec(x_33);
lean_dec(x_32);
lean_dec(x_31);
lean_dec(x_30);
lean_dec(x_29);
lean_dec(x_28);
lean_dec(x_27);
lean_dec(x_26);
lean_dec(x_24);
lean_dec(x_23);
lean_dec(x_22);
lean_dec(x_21);
lean_dec(x_20);
lean_dec(x_19);
lean_dec(x_18);
lean_dec(x_17);
lean_dec(x_16);
lean_dec(x_15);
lean_dec(x_14);
lean_dec(x_13);
lean_dec(x_12);
lean_dec(x_11);
lean_dec(x_10);
lean_dec(x_9);
lean_dec(x_8);
lean_dec(x_7);
lean_dec(x_6);
lean_dec(x_5);
lean_dec(x_4);
return x_48;
}
else
{
uint8_t x_49; 
lean_inc_ref(x_47);
x_49 = l_Option_instDecidableEq___redArg(x_47, x_4, x_26);
if (x_49 == 0)
{
lean_dec_ref(x_47);
lean_dec(x_46);
lean_dec(x_45);
lean_dec(x_44);
lean_dec(x_43);
lean_dec(x_42);
lean_dec(x_41);
lean_dec(x_40);
lean_dec(x_39);
lean_dec(x_38);
lean_dec(x_37);
lean_dec(x_36);
lean_dec(x_35);
lean_dec(x_34);
lean_dec(x_33);
lean_dec(x_32);
lean_dec(x_31);
lean_dec(x_30);
lean_dec(x_29);
lean_dec(x_28);
lean_dec(x_27);
lean_dec(x_24);
lean_dec(x_23);
lean_dec(x_22);
lean_dec(x_21);
lean_dec(x_20);
lean_dec(x_19);
lean_dec(x_18);
lean_dec(x_17);
lean_dec(x_16);
lean_dec(x_15);
lean_dec(x_14);
lean_dec(x_13);
lean_dec(x_12);
lean_dec(x_11);
lean_dec(x_10);
lean_dec(x_9);
lean_dec(x_8);
lean_dec(x_7);
lean_dec(x_6);
lean_dec(x_5);
return x_49;
}
else
{
uint8_t x_50; 
lean_inc_ref(x_47);
x_50 = l_Option_instDecidableEq___redArg(x_47, x_5, x_27);
if (x_50 == 0)
{
lean_dec_ref(x_47);
lean_dec(x_46);
lean_dec(x_45);
lean_dec(x_44);
lean_dec(x_43);
lean_dec(x_42);
lean_dec(x_41);
lean_dec(x_40);
lean_dec(x_39);
lean_dec(x_38);
lean_dec(x_37);
lean_dec(x_36);
lean_dec(x_35);
lean_dec(x_34);
lean_dec(x_33);
lean_dec(x_32);
lean_dec(x_31);
lean_dec(x_30);
lean_dec(x_29);
lean_dec(x_28);
lean_dec(x_24);
lean_dec(x_23);
lean_dec(x_22);
lean_dec(x_21);
lean_dec(x_20);
lean_dec(x_19);
lean_dec(x_18);
lean_dec(x_17);
lean_dec(x_16);
lean_dec(x_15);
lean_dec(x_14);
lean_dec(x_13);
lean_dec(x_12);
lean_dec(x_11);
lean_dec(x_10);
lean_dec(x_9);
lean_dec(x_8);
lean_dec(x_7);
lean_dec(x_6);
return x_50;
}
else
{
uint8_t x_51; 
lean_inc_ref(x_47);
x_51 = l_Option_instDecidableEq___redArg(x_47, x_6, x_28);
if (x_51 == 0)
{
lean_dec_ref(x_47);
lean_dec(x_46);
lean_dec(x_45);
lean_dec(x_44);
lean_dec(x_43);
lean_dec(x_42);
lean_dec(x_41);
lean_dec(x_40);
lean_dec(x_39);
lean_dec(x_38);
lean_dec(x_37);
lean_dec(x_36);
lean_dec(x_35);
lean_dec(x_34);
lean_dec(x_33);
lean_dec(x_32);
lean_dec(x_31);
lean_dec(x_30);
lean_dec(x_29);
lean_dec(x_24);
lean_dec(x_23);
lean_dec(x_22);
lean_dec(x_21);
lean_dec(x_20);
lean_dec(x_19);
lean_dec(x_18);
lean_dec(x_17);
lean_dec(x_16);
lean_dec(x_15);
lean_dec(x_14);
lean_dec(x_13);
lean_dec(x_12);
lean_dec(x_11);
lean_dec(x_10);
lean_dec(x_9);
lean_dec(x_8);
lean_dec(x_7);
return x_51;
}
else
{
lean_object* x_52; uint8_t x_53; 
x_52 = lean_alloc_closure((void*)(l_instDecidableEqNat___boxed), 2, 0);
lean_inc_ref(x_52);
x_53 = l_Option_instDecidableEq___redArg(x_52, x_7, x_29);
if (x_53 == 0)
{
lean_dec_ref(x_52);
lean_dec_ref(x_47);
lean_dec(x_46);
lean_dec(x_45);
lean_dec(x_44);
lean_dec(x_43);
lean_dec(x_42);
lean_dec(x_41);
lean_dec(x_40);
lean_dec(x_39);
lean_dec(x_38);
lean_dec(x_37);
lean_dec(x_36);
lean_dec(x_35);
lean_dec(x_34);
lean_dec(x_33);
lean_dec(x_32);
lean_dec(x_31);
lean_dec(x_30);
lean_dec(x_24);
lean_dec(x_23);
lean_dec(x_22);
lean_dec(x_21);
lean_dec(x_20);
lean_dec(x_19);
lean_dec(x_18);
lean_dec(x_17);
lean_dec(x_16);
lean_dec(x_15);
lean_dec(x_14);
lean_dec(x_13);
lean_dec(x_12);
lean_dec(x_11);
lean_dec(x_10);
lean_dec(x_9);
lean_dec(x_8);
return x_53;
}
else
{
uint8_t x_54; 
lean_inc_ref(x_52);
x_54 = l_Option_instDecidableEq___redArg(x_52, x_8, x_30);
if (x_54 == 0)
{
lean_dec_ref(x_52);
lean_dec_ref(x_47);
lean_dec(x_46);
lean_dec(x_45);
lean_dec(x_44);
lean_dec(x_43);
lean_dec(x_42);
lean_dec(x_41);
lean_dec(x_40);
lean_dec(x_39);
lean_dec(x_38);
lean_dec(x_37);
lean_dec(x_36);
lean_dec(x_35);
lean_dec(x_34);
lean_dec(x_33);
lean_dec(x_32);
lean_dec(x_31);
lean_dec(x_24);
lean_dec(x_23);
lean_dec(x_22);
lean_dec(x_21);
lean_dec(x_20);
lean_dec(x_19);
lean_dec(x_18);
lean_dec(x_17);
lean_dec(x_16);
lean_dec(x_15);
lean_dec(x_14);
lean_dec(x_13);
lean_dec(x_12);
lean_dec(x_11);
lean_dec(x_10);
lean_dec(x_9);
return x_54;
}
else
{
uint8_t x_55; 
lean_inc_ref(x_52);
x_55 = l_Option_instDecidableEq___redArg(x_52, x_9, x_31);
if (x_55 == 0)
{
lean_dec_ref(x_52);
lean_dec_ref(x_47);
lean_dec(x_46);
lean_dec(x_45);
lean_dec(x_44);
lean_dec(x_43);
lean_dec(x_42);
lean_dec(x_41);
lean_dec(x_40);
lean_dec(x_39);
lean_dec(x_38);
lean_dec(x_37);
lean_dec(x_36);
lean_dec(x_35);
lean_dec(x_34);
lean_dec(x_33);
lean_dec(x_32);
lean_dec(x_24);
lean_dec(x_23);
lean_dec(x_22);
lean_dec(x_21);
lean_dec(x_20);
lean_dec(x_19);
lean_dec(x_18);
lean_dec(x_17);
lean_dec(x_16);
lean_dec(x_15);
lean_dec(x_14);
lean_dec(x_13);
lean_dec(x_12);
lean_dec(x_11);
lean_dec(x_10);
return x_55;
}
else
{
uint8_t x_56; 
lean_inc_ref(x_47);
x_56 = l_Option_instDecidableEq___redArg(x_47, x_10, x_32);
if (x_56 == 0)
{
lean_dec_ref(x_52);
lean_dec_ref(x_47);
lean_dec(x_46);
lean_dec(x_45);
lean_dec(x_44);
lean_dec(x_43);
lean_dec(x_42);
lean_dec(x_41);
lean_dec(x_40);
lean_dec(x_39);
lean_dec(x_38);
lean_dec(x_37);
lean_dec(x_36);
lean_dec(x_35);
lean_dec(x_34);
lean_dec(x_33);
lean_dec(x_24);
lean_dec(x_23);
lean_dec(x_22);
lean_dec(x_21);
lean_dec(x_20);
lean_dec(x_19);
lean_dec(x_18);
lean_dec(x_17);
lean_dec(x_16);
lean_dec(x_15);
lean_dec(x_14);
lean_dec(x_13);
lean_dec(x_12);
lean_dec(x_11);
return x_56;
}
else
{
uint8_t x_57; 
lean_inc_ref(x_47);
x_57 = l_Option_instDecidableEq___redArg(x_47, x_11, x_33);
if (x_57 == 0)
{
lean_dec_ref(x_52);
lean_dec_ref(x_47);
lean_dec(x_46);
lean_dec(x_45);
lean_dec(x_44);
lean_dec(x_43);
lean_dec(x_42);
lean_dec(x_41);
lean_dec(x_40);
lean_dec(x_39);
lean_dec(x_38);
lean_dec(x_37);
lean_dec(x_36);
lean_dec(x_35);
lean_dec(x_34);
lean_dec(x_24);
lean_dec(x_23);
lean_dec(x_22);
lean_dec(x_21);
lean_dec(x_20);
lean_dec(x_19);
lean_dec(x_18);
lean_dec(x_17);
lean_dec(x_16);
lean_dec(x_15);
lean_dec(x_14);
lean_dec(x_13);
lean_dec(x_12);
return x_57;
}
else
{
uint8_t x_58; 
lean_inc_ref(x_47);
x_58 = l_Option_instDecidableEq___redArg(x_47, x_12, x_34);
if (x_58 == 0)
{
lean_dec_ref(x_52);
lean_dec_ref(x_47);
lean_dec(x_46);
lean_dec(x_45);
lean_dec(x_44);
lean_dec(x_43);
lean_dec(x_42);
lean_dec(x_41);
lean_dec(x_40);
lean_dec(x_39);
lean_dec(x_38);
lean_dec(x_37);
lean_dec(x_36);
lean_dec(x_35);
lean_dec(x_24);
lean_dec(x_23);
lean_dec(x_22);
lean_dec(x_21);
lean_dec(x_20);
lean_dec(x_19);
lean_dec(x_18);
lean_dec(x_17);
lean_dec(x_16);
lean_dec(x_15);
lean_dec(x_14);
lean_dec(x_13);
return x_58;
}
else
{
uint8_t x_59; 
lean_inc_ref(x_47);
x_59 = l_Option_instDecidableEq___redArg(x_47, x_13, x_35);
if (x_59 == 0)
{
lean_dec_ref(x_52);
lean_dec_ref(x_47);
lean_dec(x_46);
lean_dec(x_45);
lean_dec(x_44);
lean_dec(x_43);
lean_dec(x_42);
lean_dec(x_41);
lean_dec(x_40);
lean_dec(x_39);
lean_dec(x_38);
lean_dec(x_37);
lean_dec(x_36);
lean_dec(x_24);
lean_dec(x_23);
lean_dec(x_22);
lean_dec(x_21);
lean_dec(x_20);
lean_dec(x_19);
lean_dec(x_18);
lean_dec(x_17);
lean_dec(x_16);
lean_dec(x_15);
lean_dec(x_14);
return x_59;
}
else
{
uint8_t x_60; 
lean_inc_ref(x_47);
x_60 = l_Option_instDecidableEq___redArg(x_47, x_14, x_36);
if (x_60 == 0)
{
lean_dec_ref(x_52);
lean_dec_ref(x_47);
lean_dec(x_46);
lean_dec(x_45);
lean_dec(x_44);
lean_dec(x_43);
lean_dec(x_42);
lean_dec(x_41);
lean_dec(x_40);
lean_dec(x_39);
lean_dec(x_38);
lean_dec(x_37);
lean_dec(x_24);
lean_dec(x_23);
lean_dec(x_22);
lean_dec(x_21);
lean_dec(x_20);
lean_dec(x_19);
lean_dec(x_18);
lean_dec(x_17);
lean_dec(x_16);
lean_dec(x_15);
return x_60;
}
else
{
uint8_t x_61; 
lean_inc_ref(x_47);
x_61 = l_Option_instDecidableEq___redArg(x_47, x_15, x_37);
if (x_61 == 0)
{
lean_dec_ref(x_52);
lean_dec_ref(x_47);
lean_dec(x_46);
lean_dec(x_45);
lean_dec(x_44);
lean_dec(x_43);
lean_dec(x_42);
lean_dec(x_41);
lean_dec(x_40);
lean_dec(x_39);
lean_dec(x_38);
lean_dec(x_24);
lean_dec(x_23);
lean_dec(x_22);
lean_dec(x_21);
lean_dec(x_20);
lean_dec(x_19);
lean_dec(x_18);
lean_dec(x_17);
lean_dec(x_16);
return x_61;
}
else
{
uint8_t x_62; 
lean_inc_ref(x_47);
x_62 = l_Option_instDecidableEq___redArg(x_47, x_16, x_38);
if (x_62 == 0)
{
lean_dec_ref(x_52);
lean_dec_ref(x_47);
lean_dec(x_46);
lean_dec(x_45);
lean_dec(x_44);
lean_dec(x_43);
lean_dec(x_42);
lean_dec(x_41);
lean_dec(x_40);
lean_dec(x_39);
lean_dec(x_24);
lean_dec(x_23);
lean_dec(x_22);
lean_dec(x_21);
lean_dec(x_20);
lean_dec(x_19);
lean_dec(x_18);
lean_dec(x_17);
return x_62;
}
else
{
uint8_t x_63; 
lean_inc_ref(x_47);
x_63 = l_Option_instDecidableEq___redArg(x_47, x_17, x_39);
if (x_63 == 0)
{
lean_dec_ref(x_52);
lean_dec_ref(x_47);
lean_dec(x_46);
lean_dec(x_45);
lean_dec(x_44);
lean_dec(x_43);
lean_dec(x_42);
lean_dec(x_41);
lean_dec(x_40);
lean_dec(x_24);
lean_dec(x_23);
lean_dec(x_22);
lean_dec(x_21);
lean_dec(x_20);
lean_dec(x_19);
lean_dec(x_18);
return x_63;
}
else
{
uint8_t x_64; 
lean_inc_ref(x_47);
x_64 = l_Option_instDecidableEq___redArg(x_47, x_18, x_40);
if (x_64 == 0)
{
lean_dec_ref(x_52);
lean_dec_ref(x_47);
lean_dec(x_46);
lean_dec(x_45);
lean_dec(x_44);
lean_dec(x_43);
lean_dec(x_42);
lean_dec(x_41);
lean_dec(x_24);
lean_dec(x_23);
lean_dec(x_22);
lean_dec(x_21);
lean_dec(x_20);
lean_dec(x_19);
return x_64;
}
else
{
uint8_t x_65; 
lean_inc_ref(x_47);
x_65 = l_Option_instDecidableEq___redArg(x_47, x_19, x_41);
if (x_65 == 0)
{
lean_dec_ref(x_52);
lean_dec_ref(x_47);
lean_dec(x_46);
lean_dec(x_45);
lean_dec(x_44);
lean_dec(x_43);
lean_dec(x_42);
lean_dec(x_24);
lean_dec(x_23);
lean_dec(x_22);
lean_dec(x_21);
lean_dec(x_20);
return x_65;
}
else
{
uint8_t x_66; 
lean_inc_ref(x_47);
x_66 = l_Option_instDecidableEq___redArg(x_47, x_20, x_42);
if (x_66 == 0)
{
lean_dec_ref(x_52);
lean_dec_ref(x_47);
lean_dec(x_46);
lean_dec(x_45);
lean_dec(x_44);
lean_dec(x_43);
lean_dec(x_24);
lean_dec(x_23);
lean_dec(x_22);
lean_dec(x_21);
return x_66;
}
else
{
uint8_t x_67; 
x_67 = l_Option_instDecidableEq___redArg(x_47, x_21, x_43);
if (x_67 == 0)
{
lean_dec_ref(x_52);
lean_dec(x_46);
lean_dec(x_45);
lean_dec(x_44);
lean_dec(x_24);
lean_dec(x_23);
lean_dec(x_22);
return x_67;
}
else
{
lean_object* x_68; lean_object* x_69; uint8_t x_70; 
x_68 = lean_box(x_67);
x_69 = lean_alloc_closure((void*)(lp_padctl_instDecidableEqGamepadStateDelta_decEq___lam__0___boxed), 3, 1);
lean_closure_set(x_69, 0, x_68);
lean_inc_ref(x_69);
x_70 = l_Option_instDecidableEq___redArg(x_69, x_22, x_44);
if (x_70 == 0)
{
lean_dec_ref(x_69);
lean_dec_ref(x_52);
lean_dec(x_46);
lean_dec(x_45);
lean_dec(x_24);
lean_dec(x_23);
return x_70;
}
else
{
uint8_t x_71; 
x_71 = l_Option_instDecidableEq___redArg(x_69, x_23, x_45);
if (x_71 == 0)
{
lean_dec_ref(x_52);
lean_dec(x_46);
lean_dec(x_24);
return x_71;
}
else
{
uint8_t x_72; 
x_72 = l_Option_instDecidableEq___redArg(x_52, x_24, x_46);
return x_72;
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
}
LEAN_EXPORT lean_object* lp_padctl_instDecidableEqGamepadStateDelta_decEq___boxed(lean_object* x_1, lean_object* x_2) {
_start:
{
uint8_t x_3; lean_object* x_4; 
x_3 = lp_padctl_instDecidableEqGamepadStateDelta_decEq(x_1, x_2);
x_4 = lean_box(x_3);
return x_4;
}
}
LEAN_EXPORT uint8_t lp_padctl_instDecidableEqGamepadStateDelta(lean_object* x_1, lean_object* x_2) {
_start:
{
uint8_t x_3; 
x_3 = lp_padctl_instDecidableEqGamepadStateDelta_decEq(x_1, x_2);
return x_3;
}
}
LEAN_EXPORT lean_object* lp_padctl_instDecidableEqGamepadStateDelta___boxed(lean_object* x_1, lean_object* x_2) {
_start:
{
uint8_t x_3; lean_object* x_4; 
x_3 = lp_padctl_instDecidableEqGamepadStateDelta(x_1, x_2);
x_4 = lean_box(x_3);
return x_4;
}
}
LEAN_EXPORT lean_object* lp_padctl_Option_repr___at___00instReprGamepadStateDelta_repr_spec__0(lean_object* x_1, lean_object* x_2) {
_start:
{
if (lean_obj_tag(x_1) == 0)
{
lean_object* x_3; 
x_3 = ((lean_object*)(lp_padctl_Option_repr___at___00instReprGamepadStateDelta_repr_spec__0___closed__1));
return x_3;
}
else
{
lean_object* x_4; lean_object* x_5; uint8_t x_6; lean_object* x_7; lean_object* x_8; lean_object* x_9; 
x_4 = lean_ctor_get(x_1, 0);
x_5 = ((lean_object*)(lp_padctl_Option_repr___at___00instReprGamepadStateDelta_repr_spec__0___closed__3));
x_6 = lean_unbox(x_4);
x_7 = l_Bool_repr___redArg(x_6);
x_8 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_8, 0, x_5);
lean_ctor_set(x_8, 1, x_7);
x_9 = l_Repr_addAppParen(x_8, x_2);
return x_9;
}
}
}
LEAN_EXPORT lean_object* lp_padctl_Option_repr___at___00instReprGamepadStateDelta_repr_spec__0___boxed(lean_object* x_1, lean_object* x_2) {
_start:
{
lean_object* x_3; 
x_3 = lp_padctl_Option_repr___at___00instReprGamepadStateDelta_repr_spec__0(x_1, x_2);
lean_dec(x_2);
lean_dec(x_1);
return x_3;
}
}
LEAN_EXPORT lean_object* lp_padctl_instReprGamepadStateDelta_repr___redArg(lean_object* x_1) {
_start:
{
lean_object* x_2; lean_object* x_3; lean_object* x_4; lean_object* x_5; lean_object* x_6; lean_object* x_7; lean_object* x_8; lean_object* x_9; lean_object* x_10; lean_object* x_11; lean_object* x_12; lean_object* x_13; lean_object* x_14; lean_object* x_15; lean_object* x_16; lean_object* x_17; lean_object* x_18; lean_object* x_19; lean_object* x_20; lean_object* x_21; lean_object* x_22; lean_object* x_23; lean_object* x_24; lean_object* x_25; lean_object* x_26; lean_object* x_27; lean_object* x_28; lean_object* x_29; uint8_t x_30; lean_object* x_31; lean_object* x_32; lean_object* x_33; lean_object* x_34; lean_object* x_35; lean_object* x_36; lean_object* x_37; lean_object* x_38; lean_object* x_39; lean_object* x_40; lean_object* x_41; lean_object* x_42; lean_object* x_43; lean_object* x_44; lean_object* x_45; lean_object* x_46; lean_object* x_47; lean_object* x_48; lean_object* x_49; lean_object* x_50; lean_object* x_51; lean_object* x_52; lean_object* x_53; lean_object* x_54; lean_object* x_55; lean_object* x_56; lean_object* x_57; lean_object* x_58; lean_object* x_59; lean_object* x_60; lean_object* x_61; lean_object* x_62; lean_object* x_63; lean_object* x_64; lean_object* x_65; lean_object* x_66; lean_object* x_67; lean_object* x_68; lean_object* x_69; lean_object* x_70; lean_object* x_71; lean_object* x_72; lean_object* x_73; lean_object* x_74; lean_object* x_75; lean_object* x_76; lean_object* x_77; lean_object* x_78; lean_object* x_79; lean_object* x_80; lean_object* x_81; lean_object* x_82; lean_object* x_83; lean_object* x_84; lean_object* x_85; lean_object* x_86; lean_object* x_87; lean_object* x_88; lean_object* x_89; lean_object* x_90; lean_object* x_91; lean_object* x_92; lean_object* x_93; lean_object* x_94; lean_object* x_95; lean_object* x_96; lean_object* x_97; lean_object* x_98; lean_object* x_99; lean_object* x_100; lean_object* x_101; lean_object* x_102; lean_object* x_103; lean_object* x_104; lean_object* x_105; lean_object* x_106; lean_object* x_107; lean_object* x_108; lean_object* x_109; lean_object* x_110; lean_object* x_111; lean_object* x_112; lean_object* x_113; lean_object* x_114; lean_object* x_115; lean_object* x_116; lean_object* x_117; lean_object* x_118; lean_object* x_119; lean_object* x_120; lean_object* x_121; lean_object* x_122; lean_object* x_123; lean_object* x_124; lean_object* x_125; lean_object* x_126; lean_object* x_127; lean_object* x_128; lean_object* x_129; lean_object* x_130; lean_object* x_131; lean_object* x_132; lean_object* x_133; lean_object* x_134; lean_object* x_135; lean_object* x_136; lean_object* x_137; lean_object* x_138; lean_object* x_139; lean_object* x_140; lean_object* x_141; lean_object* x_142; lean_object* x_143; lean_object* x_144; lean_object* x_145; lean_object* x_146; lean_object* x_147; lean_object* x_148; lean_object* x_149; lean_object* x_150; lean_object* x_151; lean_object* x_152; lean_object* x_153; lean_object* x_154; lean_object* x_155; lean_object* x_156; lean_object* x_157; lean_object* x_158; lean_object* x_159; lean_object* x_160; lean_object* x_161; lean_object* x_162; lean_object* x_163; lean_object* x_164; lean_object* x_165; lean_object* x_166; lean_object* x_167; lean_object* x_168; lean_object* x_169; lean_object* x_170; lean_object* x_171; lean_object* x_172; lean_object* x_173; lean_object* x_174; lean_object* x_175; lean_object* x_176; lean_object* x_177; lean_object* x_178; lean_object* x_179; lean_object* x_180; lean_object* x_181; lean_object* x_182; lean_object* x_183; lean_object* x_184; lean_object* x_185; lean_object* x_186; lean_object* x_187; lean_object* x_188; lean_object* x_189; lean_object* x_190; lean_object* x_191; lean_object* x_192; lean_object* x_193; lean_object* x_194; lean_object* x_195; lean_object* x_196; lean_object* x_197; lean_object* x_198; lean_object* x_199; lean_object* x_200; lean_object* x_201; lean_object* x_202; lean_object* x_203; lean_object* x_204; lean_object* x_205; lean_object* x_206; lean_object* x_207; lean_object* x_208; lean_object* x_209; lean_object* x_210; lean_object* x_211; lean_object* x_212; lean_object* x_213; lean_object* x_214; lean_object* x_215; lean_object* x_216; lean_object* x_217; lean_object* x_218; lean_object* x_219; lean_object* x_220; lean_object* x_221; lean_object* x_222; lean_object* x_223; lean_object* x_224; lean_object* x_225; lean_object* x_226; lean_object* x_227; lean_object* x_228; lean_object* x_229; lean_object* x_230; lean_object* x_231; lean_object* x_232; lean_object* x_233; lean_object* x_234; 
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
x_8 = lean_ctor_get(x_1, 6);
lean_inc(x_8);
x_9 = lean_ctor_get(x_1, 7);
lean_inc(x_9);
x_10 = lean_ctor_get(x_1, 8);
lean_inc(x_10);
x_11 = lean_ctor_get(x_1, 9);
lean_inc(x_11);
x_12 = lean_ctor_get(x_1, 10);
lean_inc(x_12);
x_13 = lean_ctor_get(x_1, 11);
lean_inc(x_13);
x_14 = lean_ctor_get(x_1, 12);
lean_inc(x_14);
x_15 = lean_ctor_get(x_1, 13);
lean_inc(x_15);
x_16 = lean_ctor_get(x_1, 14);
lean_inc(x_16);
x_17 = lean_ctor_get(x_1, 15);
lean_inc(x_17);
x_18 = lean_ctor_get(x_1, 16);
lean_inc(x_18);
x_19 = lean_ctor_get(x_1, 17);
lean_inc(x_19);
x_20 = lean_ctor_get(x_1, 18);
lean_inc(x_20);
x_21 = lean_ctor_get(x_1, 19);
lean_inc(x_21);
x_22 = lean_ctor_get(x_1, 20);
lean_inc(x_22);
x_23 = lean_ctor_get(x_1, 21);
lean_inc(x_23);
lean_dec_ref(x_1);
x_24 = ((lean_object*)(lp_padctl_instReprGamepadState_repr___redArg___closed__5));
x_25 = ((lean_object*)(lp_padctl_instReprGamepadState_repr___redArg___closed__42));
x_26 = lean_obj_once(&lp_padctl_instReprGamepadState_repr___redArg___closed__43, &lp_padctl_instReprGamepadState_repr___redArg___closed__43_once, _init_lp_padctl_instReprGamepadState_repr___redArg___closed__43);
x_27 = lean_unsigned_to_nat(0u);
x_28 = l_Option_repr___at___00Lean_Omega_instReprConstraint_repr_spec__0(x_2, x_27);
x_29 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_29, 0, x_26);
lean_ctor_set(x_29, 1, x_28);
x_30 = 0;
x_31 = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(x_31, 0, x_29);
lean_ctor_set_uint8(x_31, sizeof(void*)*1, x_30);
x_32 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_32, 0, x_25);
lean_ctor_set(x_32, 1, x_31);
x_33 = ((lean_object*)(lp_padctl_instReprGamepadState_repr___redArg___closed__59));
x_34 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_34, 0, x_32);
lean_ctor_set(x_34, 1, x_33);
x_35 = lean_box(1);
x_36 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_36, 0, x_34);
lean_ctor_set(x_36, 1, x_35);
x_37 = ((lean_object*)(lp_padctl_instReprGamepadState_repr___redArg___closed__61));
x_38 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_38, 0, x_36);
lean_ctor_set(x_38, 1, x_37);
x_39 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_39, 0, x_38);
lean_ctor_set(x_39, 1, x_24);
x_40 = l_Option_repr___at___00Lean_Omega_instReprConstraint_repr_spec__0(x_3, x_27);
x_41 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_41, 0, x_26);
lean_ctor_set(x_41, 1, x_40);
x_42 = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(x_42, 0, x_41);
lean_ctor_set_uint8(x_42, sizeof(void*)*1, x_30);
x_43 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_43, 0, x_39);
lean_ctor_set(x_43, 1, x_42);
x_44 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_44, 0, x_43);
lean_ctor_set(x_44, 1, x_33);
x_45 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_45, 0, x_44);
lean_ctor_set(x_45, 1, x_35);
x_46 = ((lean_object*)(lp_padctl_instReprGamepadState_repr___redArg___closed__57));
x_47 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_47, 0, x_45);
lean_ctor_set(x_47, 1, x_46);
x_48 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_48, 0, x_47);
lean_ctor_set(x_48, 1, x_24);
x_49 = l_Option_repr___at___00Lean_Omega_instReprConstraint_repr_spec__0(x_4, x_27);
x_50 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_50, 0, x_26);
lean_ctor_set(x_50, 1, x_49);
x_51 = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(x_51, 0, x_50);
lean_ctor_set_uint8(x_51, sizeof(void*)*1, x_30);
x_52 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_52, 0, x_48);
lean_ctor_set(x_52, 1, x_51);
x_53 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_53, 0, x_52);
lean_ctor_set(x_53, 1, x_33);
x_54 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_54, 0, x_53);
lean_ctor_set(x_54, 1, x_35);
x_55 = ((lean_object*)(lp_padctl_instReprGamepadState_repr___redArg___closed__55));
x_56 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_56, 0, x_54);
lean_ctor_set(x_56, 1, x_55);
x_57 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_57, 0, x_56);
lean_ctor_set(x_57, 1, x_24);
x_58 = l_Option_repr___at___00Lean_Omega_instReprConstraint_repr_spec__0(x_5, x_27);
x_59 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_59, 0, x_26);
lean_ctor_set(x_59, 1, x_58);
x_60 = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(x_60, 0, x_59);
lean_ctor_set_uint8(x_60, sizeof(void*)*1, x_30);
x_61 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_61, 0, x_57);
lean_ctor_set(x_61, 1, x_60);
x_62 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_62, 0, x_61);
lean_ctor_set(x_62, 1, x_33);
x_63 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_63, 0, x_62);
lean_ctor_set(x_63, 1, x_35);
x_64 = ((lean_object*)(lp_padctl_instReprGamepadState_repr___redArg___closed__45));
x_65 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_65, 0, x_63);
lean_ctor_set(x_65, 1, x_64);
x_66 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_66, 0, x_65);
lean_ctor_set(x_66, 1, x_24);
x_67 = l_Option_repr___at___00Lean_Meta_instReprConfig__1_repr_spec__0(x_6, x_27);
x_68 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_68, 0, x_26);
lean_ctor_set(x_68, 1, x_67);
x_69 = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(x_69, 0, x_68);
lean_ctor_set_uint8(x_69, sizeof(void*)*1, x_30);
x_70 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_70, 0, x_66);
lean_ctor_set(x_70, 1, x_69);
x_71 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_71, 0, x_70);
lean_ctor_set(x_71, 1, x_33);
x_72 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_72, 0, x_71);
lean_ctor_set(x_72, 1, x_35);
x_73 = ((lean_object*)(lp_padctl_instReprGamepadState_repr___redArg___closed__47));
x_74 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_74, 0, x_72);
lean_ctor_set(x_74, 1, x_73);
x_75 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_75, 0, x_74);
lean_ctor_set(x_75, 1, x_24);
x_76 = l_Option_repr___at___00Lean_Meta_instReprConfig__1_repr_spec__0(x_7, x_27);
x_77 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_77, 0, x_26);
lean_ctor_set(x_77, 1, x_76);
x_78 = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(x_78, 0, x_77);
lean_ctor_set_uint8(x_78, sizeof(void*)*1, x_30);
x_79 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_79, 0, x_75);
lean_ctor_set(x_79, 1, x_78);
x_80 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_80, 0, x_79);
lean_ctor_set(x_80, 1, x_33);
x_81 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_81, 0, x_80);
lean_ctor_set(x_81, 1, x_35);
x_82 = ((lean_object*)(lp_padctl_instReprGamepadState_repr___redArg___closed__49));
x_83 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_83, 0, x_81);
lean_ctor_set(x_83, 1, x_82);
x_84 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_84, 0, x_83);
lean_ctor_set(x_84, 1, x_24);
x_85 = lean_obj_once(&lp_padctl_instReprGamepadState_repr___redArg___closed__50, &lp_padctl_instReprGamepadState_repr___redArg___closed__50_once, _init_lp_padctl_instReprGamepadState_repr___redArg___closed__50);
x_86 = l_Option_repr___at___00Lean_Meta_instReprConfig__1_repr_spec__0(x_8, x_27);
x_87 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_87, 0, x_85);
lean_ctor_set(x_87, 1, x_86);
x_88 = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(x_88, 0, x_87);
lean_ctor_set_uint8(x_88, sizeof(void*)*1, x_30);
x_89 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_89, 0, x_84);
lean_ctor_set(x_89, 1, x_88);
x_90 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_90, 0, x_89);
lean_ctor_set(x_90, 1, x_33);
x_91 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_91, 0, x_90);
lean_ctor_set(x_91, 1, x_35);
x_92 = ((lean_object*)(lp_padctl_instReprGamepadState_repr___redArg___closed__52));
x_93 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_93, 0, x_91);
lean_ctor_set(x_93, 1, x_92);
x_94 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_94, 0, x_93);
lean_ctor_set(x_94, 1, x_24);
x_95 = lean_obj_once(&lp_padctl_instReprGamepadState_repr___redArg___closed__53, &lp_padctl_instReprGamepadState_repr___redArg___closed__53_once, _init_lp_padctl_instReprGamepadState_repr___redArg___closed__53);
x_96 = l_Option_repr___at___00Lean_Omega_instReprConstraint_repr_spec__0(x_9, x_27);
x_97 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_97, 0, x_95);
lean_ctor_set(x_97, 1, x_96);
x_98 = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(x_98, 0, x_97);
lean_ctor_set_uint8(x_98, sizeof(void*)*1, x_30);
x_99 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_99, 0, x_94);
lean_ctor_set(x_99, 1, x_98);
x_100 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_100, 0, x_99);
lean_ctor_set(x_100, 1, x_33);
x_101 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_101, 0, x_100);
lean_ctor_set(x_101, 1, x_35);
x_102 = ((lean_object*)(lp_padctl_instReprGamepadState_repr___redArg___closed__41));
x_103 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_103, 0, x_101);
lean_ctor_set(x_103, 1, x_102);
x_104 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_104, 0, x_103);
lean_ctor_set(x_104, 1, x_24);
x_105 = l_Option_repr___at___00Lean_Omega_instReprConstraint_repr_spec__0(x_10, x_27);
x_106 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_106, 0, x_95);
lean_ctor_set(x_106, 1, x_105);
x_107 = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(x_107, 0, x_106);
lean_ctor_set_uint8(x_107, sizeof(void*)*1, x_30);
x_108 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_108, 0, x_104);
lean_ctor_set(x_108, 1, x_107);
x_109 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_109, 0, x_108);
lean_ctor_set(x_109, 1, x_33);
x_110 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_110, 0, x_109);
lean_ctor_set(x_110, 1, x_35);
x_111 = ((lean_object*)(lp_padctl_instReprGamepadState_repr___redArg___closed__39));
x_112 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_112, 0, x_110);
lean_ctor_set(x_112, 1, x_111);
x_113 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_113, 0, x_112);
lean_ctor_set(x_113, 1, x_24);
x_114 = l_Option_repr___at___00Lean_Omega_instReprConstraint_repr_spec__0(x_11, x_27);
x_115 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_115, 0, x_95);
lean_ctor_set(x_115, 1, x_114);
x_116 = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(x_116, 0, x_115);
lean_ctor_set_uint8(x_116, sizeof(void*)*1, x_30);
x_117 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_117, 0, x_113);
lean_ctor_set(x_117, 1, x_116);
x_118 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_118, 0, x_117);
lean_ctor_set(x_118, 1, x_33);
x_119 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_119, 0, x_118);
lean_ctor_set(x_119, 1, x_35);
x_120 = ((lean_object*)(lp_padctl_instReprGamepadState_repr___redArg___closed__37));
x_121 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_121, 0, x_119);
lean_ctor_set(x_121, 1, x_120);
x_122 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_122, 0, x_121);
lean_ctor_set(x_122, 1, x_24);
x_123 = l_Option_repr___at___00Lean_Omega_instReprConstraint_repr_spec__0(x_12, x_27);
x_124 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_124, 0, x_95);
lean_ctor_set(x_124, 1, x_123);
x_125 = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(x_125, 0, x_124);
lean_ctor_set_uint8(x_125, sizeof(void*)*1, x_30);
x_126 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_126, 0, x_122);
lean_ctor_set(x_126, 1, x_125);
x_127 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_127, 0, x_126);
lean_ctor_set(x_127, 1, x_33);
x_128 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_128, 0, x_127);
lean_ctor_set(x_128, 1, x_35);
x_129 = ((lean_object*)(lp_padctl_instReprGamepadState_repr___redArg___closed__35));
x_130 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_130, 0, x_128);
lean_ctor_set(x_130, 1, x_129);
x_131 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_131, 0, x_130);
lean_ctor_set(x_131, 1, x_24);
x_132 = l_Option_repr___at___00Lean_Omega_instReprConstraint_repr_spec__0(x_13, x_27);
x_133 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_133, 0, x_95);
lean_ctor_set(x_133, 1, x_132);
x_134 = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(x_134, 0, x_133);
lean_ctor_set_uint8(x_134, sizeof(void*)*1, x_30);
x_135 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_135, 0, x_131);
lean_ctor_set(x_135, 1, x_134);
x_136 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_136, 0, x_135);
lean_ctor_set(x_136, 1, x_33);
x_137 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_137, 0, x_136);
lean_ctor_set(x_137, 1, x_35);
x_138 = ((lean_object*)(lp_padctl_instReprGamepadState_repr___redArg___closed__33));
x_139 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_139, 0, x_137);
lean_ctor_set(x_139, 1, x_138);
x_140 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_140, 0, x_139);
lean_ctor_set(x_140, 1, x_24);
x_141 = l_Option_repr___at___00Lean_Omega_instReprConstraint_repr_spec__0(x_14, x_27);
x_142 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_142, 0, x_85);
lean_ctor_set(x_142, 1, x_141);
x_143 = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(x_143, 0, x_142);
lean_ctor_set_uint8(x_143, sizeof(void*)*1, x_30);
x_144 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_144, 0, x_140);
lean_ctor_set(x_144, 1, x_143);
x_145 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_145, 0, x_144);
lean_ctor_set(x_145, 1, x_33);
x_146 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_146, 0, x_145);
lean_ctor_set(x_146, 1, x_35);
x_147 = ((lean_object*)(lp_padctl_instReprGamepadState_repr___redArg___closed__31));
x_148 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_148, 0, x_146);
lean_ctor_set(x_148, 1, x_147);
x_149 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_149, 0, x_148);
lean_ctor_set(x_149, 1, x_24);
x_150 = l_Option_repr___at___00Lean_Omega_instReprConstraint_repr_spec__0(x_15, x_27);
x_151 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_151, 0, x_85);
lean_ctor_set(x_151, 1, x_150);
x_152 = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(x_152, 0, x_151);
lean_ctor_set_uint8(x_152, sizeof(void*)*1, x_30);
x_153 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_153, 0, x_149);
lean_ctor_set(x_153, 1, x_152);
x_154 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_154, 0, x_153);
lean_ctor_set(x_154, 1, x_33);
x_155 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_155, 0, x_154);
lean_ctor_set(x_155, 1, x_35);
x_156 = ((lean_object*)(lp_padctl_instReprGamepadState_repr___redArg___closed__29));
x_157 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_157, 0, x_155);
lean_ctor_set(x_157, 1, x_156);
x_158 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_158, 0, x_157);
lean_ctor_set(x_158, 1, x_24);
x_159 = l_Option_repr___at___00Lean_Omega_instReprConstraint_repr_spec__0(x_16, x_27);
x_160 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_160, 0, x_85);
lean_ctor_set(x_160, 1, x_159);
x_161 = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(x_161, 0, x_160);
lean_ctor_set_uint8(x_161, sizeof(void*)*1, x_30);
x_162 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_162, 0, x_158);
lean_ctor_set(x_162, 1, x_161);
x_163 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_163, 0, x_162);
lean_ctor_set(x_163, 1, x_33);
x_164 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_164, 0, x_163);
lean_ctor_set(x_164, 1, x_35);
x_165 = ((lean_object*)(lp_padctl_instReprGamepadState_repr___redArg___closed__26));
x_166 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_166, 0, x_164);
lean_ctor_set(x_166, 1, x_165);
x_167 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_167, 0, x_166);
lean_ctor_set(x_167, 1, x_24);
x_168 = lean_obj_once(&lp_padctl_instReprGamepadState_repr___redArg___closed__27, &lp_padctl_instReprGamepadState_repr___redArg___closed__27_once, _init_lp_padctl_instReprGamepadState_repr___redArg___closed__27);
x_169 = l_Option_repr___at___00Lean_Omega_instReprConstraint_repr_spec__0(x_17, x_27);
x_170 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_170, 0, x_168);
lean_ctor_set(x_170, 1, x_169);
x_171 = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(x_171, 0, x_170);
lean_ctor_set_uint8(x_171, sizeof(void*)*1, x_30);
x_172 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_172, 0, x_167);
lean_ctor_set(x_172, 1, x_171);
x_173 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_173, 0, x_172);
lean_ctor_set(x_173, 1, x_33);
x_174 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_174, 0, x_173);
lean_ctor_set(x_174, 1, x_35);
x_175 = ((lean_object*)(lp_padctl_instReprGamepadState_repr___redArg___closed__24));
x_176 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_176, 0, x_174);
lean_ctor_set(x_176, 1, x_175);
x_177 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_177, 0, x_176);
lean_ctor_set(x_177, 1, x_24);
x_178 = l_Option_repr___at___00Lean_Omega_instReprConstraint_repr_spec__0(x_18, x_27);
x_179 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_179, 0, x_168);
lean_ctor_set(x_179, 1, x_178);
x_180 = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(x_180, 0, x_179);
lean_ctor_set_uint8(x_180, sizeof(void*)*1, x_30);
x_181 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_181, 0, x_177);
lean_ctor_set(x_181, 1, x_180);
x_182 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_182, 0, x_181);
lean_ctor_set(x_182, 1, x_33);
x_183 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_183, 0, x_182);
lean_ctor_set(x_183, 1, x_35);
x_184 = ((lean_object*)(lp_padctl_instReprGamepadState_repr___redArg___closed__22));
x_185 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_185, 0, x_183);
lean_ctor_set(x_185, 1, x_184);
x_186 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_186, 0, x_185);
lean_ctor_set(x_186, 1, x_24);
x_187 = l_Option_repr___at___00Lean_Omega_instReprConstraint_repr_spec__0(x_19, x_27);
x_188 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_188, 0, x_168);
lean_ctor_set(x_188, 1, x_187);
x_189 = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(x_189, 0, x_188);
lean_ctor_set_uint8(x_189, sizeof(void*)*1, x_30);
x_190 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_190, 0, x_186);
lean_ctor_set(x_190, 1, x_189);
x_191 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_191, 0, x_190);
lean_ctor_set(x_191, 1, x_33);
x_192 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_192, 0, x_191);
lean_ctor_set(x_192, 1, x_35);
x_193 = ((lean_object*)(lp_padctl_instReprGamepadState_repr___redArg___closed__19));
x_194 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_194, 0, x_192);
lean_ctor_set(x_194, 1, x_193);
x_195 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_195, 0, x_194);
lean_ctor_set(x_195, 1, x_24);
x_196 = l_Option_repr___at___00Lean_Omega_instReprConstraint_repr_spec__0(x_20, x_27);
x_197 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_197, 0, x_168);
lean_ctor_set(x_197, 1, x_196);
x_198 = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(x_198, 0, x_197);
lean_ctor_set_uint8(x_198, sizeof(void*)*1, x_30);
x_199 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_199, 0, x_195);
lean_ctor_set(x_199, 1, x_198);
x_200 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_200, 0, x_199);
lean_ctor_set(x_200, 1, x_33);
x_201 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_201, 0, x_200);
lean_ctor_set(x_201, 1, x_35);
x_202 = ((lean_object*)(lp_padctl_instReprGamepadState_repr___redArg___closed__7));
x_203 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_203, 0, x_201);
lean_ctor_set(x_203, 1, x_202);
x_204 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_204, 0, x_203);
lean_ctor_set(x_204, 1, x_24);
x_205 = lean_obj_once(&lp_padctl_instReprGamepadState_repr___redArg___closed__8, &lp_padctl_instReprGamepadState_repr___redArg___closed__8_once, _init_lp_padctl_instReprGamepadState_repr___redArg___closed__8);
x_206 = lp_padctl_Option_repr___at___00instReprGamepadStateDelta_repr_spec__0(x_21, x_27);
lean_dec(x_21);
x_207 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_207, 0, x_205);
lean_ctor_set(x_207, 1, x_206);
x_208 = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(x_208, 0, x_207);
lean_ctor_set_uint8(x_208, sizeof(void*)*1, x_30);
x_209 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_209, 0, x_204);
lean_ctor_set(x_209, 1, x_208);
x_210 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_210, 0, x_209);
lean_ctor_set(x_210, 1, x_33);
x_211 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_211, 0, x_210);
lean_ctor_set(x_211, 1, x_35);
x_212 = ((lean_object*)(lp_padctl_instReprGamepadState_repr___redArg___closed__10));
x_213 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_213, 0, x_211);
lean_ctor_set(x_213, 1, x_212);
x_214 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_214, 0, x_213);
lean_ctor_set(x_214, 1, x_24);
x_215 = lp_padctl_Option_repr___at___00instReprGamepadStateDelta_repr_spec__0(x_22, x_27);
lean_dec(x_22);
x_216 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_216, 0, x_205);
lean_ctor_set(x_216, 1, x_215);
x_217 = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(x_217, 0, x_216);
lean_ctor_set_uint8(x_217, sizeof(void*)*1, x_30);
x_218 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_218, 0, x_214);
lean_ctor_set(x_218, 1, x_217);
x_219 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_219, 0, x_218);
lean_ctor_set(x_219, 1, x_33);
x_220 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_220, 0, x_219);
lean_ctor_set(x_220, 1, x_35);
x_221 = ((lean_object*)(lp_padctl_instReprGamepadState_repr___redArg___closed__12));
x_222 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_222, 0, x_220);
lean_ctor_set(x_222, 1, x_221);
x_223 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_223, 0, x_222);
lean_ctor_set(x_223, 1, x_24);
x_224 = l_Option_repr___at___00Lean_Meta_instReprConfig__1_repr_spec__0(x_23, x_27);
x_225 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_225, 0, x_205);
lean_ctor_set(x_225, 1, x_224);
x_226 = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(x_226, 0, x_225);
lean_ctor_set_uint8(x_226, sizeof(void*)*1, x_30);
x_227 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_227, 0, x_223);
lean_ctor_set(x_227, 1, x_226);
x_228 = lean_obj_once(&lp_padctl_instReprGamepadState_repr___redArg___closed__15, &lp_padctl_instReprGamepadState_repr___redArg___closed__15_once, _init_lp_padctl_instReprGamepadState_repr___redArg___closed__15);
x_229 = ((lean_object*)(lp_padctl_instReprGamepadState_repr___redArg___closed__16));
x_230 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_230, 0, x_229);
lean_ctor_set(x_230, 1, x_227);
x_231 = ((lean_object*)(lp_padctl_instReprGamepadState_repr___redArg___closed__17));
x_232 = lean_alloc_ctor(5, 2, 0);
lean_ctor_set(x_232, 0, x_230);
lean_ctor_set(x_232, 1, x_231);
x_233 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_233, 0, x_228);
lean_ctor_set(x_233, 1, x_232);
x_234 = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(x_234, 0, x_233);
lean_ctor_set_uint8(x_234, sizeof(void*)*1, x_30);
return x_234;
}
}
LEAN_EXPORT lean_object* lp_padctl_instReprGamepadStateDelta_repr(lean_object* x_1, lean_object* x_2) {
_start:
{
lean_object* x_3; 
x_3 = lp_padctl_instReprGamepadStateDelta_repr___redArg(x_1);
return x_3;
}
}
LEAN_EXPORT lean_object* lp_padctl_instReprGamepadStateDelta_repr___boxed(lean_object* x_1, lean_object* x_2) {
_start:
{
lean_object* x_3; 
x_3 = lp_padctl_instReprGamepadStateDelta_repr(x_1, x_2);
lean_dec(x_2);
return x_3;
}
}
LEAN_EXPORT lean_object* lp_padctl_applyDelta(lean_object* x_1, lean_object* x_2) {
_start:
{
lean_object* x_3; lean_object* x_4; lean_object* x_5; lean_object* x_6; lean_object* x_7; lean_object* x_8; lean_object* x_9; lean_object* x_10; lean_object* x_11; lean_object* x_12; lean_object* x_13; lean_object* x_14; lean_object* x_15; lean_object* x_16; lean_object* x_17; lean_object* x_18; lean_object* x_19; lean_object* x_20; lean_object* x_21; lean_object* x_22; lean_object* x_23; lean_object* x_24; lean_object* x_25; lean_object* x_26; lean_object* x_27; lean_object* x_28; lean_object* x_29; lean_object* x_30; lean_object* x_31; lean_object* x_32; lean_object* x_33; lean_object* x_34; lean_object* x_35; lean_object* x_36; lean_object* x_37; lean_object* x_38; lean_object* x_39; uint8_t x_40; lean_object* x_41; lean_object* x_42; lean_object* x_43; lean_object* x_44; uint8_t x_45; lean_object* x_71; lean_object* x_72; lean_object* x_73; lean_object* x_74; lean_object* x_75; lean_object* x_76; lean_object* x_77; lean_object* x_78; lean_object* x_79; lean_object* x_80; lean_object* x_81; lean_object* x_82; lean_object* x_83; lean_object* x_84; lean_object* x_85; lean_object* x_86; lean_object* x_87; lean_object* x_88; lean_object* x_89; uint8_t x_90; lean_object* x_95; lean_object* x_96; lean_object* x_97; lean_object* x_98; lean_object* x_99; lean_object* x_100; lean_object* x_101; lean_object* x_102; lean_object* x_103; lean_object* x_104; lean_object* x_105; lean_object* x_106; lean_object* x_107; lean_object* x_108; lean_object* x_109; lean_object* x_110; lean_object* x_111; lean_object* x_112; lean_object* x_113; lean_object* x_118; lean_object* x_119; lean_object* x_120; lean_object* x_121; lean_object* x_122; lean_object* x_123; lean_object* x_124; lean_object* x_125; lean_object* x_126; lean_object* x_127; lean_object* x_128; lean_object* x_129; lean_object* x_130; lean_object* x_131; lean_object* x_132; lean_object* x_133; lean_object* x_134; lean_object* x_135; lean_object* x_139; lean_object* x_140; lean_object* x_141; lean_object* x_142; lean_object* x_143; lean_object* x_144; lean_object* x_145; lean_object* x_146; lean_object* x_147; lean_object* x_148; lean_object* x_149; lean_object* x_150; lean_object* x_151; lean_object* x_152; lean_object* x_153; lean_object* x_154; lean_object* x_155; lean_object* x_159; lean_object* x_160; lean_object* x_161; lean_object* x_162; lean_object* x_163; lean_object* x_164; lean_object* x_165; lean_object* x_166; lean_object* x_167; lean_object* x_168; lean_object* x_169; lean_object* x_170; lean_object* x_171; lean_object* x_172; lean_object* x_173; lean_object* x_174; lean_object* x_178; lean_object* x_179; lean_object* x_180; lean_object* x_181; lean_object* x_182; lean_object* x_183; lean_object* x_184; lean_object* x_185; lean_object* x_186; lean_object* x_187; lean_object* x_188; lean_object* x_189; lean_object* x_190; lean_object* x_191; lean_object* x_192; lean_object* x_196; lean_object* x_197; lean_object* x_198; lean_object* x_199; lean_object* x_200; lean_object* x_201; lean_object* x_202; lean_object* x_203; lean_object* x_204; lean_object* x_205; lean_object* x_206; lean_object* x_207; lean_object* x_208; lean_object* x_209; lean_object* x_213; lean_object* x_214; lean_object* x_215; lean_object* x_216; lean_object* x_217; lean_object* x_218; lean_object* x_219; lean_object* x_220; lean_object* x_221; lean_object* x_222; lean_object* x_223; lean_object* x_224; lean_object* x_225; lean_object* x_229; lean_object* x_230; lean_object* x_231; lean_object* x_232; lean_object* x_233; lean_object* x_234; lean_object* x_235; lean_object* x_236; lean_object* x_237; lean_object* x_238; lean_object* x_239; lean_object* x_240; lean_object* x_244; lean_object* x_245; lean_object* x_246; lean_object* x_247; lean_object* x_248; lean_object* x_249; lean_object* x_250; lean_object* x_251; lean_object* x_252; lean_object* x_253; lean_object* x_254; lean_object* x_258; lean_object* x_259; lean_object* x_260; lean_object* x_261; lean_object* x_262; lean_object* x_263; lean_object* x_264; lean_object* x_265; lean_object* x_266; lean_object* x_267; lean_object* x_271; lean_object* x_272; lean_object* x_273; lean_object* x_274; lean_object* x_275; lean_object* x_276; lean_object* x_277; lean_object* x_278; lean_object* x_279; lean_object* x_283; lean_object* x_284; lean_object* x_285; lean_object* x_286; lean_object* x_287; lean_object* x_288; lean_object* x_289; lean_object* x_290; lean_object* x_294; lean_object* x_295; lean_object* x_296; lean_object* x_297; lean_object* x_298; lean_object* x_299; lean_object* x_300; lean_object* x_304; lean_object* x_305; lean_object* x_306; lean_object* x_307; lean_object* x_308; lean_object* x_309; lean_object* x_313; lean_object* x_314; lean_object* x_315; lean_object* x_316; lean_object* x_317; lean_object* x_321; lean_object* x_322; lean_object* x_323; lean_object* x_324; lean_object* x_328; lean_object* x_329; lean_object* x_330; lean_object* x_334; lean_object* x_335; lean_object* x_339; 
x_3 = lean_ctor_get(x_2, 0);
lean_inc(x_3);
x_4 = lean_ctor_get(x_2, 1);
lean_inc(x_4);
x_5 = lean_ctor_get(x_2, 2);
lean_inc(x_5);
x_6 = lean_ctor_get(x_2, 3);
lean_inc(x_6);
x_7 = lean_ctor_get(x_2, 4);
lean_inc(x_7);
x_8 = lean_ctor_get(x_2, 5);
lean_inc(x_8);
x_9 = lean_ctor_get(x_2, 6);
lean_inc(x_9);
x_10 = lean_ctor_get(x_2, 7);
lean_inc(x_10);
x_11 = lean_ctor_get(x_2, 8);
lean_inc(x_11);
x_12 = lean_ctor_get(x_2, 9);
lean_inc(x_12);
x_13 = lean_ctor_get(x_2, 10);
lean_inc(x_13);
x_14 = lean_ctor_get(x_2, 11);
lean_inc(x_14);
x_15 = lean_ctor_get(x_2, 12);
lean_inc(x_15);
x_16 = lean_ctor_get(x_2, 13);
lean_inc(x_16);
x_17 = lean_ctor_get(x_2, 14);
lean_inc(x_17);
x_18 = lean_ctor_get(x_2, 15);
lean_inc(x_18);
x_19 = lean_ctor_get(x_2, 16);
lean_inc(x_19);
x_20 = lean_ctor_get(x_2, 17);
lean_inc(x_20);
x_21 = lean_ctor_get(x_2, 18);
lean_inc(x_21);
x_22 = lean_ctor_get(x_2, 19);
lean_inc(x_22);
x_23 = lean_ctor_get(x_2, 20);
lean_inc(x_23);
x_24 = lean_ctor_get(x_2, 21);
lean_inc(x_24);
lean_dec_ref(x_2);
if (lean_obj_tag(x_3) == 0)
{
lean_object* x_343; 
x_343 = lean_ctor_get(x_1, 0);
lean_inc(x_343);
x_339 = x_343;
goto block_342;
}
else
{
lean_object* x_344; 
x_344 = lean_ctor_get(x_3, 0);
lean_inc(x_344);
lean_dec_ref(x_3);
x_339 = x_344;
goto block_342;
}
block_70:
{
if (lean_obj_tag(x_24) == 0)
{
uint8_t x_46; 
x_46 = !lean_is_exclusive(x_1);
if (x_46 == 0)
{
lean_object* x_47; lean_object* x_48; lean_object* x_49; lean_object* x_50; lean_object* x_51; lean_object* x_52; lean_object* x_53; lean_object* x_54; lean_object* x_55; lean_object* x_56; lean_object* x_57; lean_object* x_58; lean_object* x_59; lean_object* x_60; lean_object* x_61; lean_object* x_62; lean_object* x_63; lean_object* x_64; lean_object* x_65; 
x_47 = lean_ctor_get(x_1, 18);
lean_dec(x_47);
x_48 = lean_ctor_get(x_1, 17);
lean_dec(x_48);
x_49 = lean_ctor_get(x_1, 16);
lean_dec(x_49);
x_50 = lean_ctor_get(x_1, 15);
lean_dec(x_50);
x_51 = lean_ctor_get(x_1, 14);
lean_dec(x_51);
x_52 = lean_ctor_get(x_1, 13);
lean_dec(x_52);
x_53 = lean_ctor_get(x_1, 12);
lean_dec(x_53);
x_54 = lean_ctor_get(x_1, 11);
lean_dec(x_54);
x_55 = lean_ctor_get(x_1, 10);
lean_dec(x_55);
x_56 = lean_ctor_get(x_1, 9);
lean_dec(x_56);
x_57 = lean_ctor_get(x_1, 8);
lean_dec(x_57);
x_58 = lean_ctor_get(x_1, 7);
lean_dec(x_58);
x_59 = lean_ctor_get(x_1, 6);
lean_dec(x_59);
x_60 = lean_ctor_get(x_1, 5);
lean_dec(x_60);
x_61 = lean_ctor_get(x_1, 4);
lean_dec(x_61);
x_62 = lean_ctor_get(x_1, 3);
lean_dec(x_62);
x_63 = lean_ctor_get(x_1, 2);
lean_dec(x_63);
x_64 = lean_ctor_get(x_1, 1);
lean_dec(x_64);
x_65 = lean_ctor_get(x_1, 0);
lean_dec(x_65);
lean_ctor_set(x_1, 18, x_26);
lean_ctor_set(x_1, 17, x_41);
lean_ctor_set(x_1, 16, x_44);
lean_ctor_set(x_1, 15, x_33);
lean_ctor_set(x_1, 14, x_35);
lean_ctor_set(x_1, 13, x_28);
lean_ctor_set(x_1, 12, x_25);
lean_ctor_set(x_1, 11, x_36);
lean_ctor_set(x_1, 10, x_27);
lean_ctor_set(x_1, 9, x_29);
lean_ctor_set(x_1, 8, x_37);
lean_ctor_set(x_1, 7, x_39);
lean_ctor_set(x_1, 6, x_43);
lean_ctor_set(x_1, 5, x_42);
lean_ctor_set(x_1, 4, x_32);
lean_ctor_set(x_1, 3, x_31);
lean_ctor_set(x_1, 2, x_34);
lean_ctor_set(x_1, 1, x_30);
lean_ctor_set(x_1, 0, x_38);
lean_ctor_set_uint8(x_1, sizeof(void*)*20, x_40);
lean_ctor_set_uint8(x_1, sizeof(void*)*20 + 1, x_45);
return x_1;
}
else
{
lean_object* x_66; lean_object* x_67; 
x_66 = lean_ctor_get(x_1, 19);
lean_inc(x_66);
lean_dec(x_1);
x_67 = lean_alloc_ctor(0, 20, 2);
lean_ctor_set(x_67, 0, x_38);
lean_ctor_set(x_67, 1, x_30);
lean_ctor_set(x_67, 2, x_34);
lean_ctor_set(x_67, 3, x_31);
lean_ctor_set(x_67, 4, x_32);
lean_ctor_set(x_67, 5, x_42);
lean_ctor_set(x_67, 6, x_43);
lean_ctor_set(x_67, 7, x_39);
lean_ctor_set(x_67, 8, x_37);
lean_ctor_set(x_67, 9, x_29);
lean_ctor_set(x_67, 10, x_27);
lean_ctor_set(x_67, 11, x_36);
lean_ctor_set(x_67, 12, x_25);
lean_ctor_set(x_67, 13, x_28);
lean_ctor_set(x_67, 14, x_35);
lean_ctor_set(x_67, 15, x_33);
lean_ctor_set(x_67, 16, x_44);
lean_ctor_set(x_67, 17, x_41);
lean_ctor_set(x_67, 18, x_26);
lean_ctor_set(x_67, 19, x_66);
lean_ctor_set_uint8(x_67, sizeof(void*)*20, x_40);
lean_ctor_set_uint8(x_67, sizeof(void*)*20 + 1, x_45);
return x_67;
}
}
else
{
lean_object* x_68; lean_object* x_69; 
lean_dec_ref(x_1);
x_68 = lean_ctor_get(x_24, 0);
lean_inc(x_68);
lean_dec_ref(x_24);
x_69 = lean_alloc_ctor(0, 20, 2);
lean_ctor_set(x_69, 0, x_38);
lean_ctor_set(x_69, 1, x_30);
lean_ctor_set(x_69, 2, x_34);
lean_ctor_set(x_69, 3, x_31);
lean_ctor_set(x_69, 4, x_32);
lean_ctor_set(x_69, 5, x_42);
lean_ctor_set(x_69, 6, x_43);
lean_ctor_set(x_69, 7, x_39);
lean_ctor_set(x_69, 8, x_37);
lean_ctor_set(x_69, 9, x_29);
lean_ctor_set(x_69, 10, x_27);
lean_ctor_set(x_69, 11, x_36);
lean_ctor_set(x_69, 12, x_25);
lean_ctor_set(x_69, 13, x_28);
lean_ctor_set(x_69, 14, x_35);
lean_ctor_set(x_69, 15, x_33);
lean_ctor_set(x_69, 16, x_44);
lean_ctor_set(x_69, 17, x_41);
lean_ctor_set(x_69, 18, x_26);
lean_ctor_set(x_69, 19, x_68);
lean_ctor_set_uint8(x_69, sizeof(void*)*20, x_40);
lean_ctor_set_uint8(x_69, sizeof(void*)*20 + 1, x_45);
return x_69;
}
}
block_94:
{
if (lean_obj_tag(x_23) == 0)
{
uint8_t x_91; 
x_91 = lean_ctor_get_uint8(x_1, sizeof(void*)*20 + 1);
x_25 = x_71;
x_26 = x_72;
x_27 = x_73;
x_28 = x_74;
x_29 = x_75;
x_30 = x_76;
x_31 = x_77;
x_32 = x_78;
x_33 = x_79;
x_34 = x_80;
x_35 = x_81;
x_36 = x_82;
x_37 = x_83;
x_38 = x_85;
x_39 = x_84;
x_40 = x_90;
x_41 = x_86;
x_42 = x_88;
x_43 = x_87;
x_44 = x_89;
x_45 = x_91;
goto block_70;
}
else
{
lean_object* x_92; uint8_t x_93; 
x_92 = lean_ctor_get(x_23, 0);
lean_inc(x_92);
lean_dec_ref(x_23);
x_93 = lean_unbox(x_92);
lean_dec(x_92);
x_25 = x_71;
x_26 = x_72;
x_27 = x_73;
x_28 = x_74;
x_29 = x_75;
x_30 = x_76;
x_31 = x_77;
x_32 = x_78;
x_33 = x_79;
x_34 = x_80;
x_35 = x_81;
x_36 = x_82;
x_37 = x_83;
x_38 = x_85;
x_39 = x_84;
x_40 = x_90;
x_41 = x_86;
x_42 = x_88;
x_43 = x_87;
x_44 = x_89;
x_45 = x_93;
goto block_70;
}
}
block_117:
{
if (lean_obj_tag(x_22) == 0)
{
uint8_t x_114; 
x_114 = lean_ctor_get_uint8(x_1, sizeof(void*)*20);
x_71 = x_95;
x_72 = x_113;
x_73 = x_96;
x_74 = x_97;
x_75 = x_98;
x_76 = x_99;
x_77 = x_100;
x_78 = x_101;
x_79 = x_102;
x_80 = x_103;
x_81 = x_104;
x_82 = x_105;
x_83 = x_106;
x_84 = x_108;
x_85 = x_107;
x_86 = x_109;
x_87 = x_111;
x_88 = x_110;
x_89 = x_112;
x_90 = x_114;
goto block_94;
}
else
{
lean_object* x_115; uint8_t x_116; 
x_115 = lean_ctor_get(x_22, 0);
lean_inc(x_115);
lean_dec_ref(x_22);
x_116 = lean_unbox(x_115);
lean_dec(x_115);
x_71 = x_95;
x_72 = x_113;
x_73 = x_96;
x_74 = x_97;
x_75 = x_98;
x_76 = x_99;
x_77 = x_100;
x_78 = x_101;
x_79 = x_102;
x_80 = x_103;
x_81 = x_104;
x_82 = x_105;
x_83 = x_106;
x_84 = x_108;
x_85 = x_107;
x_86 = x_109;
x_87 = x_111;
x_88 = x_110;
x_89 = x_112;
x_90 = x_116;
goto block_94;
}
}
block_138:
{
if (lean_obj_tag(x_21) == 0)
{
lean_object* x_136; 
x_136 = lean_ctor_get(x_1, 18);
lean_inc(x_136);
x_95 = x_118;
x_96 = x_119;
x_97 = x_120;
x_98 = x_121;
x_99 = x_122;
x_100 = x_123;
x_101 = x_124;
x_102 = x_125;
x_103 = x_126;
x_104 = x_127;
x_105 = x_128;
x_106 = x_129;
x_107 = x_131;
x_108 = x_130;
x_109 = x_135;
x_110 = x_133;
x_111 = x_132;
x_112 = x_134;
x_113 = x_136;
goto block_117;
}
else
{
lean_object* x_137; 
x_137 = lean_ctor_get(x_21, 0);
lean_inc(x_137);
lean_dec_ref(x_21);
x_95 = x_118;
x_96 = x_119;
x_97 = x_120;
x_98 = x_121;
x_99 = x_122;
x_100 = x_123;
x_101 = x_124;
x_102 = x_125;
x_103 = x_126;
x_104 = x_127;
x_105 = x_128;
x_106 = x_129;
x_107 = x_131;
x_108 = x_130;
x_109 = x_135;
x_110 = x_133;
x_111 = x_132;
x_112 = x_134;
x_113 = x_137;
goto block_117;
}
}
block_158:
{
if (lean_obj_tag(x_20) == 0)
{
lean_object* x_156; 
x_156 = lean_ctor_get(x_1, 17);
lean_inc(x_156);
x_118 = x_139;
x_119 = x_140;
x_120 = x_141;
x_121 = x_142;
x_122 = x_143;
x_123 = x_144;
x_124 = x_145;
x_125 = x_146;
x_126 = x_147;
x_127 = x_148;
x_128 = x_149;
x_129 = x_150;
x_130 = x_152;
x_131 = x_151;
x_132 = x_154;
x_133 = x_153;
x_134 = x_155;
x_135 = x_156;
goto block_138;
}
else
{
lean_object* x_157; 
x_157 = lean_ctor_get(x_20, 0);
lean_inc(x_157);
lean_dec_ref(x_20);
x_118 = x_139;
x_119 = x_140;
x_120 = x_141;
x_121 = x_142;
x_122 = x_143;
x_123 = x_144;
x_124 = x_145;
x_125 = x_146;
x_126 = x_147;
x_127 = x_148;
x_128 = x_149;
x_129 = x_150;
x_130 = x_152;
x_131 = x_151;
x_132 = x_154;
x_133 = x_153;
x_134 = x_155;
x_135 = x_157;
goto block_138;
}
}
block_177:
{
if (lean_obj_tag(x_19) == 0)
{
lean_object* x_175; 
x_175 = lean_ctor_get(x_1, 16);
lean_inc(x_175);
x_139 = x_159;
x_140 = x_160;
x_141 = x_161;
x_142 = x_162;
x_143 = x_163;
x_144 = x_164;
x_145 = x_165;
x_146 = x_174;
x_147 = x_166;
x_148 = x_167;
x_149 = x_168;
x_150 = x_169;
x_151 = x_170;
x_152 = x_171;
x_153 = x_173;
x_154 = x_172;
x_155 = x_175;
goto block_158;
}
else
{
lean_object* x_176; 
x_176 = lean_ctor_get(x_19, 0);
lean_inc(x_176);
lean_dec_ref(x_19);
x_139 = x_159;
x_140 = x_160;
x_141 = x_161;
x_142 = x_162;
x_143 = x_163;
x_144 = x_164;
x_145 = x_165;
x_146 = x_174;
x_147 = x_166;
x_148 = x_167;
x_149 = x_168;
x_150 = x_169;
x_151 = x_170;
x_152 = x_171;
x_153 = x_173;
x_154 = x_172;
x_155 = x_176;
goto block_158;
}
}
block_195:
{
if (lean_obj_tag(x_18) == 0)
{
lean_object* x_193; 
x_193 = lean_ctor_get(x_1, 15);
lean_inc(x_193);
x_159 = x_178;
x_160 = x_179;
x_161 = x_180;
x_162 = x_181;
x_163 = x_182;
x_164 = x_183;
x_165 = x_184;
x_166 = x_185;
x_167 = x_192;
x_168 = x_186;
x_169 = x_187;
x_170 = x_188;
x_171 = x_189;
x_172 = x_191;
x_173 = x_190;
x_174 = x_193;
goto block_177;
}
else
{
lean_object* x_194; 
x_194 = lean_ctor_get(x_18, 0);
lean_inc(x_194);
lean_dec_ref(x_18);
x_159 = x_178;
x_160 = x_179;
x_161 = x_180;
x_162 = x_181;
x_163 = x_182;
x_164 = x_183;
x_165 = x_184;
x_166 = x_185;
x_167 = x_192;
x_168 = x_186;
x_169 = x_187;
x_170 = x_188;
x_171 = x_189;
x_172 = x_191;
x_173 = x_190;
x_174 = x_194;
goto block_177;
}
}
block_212:
{
if (lean_obj_tag(x_17) == 0)
{
lean_object* x_210; 
x_210 = lean_ctor_get(x_1, 14);
lean_inc(x_210);
x_178 = x_196;
x_179 = x_197;
x_180 = x_209;
x_181 = x_198;
x_182 = x_199;
x_183 = x_200;
x_184 = x_201;
x_185 = x_202;
x_186 = x_203;
x_187 = x_204;
x_188 = x_205;
x_189 = x_206;
x_190 = x_207;
x_191 = x_208;
x_192 = x_210;
goto block_195;
}
else
{
lean_object* x_211; 
x_211 = lean_ctor_get(x_17, 0);
lean_inc(x_211);
lean_dec_ref(x_17);
x_178 = x_196;
x_179 = x_197;
x_180 = x_209;
x_181 = x_198;
x_182 = x_199;
x_183 = x_200;
x_184 = x_201;
x_185 = x_202;
x_186 = x_203;
x_187 = x_204;
x_188 = x_205;
x_189 = x_206;
x_190 = x_207;
x_191 = x_208;
x_192 = x_211;
goto block_195;
}
}
block_228:
{
if (lean_obj_tag(x_16) == 0)
{
lean_object* x_226; 
x_226 = lean_ctor_get(x_1, 13);
lean_inc(x_226);
x_196 = x_225;
x_197 = x_214;
x_198 = x_216;
x_199 = x_220;
x_200 = x_219;
x_201 = x_221;
x_202 = x_222;
x_203 = x_213;
x_204 = x_215;
x_205 = x_218;
x_206 = x_217;
x_207 = x_224;
x_208 = x_223;
x_209 = x_226;
goto block_212;
}
else
{
lean_object* x_227; 
x_227 = lean_ctor_get(x_16, 0);
lean_inc(x_227);
lean_dec_ref(x_16);
x_196 = x_225;
x_197 = x_214;
x_198 = x_216;
x_199 = x_220;
x_200 = x_219;
x_201 = x_221;
x_202 = x_222;
x_203 = x_213;
x_204 = x_215;
x_205 = x_218;
x_206 = x_217;
x_207 = x_224;
x_208 = x_223;
x_209 = x_227;
goto block_212;
}
}
block_243:
{
if (lean_obj_tag(x_15) == 0)
{
lean_object* x_241; 
x_241 = lean_ctor_get(x_1, 12);
lean_inc(x_241);
x_213 = x_240;
x_214 = x_229;
x_215 = x_230;
x_216 = x_231;
x_217 = x_235;
x_218 = x_234;
x_219 = x_233;
x_220 = x_232;
x_221 = x_236;
x_222 = x_237;
x_223 = x_239;
x_224 = x_238;
x_225 = x_241;
goto block_228;
}
else
{
lean_object* x_242; 
x_242 = lean_ctor_get(x_15, 0);
lean_inc(x_242);
lean_dec_ref(x_15);
x_213 = x_240;
x_214 = x_229;
x_215 = x_230;
x_216 = x_231;
x_217 = x_235;
x_218 = x_234;
x_219 = x_233;
x_220 = x_232;
x_221 = x_236;
x_222 = x_237;
x_223 = x_239;
x_224 = x_238;
x_225 = x_242;
goto block_228;
}
}
block_257:
{
if (lean_obj_tag(x_14) == 0)
{
lean_object* x_255; 
x_255 = lean_ctor_get(x_1, 11);
lean_inc(x_255);
x_229 = x_254;
x_230 = x_244;
x_231 = x_245;
x_232 = x_249;
x_233 = x_248;
x_234 = x_247;
x_235 = x_246;
x_236 = x_250;
x_237 = x_251;
x_238 = x_253;
x_239 = x_252;
x_240 = x_255;
goto block_243;
}
else
{
lean_object* x_256; 
x_256 = lean_ctor_get(x_14, 0);
lean_inc(x_256);
lean_dec_ref(x_14);
x_229 = x_254;
x_230 = x_244;
x_231 = x_245;
x_232 = x_249;
x_233 = x_248;
x_234 = x_247;
x_235 = x_246;
x_236 = x_250;
x_237 = x_251;
x_238 = x_253;
x_239 = x_252;
x_240 = x_256;
goto block_243;
}
}
block_270:
{
if (lean_obj_tag(x_13) == 0)
{
lean_object* x_268; 
x_268 = lean_ctor_get(x_1, 10);
lean_inc(x_268);
x_244 = x_258;
x_245 = x_267;
x_246 = x_262;
x_247 = x_261;
x_248 = x_260;
x_249 = x_259;
x_250 = x_263;
x_251 = x_264;
x_252 = x_266;
x_253 = x_265;
x_254 = x_268;
goto block_257;
}
else
{
lean_object* x_269; 
x_269 = lean_ctor_get(x_13, 0);
lean_inc(x_269);
lean_dec_ref(x_13);
x_244 = x_258;
x_245 = x_267;
x_246 = x_262;
x_247 = x_261;
x_248 = x_260;
x_249 = x_259;
x_250 = x_263;
x_251 = x_264;
x_252 = x_266;
x_253 = x_265;
x_254 = x_269;
goto block_257;
}
}
block_282:
{
if (lean_obj_tag(x_12) == 0)
{
lean_object* x_280; 
x_280 = lean_ctor_get(x_1, 9);
lean_inc(x_280);
x_258 = x_279;
x_259 = x_274;
x_260 = x_273;
x_261 = x_272;
x_262 = x_271;
x_263 = x_275;
x_264 = x_276;
x_265 = x_278;
x_266 = x_277;
x_267 = x_280;
goto block_270;
}
else
{
lean_object* x_281; 
x_281 = lean_ctor_get(x_12, 0);
lean_inc(x_281);
lean_dec_ref(x_12);
x_258 = x_279;
x_259 = x_274;
x_260 = x_273;
x_261 = x_272;
x_262 = x_271;
x_263 = x_275;
x_264 = x_276;
x_265 = x_278;
x_266 = x_277;
x_267 = x_281;
goto block_270;
}
}
block_293:
{
if (lean_obj_tag(x_11) == 0)
{
lean_object* x_291; 
x_291 = lean_ctor_get(x_1, 8);
lean_inc(x_291);
x_271 = x_290;
x_272 = x_285;
x_273 = x_284;
x_274 = x_283;
x_275 = x_286;
x_276 = x_287;
x_277 = x_289;
x_278 = x_288;
x_279 = x_291;
goto block_282;
}
else
{
lean_object* x_292; 
x_292 = lean_ctor_get(x_11, 0);
lean_inc(x_292);
lean_dec_ref(x_11);
x_271 = x_290;
x_272 = x_285;
x_273 = x_284;
x_274 = x_283;
x_275 = x_286;
x_276 = x_287;
x_277 = x_289;
x_278 = x_288;
x_279 = x_292;
goto block_282;
}
}
block_303:
{
if (lean_obj_tag(x_10) == 0)
{
lean_object* x_301; 
x_301 = lean_ctor_get(x_1, 7);
lean_inc(x_301);
x_283 = x_296;
x_284 = x_295;
x_285 = x_294;
x_286 = x_297;
x_287 = x_298;
x_288 = x_299;
x_289 = x_300;
x_290 = x_301;
goto block_293;
}
else
{
lean_object* x_302; 
x_302 = lean_ctor_get(x_10, 0);
lean_inc(x_302);
lean_dec_ref(x_10);
x_283 = x_296;
x_284 = x_295;
x_285 = x_294;
x_286 = x_297;
x_287 = x_298;
x_288 = x_299;
x_289 = x_300;
x_290 = x_302;
goto block_293;
}
}
block_312:
{
if (lean_obj_tag(x_9) == 0)
{
lean_object* x_310; 
x_310 = lean_ctor_get(x_1, 6);
lean_inc(x_310);
x_294 = x_306;
x_295 = x_305;
x_296 = x_304;
x_297 = x_307;
x_298 = x_308;
x_299 = x_309;
x_300 = x_310;
goto block_303;
}
else
{
lean_object* x_311; 
x_311 = lean_ctor_get(x_9, 0);
lean_inc(x_311);
lean_dec_ref(x_9);
x_294 = x_306;
x_295 = x_305;
x_296 = x_304;
x_297 = x_307;
x_298 = x_308;
x_299 = x_309;
x_300 = x_311;
goto block_303;
}
}
block_320:
{
if (lean_obj_tag(x_8) == 0)
{
lean_object* x_318; 
x_318 = lean_ctor_get(x_1, 5);
lean_inc(x_318);
x_304 = x_315;
x_305 = x_314;
x_306 = x_313;
x_307 = x_317;
x_308 = x_316;
x_309 = x_318;
goto block_312;
}
else
{
lean_object* x_319; 
x_319 = lean_ctor_get(x_8, 0);
lean_inc(x_319);
lean_dec_ref(x_8);
x_304 = x_315;
x_305 = x_314;
x_306 = x_313;
x_307 = x_317;
x_308 = x_316;
x_309 = x_319;
goto block_312;
}
}
block_327:
{
if (lean_obj_tag(x_7) == 0)
{
lean_object* x_325; 
x_325 = lean_ctor_get(x_1, 4);
lean_inc(x_325);
x_313 = x_322;
x_314 = x_324;
x_315 = x_321;
x_316 = x_323;
x_317 = x_325;
goto block_320;
}
else
{
lean_object* x_326; 
x_326 = lean_ctor_get(x_7, 0);
lean_inc(x_326);
lean_dec_ref(x_7);
x_313 = x_322;
x_314 = x_324;
x_315 = x_321;
x_316 = x_323;
x_317 = x_326;
goto block_320;
}
}
block_333:
{
if (lean_obj_tag(x_6) == 0)
{
lean_object* x_331; 
x_331 = lean_ctor_get(x_1, 3);
lean_inc(x_331);
x_321 = x_329;
x_322 = x_328;
x_323 = x_330;
x_324 = x_331;
goto block_327;
}
else
{
lean_object* x_332; 
x_332 = lean_ctor_get(x_6, 0);
lean_inc(x_332);
lean_dec_ref(x_6);
x_321 = x_329;
x_322 = x_328;
x_323 = x_330;
x_324 = x_332;
goto block_327;
}
}
block_338:
{
if (lean_obj_tag(x_5) == 0)
{
lean_object* x_336; 
x_336 = lean_ctor_get(x_1, 2);
lean_inc(x_336);
x_328 = x_334;
x_329 = x_335;
x_330 = x_336;
goto block_333;
}
else
{
lean_object* x_337; 
x_337 = lean_ctor_get(x_5, 0);
lean_inc(x_337);
lean_dec_ref(x_5);
x_328 = x_334;
x_329 = x_335;
x_330 = x_337;
goto block_333;
}
}
block_342:
{
if (lean_obj_tag(x_4) == 0)
{
lean_object* x_340; 
x_340 = lean_ctor_get(x_1, 1);
lean_inc(x_340);
x_334 = x_339;
x_335 = x_340;
goto block_338;
}
else
{
lean_object* x_341; 
x_341 = lean_ctor_get(x_4, 0);
lean_inc(x_341);
lean_dec_ref(x_4);
x_334 = x_339;
x_335 = x_341;
goto block_338;
}
}
}
}
LEAN_EXPORT lean_object* lp_padctl_diff(lean_object* x_1, lean_object* x_2) {
_start:
{
lean_object* x_3; lean_object* x_4; lean_object* x_5; lean_object* x_6; lean_object* x_7; lean_object* x_8; lean_object* x_9; lean_object* x_10; lean_object* x_11; lean_object* x_12; lean_object* x_13; lean_object* x_14; lean_object* x_15; lean_object* x_16; lean_object* x_17; lean_object* x_18; lean_object* x_19; lean_object* x_20; lean_object* x_21; uint8_t x_22; uint8_t x_23; lean_object* x_24; lean_object* x_25; lean_object* x_26; lean_object* x_27; lean_object* x_28; lean_object* x_29; lean_object* x_30; lean_object* x_31; lean_object* x_32; lean_object* x_33; lean_object* x_34; lean_object* x_35; lean_object* x_36; lean_object* x_37; lean_object* x_38; lean_object* x_39; lean_object* x_40; lean_object* x_41; lean_object* x_42; lean_object* x_43; uint8_t x_44; uint8_t x_45; lean_object* x_46; lean_object* x_47; lean_object* x_48; lean_object* x_49; lean_object* x_50; lean_object* x_51; lean_object* x_52; lean_object* x_53; lean_object* x_54; lean_object* x_55; lean_object* x_56; lean_object* x_57; lean_object* x_58; lean_object* x_59; lean_object* x_60; lean_object* x_61; lean_object* x_62; lean_object* x_63; lean_object* x_64; lean_object* x_65; lean_object* x_66; lean_object* x_67; lean_object* x_74; lean_object* x_75; lean_object* x_76; lean_object* x_77; lean_object* x_78; lean_object* x_79; lean_object* x_80; lean_object* x_81; lean_object* x_82; lean_object* x_83; lean_object* x_84; lean_object* x_85; lean_object* x_86; lean_object* x_87; lean_object* x_88; lean_object* x_89; lean_object* x_90; lean_object* x_91; lean_object* x_92; lean_object* x_93; lean_object* x_96; lean_object* x_97; lean_object* x_98; lean_object* x_99; lean_object* x_100; uint8_t x_101; lean_object* x_102; lean_object* x_103; lean_object* x_104; lean_object* x_105; lean_object* x_106; lean_object* x_107; lean_object* x_108; lean_object* x_109; lean_object* x_110; lean_object* x_111; lean_object* x_112; lean_object* x_113; lean_object* x_114; lean_object* x_115; lean_object* x_116; lean_object* x_120; lean_object* x_121; lean_object* x_122; lean_object* x_123; lean_object* x_124; lean_object* x_125; lean_object* x_126; lean_object* x_127; lean_object* x_128; lean_object* x_129; lean_object* x_130; lean_object* x_131; lean_object* x_132; lean_object* x_133; lean_object* x_134; lean_object* x_135; lean_object* x_136; lean_object* x_137; lean_object* x_138; lean_object* x_139; lean_object* x_141; lean_object* x_142; lean_object* x_143; lean_object* x_144; lean_object* x_145; lean_object* x_146; lean_object* x_147; lean_object* x_148; lean_object* x_149; lean_object* x_150; lean_object* x_151; lean_object* x_152; lean_object* x_153; lean_object* x_154; lean_object* x_155; lean_object* x_156; lean_object* x_157; lean_object* x_158; lean_object* x_159; lean_object* x_162; lean_object* x_163; lean_object* x_164; lean_object* x_165; lean_object* x_166; lean_object* x_167; lean_object* x_168; lean_object* x_169; lean_object* x_170; lean_object* x_171; lean_object* x_172; lean_object* x_173; lean_object* x_174; lean_object* x_175; lean_object* x_176; lean_object* x_177; lean_object* x_178; lean_object* x_179; lean_object* x_180; uint8_t x_181; lean_object* x_185; lean_object* x_186; lean_object* x_187; lean_object* x_188; lean_object* x_189; lean_object* x_190; lean_object* x_191; lean_object* x_192; lean_object* x_193; lean_object* x_194; lean_object* x_195; lean_object* x_196; lean_object* x_197; lean_object* x_198; lean_object* x_199; lean_object* x_200; lean_object* x_201; lean_object* x_202; lean_object* x_203; lean_object* x_205; lean_object* x_206; lean_object* x_207; lean_object* x_208; lean_object* x_209; lean_object* x_210; lean_object* x_211; lean_object* x_212; lean_object* x_213; lean_object* x_214; lean_object* x_215; lean_object* x_216; lean_object* x_217; lean_object* x_218; lean_object* x_219; lean_object* x_220; lean_object* x_221; lean_object* x_222; lean_object* x_227; lean_object* x_228; lean_object* x_229; lean_object* x_230; lean_object* x_231; lean_object* x_232; lean_object* x_233; lean_object* x_234; lean_object* x_235; lean_object* x_236; lean_object* x_237; lean_object* x_238; lean_object* x_239; lean_object* x_240; lean_object* x_241; lean_object* x_242; lean_object* x_243; lean_object* x_248; lean_object* x_249; lean_object* x_250; lean_object* x_251; lean_object* x_252; lean_object* x_253; lean_object* x_254; lean_object* x_255; lean_object* x_256; lean_object* x_257; lean_object* x_258; lean_object* x_259; lean_object* x_260; lean_object* x_261; lean_object* x_262; lean_object* x_263; lean_object* x_268; lean_object* x_269; lean_object* x_270; lean_object* x_271; lean_object* x_272; lean_object* x_273; lean_object* x_274; lean_object* x_275; lean_object* x_276; lean_object* x_277; lean_object* x_278; lean_object* x_279; lean_object* x_280; lean_object* x_281; lean_object* x_282; lean_object* x_287; lean_object* x_288; lean_object* x_289; lean_object* x_290; lean_object* x_291; lean_object* x_292; lean_object* x_293; lean_object* x_294; lean_object* x_295; lean_object* x_296; lean_object* x_297; lean_object* x_298; lean_object* x_299; lean_object* x_300; lean_object* x_305; lean_object* x_306; lean_object* x_307; lean_object* x_308; lean_object* x_309; lean_object* x_310; lean_object* x_311; lean_object* x_312; lean_object* x_313; lean_object* x_314; lean_object* x_315; lean_object* x_316; lean_object* x_317; lean_object* x_322; lean_object* x_323; lean_object* x_324; lean_object* x_325; lean_object* x_326; lean_object* x_327; lean_object* x_328; lean_object* x_329; lean_object* x_330; lean_object* x_331; lean_object* x_332; lean_object* x_333; lean_object* x_338; lean_object* x_339; lean_object* x_340; lean_object* x_341; lean_object* x_342; lean_object* x_343; lean_object* x_344; lean_object* x_345; lean_object* x_346; lean_object* x_347; lean_object* x_348; lean_object* x_353; lean_object* x_354; lean_object* x_355; lean_object* x_356; lean_object* x_357; lean_object* x_358; lean_object* x_359; lean_object* x_360; lean_object* x_361; lean_object* x_362; lean_object* x_367; lean_object* x_368; lean_object* x_369; lean_object* x_370; lean_object* x_371; lean_object* x_372; lean_object* x_373; lean_object* x_374; lean_object* x_375; lean_object* x_380; lean_object* x_381; lean_object* x_382; lean_object* x_383; lean_object* x_384; lean_object* x_385; lean_object* x_386; lean_object* x_387; lean_object* x_392; lean_object* x_393; lean_object* x_394; lean_object* x_395; lean_object* x_396; lean_object* x_397; lean_object* x_398; lean_object* x_403; lean_object* x_404; lean_object* x_405; lean_object* x_406; lean_object* x_407; lean_object* x_408; lean_object* x_413; lean_object* x_414; lean_object* x_415; lean_object* x_416; lean_object* x_417; lean_object* x_422; lean_object* x_423; lean_object* x_424; lean_object* x_425; lean_object* x_430; lean_object* x_431; lean_object* x_432; lean_object* x_437; lean_object* x_438; lean_object* x_443; uint8_t x_448; 
x_3 = lean_ctor_get(x_1, 0);
x_4 = lean_ctor_get(x_1, 1);
x_5 = lean_ctor_get(x_1, 2);
x_6 = lean_ctor_get(x_1, 3);
x_7 = lean_ctor_get(x_1, 4);
x_8 = lean_ctor_get(x_1, 5);
x_9 = lean_ctor_get(x_1, 6);
x_10 = lean_ctor_get(x_1, 7);
x_11 = lean_ctor_get(x_1, 8);
x_12 = lean_ctor_get(x_1, 9);
x_13 = lean_ctor_get(x_1, 10);
x_14 = lean_ctor_get(x_1, 11);
x_15 = lean_ctor_get(x_1, 12);
x_16 = lean_ctor_get(x_1, 13);
x_17 = lean_ctor_get(x_1, 14);
x_18 = lean_ctor_get(x_1, 15);
x_19 = lean_ctor_get(x_1, 16);
x_20 = lean_ctor_get(x_1, 17);
x_21 = lean_ctor_get(x_1, 18);
x_22 = lean_ctor_get_uint8(x_1, sizeof(void*)*20);
x_23 = lean_ctor_get_uint8(x_1, sizeof(void*)*20 + 1);
x_24 = lean_ctor_get(x_1, 19);
x_25 = lean_ctor_get(x_2, 0);
x_26 = lean_ctor_get(x_2, 1);
x_27 = lean_ctor_get(x_2, 2);
x_28 = lean_ctor_get(x_2, 3);
x_29 = lean_ctor_get(x_2, 4);
x_30 = lean_ctor_get(x_2, 5);
x_31 = lean_ctor_get(x_2, 6);
x_32 = lean_ctor_get(x_2, 7);
x_33 = lean_ctor_get(x_2, 8);
x_34 = lean_ctor_get(x_2, 9);
x_35 = lean_ctor_get(x_2, 10);
x_36 = lean_ctor_get(x_2, 11);
x_37 = lean_ctor_get(x_2, 12);
x_38 = lean_ctor_get(x_2, 13);
x_39 = lean_ctor_get(x_2, 14);
x_40 = lean_ctor_get(x_2, 15);
x_41 = lean_ctor_get(x_2, 16);
x_42 = lean_ctor_get(x_2, 17);
x_43 = lean_ctor_get(x_2, 18);
x_44 = lean_ctor_get_uint8(x_2, sizeof(void*)*20);
x_45 = lean_ctor_get_uint8(x_2, sizeof(void*)*20 + 1);
x_46 = lean_ctor_get(x_2, 19);
x_448 = lean_int_dec_eq(x_3, x_25);
if (x_448 == 0)
{
lean_object* x_449; 
lean_inc(x_3);
x_449 = lean_alloc_ctor(1, 1, 0);
lean_ctor_set(x_449, 0, x_3);
x_443 = x_449;
goto block_447;
}
else
{
lean_object* x_450; 
x_450 = lean_box(0);
x_443 = x_450;
goto block_447;
}
block_73:
{
uint8_t x_68; 
x_68 = lean_nat_dec_eq(x_24, x_46);
if (x_68 == 0)
{
lean_object* x_69; lean_object* x_70; 
lean_inc(x_24);
x_69 = lean_alloc_ctor(1, 1, 0);
lean_ctor_set(x_69, 0, x_24);
x_70 = lean_alloc_ctor(0, 22, 0);
lean_ctor_set(x_70, 0, x_60);
lean_ctor_set(x_70, 1, x_57);
lean_ctor_set(x_70, 2, x_64);
lean_ctor_set(x_70, 3, x_56);
lean_ctor_set(x_70, 4, x_59);
lean_ctor_set(x_70, 5, x_49);
lean_ctor_set(x_70, 6, x_65);
lean_ctor_set(x_70, 7, x_53);
lean_ctor_set(x_70, 8, x_50);
lean_ctor_set(x_70, 9, x_61);
lean_ctor_set(x_70, 10, x_66);
lean_ctor_set(x_70, 11, x_51);
lean_ctor_set(x_70, 12, x_58);
lean_ctor_set(x_70, 13, x_47);
lean_ctor_set(x_70, 14, x_55);
lean_ctor_set(x_70, 15, x_54);
lean_ctor_set(x_70, 16, x_62);
lean_ctor_set(x_70, 17, x_63);
lean_ctor_set(x_70, 18, x_52);
lean_ctor_set(x_70, 19, x_48);
lean_ctor_set(x_70, 20, x_67);
lean_ctor_set(x_70, 21, x_69);
return x_70;
}
else
{
lean_object* x_71; lean_object* x_72; 
x_71 = lean_box(0);
x_72 = lean_alloc_ctor(0, 22, 0);
lean_ctor_set(x_72, 0, x_60);
lean_ctor_set(x_72, 1, x_57);
lean_ctor_set(x_72, 2, x_64);
lean_ctor_set(x_72, 3, x_56);
lean_ctor_set(x_72, 4, x_59);
lean_ctor_set(x_72, 5, x_49);
lean_ctor_set(x_72, 6, x_65);
lean_ctor_set(x_72, 7, x_53);
lean_ctor_set(x_72, 8, x_50);
lean_ctor_set(x_72, 9, x_61);
lean_ctor_set(x_72, 10, x_66);
lean_ctor_set(x_72, 11, x_51);
lean_ctor_set(x_72, 12, x_58);
lean_ctor_set(x_72, 13, x_47);
lean_ctor_set(x_72, 14, x_55);
lean_ctor_set(x_72, 15, x_54);
lean_ctor_set(x_72, 16, x_62);
lean_ctor_set(x_72, 17, x_63);
lean_ctor_set(x_72, 18, x_52);
lean_ctor_set(x_72, 19, x_48);
lean_ctor_set(x_72, 20, x_67);
lean_ctor_set(x_72, 21, x_71);
return x_72;
}
}
block_95:
{
lean_object* x_94; 
x_94 = lean_box(0);
x_47 = x_74;
x_48 = x_75;
x_49 = x_76;
x_50 = x_77;
x_51 = x_78;
x_52 = x_79;
x_53 = x_80;
x_54 = x_81;
x_55 = x_82;
x_56 = x_83;
x_57 = x_84;
x_58 = x_85;
x_59 = x_86;
x_60 = x_88;
x_61 = x_87;
x_62 = x_89;
x_63 = x_90;
x_64 = x_93;
x_65 = x_92;
x_66 = x_91;
x_67 = x_94;
goto block_73;
}
block_119:
{
lean_object* x_117; lean_object* x_118; 
x_117 = lean_box(x_101);
x_118 = lean_alloc_ctor(1, 1, 0);
lean_ctor_set(x_118, 0, x_117);
x_47 = x_96;
x_48 = x_97;
x_49 = x_98;
x_50 = x_99;
x_51 = x_100;
x_52 = x_102;
x_53 = x_103;
x_54 = x_104;
x_55 = x_105;
x_56 = x_106;
x_57 = x_107;
x_58 = x_108;
x_59 = x_109;
x_60 = x_111;
x_61 = x_110;
x_62 = x_112;
x_63 = x_113;
x_64 = x_116;
x_65 = x_115;
x_66 = x_114;
x_67 = x_118;
goto block_73;
}
block_140:
{
if (x_23 == 0)
{
if (x_45 == 0)
{
x_74 = x_120;
x_75 = x_139;
x_76 = x_121;
x_77 = x_122;
x_78 = x_123;
x_79 = x_124;
x_80 = x_125;
x_81 = x_126;
x_82 = x_127;
x_83 = x_128;
x_84 = x_129;
x_85 = x_130;
x_86 = x_131;
x_87 = x_132;
x_88 = x_133;
x_89 = x_134;
x_90 = x_135;
x_91 = x_136;
x_92 = x_137;
x_93 = x_138;
goto block_95;
}
else
{
x_96 = x_120;
x_97 = x_139;
x_98 = x_121;
x_99 = x_122;
x_100 = x_123;
x_101 = x_23;
x_102 = x_124;
x_103 = x_125;
x_104 = x_126;
x_105 = x_127;
x_106 = x_128;
x_107 = x_129;
x_108 = x_130;
x_109 = x_131;
x_110 = x_132;
x_111 = x_133;
x_112 = x_134;
x_113 = x_135;
x_114 = x_136;
x_115 = x_137;
x_116 = x_138;
goto block_119;
}
}
else
{
if (x_45 == 0)
{
x_96 = x_120;
x_97 = x_139;
x_98 = x_121;
x_99 = x_122;
x_100 = x_123;
x_101 = x_23;
x_102 = x_124;
x_103 = x_125;
x_104 = x_126;
x_105 = x_127;
x_106 = x_128;
x_107 = x_129;
x_108 = x_130;
x_109 = x_131;
x_110 = x_132;
x_111 = x_133;
x_112 = x_134;
x_113 = x_135;
x_114 = x_136;
x_115 = x_137;
x_116 = x_138;
goto block_119;
}
else
{
x_74 = x_120;
x_75 = x_139;
x_76 = x_121;
x_77 = x_122;
x_78 = x_123;
x_79 = x_124;
x_80 = x_125;
x_81 = x_126;
x_82 = x_127;
x_83 = x_128;
x_84 = x_129;
x_85 = x_130;
x_86 = x_131;
x_87 = x_132;
x_88 = x_133;
x_89 = x_134;
x_90 = x_135;
x_91 = x_136;
x_92 = x_137;
x_93 = x_138;
goto block_95;
}
}
}
block_161:
{
lean_object* x_160; 
x_160 = lean_box(0);
x_120 = x_141;
x_121 = x_142;
x_122 = x_143;
x_123 = x_144;
x_124 = x_145;
x_125 = x_146;
x_126 = x_147;
x_127 = x_148;
x_128 = x_149;
x_129 = x_150;
x_130 = x_151;
x_131 = x_152;
x_132 = x_154;
x_133 = x_153;
x_134 = x_155;
x_135 = x_156;
x_136 = x_159;
x_137 = x_158;
x_138 = x_157;
x_139 = x_160;
goto block_140;
}
block_184:
{
lean_object* x_182; lean_object* x_183; 
x_182 = lean_box(x_181);
x_183 = lean_alloc_ctor(1, 1, 0);
lean_ctor_set(x_183, 0, x_182);
x_120 = x_162;
x_121 = x_163;
x_122 = x_164;
x_123 = x_165;
x_124 = x_166;
x_125 = x_167;
x_126 = x_168;
x_127 = x_169;
x_128 = x_170;
x_129 = x_171;
x_130 = x_172;
x_131 = x_173;
x_132 = x_175;
x_133 = x_174;
x_134 = x_176;
x_135 = x_177;
x_136 = x_180;
x_137 = x_179;
x_138 = x_178;
x_139 = x_183;
goto block_140;
}
block_204:
{
if (x_22 == 0)
{
if (x_44 == 0)
{
x_141 = x_185;
x_142 = x_186;
x_143 = x_187;
x_144 = x_188;
x_145 = x_203;
x_146 = x_189;
x_147 = x_190;
x_148 = x_191;
x_149 = x_192;
x_150 = x_193;
x_151 = x_194;
x_152 = x_195;
x_153 = x_197;
x_154 = x_196;
x_155 = x_198;
x_156 = x_199;
x_157 = x_200;
x_158 = x_201;
x_159 = x_202;
goto block_161;
}
else
{
x_162 = x_185;
x_163 = x_186;
x_164 = x_187;
x_165 = x_188;
x_166 = x_203;
x_167 = x_189;
x_168 = x_190;
x_169 = x_191;
x_170 = x_192;
x_171 = x_193;
x_172 = x_194;
x_173 = x_195;
x_174 = x_197;
x_175 = x_196;
x_176 = x_198;
x_177 = x_199;
x_178 = x_200;
x_179 = x_201;
x_180 = x_202;
x_181 = x_22;
goto block_184;
}
}
else
{
if (x_44 == 0)
{
x_162 = x_185;
x_163 = x_186;
x_164 = x_187;
x_165 = x_188;
x_166 = x_203;
x_167 = x_189;
x_168 = x_190;
x_169 = x_191;
x_170 = x_192;
x_171 = x_193;
x_172 = x_194;
x_173 = x_195;
x_174 = x_197;
x_175 = x_196;
x_176 = x_198;
x_177 = x_199;
x_178 = x_200;
x_179 = x_201;
x_180 = x_202;
x_181 = x_22;
goto block_184;
}
else
{
x_141 = x_185;
x_142 = x_186;
x_143 = x_187;
x_144 = x_188;
x_145 = x_203;
x_146 = x_189;
x_147 = x_190;
x_148 = x_191;
x_149 = x_192;
x_150 = x_193;
x_151 = x_194;
x_152 = x_195;
x_153 = x_197;
x_154 = x_196;
x_155 = x_198;
x_156 = x_199;
x_157 = x_200;
x_158 = x_201;
x_159 = x_202;
goto block_161;
}
}
}
block_226:
{
uint8_t x_223; 
x_223 = lean_int_dec_eq(x_21, x_43);
if (x_223 == 0)
{
lean_object* x_224; 
lean_inc(x_21);
x_224 = lean_alloc_ctor(1, 1, 0);
lean_ctor_set(x_224, 0, x_21);
x_185 = x_205;
x_186 = x_206;
x_187 = x_207;
x_188 = x_208;
x_189 = x_209;
x_190 = x_210;
x_191 = x_211;
x_192 = x_212;
x_193 = x_213;
x_194 = x_214;
x_195 = x_215;
x_196 = x_216;
x_197 = x_217;
x_198 = x_218;
x_199 = x_222;
x_200 = x_221;
x_201 = x_220;
x_202 = x_219;
x_203 = x_224;
goto block_204;
}
else
{
lean_object* x_225; 
x_225 = lean_box(0);
x_185 = x_205;
x_186 = x_206;
x_187 = x_207;
x_188 = x_208;
x_189 = x_209;
x_190 = x_210;
x_191 = x_211;
x_192 = x_212;
x_193 = x_213;
x_194 = x_214;
x_195 = x_215;
x_196 = x_216;
x_197 = x_217;
x_198 = x_218;
x_199 = x_222;
x_200 = x_221;
x_201 = x_220;
x_202 = x_219;
x_203 = x_225;
goto block_204;
}
}
block_247:
{
uint8_t x_244; 
x_244 = lean_int_dec_eq(x_20, x_42);
if (x_244 == 0)
{
lean_object* x_245; 
lean_inc(x_20);
x_245 = lean_alloc_ctor(1, 1, 0);
lean_ctor_set(x_245, 0, x_20);
x_205 = x_227;
x_206 = x_228;
x_207 = x_229;
x_208 = x_230;
x_209 = x_231;
x_210 = x_232;
x_211 = x_233;
x_212 = x_234;
x_213 = x_235;
x_214 = x_236;
x_215 = x_237;
x_216 = x_238;
x_217 = x_239;
x_218 = x_243;
x_219 = x_242;
x_220 = x_241;
x_221 = x_240;
x_222 = x_245;
goto block_226;
}
else
{
lean_object* x_246; 
x_246 = lean_box(0);
x_205 = x_227;
x_206 = x_228;
x_207 = x_229;
x_208 = x_230;
x_209 = x_231;
x_210 = x_232;
x_211 = x_233;
x_212 = x_234;
x_213 = x_235;
x_214 = x_236;
x_215 = x_237;
x_216 = x_238;
x_217 = x_239;
x_218 = x_243;
x_219 = x_242;
x_220 = x_241;
x_221 = x_240;
x_222 = x_246;
goto block_226;
}
}
block_267:
{
uint8_t x_264; 
x_264 = lean_int_dec_eq(x_19, x_41);
if (x_264 == 0)
{
lean_object* x_265; 
lean_inc(x_19);
x_265 = lean_alloc_ctor(1, 1, 0);
lean_ctor_set(x_265, 0, x_19);
x_227 = x_248;
x_228 = x_249;
x_229 = x_250;
x_230 = x_251;
x_231 = x_252;
x_232 = x_263;
x_233 = x_253;
x_234 = x_254;
x_235 = x_255;
x_236 = x_256;
x_237 = x_257;
x_238 = x_258;
x_239 = x_259;
x_240 = x_262;
x_241 = x_261;
x_242 = x_260;
x_243 = x_265;
goto block_247;
}
else
{
lean_object* x_266; 
x_266 = lean_box(0);
x_227 = x_248;
x_228 = x_249;
x_229 = x_250;
x_230 = x_251;
x_231 = x_252;
x_232 = x_263;
x_233 = x_253;
x_234 = x_254;
x_235 = x_255;
x_236 = x_256;
x_237 = x_257;
x_238 = x_258;
x_239 = x_259;
x_240 = x_262;
x_241 = x_261;
x_242 = x_260;
x_243 = x_266;
goto block_247;
}
}
block_286:
{
uint8_t x_283; 
x_283 = lean_int_dec_eq(x_18, x_40);
if (x_283 == 0)
{
lean_object* x_284; 
lean_inc(x_18);
x_284 = lean_alloc_ctor(1, 1, 0);
lean_ctor_set(x_284, 0, x_18);
x_248 = x_268;
x_249 = x_269;
x_250 = x_270;
x_251 = x_271;
x_252 = x_272;
x_253 = x_282;
x_254 = x_273;
x_255 = x_274;
x_256 = x_275;
x_257 = x_276;
x_258 = x_277;
x_259 = x_278;
x_260 = x_280;
x_261 = x_281;
x_262 = x_279;
x_263 = x_284;
goto block_267;
}
else
{
lean_object* x_285; 
x_285 = lean_box(0);
x_248 = x_268;
x_249 = x_269;
x_250 = x_270;
x_251 = x_271;
x_252 = x_272;
x_253 = x_282;
x_254 = x_273;
x_255 = x_274;
x_256 = x_275;
x_257 = x_276;
x_258 = x_277;
x_259 = x_278;
x_260 = x_280;
x_261 = x_281;
x_262 = x_279;
x_263 = x_285;
goto block_267;
}
}
block_304:
{
uint8_t x_301; 
x_301 = lean_int_dec_eq(x_17, x_39);
if (x_301 == 0)
{
lean_object* x_302; 
lean_inc(x_17);
x_302 = lean_alloc_ctor(1, 1, 0);
lean_ctor_set(x_302, 0, x_17);
x_268 = x_300;
x_269 = x_287;
x_270 = x_288;
x_271 = x_289;
x_272 = x_290;
x_273 = x_291;
x_274 = x_292;
x_275 = x_293;
x_276 = x_294;
x_277 = x_295;
x_278 = x_296;
x_279 = x_297;
x_280 = x_298;
x_281 = x_299;
x_282 = x_302;
goto block_286;
}
else
{
lean_object* x_303; 
x_303 = lean_box(0);
x_268 = x_300;
x_269 = x_287;
x_270 = x_288;
x_271 = x_289;
x_272 = x_290;
x_273 = x_291;
x_274 = x_292;
x_275 = x_293;
x_276 = x_294;
x_277 = x_295;
x_278 = x_296;
x_279 = x_297;
x_280 = x_298;
x_281 = x_299;
x_282 = x_303;
goto block_286;
}
}
block_321:
{
uint8_t x_318; 
x_318 = lean_int_dec_eq(x_16, x_38);
if (x_318 == 0)
{
lean_object* x_319; 
lean_inc(x_16);
x_319 = lean_alloc_ctor(1, 1, 0);
lean_ctor_set(x_319, 0, x_16);
x_287 = x_305;
x_288 = x_308;
x_289 = x_310;
x_290 = x_316;
x_291 = x_306;
x_292 = x_307;
x_293 = x_317;
x_294 = x_309;
x_295 = x_312;
x_296 = x_311;
x_297 = x_315;
x_298 = x_314;
x_299 = x_313;
x_300 = x_319;
goto block_304;
}
else
{
lean_object* x_320; 
x_320 = lean_box(0);
x_287 = x_305;
x_288 = x_308;
x_289 = x_310;
x_290 = x_316;
x_291 = x_306;
x_292 = x_307;
x_293 = x_317;
x_294 = x_309;
x_295 = x_312;
x_296 = x_311;
x_297 = x_315;
x_298 = x_314;
x_299 = x_313;
x_300 = x_320;
goto block_304;
}
}
block_337:
{
uint8_t x_334; 
x_334 = lean_int_dec_eq(x_15, x_37);
if (x_334 == 0)
{
lean_object* x_335; 
lean_inc(x_15);
x_335 = lean_alloc_ctor(1, 1, 0);
lean_ctor_set(x_335, 0, x_15);
x_305 = x_322;
x_306 = x_323;
x_307 = x_324;
x_308 = x_325;
x_309 = x_326;
x_310 = x_333;
x_311 = x_328;
x_312 = x_327;
x_313 = x_331;
x_314 = x_330;
x_315 = x_329;
x_316 = x_332;
x_317 = x_335;
goto block_321;
}
else
{
lean_object* x_336; 
x_336 = lean_box(0);
x_305 = x_322;
x_306 = x_323;
x_307 = x_324;
x_308 = x_325;
x_309 = x_326;
x_310 = x_333;
x_311 = x_328;
x_312 = x_327;
x_313 = x_331;
x_314 = x_330;
x_315 = x_329;
x_316 = x_332;
x_317 = x_336;
goto block_321;
}
}
block_352:
{
uint8_t x_349; 
x_349 = lean_int_dec_eq(x_14, x_36);
if (x_349 == 0)
{
lean_object* x_350; 
lean_inc(x_14);
x_350 = lean_alloc_ctor(1, 1, 0);
lean_ctor_set(x_350, 0, x_14);
x_322 = x_338;
x_323 = x_339;
x_324 = x_340;
x_325 = x_341;
x_326 = x_342;
x_327 = x_344;
x_328 = x_343;
x_329 = x_346;
x_330 = x_348;
x_331 = x_345;
x_332 = x_347;
x_333 = x_350;
goto block_337;
}
else
{
lean_object* x_351; 
x_351 = lean_box(0);
x_322 = x_338;
x_323 = x_339;
x_324 = x_340;
x_325 = x_341;
x_326 = x_342;
x_327 = x_344;
x_328 = x_343;
x_329 = x_346;
x_330 = x_348;
x_331 = x_345;
x_332 = x_347;
x_333 = x_351;
goto block_337;
}
}
block_366:
{
uint8_t x_363; 
x_363 = lean_int_dec_eq(x_13, x_35);
if (x_363 == 0)
{
lean_object* x_364; 
lean_inc(x_13);
x_364 = lean_alloc_ctor(1, 1, 0);
lean_ctor_set(x_364, 0, x_13);
x_338 = x_353;
x_339 = x_354;
x_340 = x_355;
x_341 = x_356;
x_342 = x_357;
x_343 = x_358;
x_344 = x_362;
x_345 = x_360;
x_346 = x_359;
x_347 = x_361;
x_348 = x_364;
goto block_352;
}
else
{
lean_object* x_365; 
x_365 = lean_box(0);
x_338 = x_353;
x_339 = x_354;
x_340 = x_355;
x_341 = x_356;
x_342 = x_357;
x_343 = x_358;
x_344 = x_362;
x_345 = x_360;
x_346 = x_359;
x_347 = x_361;
x_348 = x_365;
goto block_352;
}
}
block_379:
{
uint8_t x_376; 
x_376 = lean_int_dec_eq(x_12, x_34);
if (x_376 == 0)
{
lean_object* x_377; 
lean_inc(x_12);
x_377 = lean_alloc_ctor(1, 1, 0);
lean_ctor_set(x_377, 0, x_12);
x_353 = x_367;
x_354 = x_368;
x_355 = x_369;
x_356 = x_375;
x_357 = x_370;
x_358 = x_371;
x_359 = x_373;
x_360 = x_372;
x_361 = x_374;
x_362 = x_377;
goto block_366;
}
else
{
lean_object* x_378; 
x_378 = lean_box(0);
x_353 = x_367;
x_354 = x_368;
x_355 = x_369;
x_356 = x_375;
x_357 = x_370;
x_358 = x_371;
x_359 = x_373;
x_360 = x_372;
x_361 = x_374;
x_362 = x_378;
goto block_366;
}
}
block_391:
{
uint8_t x_388; 
x_388 = lean_int_dec_eq(x_11, x_33);
if (x_388 == 0)
{
lean_object* x_389; 
lean_inc(x_11);
x_389 = lean_alloc_ctor(1, 1, 0);
lean_ctor_set(x_389, 0, x_11);
x_367 = x_380;
x_368 = x_381;
x_369 = x_382;
x_370 = x_383;
x_371 = x_384;
x_372 = x_386;
x_373 = x_385;
x_374 = x_387;
x_375 = x_389;
goto block_379;
}
else
{
lean_object* x_390; 
x_390 = lean_box(0);
x_367 = x_380;
x_368 = x_381;
x_369 = x_382;
x_370 = x_383;
x_371 = x_384;
x_372 = x_386;
x_373 = x_385;
x_374 = x_387;
x_375 = x_390;
goto block_379;
}
}
block_402:
{
uint8_t x_399; 
x_399 = lean_int_dec_eq(x_10, x_32);
if (x_399 == 0)
{
lean_object* x_400; 
lean_inc(x_10);
x_400 = lean_alloc_ctor(1, 1, 0);
lean_ctor_set(x_400, 0, x_10);
x_380 = x_392;
x_381 = x_393;
x_382 = x_394;
x_383 = x_395;
x_384 = x_396;
x_385 = x_397;
x_386 = x_398;
x_387 = x_400;
goto block_391;
}
else
{
lean_object* x_401; 
x_401 = lean_box(0);
x_380 = x_392;
x_381 = x_393;
x_382 = x_394;
x_383 = x_395;
x_384 = x_396;
x_385 = x_397;
x_386 = x_398;
x_387 = x_401;
goto block_391;
}
}
block_412:
{
uint8_t x_409; 
x_409 = lean_nat_dec_eq(x_9, x_31);
if (x_409 == 0)
{
lean_object* x_410; 
lean_inc(x_9);
x_410 = lean_alloc_ctor(1, 1, 0);
lean_ctor_set(x_410, 0, x_9);
x_392 = x_408;
x_393 = x_403;
x_394 = x_404;
x_395 = x_405;
x_396 = x_406;
x_397 = x_407;
x_398 = x_410;
goto block_402;
}
else
{
lean_object* x_411; 
x_411 = lean_box(0);
x_392 = x_408;
x_393 = x_403;
x_394 = x_404;
x_395 = x_405;
x_396 = x_406;
x_397 = x_407;
x_398 = x_411;
goto block_402;
}
}
block_421:
{
uint8_t x_418; 
x_418 = lean_nat_dec_eq(x_8, x_30);
if (x_418 == 0)
{
lean_object* x_419; 
lean_inc(x_8);
x_419 = lean_alloc_ctor(1, 1, 0);
lean_ctor_set(x_419, 0, x_8);
x_403 = x_413;
x_404 = x_414;
x_405 = x_417;
x_406 = x_415;
x_407 = x_416;
x_408 = x_419;
goto block_412;
}
else
{
lean_object* x_420; 
x_420 = lean_box(0);
x_403 = x_413;
x_404 = x_414;
x_405 = x_417;
x_406 = x_415;
x_407 = x_416;
x_408 = x_420;
goto block_412;
}
}
block_429:
{
uint8_t x_426; 
x_426 = lean_nat_dec_eq(x_7, x_29);
if (x_426 == 0)
{
lean_object* x_427; 
lean_inc(x_7);
x_427 = lean_alloc_ctor(1, 1, 0);
lean_ctor_set(x_427, 0, x_7);
x_413 = x_425;
x_414 = x_422;
x_415 = x_423;
x_416 = x_424;
x_417 = x_427;
goto block_421;
}
else
{
lean_object* x_428; 
x_428 = lean_box(0);
x_413 = x_425;
x_414 = x_422;
x_415 = x_423;
x_416 = x_424;
x_417 = x_428;
goto block_421;
}
}
block_436:
{
uint8_t x_433; 
x_433 = lean_int_dec_eq(x_6, x_28);
if (x_433 == 0)
{
lean_object* x_434; 
lean_inc(x_6);
x_434 = lean_alloc_ctor(1, 1, 0);
lean_ctor_set(x_434, 0, x_6);
x_422 = x_430;
x_423 = x_431;
x_424 = x_432;
x_425 = x_434;
goto block_429;
}
else
{
lean_object* x_435; 
x_435 = lean_box(0);
x_422 = x_430;
x_423 = x_431;
x_424 = x_432;
x_425 = x_435;
goto block_429;
}
}
block_442:
{
uint8_t x_439; 
x_439 = lean_int_dec_eq(x_5, x_27);
if (x_439 == 0)
{
lean_object* x_440; 
lean_inc(x_5);
x_440 = lean_alloc_ctor(1, 1, 0);
lean_ctor_set(x_440, 0, x_5);
x_430 = x_438;
x_431 = x_437;
x_432 = x_440;
goto block_436;
}
else
{
lean_object* x_441; 
x_441 = lean_box(0);
x_430 = x_438;
x_431 = x_437;
x_432 = x_441;
goto block_436;
}
}
block_447:
{
uint8_t x_444; 
x_444 = lean_int_dec_eq(x_4, x_26);
if (x_444 == 0)
{
lean_object* x_445; 
lean_inc(x_4);
x_445 = lean_alloc_ctor(1, 1, 0);
lean_ctor_set(x_445, 0, x_4);
x_437 = x_443;
x_438 = x_445;
goto block_442;
}
else
{
lean_object* x_446; 
x_446 = lean_box(0);
x_437 = x_443;
x_438 = x_446;
goto block_442;
}
}
}
}
LEAN_EXPORT lean_object* lp_padctl_diff___boxed(lean_object* x_1, lean_object* x_2) {
_start:
{
lean_object* x_3; 
x_3 = lp_padctl_diff(x_1, x_2);
lean_dec_ref(x_2);
lean_dec_ref(x_1);
return x_3;
}
}
LEAN_EXPORT lean_object* lp_padctl_ButtonId_ctorIdx(uint8_t x_1) {
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
case 4:
{
lean_object* x_6; 
x_6 = lean_unsigned_to_nat(4u);
return x_6;
}
case 5:
{
lean_object* x_7; 
x_7 = lean_unsigned_to_nat(5u);
return x_7;
}
case 6:
{
lean_object* x_8; 
x_8 = lean_unsigned_to_nat(6u);
return x_8;
}
case 7:
{
lean_object* x_9; 
x_9 = lean_unsigned_to_nat(7u);
return x_9;
}
case 8:
{
lean_object* x_10; 
x_10 = lean_unsigned_to_nat(8u);
return x_10;
}
case 9:
{
lean_object* x_11; 
x_11 = lean_unsigned_to_nat(9u);
return x_11;
}
case 10:
{
lean_object* x_12; 
x_12 = lean_unsigned_to_nat(10u);
return x_12;
}
case 11:
{
lean_object* x_13; 
x_13 = lean_unsigned_to_nat(11u);
return x_13;
}
case 12:
{
lean_object* x_14; 
x_14 = lean_unsigned_to_nat(12u);
return x_14;
}
case 13:
{
lean_object* x_15; 
x_15 = lean_unsigned_to_nat(13u);
return x_15;
}
case 14:
{
lean_object* x_16; 
x_16 = lean_unsigned_to_nat(14u);
return x_16;
}
case 15:
{
lean_object* x_17; 
x_17 = lean_unsigned_to_nat(15u);
return x_17;
}
case 16:
{
lean_object* x_18; 
x_18 = lean_unsigned_to_nat(16u);
return x_18;
}
case 17:
{
lean_object* x_19; 
x_19 = lean_unsigned_to_nat(17u);
return x_19;
}
case 18:
{
lean_object* x_20; 
x_20 = lean_unsigned_to_nat(18u);
return x_20;
}
case 19:
{
lean_object* x_21; 
x_21 = lean_unsigned_to_nat(19u);
return x_21;
}
case 20:
{
lean_object* x_22; 
x_22 = lean_unsigned_to_nat(20u);
return x_22;
}
case 21:
{
lean_object* x_23; 
x_23 = lean_unsigned_to_nat(21u);
return x_23;
}
case 22:
{
lean_object* x_24; 
x_24 = lean_unsigned_to_nat(22u);
return x_24;
}
case 23:
{
lean_object* x_25; 
x_25 = lean_unsigned_to_nat(23u);
return x_25;
}
case 24:
{
lean_object* x_26; 
x_26 = lean_unsigned_to_nat(24u);
return x_26;
}
case 25:
{
lean_object* x_27; 
x_27 = lean_unsigned_to_nat(25u);
return x_27;
}
case 26:
{
lean_object* x_28; 
x_28 = lean_unsigned_to_nat(26u);
return x_28;
}
case 27:
{
lean_object* x_29; 
x_29 = lean_unsigned_to_nat(27u);
return x_29;
}
case 28:
{
lean_object* x_30; 
x_30 = lean_unsigned_to_nat(28u);
return x_30;
}
case 29:
{
lean_object* x_31; 
x_31 = lean_unsigned_to_nat(29u);
return x_31;
}
case 30:
{
lean_object* x_32; 
x_32 = lean_unsigned_to_nat(30u);
return x_32;
}
case 31:
{
lean_object* x_33; 
x_33 = lean_unsigned_to_nat(31u);
return x_33;
}
default: 
{
lean_object* x_34; 
x_34 = lean_unsigned_to_nat(32u);
return x_34;
}
}
}
}
LEAN_EXPORT lean_object* lp_padctl_ButtonId_ctorIdx___boxed(lean_object* x_1) {
_start:
{
uint8_t x_2; lean_object* x_3; 
x_2 = lean_unbox(x_1);
x_3 = lp_padctl_ButtonId_ctorIdx(x_2);
return x_3;
}
}
LEAN_EXPORT lean_object* lp_padctl_ButtonId_toCtorIdx(uint8_t x_1) {
_start:
{
lean_object* x_2; 
x_2 = lp_padctl_ButtonId_ctorIdx(x_1);
return x_2;
}
}
LEAN_EXPORT lean_object* lp_padctl_ButtonId_toCtorIdx___boxed(lean_object* x_1) {
_start:
{
uint8_t x_2; lean_object* x_3; 
x_2 = lean_unbox(x_1);
x_3 = lp_padctl_ButtonId_toCtorIdx(x_2);
return x_3;
}
}
LEAN_EXPORT lean_object* lp_padctl_ButtonId_ctorElim___redArg(lean_object* x_1) {
_start:
{
lean_inc(x_1);
return x_1;
}
}
LEAN_EXPORT lean_object* lp_padctl_ButtonId_ctorElim___redArg___boxed(lean_object* x_1) {
_start:
{
lean_object* x_2; 
x_2 = lp_padctl_ButtonId_ctorElim___redArg(x_1);
lean_dec(x_1);
return x_2;
}
}
LEAN_EXPORT lean_object* lp_padctl_ButtonId_ctorElim(lean_object* x_1, lean_object* x_2, uint8_t x_3, lean_object* x_4, lean_object* x_5) {
_start:
{
lean_inc(x_5);
return x_5;
}
}
LEAN_EXPORT lean_object* lp_padctl_ButtonId_ctorElim___boxed(lean_object* x_1, lean_object* x_2, lean_object* x_3, lean_object* x_4, lean_object* x_5) {
_start:
{
uint8_t x_6; lean_object* x_7; 
x_6 = lean_unbox(x_3);
x_7 = lp_padctl_ButtonId_ctorElim(x_1, x_2, x_6, x_4, x_5);
lean_dec(x_5);
lean_dec(x_2);
return x_7;
}
}
LEAN_EXPORT lean_object* lp_padctl_ButtonId_south_elim___redArg(lean_object* x_1) {
_start:
{
lean_inc(x_1);
return x_1;
}
}
LEAN_EXPORT lean_object* lp_padctl_ButtonId_south_elim___redArg___boxed(lean_object* x_1) {
_start:
{
lean_object* x_2; 
x_2 = lp_padctl_ButtonId_south_elim___redArg(x_1);
lean_dec(x_1);
return x_2;
}
}
LEAN_EXPORT lean_object* lp_padctl_ButtonId_south_elim(lean_object* x_1, uint8_t x_2, lean_object* x_3, lean_object* x_4) {
_start:
{
lean_inc(x_4);
return x_4;
}
}
LEAN_EXPORT lean_object* lp_padctl_ButtonId_south_elim___boxed(lean_object* x_1, lean_object* x_2, lean_object* x_3, lean_object* x_4) {
_start:
{
uint8_t x_5; lean_object* x_6; 
x_5 = lean_unbox(x_2);
x_6 = lp_padctl_ButtonId_south_elim(x_1, x_5, x_3, x_4);
lean_dec(x_4);
return x_6;
}
}
LEAN_EXPORT lean_object* lp_padctl_ButtonId_east_elim___redArg(lean_object* x_1) {
_start:
{
lean_inc(x_1);
return x_1;
}
}
LEAN_EXPORT lean_object* lp_padctl_ButtonId_east_elim___redArg___boxed(lean_object* x_1) {
_start:
{
lean_object* x_2; 
x_2 = lp_padctl_ButtonId_east_elim___redArg(x_1);
lean_dec(x_1);
return x_2;
}
}
LEAN_EXPORT lean_object* lp_padctl_ButtonId_east_elim(lean_object* x_1, uint8_t x_2, lean_object* x_3, lean_object* x_4) {
_start:
{
lean_inc(x_4);
return x_4;
}
}
LEAN_EXPORT lean_object* lp_padctl_ButtonId_east_elim___boxed(lean_object* x_1, lean_object* x_2, lean_object* x_3, lean_object* x_4) {
_start:
{
uint8_t x_5; lean_object* x_6; 
x_5 = lean_unbox(x_2);
x_6 = lp_padctl_ButtonId_east_elim(x_1, x_5, x_3, x_4);
lean_dec(x_4);
return x_6;
}
}
LEAN_EXPORT lean_object* lp_padctl_ButtonId_north_elim___redArg(lean_object* x_1) {
_start:
{
lean_inc(x_1);
return x_1;
}
}
LEAN_EXPORT lean_object* lp_padctl_ButtonId_north_elim___redArg___boxed(lean_object* x_1) {
_start:
{
lean_object* x_2; 
x_2 = lp_padctl_ButtonId_north_elim___redArg(x_1);
lean_dec(x_1);
return x_2;
}
}
LEAN_EXPORT lean_object* lp_padctl_ButtonId_north_elim(lean_object* x_1, uint8_t x_2, lean_object* x_3, lean_object* x_4) {
_start:
{
lean_inc(x_4);
return x_4;
}
}
LEAN_EXPORT lean_object* lp_padctl_ButtonId_north_elim___boxed(lean_object* x_1, lean_object* x_2, lean_object* x_3, lean_object* x_4) {
_start:
{
uint8_t x_5; lean_object* x_6; 
x_5 = lean_unbox(x_2);
x_6 = lp_padctl_ButtonId_north_elim(x_1, x_5, x_3, x_4);
lean_dec(x_4);
return x_6;
}
}
LEAN_EXPORT lean_object* lp_padctl_ButtonId_west_elim___redArg(lean_object* x_1) {
_start:
{
lean_inc(x_1);
return x_1;
}
}
LEAN_EXPORT lean_object* lp_padctl_ButtonId_west_elim___redArg___boxed(lean_object* x_1) {
_start:
{
lean_object* x_2; 
x_2 = lp_padctl_ButtonId_west_elim___redArg(x_1);
lean_dec(x_1);
return x_2;
}
}
LEAN_EXPORT lean_object* lp_padctl_ButtonId_west_elim(lean_object* x_1, uint8_t x_2, lean_object* x_3, lean_object* x_4) {
_start:
{
lean_inc(x_4);
return x_4;
}
}
LEAN_EXPORT lean_object* lp_padctl_ButtonId_west_elim___boxed(lean_object* x_1, lean_object* x_2, lean_object* x_3, lean_object* x_4) {
_start:
{
uint8_t x_5; lean_object* x_6; 
x_5 = lean_unbox(x_2);
x_6 = lp_padctl_ButtonId_west_elim(x_1, x_5, x_3, x_4);
lean_dec(x_4);
return x_6;
}
}
LEAN_EXPORT lean_object* lp_padctl_ButtonId_lsb_elim___redArg(lean_object* x_1) {
_start:
{
lean_inc(x_1);
return x_1;
}
}
LEAN_EXPORT lean_object* lp_padctl_ButtonId_lsb_elim___redArg___boxed(lean_object* x_1) {
_start:
{
lean_object* x_2; 
x_2 = lp_padctl_ButtonId_lsb_elim___redArg(x_1);
lean_dec(x_1);
return x_2;
}
}
LEAN_EXPORT lean_object* lp_padctl_ButtonId_lsb_elim(lean_object* x_1, uint8_t x_2, lean_object* x_3, lean_object* x_4) {
_start:
{
lean_inc(x_4);
return x_4;
}
}
LEAN_EXPORT lean_object* lp_padctl_ButtonId_lsb_elim___boxed(lean_object* x_1, lean_object* x_2, lean_object* x_3, lean_object* x_4) {
_start:
{
uint8_t x_5; lean_object* x_6; 
x_5 = lean_unbox(x_2);
x_6 = lp_padctl_ButtonId_lsb_elim(x_1, x_5, x_3, x_4);
lean_dec(x_4);
return x_6;
}
}
LEAN_EXPORT lean_object* lp_padctl_ButtonId_rsb_elim___redArg(lean_object* x_1) {
_start:
{
lean_inc(x_1);
return x_1;
}
}
LEAN_EXPORT lean_object* lp_padctl_ButtonId_rsb_elim___redArg___boxed(lean_object* x_1) {
_start:
{
lean_object* x_2; 
x_2 = lp_padctl_ButtonId_rsb_elim___redArg(x_1);
lean_dec(x_1);
return x_2;
}
}
LEAN_EXPORT lean_object* lp_padctl_ButtonId_rsb_elim(lean_object* x_1, uint8_t x_2, lean_object* x_3, lean_object* x_4) {
_start:
{
lean_inc(x_4);
return x_4;
}
}
LEAN_EXPORT lean_object* lp_padctl_ButtonId_rsb_elim___boxed(lean_object* x_1, lean_object* x_2, lean_object* x_3, lean_object* x_4) {
_start:
{
uint8_t x_5; lean_object* x_6; 
x_5 = lean_unbox(x_2);
x_6 = lp_padctl_ButtonId_rsb_elim(x_1, x_5, x_3, x_4);
lean_dec(x_4);
return x_6;
}
}
LEAN_EXPORT lean_object* lp_padctl_ButtonId_back_elim___redArg(lean_object* x_1) {
_start:
{
lean_inc(x_1);
return x_1;
}
}
LEAN_EXPORT lean_object* lp_padctl_ButtonId_back_elim___redArg___boxed(lean_object* x_1) {
_start:
{
lean_object* x_2; 
x_2 = lp_padctl_ButtonId_back_elim___redArg(x_1);
lean_dec(x_1);
return x_2;
}
}
LEAN_EXPORT lean_object* lp_padctl_ButtonId_back_elim(lean_object* x_1, uint8_t x_2, lean_object* x_3, lean_object* x_4) {
_start:
{
lean_inc(x_4);
return x_4;
}
}
LEAN_EXPORT lean_object* lp_padctl_ButtonId_back_elim___boxed(lean_object* x_1, lean_object* x_2, lean_object* x_3, lean_object* x_4) {
_start:
{
uint8_t x_5; lean_object* x_6; 
x_5 = lean_unbox(x_2);
x_6 = lp_padctl_ButtonId_back_elim(x_1, x_5, x_3, x_4);
lean_dec(x_4);
return x_6;
}
}
LEAN_EXPORT lean_object* lp_padctl_ButtonId_start_elim___redArg(lean_object* x_1) {
_start:
{
lean_inc(x_1);
return x_1;
}
}
LEAN_EXPORT lean_object* lp_padctl_ButtonId_start_elim___redArg___boxed(lean_object* x_1) {
_start:
{
lean_object* x_2; 
x_2 = lp_padctl_ButtonId_start_elim___redArg(x_1);
lean_dec(x_1);
return x_2;
}
}
LEAN_EXPORT lean_object* lp_padctl_ButtonId_start_elim(lean_object* x_1, uint8_t x_2, lean_object* x_3, lean_object* x_4) {
_start:
{
lean_inc(x_4);
return x_4;
}
}
LEAN_EXPORT lean_object* lp_padctl_ButtonId_start_elim___boxed(lean_object* x_1, lean_object* x_2, lean_object* x_3, lean_object* x_4) {
_start:
{
uint8_t x_5; lean_object* x_6; 
x_5 = lean_unbox(x_2);
x_6 = lp_padctl_ButtonId_start_elim(x_1, x_5, x_3, x_4);
lean_dec(x_4);
return x_6;
}
}
LEAN_EXPORT lean_object* lp_padctl_ButtonId_guide_elim___redArg(lean_object* x_1) {
_start:
{
lean_inc(x_1);
return x_1;
}
}
LEAN_EXPORT lean_object* lp_padctl_ButtonId_guide_elim___redArg___boxed(lean_object* x_1) {
_start:
{
lean_object* x_2; 
x_2 = lp_padctl_ButtonId_guide_elim___redArg(x_1);
lean_dec(x_1);
return x_2;
}
}
LEAN_EXPORT lean_object* lp_padctl_ButtonId_guide_elim(lean_object* x_1, uint8_t x_2, lean_object* x_3, lean_object* x_4) {
_start:
{
lean_inc(x_4);
return x_4;
}
}
LEAN_EXPORT lean_object* lp_padctl_ButtonId_guide_elim___boxed(lean_object* x_1, lean_object* x_2, lean_object* x_3, lean_object* x_4) {
_start:
{
uint8_t x_5; lean_object* x_6; 
x_5 = lean_unbox(x_2);
x_6 = lp_padctl_ButtonId_guide_elim(x_1, x_5, x_3, x_4);
lean_dec(x_4);
return x_6;
}
}
LEAN_EXPORT lean_object* lp_padctl_ButtonId_misc_elim___redArg(lean_object* x_1) {
_start:
{
lean_inc(x_1);
return x_1;
}
}
LEAN_EXPORT lean_object* lp_padctl_ButtonId_misc_elim___redArg___boxed(lean_object* x_1) {
_start:
{
lean_object* x_2; 
x_2 = lp_padctl_ButtonId_misc_elim___redArg(x_1);
lean_dec(x_1);
return x_2;
}
}
LEAN_EXPORT lean_object* lp_padctl_ButtonId_misc_elim(lean_object* x_1, uint8_t x_2, lean_object* x_3, lean_object* x_4) {
_start:
{
lean_inc(x_4);
return x_4;
}
}
LEAN_EXPORT lean_object* lp_padctl_ButtonId_misc_elim___boxed(lean_object* x_1, lean_object* x_2, lean_object* x_3, lean_object* x_4) {
_start:
{
uint8_t x_5; lean_object* x_6; 
x_5 = lean_unbox(x_2);
x_6 = lp_padctl_ButtonId_misc_elim(x_1, x_5, x_3, x_4);
lean_dec(x_4);
return x_6;
}
}
LEAN_EXPORT lean_object* lp_padctl_ButtonId_lt_elim___redArg(lean_object* x_1) {
_start:
{
lean_inc(x_1);
return x_1;
}
}
LEAN_EXPORT lean_object* lp_padctl_ButtonId_lt_elim___redArg___boxed(lean_object* x_1) {
_start:
{
lean_object* x_2; 
x_2 = lp_padctl_ButtonId_lt_elim___redArg(x_1);
lean_dec(x_1);
return x_2;
}
}
LEAN_EXPORT lean_object* lp_padctl_ButtonId_lt_elim(lean_object* x_1, uint8_t x_2, lean_object* x_3, lean_object* x_4) {
_start:
{
lean_inc(x_4);
return x_4;
}
}
LEAN_EXPORT lean_object* lp_padctl_ButtonId_lt_elim___boxed(lean_object* x_1, lean_object* x_2, lean_object* x_3, lean_object* x_4) {
_start:
{
uint8_t x_5; lean_object* x_6; 
x_5 = lean_unbox(x_2);
x_6 = lp_padctl_ButtonId_lt_elim(x_1, x_5, x_3, x_4);
lean_dec(x_4);
return x_6;
}
}
LEAN_EXPORT lean_object* lp_padctl_ButtonId_rt_elim___redArg(lean_object* x_1) {
_start:
{
lean_inc(x_1);
return x_1;
}
}
LEAN_EXPORT lean_object* lp_padctl_ButtonId_rt_elim___redArg___boxed(lean_object* x_1) {
_start:
{
lean_object* x_2; 
x_2 = lp_padctl_ButtonId_rt_elim___redArg(x_1);
lean_dec(x_1);
return x_2;
}
}
LEAN_EXPORT lean_object* lp_padctl_ButtonId_rt_elim(lean_object* x_1, uint8_t x_2, lean_object* x_3, lean_object* x_4) {
_start:
{
lean_inc(x_4);
return x_4;
}
}
LEAN_EXPORT lean_object* lp_padctl_ButtonId_rt_elim___boxed(lean_object* x_1, lean_object* x_2, lean_object* x_3, lean_object* x_4) {
_start:
{
uint8_t x_5; lean_object* x_6; 
x_5 = lean_unbox(x_2);
x_6 = lp_padctl_ButtonId_rt_elim(x_1, x_5, x_3, x_4);
lean_dec(x_4);
return x_6;
}
}
LEAN_EXPORT lean_object* lp_padctl_ButtonId_lb_elim___redArg(lean_object* x_1) {
_start:
{
lean_inc(x_1);
return x_1;
}
}
LEAN_EXPORT lean_object* lp_padctl_ButtonId_lb_elim___redArg___boxed(lean_object* x_1) {
_start:
{
lean_object* x_2; 
x_2 = lp_padctl_ButtonId_lb_elim___redArg(x_1);
lean_dec(x_1);
return x_2;
}
}
LEAN_EXPORT lean_object* lp_padctl_ButtonId_lb_elim(lean_object* x_1, uint8_t x_2, lean_object* x_3, lean_object* x_4) {
_start:
{
lean_inc(x_4);
return x_4;
}
}
LEAN_EXPORT lean_object* lp_padctl_ButtonId_lb_elim___boxed(lean_object* x_1, lean_object* x_2, lean_object* x_3, lean_object* x_4) {
_start:
{
uint8_t x_5; lean_object* x_6; 
x_5 = lean_unbox(x_2);
x_6 = lp_padctl_ButtonId_lb_elim(x_1, x_5, x_3, x_4);
lean_dec(x_4);
return x_6;
}
}
LEAN_EXPORT lean_object* lp_padctl_ButtonId_rb_elim___redArg(lean_object* x_1) {
_start:
{
lean_inc(x_1);
return x_1;
}
}
LEAN_EXPORT lean_object* lp_padctl_ButtonId_rb_elim___redArg___boxed(lean_object* x_1) {
_start:
{
lean_object* x_2; 
x_2 = lp_padctl_ButtonId_rb_elim___redArg(x_1);
lean_dec(x_1);
return x_2;
}
}
LEAN_EXPORT lean_object* lp_padctl_ButtonId_rb_elim(lean_object* x_1, uint8_t x_2, lean_object* x_3, lean_object* x_4) {
_start:
{
lean_inc(x_4);
return x_4;
}
}
LEAN_EXPORT lean_object* lp_padctl_ButtonId_rb_elim___boxed(lean_object* x_1, lean_object* x_2, lean_object* x_3, lean_object* x_4) {
_start:
{
uint8_t x_5; lean_object* x_6; 
x_5 = lean_unbox(x_2);
x_6 = lp_padctl_ButtonId_rb_elim(x_1, x_5, x_3, x_4);
lean_dec(x_4);
return x_6;
}
}
LEAN_EXPORT lean_object* lp_padctl_ButtonId_dpadUp_elim___redArg(lean_object* x_1) {
_start:
{
lean_inc(x_1);
return x_1;
}
}
LEAN_EXPORT lean_object* lp_padctl_ButtonId_dpadUp_elim___redArg___boxed(lean_object* x_1) {
_start:
{
lean_object* x_2; 
x_2 = lp_padctl_ButtonId_dpadUp_elim___redArg(x_1);
lean_dec(x_1);
return x_2;
}
}
LEAN_EXPORT lean_object* lp_padctl_ButtonId_dpadUp_elim(lean_object* x_1, uint8_t x_2, lean_object* x_3, lean_object* x_4) {
_start:
{
lean_inc(x_4);
return x_4;
}
}
LEAN_EXPORT lean_object* lp_padctl_ButtonId_dpadUp_elim___boxed(lean_object* x_1, lean_object* x_2, lean_object* x_3, lean_object* x_4) {
_start:
{
uint8_t x_5; lean_object* x_6; 
x_5 = lean_unbox(x_2);
x_6 = lp_padctl_ButtonId_dpadUp_elim(x_1, x_5, x_3, x_4);
lean_dec(x_4);
return x_6;
}
}
LEAN_EXPORT lean_object* lp_padctl_ButtonId_dpadDown_elim___redArg(lean_object* x_1) {
_start:
{
lean_inc(x_1);
return x_1;
}
}
LEAN_EXPORT lean_object* lp_padctl_ButtonId_dpadDown_elim___redArg___boxed(lean_object* x_1) {
_start:
{
lean_object* x_2; 
x_2 = lp_padctl_ButtonId_dpadDown_elim___redArg(x_1);
lean_dec(x_1);
return x_2;
}
}
LEAN_EXPORT lean_object* lp_padctl_ButtonId_dpadDown_elim(lean_object* x_1, uint8_t x_2, lean_object* x_3, lean_object* x_4) {
_start:
{
lean_inc(x_4);
return x_4;
}
}
LEAN_EXPORT lean_object* lp_padctl_ButtonId_dpadDown_elim___boxed(lean_object* x_1, lean_object* x_2, lean_object* x_3, lean_object* x_4) {
_start:
{
uint8_t x_5; lean_object* x_6; 
x_5 = lean_unbox(x_2);
x_6 = lp_padctl_ButtonId_dpadDown_elim(x_1, x_5, x_3, x_4);
lean_dec(x_4);
return x_6;
}
}
LEAN_EXPORT lean_object* lp_padctl_ButtonId_dpadLeft_elim___redArg(lean_object* x_1) {
_start:
{
lean_inc(x_1);
return x_1;
}
}
LEAN_EXPORT lean_object* lp_padctl_ButtonId_dpadLeft_elim___redArg___boxed(lean_object* x_1) {
_start:
{
lean_object* x_2; 
x_2 = lp_padctl_ButtonId_dpadLeft_elim___redArg(x_1);
lean_dec(x_1);
return x_2;
}
}
LEAN_EXPORT lean_object* lp_padctl_ButtonId_dpadLeft_elim(lean_object* x_1, uint8_t x_2, lean_object* x_3, lean_object* x_4) {
_start:
{
lean_inc(x_4);
return x_4;
}
}
LEAN_EXPORT lean_object* lp_padctl_ButtonId_dpadLeft_elim___boxed(lean_object* x_1, lean_object* x_2, lean_object* x_3, lean_object* x_4) {
_start:
{
uint8_t x_5; lean_object* x_6; 
x_5 = lean_unbox(x_2);
x_6 = lp_padctl_ButtonId_dpadLeft_elim(x_1, x_5, x_3, x_4);
lean_dec(x_4);
return x_6;
}
}
LEAN_EXPORT lean_object* lp_padctl_ButtonId_dpadRight_elim___redArg(lean_object* x_1) {
_start:
{
lean_inc(x_1);
return x_1;
}
}
LEAN_EXPORT lean_object* lp_padctl_ButtonId_dpadRight_elim___redArg___boxed(lean_object* x_1) {
_start:
{
lean_object* x_2; 
x_2 = lp_padctl_ButtonId_dpadRight_elim___redArg(x_1);
lean_dec(x_1);
return x_2;
}
}
LEAN_EXPORT lean_object* lp_padctl_ButtonId_dpadRight_elim(lean_object* x_1, uint8_t x_2, lean_object* x_3, lean_object* x_4) {
_start:
{
lean_inc(x_4);
return x_4;
}
}
LEAN_EXPORT lean_object* lp_padctl_ButtonId_dpadRight_elim___boxed(lean_object* x_1, lean_object* x_2, lean_object* x_3, lean_object* x_4) {
_start:
{
uint8_t x_5; lean_object* x_6; 
x_5 = lean_unbox(x_2);
x_6 = lp_padctl_ButtonId_dpadRight_elim(x_1, x_5, x_3, x_4);
lean_dec(x_4);
return x_6;
}
}
LEAN_EXPORT lean_object* lp_padctl_ButtonId_lt2_elim___redArg(lean_object* x_1) {
_start:
{
lean_inc(x_1);
return x_1;
}
}
LEAN_EXPORT lean_object* lp_padctl_ButtonId_lt2_elim___redArg___boxed(lean_object* x_1) {
_start:
{
lean_object* x_2; 
x_2 = lp_padctl_ButtonId_lt2_elim___redArg(x_1);
lean_dec(x_1);
return x_2;
}
}
LEAN_EXPORT lean_object* lp_padctl_ButtonId_lt2_elim(lean_object* x_1, uint8_t x_2, lean_object* x_3, lean_object* x_4) {
_start:
{
lean_inc(x_4);
return x_4;
}
}
LEAN_EXPORT lean_object* lp_padctl_ButtonId_lt2_elim___boxed(lean_object* x_1, lean_object* x_2, lean_object* x_3, lean_object* x_4) {
_start:
{
uint8_t x_5; lean_object* x_6; 
x_5 = lean_unbox(x_2);
x_6 = lp_padctl_ButtonId_lt2_elim(x_1, x_5, x_3, x_4);
lean_dec(x_4);
return x_6;
}
}
LEAN_EXPORT lean_object* lp_padctl_ButtonId_rt2_elim___redArg(lean_object* x_1) {
_start:
{
lean_inc(x_1);
return x_1;
}
}
LEAN_EXPORT lean_object* lp_padctl_ButtonId_rt2_elim___redArg___boxed(lean_object* x_1) {
_start:
{
lean_object* x_2; 
x_2 = lp_padctl_ButtonId_rt2_elim___redArg(x_1);
lean_dec(x_1);
return x_2;
}
}
LEAN_EXPORT lean_object* lp_padctl_ButtonId_rt2_elim(lean_object* x_1, uint8_t x_2, lean_object* x_3, lean_object* x_4) {
_start:
{
lean_inc(x_4);
return x_4;
}
}
LEAN_EXPORT lean_object* lp_padctl_ButtonId_rt2_elim___boxed(lean_object* x_1, lean_object* x_2, lean_object* x_3, lean_object* x_4) {
_start:
{
uint8_t x_5; lean_object* x_6; 
x_5 = lean_unbox(x_2);
x_6 = lp_padctl_ButtonId_rt2_elim(x_1, x_5, x_3, x_4);
lean_dec(x_4);
return x_6;
}
}
LEAN_EXPORT lean_object* lp_padctl_ButtonId_paddle1_elim___redArg(lean_object* x_1) {
_start:
{
lean_inc(x_1);
return x_1;
}
}
LEAN_EXPORT lean_object* lp_padctl_ButtonId_paddle1_elim___redArg___boxed(lean_object* x_1) {
_start:
{
lean_object* x_2; 
x_2 = lp_padctl_ButtonId_paddle1_elim___redArg(x_1);
lean_dec(x_1);
return x_2;
}
}
LEAN_EXPORT lean_object* lp_padctl_ButtonId_paddle1_elim(lean_object* x_1, uint8_t x_2, lean_object* x_3, lean_object* x_4) {
_start:
{
lean_inc(x_4);
return x_4;
}
}
LEAN_EXPORT lean_object* lp_padctl_ButtonId_paddle1_elim___boxed(lean_object* x_1, lean_object* x_2, lean_object* x_3, lean_object* x_4) {
_start:
{
uint8_t x_5; lean_object* x_6; 
x_5 = lean_unbox(x_2);
x_6 = lp_padctl_ButtonId_paddle1_elim(x_1, x_5, x_3, x_4);
lean_dec(x_4);
return x_6;
}
}
LEAN_EXPORT lean_object* lp_padctl_ButtonId_paddle2_elim___redArg(lean_object* x_1) {
_start:
{
lean_inc(x_1);
return x_1;
}
}
LEAN_EXPORT lean_object* lp_padctl_ButtonId_paddle2_elim___redArg___boxed(lean_object* x_1) {
_start:
{
lean_object* x_2; 
x_2 = lp_padctl_ButtonId_paddle2_elim___redArg(x_1);
lean_dec(x_1);
return x_2;
}
}
LEAN_EXPORT lean_object* lp_padctl_ButtonId_paddle2_elim(lean_object* x_1, uint8_t x_2, lean_object* x_3, lean_object* x_4) {
_start:
{
lean_inc(x_4);
return x_4;
}
}
LEAN_EXPORT lean_object* lp_padctl_ButtonId_paddle2_elim___boxed(lean_object* x_1, lean_object* x_2, lean_object* x_3, lean_object* x_4) {
_start:
{
uint8_t x_5; lean_object* x_6; 
x_5 = lean_unbox(x_2);
x_6 = lp_padctl_ButtonId_paddle2_elim(x_1, x_5, x_3, x_4);
lean_dec(x_4);
return x_6;
}
}
LEAN_EXPORT lean_object* lp_padctl_ButtonId_paddle3_elim___redArg(lean_object* x_1) {
_start:
{
lean_inc(x_1);
return x_1;
}
}
LEAN_EXPORT lean_object* lp_padctl_ButtonId_paddle3_elim___redArg___boxed(lean_object* x_1) {
_start:
{
lean_object* x_2; 
x_2 = lp_padctl_ButtonId_paddle3_elim___redArg(x_1);
lean_dec(x_1);
return x_2;
}
}
LEAN_EXPORT lean_object* lp_padctl_ButtonId_paddle3_elim(lean_object* x_1, uint8_t x_2, lean_object* x_3, lean_object* x_4) {
_start:
{
lean_inc(x_4);
return x_4;
}
}
LEAN_EXPORT lean_object* lp_padctl_ButtonId_paddle3_elim___boxed(lean_object* x_1, lean_object* x_2, lean_object* x_3, lean_object* x_4) {
_start:
{
uint8_t x_5; lean_object* x_6; 
x_5 = lean_unbox(x_2);
x_6 = lp_padctl_ButtonId_paddle3_elim(x_1, x_5, x_3, x_4);
lean_dec(x_4);
return x_6;
}
}
LEAN_EXPORT lean_object* lp_padctl_ButtonId_paddle4_elim___redArg(lean_object* x_1) {
_start:
{
lean_inc(x_1);
return x_1;
}
}
LEAN_EXPORT lean_object* lp_padctl_ButtonId_paddle4_elim___redArg___boxed(lean_object* x_1) {
_start:
{
lean_object* x_2; 
x_2 = lp_padctl_ButtonId_paddle4_elim___redArg(x_1);
lean_dec(x_1);
return x_2;
}
}
LEAN_EXPORT lean_object* lp_padctl_ButtonId_paddle4_elim(lean_object* x_1, uint8_t x_2, lean_object* x_3, lean_object* x_4) {
_start:
{
lean_inc(x_4);
return x_4;
}
}
LEAN_EXPORT lean_object* lp_padctl_ButtonId_paddle4_elim___boxed(lean_object* x_1, lean_object* x_2, lean_object* x_3, lean_object* x_4) {
_start:
{
uint8_t x_5; lean_object* x_6; 
x_5 = lean_unbox(x_2);
x_6 = lp_padctl_ButtonId_paddle4_elim(x_1, x_5, x_3, x_4);
lean_dec(x_4);
return x_6;
}
}
LEAN_EXPORT lean_object* lp_padctl_ButtonId_touchpadButton_elim___redArg(lean_object* x_1) {
_start:
{
lean_inc(x_1);
return x_1;
}
}
LEAN_EXPORT lean_object* lp_padctl_ButtonId_touchpadButton_elim___redArg___boxed(lean_object* x_1) {
_start:
{
lean_object* x_2; 
x_2 = lp_padctl_ButtonId_touchpadButton_elim___redArg(x_1);
lean_dec(x_1);
return x_2;
}
}
LEAN_EXPORT lean_object* lp_padctl_ButtonId_touchpadButton_elim(lean_object* x_1, uint8_t x_2, lean_object* x_3, lean_object* x_4) {
_start:
{
lean_inc(x_4);
return x_4;
}
}
LEAN_EXPORT lean_object* lp_padctl_ButtonId_touchpadButton_elim___boxed(lean_object* x_1, lean_object* x_2, lean_object* x_3, lean_object* x_4) {
_start:
{
uint8_t x_5; lean_object* x_6; 
x_5 = lean_unbox(x_2);
x_6 = lp_padctl_ButtonId_touchpadButton_elim(x_1, x_5, x_3, x_4);
lean_dec(x_4);
return x_6;
}
}
LEAN_EXPORT lean_object* lp_padctl_ButtonId_misc2_elim___redArg(lean_object* x_1) {
_start:
{
lean_inc(x_1);
return x_1;
}
}
LEAN_EXPORT lean_object* lp_padctl_ButtonId_misc2_elim___redArg___boxed(lean_object* x_1) {
_start:
{
lean_object* x_2; 
x_2 = lp_padctl_ButtonId_misc2_elim___redArg(x_1);
lean_dec(x_1);
return x_2;
}
}
LEAN_EXPORT lean_object* lp_padctl_ButtonId_misc2_elim(lean_object* x_1, uint8_t x_2, lean_object* x_3, lean_object* x_4) {
_start:
{
lean_inc(x_4);
return x_4;
}
}
LEAN_EXPORT lean_object* lp_padctl_ButtonId_misc2_elim___boxed(lean_object* x_1, lean_object* x_2, lean_object* x_3, lean_object* x_4) {
_start:
{
uint8_t x_5; lean_object* x_6; 
x_5 = lean_unbox(x_2);
x_6 = lp_padctl_ButtonId_misc2_elim(x_1, x_5, x_3, x_4);
lean_dec(x_4);
return x_6;
}
}
LEAN_EXPORT lean_object* lp_padctl_ButtonId_misc3_elim___redArg(lean_object* x_1) {
_start:
{
lean_inc(x_1);
return x_1;
}
}
LEAN_EXPORT lean_object* lp_padctl_ButtonId_misc3_elim___redArg___boxed(lean_object* x_1) {
_start:
{
lean_object* x_2; 
x_2 = lp_padctl_ButtonId_misc3_elim___redArg(x_1);
lean_dec(x_1);
return x_2;
}
}
LEAN_EXPORT lean_object* lp_padctl_ButtonId_misc3_elim(lean_object* x_1, uint8_t x_2, lean_object* x_3, lean_object* x_4) {
_start:
{
lean_inc(x_4);
return x_4;
}
}
LEAN_EXPORT lean_object* lp_padctl_ButtonId_misc3_elim___boxed(lean_object* x_1, lean_object* x_2, lean_object* x_3, lean_object* x_4) {
_start:
{
uint8_t x_5; lean_object* x_6; 
x_5 = lean_unbox(x_2);
x_6 = lp_padctl_ButtonId_misc3_elim(x_1, x_5, x_3, x_4);
lean_dec(x_4);
return x_6;
}
}
LEAN_EXPORT lean_object* lp_padctl_ButtonId_misc4_elim___redArg(lean_object* x_1) {
_start:
{
lean_inc(x_1);
return x_1;
}
}
LEAN_EXPORT lean_object* lp_padctl_ButtonId_misc4_elim___redArg___boxed(lean_object* x_1) {
_start:
{
lean_object* x_2; 
x_2 = lp_padctl_ButtonId_misc4_elim___redArg(x_1);
lean_dec(x_1);
return x_2;
}
}
LEAN_EXPORT lean_object* lp_padctl_ButtonId_misc4_elim(lean_object* x_1, uint8_t x_2, lean_object* x_3, lean_object* x_4) {
_start:
{
lean_inc(x_4);
return x_4;
}
}
LEAN_EXPORT lean_object* lp_padctl_ButtonId_misc4_elim___boxed(lean_object* x_1, lean_object* x_2, lean_object* x_3, lean_object* x_4) {
_start:
{
uint8_t x_5; lean_object* x_6; 
x_5 = lean_unbox(x_2);
x_6 = lp_padctl_ButtonId_misc4_elim(x_1, x_5, x_3, x_4);
lean_dec(x_4);
return x_6;
}
}
LEAN_EXPORT lean_object* lp_padctl_ButtonId_misc5_elim___redArg(lean_object* x_1) {
_start:
{
lean_inc(x_1);
return x_1;
}
}
LEAN_EXPORT lean_object* lp_padctl_ButtonId_misc5_elim___redArg___boxed(lean_object* x_1) {
_start:
{
lean_object* x_2; 
x_2 = lp_padctl_ButtonId_misc5_elim___redArg(x_1);
lean_dec(x_1);
return x_2;
}
}
LEAN_EXPORT lean_object* lp_padctl_ButtonId_misc5_elim(lean_object* x_1, uint8_t x_2, lean_object* x_3, lean_object* x_4) {
_start:
{
lean_inc(x_4);
return x_4;
}
}
LEAN_EXPORT lean_object* lp_padctl_ButtonId_misc5_elim___boxed(lean_object* x_1, lean_object* x_2, lean_object* x_3, lean_object* x_4) {
_start:
{
uint8_t x_5; lean_object* x_6; 
x_5 = lean_unbox(x_2);
x_6 = lp_padctl_ButtonId_misc5_elim(x_1, x_5, x_3, x_4);
lean_dec(x_4);
return x_6;
}
}
LEAN_EXPORT lean_object* lp_padctl_ButtonId_misc6_elim___redArg(lean_object* x_1) {
_start:
{
lean_inc(x_1);
return x_1;
}
}
LEAN_EXPORT lean_object* lp_padctl_ButtonId_misc6_elim___redArg___boxed(lean_object* x_1) {
_start:
{
lean_object* x_2; 
x_2 = lp_padctl_ButtonId_misc6_elim___redArg(x_1);
lean_dec(x_1);
return x_2;
}
}
LEAN_EXPORT lean_object* lp_padctl_ButtonId_misc6_elim(lean_object* x_1, uint8_t x_2, lean_object* x_3, lean_object* x_4) {
_start:
{
lean_inc(x_4);
return x_4;
}
}
LEAN_EXPORT lean_object* lp_padctl_ButtonId_misc6_elim___boxed(lean_object* x_1, lean_object* x_2, lean_object* x_3, lean_object* x_4) {
_start:
{
uint8_t x_5; lean_object* x_6; 
x_5 = lean_unbox(x_2);
x_6 = lp_padctl_ButtonId_misc6_elim(x_1, x_5, x_3, x_4);
lean_dec(x_4);
return x_6;
}
}
LEAN_EXPORT lean_object* lp_padctl_ButtonId_misc7_elim___redArg(lean_object* x_1) {
_start:
{
lean_inc(x_1);
return x_1;
}
}
LEAN_EXPORT lean_object* lp_padctl_ButtonId_misc7_elim___redArg___boxed(lean_object* x_1) {
_start:
{
lean_object* x_2; 
x_2 = lp_padctl_ButtonId_misc7_elim___redArg(x_1);
lean_dec(x_1);
return x_2;
}
}
LEAN_EXPORT lean_object* lp_padctl_ButtonId_misc7_elim(lean_object* x_1, uint8_t x_2, lean_object* x_3, lean_object* x_4) {
_start:
{
lean_inc(x_4);
return x_4;
}
}
LEAN_EXPORT lean_object* lp_padctl_ButtonId_misc7_elim___boxed(lean_object* x_1, lean_object* x_2, lean_object* x_3, lean_object* x_4) {
_start:
{
uint8_t x_5; lean_object* x_6; 
x_5 = lean_unbox(x_2);
x_6 = lp_padctl_ButtonId_misc7_elim(x_1, x_5, x_3, x_4);
lean_dec(x_4);
return x_6;
}
}
LEAN_EXPORT lean_object* lp_padctl_ButtonId_misc8_elim___redArg(lean_object* x_1) {
_start:
{
lean_inc(x_1);
return x_1;
}
}
LEAN_EXPORT lean_object* lp_padctl_ButtonId_misc8_elim___redArg___boxed(lean_object* x_1) {
_start:
{
lean_object* x_2; 
x_2 = lp_padctl_ButtonId_misc8_elim___redArg(x_1);
lean_dec(x_1);
return x_2;
}
}
LEAN_EXPORT lean_object* lp_padctl_ButtonId_misc8_elim(lean_object* x_1, uint8_t x_2, lean_object* x_3, lean_object* x_4) {
_start:
{
lean_inc(x_4);
return x_4;
}
}
LEAN_EXPORT lean_object* lp_padctl_ButtonId_misc8_elim___boxed(lean_object* x_1, lean_object* x_2, lean_object* x_3, lean_object* x_4) {
_start:
{
uint8_t x_5; lean_object* x_6; 
x_5 = lean_unbox(x_2);
x_6 = lp_padctl_ButtonId_misc8_elim(x_1, x_5, x_3, x_4);
lean_dec(x_4);
return x_6;
}
}
LEAN_EXPORT lean_object* lp_padctl_ButtonId_misc9_elim___redArg(lean_object* x_1) {
_start:
{
lean_inc(x_1);
return x_1;
}
}
LEAN_EXPORT lean_object* lp_padctl_ButtonId_misc9_elim___redArg___boxed(lean_object* x_1) {
_start:
{
lean_object* x_2; 
x_2 = lp_padctl_ButtonId_misc9_elim___redArg(x_1);
lean_dec(x_1);
return x_2;
}
}
LEAN_EXPORT lean_object* lp_padctl_ButtonId_misc9_elim(lean_object* x_1, uint8_t x_2, lean_object* x_3, lean_object* x_4) {
_start:
{
lean_inc(x_4);
return x_4;
}
}
LEAN_EXPORT lean_object* lp_padctl_ButtonId_misc9_elim___boxed(lean_object* x_1, lean_object* x_2, lean_object* x_3, lean_object* x_4) {
_start:
{
uint8_t x_5; lean_object* x_6; 
x_5 = lean_unbox(x_2);
x_6 = lp_padctl_ButtonId_misc9_elim(x_1, x_5, x_3, x_4);
lean_dec(x_4);
return x_6;
}
}
LEAN_EXPORT uint8_t lp_padctl_ButtonId_ofNat(lean_object* x_1) {
_start:
{
lean_object* x_2; uint8_t x_3; 
x_2 = lean_unsigned_to_nat(15u);
x_3 = lean_nat_dec_le(x_1, x_2);
if (x_3 == 0)
{
lean_object* x_4; uint8_t x_5; 
x_4 = lean_unsigned_to_nat(23u);
x_5 = lean_nat_dec_le(x_1, x_4);
if (x_5 == 0)
{
lean_object* x_6; uint8_t x_7; 
x_6 = lean_unsigned_to_nat(27u);
x_7 = lean_nat_dec_le(x_1, x_6);
if (x_7 == 0)
{
lean_object* x_8; uint8_t x_9; 
x_8 = lean_unsigned_to_nat(29u);
x_9 = lean_nat_dec_le(x_1, x_8);
if (x_9 == 0)
{
lean_object* x_10; uint8_t x_11; 
x_10 = lean_unsigned_to_nat(30u);
x_11 = lean_nat_dec_le(x_1, x_10);
if (x_11 == 0)
{
lean_object* x_12; uint8_t x_13; 
x_12 = lean_unsigned_to_nat(31u);
x_13 = lean_nat_dec_le(x_1, x_12);
if (x_13 == 0)
{
uint8_t x_14; 
x_14 = 32;
return x_14;
}
else
{
uint8_t x_15; 
x_15 = 31;
return x_15;
}
}
else
{
uint8_t x_16; 
x_16 = 30;
return x_16;
}
}
else
{
lean_object* x_17; uint8_t x_18; 
x_17 = lean_unsigned_to_nat(28u);
x_18 = lean_nat_dec_le(x_1, x_17);
if (x_18 == 0)
{
uint8_t x_19; 
x_19 = 29;
return x_19;
}
else
{
uint8_t x_20; 
x_20 = 28;
return x_20;
}
}
}
else
{
lean_object* x_21; uint8_t x_22; 
x_21 = lean_unsigned_to_nat(25u);
x_22 = lean_nat_dec_le(x_1, x_21);
if (x_22 == 0)
{
lean_object* x_23; uint8_t x_24; 
x_23 = lean_unsigned_to_nat(26u);
x_24 = lean_nat_dec_le(x_1, x_23);
if (x_24 == 0)
{
uint8_t x_25; 
x_25 = 27;
return x_25;
}
else
{
uint8_t x_26; 
x_26 = 26;
return x_26;
}
}
else
{
lean_object* x_27; uint8_t x_28; 
x_27 = lean_unsigned_to_nat(24u);
x_28 = lean_nat_dec_le(x_1, x_27);
if (x_28 == 0)
{
uint8_t x_29; 
x_29 = 25;
return x_29;
}
else
{
uint8_t x_30; 
x_30 = 24;
return x_30;
}
}
}
}
else
{
lean_object* x_31; uint8_t x_32; 
x_31 = lean_unsigned_to_nat(19u);
x_32 = lean_nat_dec_le(x_1, x_31);
if (x_32 == 0)
{
lean_object* x_33; uint8_t x_34; 
x_33 = lean_unsigned_to_nat(21u);
x_34 = lean_nat_dec_le(x_1, x_33);
if (x_34 == 0)
{
lean_object* x_35; uint8_t x_36; 
x_35 = lean_unsigned_to_nat(22u);
x_36 = lean_nat_dec_le(x_1, x_35);
if (x_36 == 0)
{
uint8_t x_37; 
x_37 = 23;
return x_37;
}
else
{
uint8_t x_38; 
x_38 = 22;
return x_38;
}
}
else
{
lean_object* x_39; uint8_t x_40; 
x_39 = lean_unsigned_to_nat(20u);
x_40 = lean_nat_dec_le(x_1, x_39);
if (x_40 == 0)
{
uint8_t x_41; 
x_41 = 21;
return x_41;
}
else
{
uint8_t x_42; 
x_42 = 20;
return x_42;
}
}
}
else
{
lean_object* x_43; uint8_t x_44; 
x_43 = lean_unsigned_to_nat(17u);
x_44 = lean_nat_dec_le(x_1, x_43);
if (x_44 == 0)
{
lean_object* x_45; uint8_t x_46; 
x_45 = lean_unsigned_to_nat(18u);
x_46 = lean_nat_dec_le(x_1, x_45);
if (x_46 == 0)
{
uint8_t x_47; 
x_47 = 19;
return x_47;
}
else
{
uint8_t x_48; 
x_48 = 18;
return x_48;
}
}
else
{
lean_object* x_49; uint8_t x_50; 
x_49 = lean_unsigned_to_nat(16u);
x_50 = lean_nat_dec_le(x_1, x_49);
if (x_50 == 0)
{
uint8_t x_51; 
x_51 = 17;
return x_51;
}
else
{
uint8_t x_52; 
x_52 = 16;
return x_52;
}
}
}
}
}
else
{
lean_object* x_53; uint8_t x_54; 
x_53 = lean_unsigned_to_nat(7u);
x_54 = lean_nat_dec_le(x_1, x_53);
if (x_54 == 0)
{
lean_object* x_55; uint8_t x_56; 
x_55 = lean_unsigned_to_nat(11u);
x_56 = lean_nat_dec_le(x_1, x_55);
if (x_56 == 0)
{
lean_object* x_57; uint8_t x_58; 
x_57 = lean_unsigned_to_nat(13u);
x_58 = lean_nat_dec_le(x_1, x_57);
if (x_58 == 0)
{
lean_object* x_59; uint8_t x_60; 
x_59 = lean_unsigned_to_nat(14u);
x_60 = lean_nat_dec_le(x_1, x_59);
if (x_60 == 0)
{
uint8_t x_61; 
x_61 = 15;
return x_61;
}
else
{
uint8_t x_62; 
x_62 = 14;
return x_62;
}
}
else
{
lean_object* x_63; uint8_t x_64; 
x_63 = lean_unsigned_to_nat(12u);
x_64 = lean_nat_dec_le(x_1, x_63);
if (x_64 == 0)
{
uint8_t x_65; 
x_65 = 13;
return x_65;
}
else
{
uint8_t x_66; 
x_66 = 12;
return x_66;
}
}
}
else
{
lean_object* x_67; uint8_t x_68; 
x_67 = lean_unsigned_to_nat(9u);
x_68 = lean_nat_dec_le(x_1, x_67);
if (x_68 == 0)
{
lean_object* x_69; uint8_t x_70; 
x_69 = lean_unsigned_to_nat(10u);
x_70 = lean_nat_dec_le(x_1, x_69);
if (x_70 == 0)
{
uint8_t x_71; 
x_71 = 11;
return x_71;
}
else
{
uint8_t x_72; 
x_72 = 10;
return x_72;
}
}
else
{
lean_object* x_73; uint8_t x_74; 
x_73 = lean_unsigned_to_nat(8u);
x_74 = lean_nat_dec_le(x_1, x_73);
if (x_74 == 0)
{
uint8_t x_75; 
x_75 = 9;
return x_75;
}
else
{
uint8_t x_76; 
x_76 = 8;
return x_76;
}
}
}
}
else
{
lean_object* x_77; uint8_t x_78; 
x_77 = lean_unsigned_to_nat(3u);
x_78 = lean_nat_dec_le(x_1, x_77);
if (x_78 == 0)
{
lean_object* x_79; uint8_t x_80; 
x_79 = lean_unsigned_to_nat(5u);
x_80 = lean_nat_dec_le(x_1, x_79);
if (x_80 == 0)
{
lean_object* x_81; uint8_t x_82; 
x_81 = lean_unsigned_to_nat(6u);
x_82 = lean_nat_dec_le(x_1, x_81);
if (x_82 == 0)
{
uint8_t x_83; 
x_83 = 7;
return x_83;
}
else
{
uint8_t x_84; 
x_84 = 6;
return x_84;
}
}
else
{
lean_object* x_85; uint8_t x_86; 
x_85 = lean_unsigned_to_nat(4u);
x_86 = lean_nat_dec_le(x_1, x_85);
if (x_86 == 0)
{
uint8_t x_87; 
x_87 = 5;
return x_87;
}
else
{
uint8_t x_88; 
x_88 = 4;
return x_88;
}
}
}
else
{
lean_object* x_89; uint8_t x_90; 
x_89 = lean_unsigned_to_nat(1u);
x_90 = lean_nat_dec_le(x_1, x_89);
if (x_90 == 0)
{
lean_object* x_91; uint8_t x_92; 
x_91 = lean_unsigned_to_nat(2u);
x_92 = lean_nat_dec_le(x_1, x_91);
if (x_92 == 0)
{
uint8_t x_93; 
x_93 = 3;
return x_93;
}
else
{
uint8_t x_94; 
x_94 = 2;
return x_94;
}
}
else
{
lean_object* x_95; uint8_t x_96; 
x_95 = lean_unsigned_to_nat(0u);
x_96 = lean_nat_dec_le(x_1, x_95);
if (x_96 == 0)
{
uint8_t x_97; 
x_97 = 1;
return x_97;
}
else
{
uint8_t x_98; 
x_98 = 0;
return x_98;
}
}
}
}
}
}
}
LEAN_EXPORT lean_object* lp_padctl_ButtonId_ofNat___boxed(lean_object* x_1) {
_start:
{
uint8_t x_2; lean_object* x_3; 
x_2 = lp_padctl_ButtonId_ofNat(x_1);
lean_dec(x_1);
x_3 = lean_box(x_2);
return x_3;
}
}
LEAN_EXPORT uint8_t lp_padctl_instDecidableEqButtonId(uint8_t x_1, uint8_t x_2) {
_start:
{
lean_object* x_3; lean_object* x_4; uint8_t x_5; 
x_3 = lp_padctl_ButtonId_ctorIdx(x_1);
x_4 = lp_padctl_ButtonId_ctorIdx(x_2);
x_5 = lean_nat_dec_eq(x_3, x_4);
lean_dec(x_4);
lean_dec(x_3);
return x_5;
}
}
LEAN_EXPORT lean_object* lp_padctl_instDecidableEqButtonId___boxed(lean_object* x_1, lean_object* x_2) {
_start:
{
uint8_t x_3; uint8_t x_4; uint8_t x_5; lean_object* x_6; 
x_3 = lean_unbox(x_1);
x_4 = lean_unbox(x_2);
x_5 = lp_padctl_instDecidableEqButtonId(x_3, x_4);
x_6 = lean_box(x_5);
return x_6;
}
}
static lean_object* _init_lp_padctl_instReprButtonId_repr___closed__66(void) {
_start:
{
lean_object* x_1; lean_object* x_2; 
x_1 = lean_unsigned_to_nat(2u);
x_2 = lean_nat_to_int(x_1);
return x_2;
}
}
static lean_object* _init_lp_padctl_instReprButtonId_repr___closed__67(void) {
_start:
{
lean_object* x_1; lean_object* x_2; 
x_1 = lean_unsigned_to_nat(1u);
x_2 = lean_nat_to_int(x_1);
return x_2;
}
}
LEAN_EXPORT lean_object* lp_padctl_instReprButtonId_repr(uint8_t x_1, lean_object* x_2) {
_start:
{
lean_object* x_3; lean_object* x_10; lean_object* x_17; lean_object* x_24; lean_object* x_31; lean_object* x_38; lean_object* x_45; lean_object* x_52; lean_object* x_59; lean_object* x_66; lean_object* x_73; lean_object* x_80; lean_object* x_87; lean_object* x_94; lean_object* x_101; lean_object* x_108; lean_object* x_115; lean_object* x_122; lean_object* x_129; lean_object* x_136; lean_object* x_143; lean_object* x_150; lean_object* x_157; lean_object* x_164; lean_object* x_171; lean_object* x_178; lean_object* x_185; lean_object* x_192; lean_object* x_199; lean_object* x_206; lean_object* x_213; lean_object* x_220; lean_object* x_227; 
switch (x_1) {
case 0:
{
lean_object* x_234; uint8_t x_235; 
x_234 = lean_unsigned_to_nat(1024u);
x_235 = lean_nat_dec_le(x_234, x_2);
if (x_235 == 0)
{
lean_object* x_236; 
x_236 = lean_obj_once(&lp_padctl_instReprButtonId_repr___closed__66, &lp_padctl_instReprButtonId_repr___closed__66_once, _init_lp_padctl_instReprButtonId_repr___closed__66);
x_3 = x_236;
goto block_9;
}
else
{
lean_object* x_237; 
x_237 = lean_obj_once(&lp_padctl_instReprButtonId_repr___closed__67, &lp_padctl_instReprButtonId_repr___closed__67_once, _init_lp_padctl_instReprButtonId_repr___closed__67);
x_3 = x_237;
goto block_9;
}
}
case 1:
{
lean_object* x_238; uint8_t x_239; 
x_238 = lean_unsigned_to_nat(1024u);
x_239 = lean_nat_dec_le(x_238, x_2);
if (x_239 == 0)
{
lean_object* x_240; 
x_240 = lean_obj_once(&lp_padctl_instReprButtonId_repr___closed__66, &lp_padctl_instReprButtonId_repr___closed__66_once, _init_lp_padctl_instReprButtonId_repr___closed__66);
x_10 = x_240;
goto block_16;
}
else
{
lean_object* x_241; 
x_241 = lean_obj_once(&lp_padctl_instReprButtonId_repr___closed__67, &lp_padctl_instReprButtonId_repr___closed__67_once, _init_lp_padctl_instReprButtonId_repr___closed__67);
x_10 = x_241;
goto block_16;
}
}
case 2:
{
lean_object* x_242; uint8_t x_243; 
x_242 = lean_unsigned_to_nat(1024u);
x_243 = lean_nat_dec_le(x_242, x_2);
if (x_243 == 0)
{
lean_object* x_244; 
x_244 = lean_obj_once(&lp_padctl_instReprButtonId_repr___closed__66, &lp_padctl_instReprButtonId_repr___closed__66_once, _init_lp_padctl_instReprButtonId_repr___closed__66);
x_17 = x_244;
goto block_23;
}
else
{
lean_object* x_245; 
x_245 = lean_obj_once(&lp_padctl_instReprButtonId_repr___closed__67, &lp_padctl_instReprButtonId_repr___closed__67_once, _init_lp_padctl_instReprButtonId_repr___closed__67);
x_17 = x_245;
goto block_23;
}
}
case 3:
{
lean_object* x_246; uint8_t x_247; 
x_246 = lean_unsigned_to_nat(1024u);
x_247 = lean_nat_dec_le(x_246, x_2);
if (x_247 == 0)
{
lean_object* x_248; 
x_248 = lean_obj_once(&lp_padctl_instReprButtonId_repr___closed__66, &lp_padctl_instReprButtonId_repr___closed__66_once, _init_lp_padctl_instReprButtonId_repr___closed__66);
x_24 = x_248;
goto block_30;
}
else
{
lean_object* x_249; 
x_249 = lean_obj_once(&lp_padctl_instReprButtonId_repr___closed__67, &lp_padctl_instReprButtonId_repr___closed__67_once, _init_lp_padctl_instReprButtonId_repr___closed__67);
x_24 = x_249;
goto block_30;
}
}
case 4:
{
lean_object* x_250; uint8_t x_251; 
x_250 = lean_unsigned_to_nat(1024u);
x_251 = lean_nat_dec_le(x_250, x_2);
if (x_251 == 0)
{
lean_object* x_252; 
x_252 = lean_obj_once(&lp_padctl_instReprButtonId_repr___closed__66, &lp_padctl_instReprButtonId_repr___closed__66_once, _init_lp_padctl_instReprButtonId_repr___closed__66);
x_31 = x_252;
goto block_37;
}
else
{
lean_object* x_253; 
x_253 = lean_obj_once(&lp_padctl_instReprButtonId_repr___closed__67, &lp_padctl_instReprButtonId_repr___closed__67_once, _init_lp_padctl_instReprButtonId_repr___closed__67);
x_31 = x_253;
goto block_37;
}
}
case 5:
{
lean_object* x_254; uint8_t x_255; 
x_254 = lean_unsigned_to_nat(1024u);
x_255 = lean_nat_dec_le(x_254, x_2);
if (x_255 == 0)
{
lean_object* x_256; 
x_256 = lean_obj_once(&lp_padctl_instReprButtonId_repr___closed__66, &lp_padctl_instReprButtonId_repr___closed__66_once, _init_lp_padctl_instReprButtonId_repr___closed__66);
x_38 = x_256;
goto block_44;
}
else
{
lean_object* x_257; 
x_257 = lean_obj_once(&lp_padctl_instReprButtonId_repr___closed__67, &lp_padctl_instReprButtonId_repr___closed__67_once, _init_lp_padctl_instReprButtonId_repr___closed__67);
x_38 = x_257;
goto block_44;
}
}
case 6:
{
lean_object* x_258; uint8_t x_259; 
x_258 = lean_unsigned_to_nat(1024u);
x_259 = lean_nat_dec_le(x_258, x_2);
if (x_259 == 0)
{
lean_object* x_260; 
x_260 = lean_obj_once(&lp_padctl_instReprButtonId_repr___closed__66, &lp_padctl_instReprButtonId_repr___closed__66_once, _init_lp_padctl_instReprButtonId_repr___closed__66);
x_45 = x_260;
goto block_51;
}
else
{
lean_object* x_261; 
x_261 = lean_obj_once(&lp_padctl_instReprButtonId_repr___closed__67, &lp_padctl_instReprButtonId_repr___closed__67_once, _init_lp_padctl_instReprButtonId_repr___closed__67);
x_45 = x_261;
goto block_51;
}
}
case 7:
{
lean_object* x_262; uint8_t x_263; 
x_262 = lean_unsigned_to_nat(1024u);
x_263 = lean_nat_dec_le(x_262, x_2);
if (x_263 == 0)
{
lean_object* x_264; 
x_264 = lean_obj_once(&lp_padctl_instReprButtonId_repr___closed__66, &lp_padctl_instReprButtonId_repr___closed__66_once, _init_lp_padctl_instReprButtonId_repr___closed__66);
x_52 = x_264;
goto block_58;
}
else
{
lean_object* x_265; 
x_265 = lean_obj_once(&lp_padctl_instReprButtonId_repr___closed__67, &lp_padctl_instReprButtonId_repr___closed__67_once, _init_lp_padctl_instReprButtonId_repr___closed__67);
x_52 = x_265;
goto block_58;
}
}
case 8:
{
lean_object* x_266; uint8_t x_267; 
x_266 = lean_unsigned_to_nat(1024u);
x_267 = lean_nat_dec_le(x_266, x_2);
if (x_267 == 0)
{
lean_object* x_268; 
x_268 = lean_obj_once(&lp_padctl_instReprButtonId_repr___closed__66, &lp_padctl_instReprButtonId_repr___closed__66_once, _init_lp_padctl_instReprButtonId_repr___closed__66);
x_59 = x_268;
goto block_65;
}
else
{
lean_object* x_269; 
x_269 = lean_obj_once(&lp_padctl_instReprButtonId_repr___closed__67, &lp_padctl_instReprButtonId_repr___closed__67_once, _init_lp_padctl_instReprButtonId_repr___closed__67);
x_59 = x_269;
goto block_65;
}
}
case 9:
{
lean_object* x_270; uint8_t x_271; 
x_270 = lean_unsigned_to_nat(1024u);
x_271 = lean_nat_dec_le(x_270, x_2);
if (x_271 == 0)
{
lean_object* x_272; 
x_272 = lean_obj_once(&lp_padctl_instReprButtonId_repr___closed__66, &lp_padctl_instReprButtonId_repr___closed__66_once, _init_lp_padctl_instReprButtonId_repr___closed__66);
x_66 = x_272;
goto block_72;
}
else
{
lean_object* x_273; 
x_273 = lean_obj_once(&lp_padctl_instReprButtonId_repr___closed__67, &lp_padctl_instReprButtonId_repr___closed__67_once, _init_lp_padctl_instReprButtonId_repr___closed__67);
x_66 = x_273;
goto block_72;
}
}
case 10:
{
lean_object* x_274; uint8_t x_275; 
x_274 = lean_unsigned_to_nat(1024u);
x_275 = lean_nat_dec_le(x_274, x_2);
if (x_275 == 0)
{
lean_object* x_276; 
x_276 = lean_obj_once(&lp_padctl_instReprButtonId_repr___closed__66, &lp_padctl_instReprButtonId_repr___closed__66_once, _init_lp_padctl_instReprButtonId_repr___closed__66);
x_73 = x_276;
goto block_79;
}
else
{
lean_object* x_277; 
x_277 = lean_obj_once(&lp_padctl_instReprButtonId_repr___closed__67, &lp_padctl_instReprButtonId_repr___closed__67_once, _init_lp_padctl_instReprButtonId_repr___closed__67);
x_73 = x_277;
goto block_79;
}
}
case 11:
{
lean_object* x_278; uint8_t x_279; 
x_278 = lean_unsigned_to_nat(1024u);
x_279 = lean_nat_dec_le(x_278, x_2);
if (x_279 == 0)
{
lean_object* x_280; 
x_280 = lean_obj_once(&lp_padctl_instReprButtonId_repr___closed__66, &lp_padctl_instReprButtonId_repr___closed__66_once, _init_lp_padctl_instReprButtonId_repr___closed__66);
x_80 = x_280;
goto block_86;
}
else
{
lean_object* x_281; 
x_281 = lean_obj_once(&lp_padctl_instReprButtonId_repr___closed__67, &lp_padctl_instReprButtonId_repr___closed__67_once, _init_lp_padctl_instReprButtonId_repr___closed__67);
x_80 = x_281;
goto block_86;
}
}
case 12:
{
lean_object* x_282; uint8_t x_283; 
x_282 = lean_unsigned_to_nat(1024u);
x_283 = lean_nat_dec_le(x_282, x_2);
if (x_283 == 0)
{
lean_object* x_284; 
x_284 = lean_obj_once(&lp_padctl_instReprButtonId_repr___closed__66, &lp_padctl_instReprButtonId_repr___closed__66_once, _init_lp_padctl_instReprButtonId_repr___closed__66);
x_87 = x_284;
goto block_93;
}
else
{
lean_object* x_285; 
x_285 = lean_obj_once(&lp_padctl_instReprButtonId_repr___closed__67, &lp_padctl_instReprButtonId_repr___closed__67_once, _init_lp_padctl_instReprButtonId_repr___closed__67);
x_87 = x_285;
goto block_93;
}
}
case 13:
{
lean_object* x_286; uint8_t x_287; 
x_286 = lean_unsigned_to_nat(1024u);
x_287 = lean_nat_dec_le(x_286, x_2);
if (x_287 == 0)
{
lean_object* x_288; 
x_288 = lean_obj_once(&lp_padctl_instReprButtonId_repr___closed__66, &lp_padctl_instReprButtonId_repr___closed__66_once, _init_lp_padctl_instReprButtonId_repr___closed__66);
x_94 = x_288;
goto block_100;
}
else
{
lean_object* x_289; 
x_289 = lean_obj_once(&lp_padctl_instReprButtonId_repr___closed__67, &lp_padctl_instReprButtonId_repr___closed__67_once, _init_lp_padctl_instReprButtonId_repr___closed__67);
x_94 = x_289;
goto block_100;
}
}
case 14:
{
lean_object* x_290; uint8_t x_291; 
x_290 = lean_unsigned_to_nat(1024u);
x_291 = lean_nat_dec_le(x_290, x_2);
if (x_291 == 0)
{
lean_object* x_292; 
x_292 = lean_obj_once(&lp_padctl_instReprButtonId_repr___closed__66, &lp_padctl_instReprButtonId_repr___closed__66_once, _init_lp_padctl_instReprButtonId_repr___closed__66);
x_101 = x_292;
goto block_107;
}
else
{
lean_object* x_293; 
x_293 = lean_obj_once(&lp_padctl_instReprButtonId_repr___closed__67, &lp_padctl_instReprButtonId_repr___closed__67_once, _init_lp_padctl_instReprButtonId_repr___closed__67);
x_101 = x_293;
goto block_107;
}
}
case 15:
{
lean_object* x_294; uint8_t x_295; 
x_294 = lean_unsigned_to_nat(1024u);
x_295 = lean_nat_dec_le(x_294, x_2);
if (x_295 == 0)
{
lean_object* x_296; 
x_296 = lean_obj_once(&lp_padctl_instReprButtonId_repr___closed__66, &lp_padctl_instReprButtonId_repr___closed__66_once, _init_lp_padctl_instReprButtonId_repr___closed__66);
x_108 = x_296;
goto block_114;
}
else
{
lean_object* x_297; 
x_297 = lean_obj_once(&lp_padctl_instReprButtonId_repr___closed__67, &lp_padctl_instReprButtonId_repr___closed__67_once, _init_lp_padctl_instReprButtonId_repr___closed__67);
x_108 = x_297;
goto block_114;
}
}
case 16:
{
lean_object* x_298; uint8_t x_299; 
x_298 = lean_unsigned_to_nat(1024u);
x_299 = lean_nat_dec_le(x_298, x_2);
if (x_299 == 0)
{
lean_object* x_300; 
x_300 = lean_obj_once(&lp_padctl_instReprButtonId_repr___closed__66, &lp_padctl_instReprButtonId_repr___closed__66_once, _init_lp_padctl_instReprButtonId_repr___closed__66);
x_115 = x_300;
goto block_121;
}
else
{
lean_object* x_301; 
x_301 = lean_obj_once(&lp_padctl_instReprButtonId_repr___closed__67, &lp_padctl_instReprButtonId_repr___closed__67_once, _init_lp_padctl_instReprButtonId_repr___closed__67);
x_115 = x_301;
goto block_121;
}
}
case 17:
{
lean_object* x_302; uint8_t x_303; 
x_302 = lean_unsigned_to_nat(1024u);
x_303 = lean_nat_dec_le(x_302, x_2);
if (x_303 == 0)
{
lean_object* x_304; 
x_304 = lean_obj_once(&lp_padctl_instReprButtonId_repr___closed__66, &lp_padctl_instReprButtonId_repr___closed__66_once, _init_lp_padctl_instReprButtonId_repr___closed__66);
x_122 = x_304;
goto block_128;
}
else
{
lean_object* x_305; 
x_305 = lean_obj_once(&lp_padctl_instReprButtonId_repr___closed__67, &lp_padctl_instReprButtonId_repr___closed__67_once, _init_lp_padctl_instReprButtonId_repr___closed__67);
x_122 = x_305;
goto block_128;
}
}
case 18:
{
lean_object* x_306; uint8_t x_307; 
x_306 = lean_unsigned_to_nat(1024u);
x_307 = lean_nat_dec_le(x_306, x_2);
if (x_307 == 0)
{
lean_object* x_308; 
x_308 = lean_obj_once(&lp_padctl_instReprButtonId_repr___closed__66, &lp_padctl_instReprButtonId_repr___closed__66_once, _init_lp_padctl_instReprButtonId_repr___closed__66);
x_129 = x_308;
goto block_135;
}
else
{
lean_object* x_309; 
x_309 = lean_obj_once(&lp_padctl_instReprButtonId_repr___closed__67, &lp_padctl_instReprButtonId_repr___closed__67_once, _init_lp_padctl_instReprButtonId_repr___closed__67);
x_129 = x_309;
goto block_135;
}
}
case 19:
{
lean_object* x_310; uint8_t x_311; 
x_310 = lean_unsigned_to_nat(1024u);
x_311 = lean_nat_dec_le(x_310, x_2);
if (x_311 == 0)
{
lean_object* x_312; 
x_312 = lean_obj_once(&lp_padctl_instReprButtonId_repr___closed__66, &lp_padctl_instReprButtonId_repr___closed__66_once, _init_lp_padctl_instReprButtonId_repr___closed__66);
x_136 = x_312;
goto block_142;
}
else
{
lean_object* x_313; 
x_313 = lean_obj_once(&lp_padctl_instReprButtonId_repr___closed__67, &lp_padctl_instReprButtonId_repr___closed__67_once, _init_lp_padctl_instReprButtonId_repr___closed__67);
x_136 = x_313;
goto block_142;
}
}
case 20:
{
lean_object* x_314; uint8_t x_315; 
x_314 = lean_unsigned_to_nat(1024u);
x_315 = lean_nat_dec_le(x_314, x_2);
if (x_315 == 0)
{
lean_object* x_316; 
x_316 = lean_obj_once(&lp_padctl_instReprButtonId_repr___closed__66, &lp_padctl_instReprButtonId_repr___closed__66_once, _init_lp_padctl_instReprButtonId_repr___closed__66);
x_143 = x_316;
goto block_149;
}
else
{
lean_object* x_317; 
x_317 = lean_obj_once(&lp_padctl_instReprButtonId_repr___closed__67, &lp_padctl_instReprButtonId_repr___closed__67_once, _init_lp_padctl_instReprButtonId_repr___closed__67);
x_143 = x_317;
goto block_149;
}
}
case 21:
{
lean_object* x_318; uint8_t x_319; 
x_318 = lean_unsigned_to_nat(1024u);
x_319 = lean_nat_dec_le(x_318, x_2);
if (x_319 == 0)
{
lean_object* x_320; 
x_320 = lean_obj_once(&lp_padctl_instReprButtonId_repr___closed__66, &lp_padctl_instReprButtonId_repr___closed__66_once, _init_lp_padctl_instReprButtonId_repr___closed__66);
x_150 = x_320;
goto block_156;
}
else
{
lean_object* x_321; 
x_321 = lean_obj_once(&lp_padctl_instReprButtonId_repr___closed__67, &lp_padctl_instReprButtonId_repr___closed__67_once, _init_lp_padctl_instReprButtonId_repr___closed__67);
x_150 = x_321;
goto block_156;
}
}
case 22:
{
lean_object* x_322; uint8_t x_323; 
x_322 = lean_unsigned_to_nat(1024u);
x_323 = lean_nat_dec_le(x_322, x_2);
if (x_323 == 0)
{
lean_object* x_324; 
x_324 = lean_obj_once(&lp_padctl_instReprButtonId_repr___closed__66, &lp_padctl_instReprButtonId_repr___closed__66_once, _init_lp_padctl_instReprButtonId_repr___closed__66);
x_157 = x_324;
goto block_163;
}
else
{
lean_object* x_325; 
x_325 = lean_obj_once(&lp_padctl_instReprButtonId_repr___closed__67, &lp_padctl_instReprButtonId_repr___closed__67_once, _init_lp_padctl_instReprButtonId_repr___closed__67);
x_157 = x_325;
goto block_163;
}
}
case 23:
{
lean_object* x_326; uint8_t x_327; 
x_326 = lean_unsigned_to_nat(1024u);
x_327 = lean_nat_dec_le(x_326, x_2);
if (x_327 == 0)
{
lean_object* x_328; 
x_328 = lean_obj_once(&lp_padctl_instReprButtonId_repr___closed__66, &lp_padctl_instReprButtonId_repr___closed__66_once, _init_lp_padctl_instReprButtonId_repr___closed__66);
x_164 = x_328;
goto block_170;
}
else
{
lean_object* x_329; 
x_329 = lean_obj_once(&lp_padctl_instReprButtonId_repr___closed__67, &lp_padctl_instReprButtonId_repr___closed__67_once, _init_lp_padctl_instReprButtonId_repr___closed__67);
x_164 = x_329;
goto block_170;
}
}
case 24:
{
lean_object* x_330; uint8_t x_331; 
x_330 = lean_unsigned_to_nat(1024u);
x_331 = lean_nat_dec_le(x_330, x_2);
if (x_331 == 0)
{
lean_object* x_332; 
x_332 = lean_obj_once(&lp_padctl_instReprButtonId_repr___closed__66, &lp_padctl_instReprButtonId_repr___closed__66_once, _init_lp_padctl_instReprButtonId_repr___closed__66);
x_171 = x_332;
goto block_177;
}
else
{
lean_object* x_333; 
x_333 = lean_obj_once(&lp_padctl_instReprButtonId_repr___closed__67, &lp_padctl_instReprButtonId_repr___closed__67_once, _init_lp_padctl_instReprButtonId_repr___closed__67);
x_171 = x_333;
goto block_177;
}
}
case 25:
{
lean_object* x_334; uint8_t x_335; 
x_334 = lean_unsigned_to_nat(1024u);
x_335 = lean_nat_dec_le(x_334, x_2);
if (x_335 == 0)
{
lean_object* x_336; 
x_336 = lean_obj_once(&lp_padctl_instReprButtonId_repr___closed__66, &lp_padctl_instReprButtonId_repr___closed__66_once, _init_lp_padctl_instReprButtonId_repr___closed__66);
x_178 = x_336;
goto block_184;
}
else
{
lean_object* x_337; 
x_337 = lean_obj_once(&lp_padctl_instReprButtonId_repr___closed__67, &lp_padctl_instReprButtonId_repr___closed__67_once, _init_lp_padctl_instReprButtonId_repr___closed__67);
x_178 = x_337;
goto block_184;
}
}
case 26:
{
lean_object* x_338; uint8_t x_339; 
x_338 = lean_unsigned_to_nat(1024u);
x_339 = lean_nat_dec_le(x_338, x_2);
if (x_339 == 0)
{
lean_object* x_340; 
x_340 = lean_obj_once(&lp_padctl_instReprButtonId_repr___closed__66, &lp_padctl_instReprButtonId_repr___closed__66_once, _init_lp_padctl_instReprButtonId_repr___closed__66);
x_185 = x_340;
goto block_191;
}
else
{
lean_object* x_341; 
x_341 = lean_obj_once(&lp_padctl_instReprButtonId_repr___closed__67, &lp_padctl_instReprButtonId_repr___closed__67_once, _init_lp_padctl_instReprButtonId_repr___closed__67);
x_185 = x_341;
goto block_191;
}
}
case 27:
{
lean_object* x_342; uint8_t x_343; 
x_342 = lean_unsigned_to_nat(1024u);
x_343 = lean_nat_dec_le(x_342, x_2);
if (x_343 == 0)
{
lean_object* x_344; 
x_344 = lean_obj_once(&lp_padctl_instReprButtonId_repr___closed__66, &lp_padctl_instReprButtonId_repr___closed__66_once, _init_lp_padctl_instReprButtonId_repr___closed__66);
x_192 = x_344;
goto block_198;
}
else
{
lean_object* x_345; 
x_345 = lean_obj_once(&lp_padctl_instReprButtonId_repr___closed__67, &lp_padctl_instReprButtonId_repr___closed__67_once, _init_lp_padctl_instReprButtonId_repr___closed__67);
x_192 = x_345;
goto block_198;
}
}
case 28:
{
lean_object* x_346; uint8_t x_347; 
x_346 = lean_unsigned_to_nat(1024u);
x_347 = lean_nat_dec_le(x_346, x_2);
if (x_347 == 0)
{
lean_object* x_348; 
x_348 = lean_obj_once(&lp_padctl_instReprButtonId_repr___closed__66, &lp_padctl_instReprButtonId_repr___closed__66_once, _init_lp_padctl_instReprButtonId_repr___closed__66);
x_199 = x_348;
goto block_205;
}
else
{
lean_object* x_349; 
x_349 = lean_obj_once(&lp_padctl_instReprButtonId_repr___closed__67, &lp_padctl_instReprButtonId_repr___closed__67_once, _init_lp_padctl_instReprButtonId_repr___closed__67);
x_199 = x_349;
goto block_205;
}
}
case 29:
{
lean_object* x_350; uint8_t x_351; 
x_350 = lean_unsigned_to_nat(1024u);
x_351 = lean_nat_dec_le(x_350, x_2);
if (x_351 == 0)
{
lean_object* x_352; 
x_352 = lean_obj_once(&lp_padctl_instReprButtonId_repr___closed__66, &lp_padctl_instReprButtonId_repr___closed__66_once, _init_lp_padctl_instReprButtonId_repr___closed__66);
x_206 = x_352;
goto block_212;
}
else
{
lean_object* x_353; 
x_353 = lean_obj_once(&lp_padctl_instReprButtonId_repr___closed__67, &lp_padctl_instReprButtonId_repr___closed__67_once, _init_lp_padctl_instReprButtonId_repr___closed__67);
x_206 = x_353;
goto block_212;
}
}
case 30:
{
lean_object* x_354; uint8_t x_355; 
x_354 = lean_unsigned_to_nat(1024u);
x_355 = lean_nat_dec_le(x_354, x_2);
if (x_355 == 0)
{
lean_object* x_356; 
x_356 = lean_obj_once(&lp_padctl_instReprButtonId_repr___closed__66, &lp_padctl_instReprButtonId_repr___closed__66_once, _init_lp_padctl_instReprButtonId_repr___closed__66);
x_213 = x_356;
goto block_219;
}
else
{
lean_object* x_357; 
x_357 = lean_obj_once(&lp_padctl_instReprButtonId_repr___closed__67, &lp_padctl_instReprButtonId_repr___closed__67_once, _init_lp_padctl_instReprButtonId_repr___closed__67);
x_213 = x_357;
goto block_219;
}
}
case 31:
{
lean_object* x_358; uint8_t x_359; 
x_358 = lean_unsigned_to_nat(1024u);
x_359 = lean_nat_dec_le(x_358, x_2);
if (x_359 == 0)
{
lean_object* x_360; 
x_360 = lean_obj_once(&lp_padctl_instReprButtonId_repr___closed__66, &lp_padctl_instReprButtonId_repr___closed__66_once, _init_lp_padctl_instReprButtonId_repr___closed__66);
x_220 = x_360;
goto block_226;
}
else
{
lean_object* x_361; 
x_361 = lean_obj_once(&lp_padctl_instReprButtonId_repr___closed__67, &lp_padctl_instReprButtonId_repr___closed__67_once, _init_lp_padctl_instReprButtonId_repr___closed__67);
x_220 = x_361;
goto block_226;
}
}
default: 
{
lean_object* x_362; uint8_t x_363; 
x_362 = lean_unsigned_to_nat(1024u);
x_363 = lean_nat_dec_le(x_362, x_2);
if (x_363 == 0)
{
lean_object* x_364; 
x_364 = lean_obj_once(&lp_padctl_instReprButtonId_repr___closed__66, &lp_padctl_instReprButtonId_repr___closed__66_once, _init_lp_padctl_instReprButtonId_repr___closed__66);
x_227 = x_364;
goto block_233;
}
else
{
lean_object* x_365; 
x_365 = lean_obj_once(&lp_padctl_instReprButtonId_repr___closed__67, &lp_padctl_instReprButtonId_repr___closed__67_once, _init_lp_padctl_instReprButtonId_repr___closed__67);
x_227 = x_365;
goto block_233;
}
}
}
block_9:
{
lean_object* x_4; lean_object* x_5; uint8_t x_6; lean_object* x_7; lean_object* x_8; 
x_4 = ((lean_object*)(lp_padctl_instReprButtonId_repr___closed__1));
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
x_11 = ((lean_object*)(lp_padctl_instReprButtonId_repr___closed__3));
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
x_18 = ((lean_object*)(lp_padctl_instReprButtonId_repr___closed__5));
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
block_30:
{
lean_object* x_25; lean_object* x_26; uint8_t x_27; lean_object* x_28; lean_object* x_29; 
x_25 = ((lean_object*)(lp_padctl_instReprButtonId_repr___closed__7));
x_26 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_26, 0, x_24);
lean_ctor_set(x_26, 1, x_25);
x_27 = 0;
x_28 = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(x_28, 0, x_26);
lean_ctor_set_uint8(x_28, sizeof(void*)*1, x_27);
x_29 = l_Repr_addAppParen(x_28, x_2);
return x_29;
}
block_37:
{
lean_object* x_32; lean_object* x_33; uint8_t x_34; lean_object* x_35; lean_object* x_36; 
x_32 = ((lean_object*)(lp_padctl_instReprButtonId_repr___closed__9));
x_33 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_33, 0, x_31);
lean_ctor_set(x_33, 1, x_32);
x_34 = 0;
x_35 = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(x_35, 0, x_33);
lean_ctor_set_uint8(x_35, sizeof(void*)*1, x_34);
x_36 = l_Repr_addAppParen(x_35, x_2);
return x_36;
}
block_44:
{
lean_object* x_39; lean_object* x_40; uint8_t x_41; lean_object* x_42; lean_object* x_43; 
x_39 = ((lean_object*)(lp_padctl_instReprButtonId_repr___closed__11));
x_40 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_40, 0, x_38);
lean_ctor_set(x_40, 1, x_39);
x_41 = 0;
x_42 = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(x_42, 0, x_40);
lean_ctor_set_uint8(x_42, sizeof(void*)*1, x_41);
x_43 = l_Repr_addAppParen(x_42, x_2);
return x_43;
}
block_51:
{
lean_object* x_46; lean_object* x_47; uint8_t x_48; lean_object* x_49; lean_object* x_50; 
x_46 = ((lean_object*)(lp_padctl_instReprButtonId_repr___closed__13));
x_47 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_47, 0, x_45);
lean_ctor_set(x_47, 1, x_46);
x_48 = 0;
x_49 = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(x_49, 0, x_47);
lean_ctor_set_uint8(x_49, sizeof(void*)*1, x_48);
x_50 = l_Repr_addAppParen(x_49, x_2);
return x_50;
}
block_58:
{
lean_object* x_53; lean_object* x_54; uint8_t x_55; lean_object* x_56; lean_object* x_57; 
x_53 = ((lean_object*)(lp_padctl_instReprButtonId_repr___closed__15));
x_54 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_54, 0, x_52);
lean_ctor_set(x_54, 1, x_53);
x_55 = 0;
x_56 = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(x_56, 0, x_54);
lean_ctor_set_uint8(x_56, sizeof(void*)*1, x_55);
x_57 = l_Repr_addAppParen(x_56, x_2);
return x_57;
}
block_65:
{
lean_object* x_60; lean_object* x_61; uint8_t x_62; lean_object* x_63; lean_object* x_64; 
x_60 = ((lean_object*)(lp_padctl_instReprButtonId_repr___closed__17));
x_61 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_61, 0, x_59);
lean_ctor_set(x_61, 1, x_60);
x_62 = 0;
x_63 = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(x_63, 0, x_61);
lean_ctor_set_uint8(x_63, sizeof(void*)*1, x_62);
x_64 = l_Repr_addAppParen(x_63, x_2);
return x_64;
}
block_72:
{
lean_object* x_67; lean_object* x_68; uint8_t x_69; lean_object* x_70; lean_object* x_71; 
x_67 = ((lean_object*)(lp_padctl_instReprButtonId_repr___closed__19));
x_68 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_68, 0, x_66);
lean_ctor_set(x_68, 1, x_67);
x_69 = 0;
x_70 = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(x_70, 0, x_68);
lean_ctor_set_uint8(x_70, sizeof(void*)*1, x_69);
x_71 = l_Repr_addAppParen(x_70, x_2);
return x_71;
}
block_79:
{
lean_object* x_74; lean_object* x_75; uint8_t x_76; lean_object* x_77; lean_object* x_78; 
x_74 = ((lean_object*)(lp_padctl_instReprButtonId_repr___closed__21));
x_75 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_75, 0, x_73);
lean_ctor_set(x_75, 1, x_74);
x_76 = 0;
x_77 = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(x_77, 0, x_75);
lean_ctor_set_uint8(x_77, sizeof(void*)*1, x_76);
x_78 = l_Repr_addAppParen(x_77, x_2);
return x_78;
}
block_86:
{
lean_object* x_81; lean_object* x_82; uint8_t x_83; lean_object* x_84; lean_object* x_85; 
x_81 = ((lean_object*)(lp_padctl_instReprButtonId_repr___closed__23));
x_82 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_82, 0, x_80);
lean_ctor_set(x_82, 1, x_81);
x_83 = 0;
x_84 = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(x_84, 0, x_82);
lean_ctor_set_uint8(x_84, sizeof(void*)*1, x_83);
x_85 = l_Repr_addAppParen(x_84, x_2);
return x_85;
}
block_93:
{
lean_object* x_88; lean_object* x_89; uint8_t x_90; lean_object* x_91; lean_object* x_92; 
x_88 = ((lean_object*)(lp_padctl_instReprButtonId_repr___closed__25));
x_89 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_89, 0, x_87);
lean_ctor_set(x_89, 1, x_88);
x_90 = 0;
x_91 = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(x_91, 0, x_89);
lean_ctor_set_uint8(x_91, sizeof(void*)*1, x_90);
x_92 = l_Repr_addAppParen(x_91, x_2);
return x_92;
}
block_100:
{
lean_object* x_95; lean_object* x_96; uint8_t x_97; lean_object* x_98; lean_object* x_99; 
x_95 = ((lean_object*)(lp_padctl_instReprButtonId_repr___closed__27));
x_96 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_96, 0, x_94);
lean_ctor_set(x_96, 1, x_95);
x_97 = 0;
x_98 = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(x_98, 0, x_96);
lean_ctor_set_uint8(x_98, sizeof(void*)*1, x_97);
x_99 = l_Repr_addAppParen(x_98, x_2);
return x_99;
}
block_107:
{
lean_object* x_102; lean_object* x_103; uint8_t x_104; lean_object* x_105; lean_object* x_106; 
x_102 = ((lean_object*)(lp_padctl_instReprButtonId_repr___closed__29));
x_103 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_103, 0, x_101);
lean_ctor_set(x_103, 1, x_102);
x_104 = 0;
x_105 = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(x_105, 0, x_103);
lean_ctor_set_uint8(x_105, sizeof(void*)*1, x_104);
x_106 = l_Repr_addAppParen(x_105, x_2);
return x_106;
}
block_114:
{
lean_object* x_109; lean_object* x_110; uint8_t x_111; lean_object* x_112; lean_object* x_113; 
x_109 = ((lean_object*)(lp_padctl_instReprButtonId_repr___closed__31));
x_110 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_110, 0, x_108);
lean_ctor_set(x_110, 1, x_109);
x_111 = 0;
x_112 = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(x_112, 0, x_110);
lean_ctor_set_uint8(x_112, sizeof(void*)*1, x_111);
x_113 = l_Repr_addAppParen(x_112, x_2);
return x_113;
}
block_121:
{
lean_object* x_116; lean_object* x_117; uint8_t x_118; lean_object* x_119; lean_object* x_120; 
x_116 = ((lean_object*)(lp_padctl_instReprButtonId_repr___closed__33));
x_117 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_117, 0, x_115);
lean_ctor_set(x_117, 1, x_116);
x_118 = 0;
x_119 = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(x_119, 0, x_117);
lean_ctor_set_uint8(x_119, sizeof(void*)*1, x_118);
x_120 = l_Repr_addAppParen(x_119, x_2);
return x_120;
}
block_128:
{
lean_object* x_123; lean_object* x_124; uint8_t x_125; lean_object* x_126; lean_object* x_127; 
x_123 = ((lean_object*)(lp_padctl_instReprButtonId_repr___closed__35));
x_124 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_124, 0, x_122);
lean_ctor_set(x_124, 1, x_123);
x_125 = 0;
x_126 = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(x_126, 0, x_124);
lean_ctor_set_uint8(x_126, sizeof(void*)*1, x_125);
x_127 = l_Repr_addAppParen(x_126, x_2);
return x_127;
}
block_135:
{
lean_object* x_130; lean_object* x_131; uint8_t x_132; lean_object* x_133; lean_object* x_134; 
x_130 = ((lean_object*)(lp_padctl_instReprButtonId_repr___closed__37));
x_131 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_131, 0, x_129);
lean_ctor_set(x_131, 1, x_130);
x_132 = 0;
x_133 = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(x_133, 0, x_131);
lean_ctor_set_uint8(x_133, sizeof(void*)*1, x_132);
x_134 = l_Repr_addAppParen(x_133, x_2);
return x_134;
}
block_142:
{
lean_object* x_137; lean_object* x_138; uint8_t x_139; lean_object* x_140; lean_object* x_141; 
x_137 = ((lean_object*)(lp_padctl_instReprButtonId_repr___closed__39));
x_138 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_138, 0, x_136);
lean_ctor_set(x_138, 1, x_137);
x_139 = 0;
x_140 = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(x_140, 0, x_138);
lean_ctor_set_uint8(x_140, sizeof(void*)*1, x_139);
x_141 = l_Repr_addAppParen(x_140, x_2);
return x_141;
}
block_149:
{
lean_object* x_144; lean_object* x_145; uint8_t x_146; lean_object* x_147; lean_object* x_148; 
x_144 = ((lean_object*)(lp_padctl_instReprButtonId_repr___closed__41));
x_145 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_145, 0, x_143);
lean_ctor_set(x_145, 1, x_144);
x_146 = 0;
x_147 = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(x_147, 0, x_145);
lean_ctor_set_uint8(x_147, sizeof(void*)*1, x_146);
x_148 = l_Repr_addAppParen(x_147, x_2);
return x_148;
}
block_156:
{
lean_object* x_151; lean_object* x_152; uint8_t x_153; lean_object* x_154; lean_object* x_155; 
x_151 = ((lean_object*)(lp_padctl_instReprButtonId_repr___closed__43));
x_152 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_152, 0, x_150);
lean_ctor_set(x_152, 1, x_151);
x_153 = 0;
x_154 = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(x_154, 0, x_152);
lean_ctor_set_uint8(x_154, sizeof(void*)*1, x_153);
x_155 = l_Repr_addAppParen(x_154, x_2);
return x_155;
}
block_163:
{
lean_object* x_158; lean_object* x_159; uint8_t x_160; lean_object* x_161; lean_object* x_162; 
x_158 = ((lean_object*)(lp_padctl_instReprButtonId_repr___closed__45));
x_159 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_159, 0, x_157);
lean_ctor_set(x_159, 1, x_158);
x_160 = 0;
x_161 = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(x_161, 0, x_159);
lean_ctor_set_uint8(x_161, sizeof(void*)*1, x_160);
x_162 = l_Repr_addAppParen(x_161, x_2);
return x_162;
}
block_170:
{
lean_object* x_165; lean_object* x_166; uint8_t x_167; lean_object* x_168; lean_object* x_169; 
x_165 = ((lean_object*)(lp_padctl_instReprButtonId_repr___closed__47));
x_166 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_166, 0, x_164);
lean_ctor_set(x_166, 1, x_165);
x_167 = 0;
x_168 = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(x_168, 0, x_166);
lean_ctor_set_uint8(x_168, sizeof(void*)*1, x_167);
x_169 = l_Repr_addAppParen(x_168, x_2);
return x_169;
}
block_177:
{
lean_object* x_172; lean_object* x_173; uint8_t x_174; lean_object* x_175; lean_object* x_176; 
x_172 = ((lean_object*)(lp_padctl_instReprButtonId_repr___closed__49));
x_173 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_173, 0, x_171);
lean_ctor_set(x_173, 1, x_172);
x_174 = 0;
x_175 = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(x_175, 0, x_173);
lean_ctor_set_uint8(x_175, sizeof(void*)*1, x_174);
x_176 = l_Repr_addAppParen(x_175, x_2);
return x_176;
}
block_184:
{
lean_object* x_179; lean_object* x_180; uint8_t x_181; lean_object* x_182; lean_object* x_183; 
x_179 = ((lean_object*)(lp_padctl_instReprButtonId_repr___closed__51));
x_180 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_180, 0, x_178);
lean_ctor_set(x_180, 1, x_179);
x_181 = 0;
x_182 = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(x_182, 0, x_180);
lean_ctor_set_uint8(x_182, sizeof(void*)*1, x_181);
x_183 = l_Repr_addAppParen(x_182, x_2);
return x_183;
}
block_191:
{
lean_object* x_186; lean_object* x_187; uint8_t x_188; lean_object* x_189; lean_object* x_190; 
x_186 = ((lean_object*)(lp_padctl_instReprButtonId_repr___closed__53));
x_187 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_187, 0, x_185);
lean_ctor_set(x_187, 1, x_186);
x_188 = 0;
x_189 = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(x_189, 0, x_187);
lean_ctor_set_uint8(x_189, sizeof(void*)*1, x_188);
x_190 = l_Repr_addAppParen(x_189, x_2);
return x_190;
}
block_198:
{
lean_object* x_193; lean_object* x_194; uint8_t x_195; lean_object* x_196; lean_object* x_197; 
x_193 = ((lean_object*)(lp_padctl_instReprButtonId_repr___closed__55));
x_194 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_194, 0, x_192);
lean_ctor_set(x_194, 1, x_193);
x_195 = 0;
x_196 = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(x_196, 0, x_194);
lean_ctor_set_uint8(x_196, sizeof(void*)*1, x_195);
x_197 = l_Repr_addAppParen(x_196, x_2);
return x_197;
}
block_205:
{
lean_object* x_200; lean_object* x_201; uint8_t x_202; lean_object* x_203; lean_object* x_204; 
x_200 = ((lean_object*)(lp_padctl_instReprButtonId_repr___closed__57));
x_201 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_201, 0, x_199);
lean_ctor_set(x_201, 1, x_200);
x_202 = 0;
x_203 = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(x_203, 0, x_201);
lean_ctor_set_uint8(x_203, sizeof(void*)*1, x_202);
x_204 = l_Repr_addAppParen(x_203, x_2);
return x_204;
}
block_212:
{
lean_object* x_207; lean_object* x_208; uint8_t x_209; lean_object* x_210; lean_object* x_211; 
x_207 = ((lean_object*)(lp_padctl_instReprButtonId_repr___closed__59));
x_208 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_208, 0, x_206);
lean_ctor_set(x_208, 1, x_207);
x_209 = 0;
x_210 = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(x_210, 0, x_208);
lean_ctor_set_uint8(x_210, sizeof(void*)*1, x_209);
x_211 = l_Repr_addAppParen(x_210, x_2);
return x_211;
}
block_219:
{
lean_object* x_214; lean_object* x_215; uint8_t x_216; lean_object* x_217; lean_object* x_218; 
x_214 = ((lean_object*)(lp_padctl_instReprButtonId_repr___closed__61));
x_215 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_215, 0, x_213);
lean_ctor_set(x_215, 1, x_214);
x_216 = 0;
x_217 = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(x_217, 0, x_215);
lean_ctor_set_uint8(x_217, sizeof(void*)*1, x_216);
x_218 = l_Repr_addAppParen(x_217, x_2);
return x_218;
}
block_226:
{
lean_object* x_221; lean_object* x_222; uint8_t x_223; lean_object* x_224; lean_object* x_225; 
x_221 = ((lean_object*)(lp_padctl_instReprButtonId_repr___closed__63));
x_222 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_222, 0, x_220);
lean_ctor_set(x_222, 1, x_221);
x_223 = 0;
x_224 = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(x_224, 0, x_222);
lean_ctor_set_uint8(x_224, sizeof(void*)*1, x_223);
x_225 = l_Repr_addAppParen(x_224, x_2);
return x_225;
}
block_233:
{
lean_object* x_228; lean_object* x_229; uint8_t x_230; lean_object* x_231; lean_object* x_232; 
x_228 = ((lean_object*)(lp_padctl_instReprButtonId_repr___closed__65));
x_229 = lean_alloc_ctor(4, 2, 0);
lean_ctor_set(x_229, 0, x_227);
lean_ctor_set(x_229, 1, x_228);
x_230 = 0;
x_231 = lean_alloc_ctor(6, 1, 1);
lean_ctor_set(x_231, 0, x_229);
lean_ctor_set_uint8(x_231, sizeof(void*)*1, x_230);
x_232 = l_Repr_addAppParen(x_231, x_2);
return x_232;
}
}
}
LEAN_EXPORT lean_object* lp_padctl_instReprButtonId_repr___boxed(lean_object* x_1, lean_object* x_2) {
_start:
{
uint8_t x_3; lean_object* x_4; 
x_3 = lean_unbox(x_1);
x_4 = lp_padctl_instReprButtonId_repr(x_3, x_2);
lean_dec(x_2);
return x_4;
}
}
LEAN_EXPORT lean_object* lp_padctl_ButtonId_toNat(uint8_t x_1) {
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
case 4:
{
lean_object* x_6; 
x_6 = lean_unsigned_to_nat(4u);
return x_6;
}
case 5:
{
lean_object* x_7; 
x_7 = lean_unsigned_to_nat(5u);
return x_7;
}
case 6:
{
lean_object* x_8; 
x_8 = lean_unsigned_to_nat(6u);
return x_8;
}
case 7:
{
lean_object* x_9; 
x_9 = lean_unsigned_to_nat(7u);
return x_9;
}
case 8:
{
lean_object* x_10; 
x_10 = lean_unsigned_to_nat(8u);
return x_10;
}
case 9:
{
lean_object* x_11; 
x_11 = lean_unsigned_to_nat(9u);
return x_11;
}
case 10:
{
lean_object* x_12; 
x_12 = lean_unsigned_to_nat(10u);
return x_12;
}
case 11:
{
lean_object* x_13; 
x_13 = lean_unsigned_to_nat(11u);
return x_13;
}
case 12:
{
lean_object* x_14; 
x_14 = lean_unsigned_to_nat(12u);
return x_14;
}
case 13:
{
lean_object* x_15; 
x_15 = lean_unsigned_to_nat(13u);
return x_15;
}
case 14:
{
lean_object* x_16; 
x_16 = lean_unsigned_to_nat(14u);
return x_16;
}
case 15:
{
lean_object* x_17; 
x_17 = lean_unsigned_to_nat(15u);
return x_17;
}
case 16:
{
lean_object* x_18; 
x_18 = lean_unsigned_to_nat(16u);
return x_18;
}
case 17:
{
lean_object* x_19; 
x_19 = lean_unsigned_to_nat(17u);
return x_19;
}
case 18:
{
lean_object* x_20; 
x_20 = lean_unsigned_to_nat(18u);
return x_20;
}
case 19:
{
lean_object* x_21; 
x_21 = lean_unsigned_to_nat(19u);
return x_21;
}
case 20:
{
lean_object* x_22; 
x_22 = lean_unsigned_to_nat(20u);
return x_22;
}
case 21:
{
lean_object* x_23; 
x_23 = lean_unsigned_to_nat(21u);
return x_23;
}
case 22:
{
lean_object* x_24; 
x_24 = lean_unsigned_to_nat(22u);
return x_24;
}
case 23:
{
lean_object* x_25; 
x_25 = lean_unsigned_to_nat(23u);
return x_25;
}
case 24:
{
lean_object* x_26; 
x_26 = lean_unsigned_to_nat(24u);
return x_26;
}
case 25:
{
lean_object* x_27; 
x_27 = lean_unsigned_to_nat(25u);
return x_27;
}
case 26:
{
lean_object* x_28; 
x_28 = lean_unsigned_to_nat(26u);
return x_28;
}
case 27:
{
lean_object* x_29; 
x_29 = lean_unsigned_to_nat(27u);
return x_29;
}
case 28:
{
lean_object* x_30; 
x_30 = lean_unsigned_to_nat(28u);
return x_30;
}
case 29:
{
lean_object* x_31; 
x_31 = lean_unsigned_to_nat(29u);
return x_31;
}
case 30:
{
lean_object* x_32; 
x_32 = lean_unsigned_to_nat(30u);
return x_32;
}
case 31:
{
lean_object* x_33; 
x_33 = lean_unsigned_to_nat(31u);
return x_33;
}
default: 
{
lean_object* x_34; 
x_34 = lean_unsigned_to_nat(32u);
return x_34;
}
}
}
}
LEAN_EXPORT lean_object* lp_padctl_ButtonId_toNat___boxed(lean_object* x_1) {
_start:
{
uint8_t x_2; lean_object* x_3; 
x_2 = lean_unbox(x_1);
x_3 = lp_padctl_ButtonId_toNat(x_2);
return x_3;
}
}
static lean_object* _init_lp_padctl_dpadUpBit___closed__0(void) {
_start:
{
uint8_t x_1; lean_object* x_2; 
x_1 = 14;
x_2 = lp_padctl_ButtonId_toNat(x_1);
return x_2;
}
}
static lean_object* _init_lp_padctl_dpadUpBit(void) {
_start:
{
lean_object* x_1; 
x_1 = lean_obj_once(&lp_padctl_dpadUpBit___closed__0, &lp_padctl_dpadUpBit___closed__0_once, _init_lp_padctl_dpadUpBit___closed__0);
return x_1;
}
}
static lean_object* _init_lp_padctl_dpadDownBit___closed__0(void) {
_start:
{
uint8_t x_1; lean_object* x_2; 
x_1 = 15;
x_2 = lp_padctl_ButtonId_toNat(x_1);
return x_2;
}
}
static lean_object* _init_lp_padctl_dpadDownBit(void) {
_start:
{
lean_object* x_1; 
x_1 = lean_obj_once(&lp_padctl_dpadDownBit___closed__0, &lp_padctl_dpadDownBit___closed__0_once, _init_lp_padctl_dpadDownBit___closed__0);
return x_1;
}
}
static lean_object* _init_lp_padctl_dpadLeftBit___closed__0(void) {
_start:
{
uint8_t x_1; lean_object* x_2; 
x_1 = 16;
x_2 = lp_padctl_ButtonId_toNat(x_1);
return x_2;
}
}
static lean_object* _init_lp_padctl_dpadLeftBit(void) {
_start:
{
lean_object* x_1; 
x_1 = lean_obj_once(&lp_padctl_dpadLeftBit___closed__0, &lp_padctl_dpadLeftBit___closed__0_once, _init_lp_padctl_dpadLeftBit___closed__0);
return x_1;
}
}
static lean_object* _init_lp_padctl_dpadRightBit___closed__0(void) {
_start:
{
uint8_t x_1; lean_object* x_2; 
x_1 = 17;
x_2 = lp_padctl_ButtonId_toNat(x_1);
return x_2;
}
}
static lean_object* _init_lp_padctl_dpadRightBit(void) {
_start:
{
lean_object* x_1; 
x_1 = lean_obj_once(&lp_padctl_dpadRightBit___closed__0, &lp_padctl_dpadRightBit___closed__0_once, _init_lp_padctl_dpadRightBit___closed__0);
return x_1;
}
}
LEAN_EXPORT uint8_t lp_padctl_testBit(lean_object* x_1, lean_object* x_2) {
_start:
{
lean_object* x_3; lean_object* x_4; lean_object* x_5; lean_object* x_6; lean_object* x_7; uint8_t x_8; 
x_3 = lean_unsigned_to_nat(2u);
x_4 = lean_nat_pow(x_3, x_2);
x_5 = lean_nat_div(x_1, x_4);
lean_dec(x_4);
x_6 = lean_nat_mod(x_5, x_3);
lean_dec(x_5);
x_7 = lean_unsigned_to_nat(1u);
x_8 = lean_nat_dec_eq(x_6, x_7);
lean_dec(x_6);
return x_8;
}
}
LEAN_EXPORT lean_object* lp_padctl_testBit___boxed(lean_object* x_1, lean_object* x_2) {
_start:
{
uint8_t x_3; lean_object* x_4; 
x_3 = lp_padctl_testBit(x_1, x_2);
lean_dec(x_2);
lean_dec(x_1);
x_4 = lean_box(x_3);
return x_4;
}
}
LEAN_EXPORT lean_object* lp_padctl_synthesizeDpadAxes(lean_object* x_1) {
_start:
{
lean_object* x_2; lean_object* x_3; lean_object* x_4; lean_object* x_8; uint8_t x_9; lean_object* x_10; uint8_t x_11; lean_object* x_12; uint8_t x_13; lean_object* x_14; uint8_t x_15; lean_object* x_16; lean_object* x_17; lean_object* x_21; lean_object* x_22; lean_object* x_27; 
x_8 = lp_padctl_dpadRightBit;
x_9 = lp_padctl_testBit(x_1, x_8);
x_10 = lp_padctl_dpadLeftBit;
x_11 = lp_padctl_testBit(x_1, x_10);
x_12 = lp_padctl_dpadDownBit;
x_13 = lp_padctl_testBit(x_1, x_12);
x_14 = lp_padctl_dpadUpBit;
x_15 = lp_padctl_testBit(x_1, x_14);
if (x_9 == 0)
{
lean_object* x_31; 
x_31 = lean_obj_once(&lp_padctl_instReprGamepadState_repr___redArg___closed__20, &lp_padctl_instReprGamepadState_repr___redArg___closed__20_once, _init_lp_padctl_instReprGamepadState_repr___redArg___closed__20);
x_27 = x_31;
goto block_30;
}
else
{
lean_object* x_32; 
x_32 = lean_obj_once(&lp_padctl_instReprButtonId_repr___closed__67, &lp_padctl_instReprButtonId_repr___closed__67_once, _init_lp_padctl_instReprButtonId_repr___closed__67);
x_27 = x_32;
goto block_30;
}
block_7:
{
lean_object* x_5; lean_object* x_6; 
x_5 = lean_int_sub(x_2, x_4);
lean_dec(x_4);
lean_dec(x_2);
x_6 = lean_alloc_ctor(0, 2, 0);
lean_ctor_set(x_6, 0, x_3);
lean_ctor_set(x_6, 1, x_5);
return x_6;
}
block_20:
{
if (x_15 == 0)
{
lean_object* x_18; 
x_18 = lean_obj_once(&lp_padctl_instReprGamepadState_repr___redArg___closed__20, &lp_padctl_instReprGamepadState_repr___redArg___closed__20_once, _init_lp_padctl_instReprGamepadState_repr___redArg___closed__20);
x_2 = x_17;
x_3 = x_16;
x_4 = x_18;
goto block_7;
}
else
{
lean_object* x_19; 
x_19 = lean_obj_once(&lp_padctl_instReprButtonId_repr___closed__67, &lp_padctl_instReprButtonId_repr___closed__67_once, _init_lp_padctl_instReprButtonId_repr___closed__67);
x_2 = x_17;
x_3 = x_16;
x_4 = x_19;
goto block_7;
}
}
block_26:
{
lean_object* x_23; 
x_23 = lean_int_sub(x_21, x_22);
lean_dec(x_22);
lean_dec(x_21);
if (x_13 == 0)
{
lean_object* x_24; 
x_24 = lean_obj_once(&lp_padctl_instReprGamepadState_repr___redArg___closed__20, &lp_padctl_instReprGamepadState_repr___redArg___closed__20_once, _init_lp_padctl_instReprGamepadState_repr___redArg___closed__20);
x_16 = x_23;
x_17 = x_24;
goto block_20;
}
else
{
lean_object* x_25; 
x_25 = lean_obj_once(&lp_padctl_instReprButtonId_repr___closed__67, &lp_padctl_instReprButtonId_repr___closed__67_once, _init_lp_padctl_instReprButtonId_repr___closed__67);
x_16 = x_23;
x_17 = x_25;
goto block_20;
}
}
block_30:
{
if (x_11 == 0)
{
lean_object* x_28; 
x_28 = lean_obj_once(&lp_padctl_instReprGamepadState_repr___redArg___closed__20, &lp_padctl_instReprGamepadState_repr___redArg___closed__20_once, _init_lp_padctl_instReprGamepadState_repr___redArg___closed__20);
x_21 = x_27;
x_22 = x_28;
goto block_26;
}
else
{
lean_object* x_29; 
x_29 = lean_obj_once(&lp_padctl_instReprButtonId_repr___closed__67, &lp_padctl_instReprButtonId_repr___closed__67_once, _init_lp_padctl_instReprButtonId_repr___closed__67);
x_21 = x_27;
x_22 = x_29;
goto block_26;
}
}
}
}
LEAN_EXPORT lean_object* lp_padctl_synthesizeDpadAxes___boxed(lean_object* x_1) {
_start:
{
lean_object* x_2; 
x_2 = lp_padctl_synthesizeDpadAxes(x_1);
lean_dec(x_1);
return x_2;
}
}
lean_object* initialize_Init(uint8_t builtin);
lean_object* initialize_padctl_Padctl_Types(uint8_t builtin);
static bool _G_initialized = false;
LEAN_EXPORT lean_object* initialize_padctl_Padctl_State(uint8_t builtin) {
lean_object * res;
if (_G_initialized) return lean_io_result_mk_ok(lean_box(0));
_G_initialized = true;
res = initialize_Init(builtin);
if (lean_io_result_is_error(res)) return res;
lean_dec_ref(res);
res = initialize_padctl_Padctl_Types(builtin);
if (lean_io_result_is_error(res)) return res;
lean_dec_ref(res);
lp_padctl_dpadUpBit = _init_lp_padctl_dpadUpBit();
lean_mark_persistent(lp_padctl_dpadUpBit);
lp_padctl_dpadDownBit = _init_lp_padctl_dpadDownBit();
lean_mark_persistent(lp_padctl_dpadDownBit);
lp_padctl_dpadLeftBit = _init_lp_padctl_dpadLeftBit();
lean_mark_persistent(lp_padctl_dpadLeftBit);
lp_padctl_dpadRightBit = _init_lp_padctl_dpadRightBit();
lean_mark_persistent(lp_padctl_dpadRightBit);
return lean_io_result_mk_ok(lean_box(0));
}
#ifdef __cplusplus
}
#endif
