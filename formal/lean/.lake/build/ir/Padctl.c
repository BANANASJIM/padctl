// Lean compiler output
// Module: Padctl
// Imports: public import Init public import Padctl.Types public import Padctl.Transform public import Padctl.Interpreter public import Padctl.State public import Padctl.Mapper public import Padctl.Properties
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
lean_object* initialize_Init(uint8_t builtin);
lean_object* initialize_padctl_Padctl_Types(uint8_t builtin);
lean_object* initialize_padctl_Padctl_Transform(uint8_t builtin);
lean_object* initialize_padctl_Padctl_Interpreter(uint8_t builtin);
lean_object* initialize_padctl_Padctl_State(uint8_t builtin);
lean_object* initialize_padctl_Padctl_Mapper(uint8_t builtin);
lean_object* initialize_padctl_Padctl_Properties(uint8_t builtin);
static bool _G_initialized = false;
LEAN_EXPORT lean_object* initialize_padctl_Padctl(uint8_t builtin) {
lean_object * res;
if (_G_initialized) return lean_io_result_mk_ok(lean_box(0));
_G_initialized = true;
res = initialize_Init(builtin);
if (lean_io_result_is_error(res)) return res;
lean_dec_ref(res);
res = initialize_padctl_Padctl_Types(builtin);
if (lean_io_result_is_error(res)) return res;
lean_dec_ref(res);
res = initialize_padctl_Padctl_Transform(builtin);
if (lean_io_result_is_error(res)) return res;
lean_dec_ref(res);
res = initialize_padctl_Padctl_Interpreter(builtin);
if (lean_io_result_is_error(res)) return res;
lean_dec_ref(res);
res = initialize_padctl_Padctl_State(builtin);
if (lean_io_result_is_error(res)) return res;
lean_dec_ref(res);
res = initialize_padctl_Padctl_Mapper(builtin);
if (lean_io_result_is_error(res)) return res;
lean_dec_ref(res);
res = initialize_padctl_Padctl_Properties(builtin);
if (lean_io_result_is_error(res)) return res;
lean_dec_ref(res);
return lean_io_result_mk_ok(lean_box(0));
}
#ifdef __cplusplus
}
#endif
