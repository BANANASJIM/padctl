// Lean compiler output
// Module: Padctl.Transform
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
lean_object* lean_nat_to_int(lean_object*);
static lean_once_cell_t lp_padctl_applyTransform___closed__0_once = LEAN_ONCE_CELL_INITIALIZER;
static lean_object* lp_padctl_applyTransform___closed__0;
lean_object* lean_int_neg_succ_of_nat(lean_object*);
uint8_t lean_int_dec_eq(lean_object*, lean_object*);
lean_object* lean_int_neg(lean_object*);
lean_object* lean_nat_abs(lean_object*);
uint8_t lean_nat_dec_eq(lean_object*, lean_object*);
lean_object* lean_int_sub(lean_object*, lean_object*);
lean_object* lean_int_mul(lean_object*, lean_object*);
lean_object* lean_int_div(lean_object*, lean_object*);
lean_object* lean_int_add(lean_object*, lean_object*);
uint8_t lean_int_dec_le(lean_object*, lean_object*);
uint8_t lean_nat_dec_lt(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_applyTransform(lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_applyTransform___boxed(lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_List_foldl___at___00runTransformChain_spec__0(lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_List_foldl___at___00runTransformChain_spec__0___boxed(lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_runTransformChain(lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_runTransformChain___boxed(lean_object*, lean_object*, lean_object*);
static lean_object* _init_lp_padctl_applyTransform___closed__0(void) {
_start:
{
lean_object* x_1; lean_object* x_2; 
x_1 = lean_unsigned_to_nat(0u);
x_2 = lean_nat_to_int(x_1);
return x_2;
}
}
LEAN_EXPORT lean_object* lp_padctl_applyTransform(lean_object* x_1, lean_object* x_2, lean_object* x_3) {
_start:
{
switch (lean_obj_tag(x_1)) {
case 0:
{
lean_object* x_4; uint8_t x_5; 
lean_inc(x_3);
x_4 = lean_int_neg_succ_of_nat(x_3);
x_5 = lean_int_dec_eq(x_2, x_4);
lean_dec(x_4);
if (x_5 == 0)
{
lean_object* x_6; 
lean_dec(x_3);
x_6 = lean_int_neg(x_2);
return x_6;
}
else
{
lean_object* x_7; 
x_7 = lean_nat_to_int(x_3);
return x_7;
}
}
case 1:
{
lean_object* x_8; uint8_t x_9; 
lean_inc(x_3);
x_8 = lean_int_neg_succ_of_nat(x_3);
x_9 = lean_int_dec_eq(x_2, x_8);
lean_dec(x_8);
if (x_9 == 0)
{
lean_object* x_10; lean_object* x_11; 
lean_dec(x_3);
x_10 = lean_nat_abs(x_2);
x_11 = lean_nat_to_int(x_10);
return x_11;
}
else
{
lean_object* x_12; 
x_12 = lean_nat_to_int(x_3);
return x_12;
}
}
case 2:
{
lean_object* x_13; lean_object* x_14; lean_object* x_15; uint8_t x_16; 
x_13 = lean_ctor_get(x_1, 0);
x_14 = lean_ctor_get(x_1, 1);
x_15 = lean_unsigned_to_nat(0u);
x_16 = lean_nat_dec_eq(x_3, x_15);
if (x_16 == 0)
{
lean_object* x_17; lean_object* x_18; lean_object* x_19; lean_object* x_20; lean_object* x_21; 
x_17 = lean_int_sub(x_14, x_13);
x_18 = lean_int_mul(x_2, x_17);
lean_dec(x_17);
x_19 = lean_nat_to_int(x_3);
x_20 = lean_int_div(x_18, x_19);
lean_dec(x_19);
lean_dec(x_18);
x_21 = lean_int_add(x_20, x_13);
lean_dec(x_20);
return x_21;
}
else
{
lean_dec(x_3);
lean_inc(x_2);
return x_2;
}
}
case 3:
{
lean_object* x_22; lean_object* x_23; lean_object* x_24; uint8_t x_27; 
lean_dec(x_3);
x_22 = lean_ctor_get(x_1, 0);
x_23 = lean_ctor_get(x_1, 1);
x_27 = lean_int_dec_le(x_23, x_2);
if (x_27 == 0)
{
x_24 = x_2;
goto block_26;
}
else
{
x_24 = x_23;
goto block_26;
}
block_26:
{
uint8_t x_25; 
x_25 = lean_int_dec_le(x_22, x_24);
if (x_25 == 0)
{
lean_inc(x_22);
return x_22;
}
else
{
lean_inc(x_24);
return x_24;
}
}
}
default: 
{
lean_object* x_28; lean_object* x_29; uint8_t x_30; 
lean_dec(x_3);
x_28 = lean_ctor_get(x_1, 0);
x_29 = lean_nat_abs(x_2);
x_30 = lean_nat_dec_lt(x_29, x_28);
lean_dec(x_29);
if (x_30 == 0)
{
lean_inc(x_2);
return x_2;
}
else
{
lean_object* x_31; 
x_31 = lean_obj_once(&lp_padctl_applyTransform___closed__0, &lp_padctl_applyTransform___closed__0_once, _init_lp_padctl_applyTransform___closed__0);
return x_31;
}
}
}
}
}
LEAN_EXPORT lean_object* lp_padctl_applyTransform___boxed(lean_object* x_1, lean_object* x_2, lean_object* x_3) {
_start:
{
lean_object* x_4; 
x_4 = lp_padctl_applyTransform(x_1, x_2, x_3);
lean_dec(x_2);
lean_dec(x_1);
return x_4;
}
}
LEAN_EXPORT lean_object* lp_padctl_List_foldl___at___00runTransformChain_spec__0(lean_object* x_1, lean_object* x_2, lean_object* x_3) {
_start:
{
if (lean_obj_tag(x_3) == 0)
{
lean_dec(x_1);
return x_2;
}
else
{
lean_object* x_4; lean_object* x_5; lean_object* x_6; 
x_4 = lean_ctor_get(x_3, 0);
x_5 = lean_ctor_get(x_3, 1);
lean_inc(x_1);
x_6 = lp_padctl_applyTransform(x_4, x_2, x_1);
lean_dec(x_2);
x_2 = x_6;
x_3 = x_5;
goto _start;
}
}
}
LEAN_EXPORT lean_object* lp_padctl_List_foldl___at___00runTransformChain_spec__0___boxed(lean_object* x_1, lean_object* x_2, lean_object* x_3) {
_start:
{
lean_object* x_4; 
x_4 = lp_padctl_List_foldl___at___00runTransformChain_spec__0(x_1, x_2, x_3);
lean_dec(x_3);
return x_4;
}
}
LEAN_EXPORT lean_object* lp_padctl_runTransformChain(lean_object* x_1, lean_object* x_2, lean_object* x_3) {
_start:
{
lean_object* x_4; 
x_4 = lp_padctl_List_foldl___at___00runTransformChain_spec__0(x_3, x_1, x_2);
return x_4;
}
}
LEAN_EXPORT lean_object* lp_padctl_runTransformChain___boxed(lean_object* x_1, lean_object* x_2, lean_object* x_3) {
_start:
{
lean_object* x_4; 
x_4 = lp_padctl_runTransformChain(x_1, x_2, x_3);
lean_dec(x_2);
return x_4;
}
}
lean_object* initialize_Init(uint8_t builtin);
lean_object* initialize_padctl_Padctl_Types(uint8_t builtin);
static bool _G_initialized = false;
LEAN_EXPORT lean_object* initialize_padctl_Padctl_Transform(uint8_t builtin) {
lean_object * res;
if (_G_initialized) return lean_io_result_mk_ok(lean_box(0));
_G_initialized = true;
res = initialize_Init(builtin);
if (lean_io_result_is_error(res)) return res;
lean_dec_ref(res);
res = initialize_padctl_Padctl_Types(builtin);
if (lean_io_result_is_error(res)) return res;
lean_dec_ref(res);
return lean_io_result_mk_ok(lean_box(0));
}
#ifdef __cplusplus
}
#endif
