// Lean compiler output
// Module: Padctl.Interpreter
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
lean_object* lean_uint8_to_nat(uint8_t);
lean_object* lean_byte_array_size(lean_object*);
uint8_t lean_nat_dec_lt(lean_object*, lean_object*);
extern uint8_t l_instInhabitedUInt8;
lean_object* l_outOfBounds___redArg(lean_object*);
uint8_t lean_byte_array_fget(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_readU8(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_readU8___boxed(lean_object*, lean_object*);
LEAN_EXPORT uint8_t lp_padctl_readU16le___lam__0(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_readU16le___lam__0___boxed(lean_object*, lean_object*);
lean_object* lean_nat_mul(lean_object*, lean_object*);
lean_object* lean_nat_add(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_readU16le(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_readU16le___boxed(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_readU16be(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_readU16be___boxed(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_readU32le(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_readU32le___boxed(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_readU32be(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_readU32be___boxed(lean_object*, lean_object*);
lean_object* lean_nat_to_int(lean_object*);
static lean_once_cell_t lp_padctl_toSigned___closed__0_once = LEAN_ONCE_CELL_INITIALIZER;
static lean_object* lp_padctl_toSigned___closed__0;
uint8_t lean_nat_dec_eq(lean_object*, lean_object*);
lean_object* lean_nat_sub(lean_object*, lean_object*);
lean_object* lean_nat_pow(lean_object*, lean_object*);
lean_object* lean_int_sub(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_toSigned(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_toSigned___boxed(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_readField(lean_object*, lean_object*, uint8_t);
LEAN_EXPORT lean_object* lp_padctl_readField___boxed(lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_List_foldl___at___00extractBits_spec__0(lean_object*, lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_List_foldl___at___00extractBits_spec__0___boxed(lean_object*, lean_object*, lean_object*, lean_object*);
lean_object* lean_nat_shiftr(lean_object*, lean_object*);
lean_object* l_List_range(lean_object*);
lean_object* lean_nat_div(lean_object*, lean_object*);
lean_object* lean_nat_mod(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_extractBits(lean_object*, lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_extractBits___boxed(lean_object*, lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_signExtend(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_signExtend___boxed(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_ChecksumAlgo_ctorIdx(uint8_t);
LEAN_EXPORT lean_object* lp_padctl_ChecksumAlgo_ctorIdx___boxed(lean_object*);
LEAN_EXPORT lean_object* lp_padctl_ChecksumAlgo_toCtorIdx(uint8_t);
LEAN_EXPORT lean_object* lp_padctl_ChecksumAlgo_toCtorIdx___boxed(lean_object*);
LEAN_EXPORT lean_object* lp_padctl_ChecksumAlgo_ctorElim___redArg(lean_object*);
LEAN_EXPORT lean_object* lp_padctl_ChecksumAlgo_ctorElim___redArg___boxed(lean_object*);
LEAN_EXPORT lean_object* lp_padctl_ChecksumAlgo_ctorElim(lean_object*, lean_object*, uint8_t, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_ChecksumAlgo_ctorElim___boxed(lean_object*, lean_object*, lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_ChecksumAlgo_sum8_elim___redArg(lean_object*);
LEAN_EXPORT lean_object* lp_padctl_ChecksumAlgo_sum8_elim___redArg___boxed(lean_object*);
LEAN_EXPORT lean_object* lp_padctl_ChecksumAlgo_sum8_elim(lean_object*, uint8_t, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_ChecksumAlgo_sum8_elim___boxed(lean_object*, lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_ChecksumAlgo_xor_elim___redArg(lean_object*);
LEAN_EXPORT lean_object* lp_padctl_ChecksumAlgo_xor_elim___redArg___boxed(lean_object*);
LEAN_EXPORT lean_object* lp_padctl_ChecksumAlgo_xor_elim(lean_object*, uint8_t, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_ChecksumAlgo_xor_elim___boxed(lean_object*, lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_ChecksumAlgo_crc32_elim___redArg(lean_object*);
LEAN_EXPORT lean_object* lp_padctl_ChecksumAlgo_crc32_elim___redArg___boxed(lean_object*);
LEAN_EXPORT lean_object* lp_padctl_ChecksumAlgo_crc32_elim(lean_object*, uint8_t, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_ChecksumAlgo_crc32_elim___boxed(lean_object*, lean_object*, lean_object*, lean_object*);
uint8_t lean_nat_dec_le(lean_object*, lean_object*);
LEAN_EXPORT uint8_t lp_padctl_ChecksumAlgo_ofNat(lean_object*);
LEAN_EXPORT lean_object* lp_padctl_ChecksumAlgo_ofNat___boxed(lean_object*);
LEAN_EXPORT uint8_t lp_padctl_instDecidableEqChecksumAlgo(uint8_t, uint8_t);
LEAN_EXPORT lean_object* lp_padctl_instDecidableEqChecksumAlgo___boxed(lean_object*, lean_object*);
static const lean_string_object lp_padctl_instReprChecksumAlgo_repr___closed__0_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 18, .m_capacity = 18, .m_length = 17, .m_data = "ChecksumAlgo.sum8"};
static const lean_object* lp_padctl_instReprChecksumAlgo_repr___closed__0 = (const lean_object*)&lp_padctl_instReprChecksumAlgo_repr___closed__0_value;
static const lean_ctor_object lp_padctl_instReprChecksumAlgo_repr___closed__1_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*1 + 0, .m_other = 1, .m_tag = 3}, .m_objs = {((lean_object*)&lp_padctl_instReprChecksumAlgo_repr___closed__0_value)}};
static const lean_object* lp_padctl_instReprChecksumAlgo_repr___closed__1 = (const lean_object*)&lp_padctl_instReprChecksumAlgo_repr___closed__1_value;
static const lean_string_object lp_padctl_instReprChecksumAlgo_repr___closed__2_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 17, .m_capacity = 17, .m_length = 16, .m_data = "ChecksumAlgo.xor"};
static const lean_object* lp_padctl_instReprChecksumAlgo_repr___closed__2 = (const lean_object*)&lp_padctl_instReprChecksumAlgo_repr___closed__2_value;
static const lean_ctor_object lp_padctl_instReprChecksumAlgo_repr___closed__3_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*1 + 0, .m_other = 1, .m_tag = 3}, .m_objs = {((lean_object*)&lp_padctl_instReprChecksumAlgo_repr___closed__2_value)}};
static const lean_object* lp_padctl_instReprChecksumAlgo_repr___closed__3 = (const lean_object*)&lp_padctl_instReprChecksumAlgo_repr___closed__3_value;
static const lean_string_object lp_padctl_instReprChecksumAlgo_repr___closed__4_value = {.m_header = {.m_rc = 0, .m_cs_sz = 0, .m_other = 0, .m_tag = 249}, .m_size = 19, .m_capacity = 19, .m_length = 18, .m_data = "ChecksumAlgo.crc32"};
static const lean_object* lp_padctl_instReprChecksumAlgo_repr___closed__4 = (const lean_object*)&lp_padctl_instReprChecksumAlgo_repr___closed__4_value;
static const lean_ctor_object lp_padctl_instReprChecksumAlgo_repr___closed__5_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_ctor_object) + sizeof(void*)*1 + 0, .m_other = 1, .m_tag = 3}, .m_objs = {((lean_object*)&lp_padctl_instReprChecksumAlgo_repr___closed__4_value)}};
static const lean_object* lp_padctl_instReprChecksumAlgo_repr___closed__5 = (const lean_object*)&lp_padctl_instReprChecksumAlgo_repr___closed__5_value;
static lean_once_cell_t lp_padctl_instReprChecksumAlgo_repr___closed__6_once = LEAN_ONCE_CELL_INITIALIZER;
static lean_object* lp_padctl_instReprChecksumAlgo_repr___closed__6;
static lean_once_cell_t lp_padctl_instReprChecksumAlgo_repr___closed__7_once = LEAN_ONCE_CELL_INITIALIZER;
static lean_object* lp_padctl_instReprChecksumAlgo_repr___closed__7;
lean_object* l_Repr_addAppParen(lean_object*, lean_object*);
uint8_t lean_nat_dec_le(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_instReprChecksumAlgo_repr(uint8_t, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_instReprChecksumAlgo_repr___boxed(lean_object*, lean_object*);
static const lean_closure_object lp_padctl_instReprChecksumAlgo___closed__0_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_closure_object) + sizeof(void*)*0, .m_other = 0, .m_tag = 245}, .m_fun = (void*)lp_padctl_instReprChecksumAlgo_repr___boxed, .m_arity = 2, .m_num_fixed = 0, .m_objs = {} };
static const lean_object* lp_padctl_instReprChecksumAlgo___closed__0 = (const lean_object*)&lp_padctl_instReprChecksumAlgo___closed__0_value;
LEAN_EXPORT const lean_object* lp_padctl_instReprChecksumAlgo = (const lean_object*)&lp_padctl_instReprChecksumAlgo___closed__0_value;
LEAN_EXPORT lean_object* lp_padctl_List_foldl___at___00checksumSum8_spec__0(lean_object*, lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_List_foldl___at___00checksumSum8_spec__0___boxed(lean_object*, lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_checksumSum8(lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_checksumSum8___boxed(lean_object*, lean_object*, lean_object*);
lean_object* lean_nat_lxor(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_List_foldl___at___00checksumXor_spec__0(lean_object*, lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_List_foldl___at___00checksumXor_spec__0___boxed(lean_object*, lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_checksumXor(lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_checksumXor___boxed(lean_object*, lean_object*, lean_object*);
uint32_t lean_uint32_land(uint32_t, uint32_t);
uint8_t lean_uint32_dec_eq(uint32_t, uint32_t);
uint32_t lean_uint32_shift_right(uint32_t, uint32_t);
uint32_t lean_uint32_xor(uint32_t, uint32_t);
LEAN_EXPORT uint32_t lp_padctl___private_Padctl_Interpreter_0__crc32Byte___lam__0(uint32_t);
LEAN_EXPORT lean_object* lp_padctl___private_Padctl_Interpreter_0__crc32Byte___lam__0___boxed(lean_object*);
uint32_t lean_uint8_to_uint32(uint8_t);
LEAN_EXPORT uint32_t lp_padctl___private_Padctl_Interpreter_0__crc32Byte(uint32_t, uint8_t);
LEAN_EXPORT lean_object* lp_padctl___private_Padctl_Interpreter_0__crc32Byte___boxed(lean_object*, lean_object*);
LEAN_EXPORT uint32_t lp_padctl_List_foldl___at___00crc32_spec__0(lean_object*, lean_object*, uint32_t, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_List_foldl___at___00crc32_spec__0___boxed(lean_object*, lean_object*, lean_object*, lean_object*);
LEAN_EXPORT uint32_t lp_padctl_crc32(lean_object*, lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_crc32___boxed(lean_object*, lean_object*, lean_object*, lean_object*);
lean_object* lean_uint32_to_nat(uint32_t);
LEAN_EXPORT uint8_t lp_padctl_verifyChecksum(lean_object*, uint8_t, lean_object*, lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_verifyChecksum___boxed(lean_object*, lean_object*, lean_object*, lean_object*, lean_object*, lean_object*);
uint8_t lean_uint8_dec_eq(uint8_t, uint8_t);
LEAN_EXPORT uint8_t lp_padctl_checkMatch___lam__1(lean_object*, lean_object*, lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_checkMatch___lam__1___boxed(lean_object*, lean_object*, lean_object*, lean_object*, lean_object*);
static const lean_closure_object lp_padctl_checkMatch___closed__0_value = {.m_header = {.m_rc = 0, .m_cs_sz = sizeof(lean_closure_object) + sizeof(void*)*0, .m_other = 0, .m_tag = 245}, .m_fun = (void*)lp_padctl_readU16le___lam__0___boxed, .m_arity = 2, .m_num_fixed = 0, .m_objs = {} };
static const lean_object* lp_padctl_checkMatch___closed__0 = (const lean_object*)&lp_padctl_checkMatch___closed__0_value;
uint8_t l_List_all___redArg(lean_object*, lean_object*);
LEAN_EXPORT uint8_t lp_padctl_checkMatch(lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_checkMatch___boxed(lean_object*, lean_object*, lean_object*);
static lean_once_cell_t lp_padctl_decodeDpadHat___closed__0_once = LEAN_ONCE_CELL_INITIALIZER;
static lean_object* lp_padctl_decodeDpadHat___closed__0;
lean_object* lean_int_neg(lean_object*);
static lean_once_cell_t lp_padctl_decodeDpadHat___closed__1_once = LEAN_ONCE_CELL_INITIALIZER;
static lean_object* lp_padctl_decodeDpadHat___closed__1;
static lean_once_cell_t lp_padctl_decodeDpadHat___closed__2_once = LEAN_ONCE_CELL_INITIALIZER;
static lean_object* lp_padctl_decodeDpadHat___closed__2;
static lean_once_cell_t lp_padctl_decodeDpadHat___closed__3_once = LEAN_ONCE_CELL_INITIALIZER;
static lean_object* lp_padctl_decodeDpadHat___closed__3;
static lean_once_cell_t lp_padctl_decodeDpadHat___closed__4_once = LEAN_ONCE_CELL_INITIALIZER;
static lean_object* lp_padctl_decodeDpadHat___closed__4;
static lean_once_cell_t lp_padctl_decodeDpadHat___closed__5_once = LEAN_ONCE_CELL_INITIALIZER;
static lean_object* lp_padctl_decodeDpadHat___closed__5;
static lean_once_cell_t lp_padctl_decodeDpadHat___closed__6_once = LEAN_ONCE_CELL_INITIALIZER;
static lean_object* lp_padctl_decodeDpadHat___closed__6;
static lean_once_cell_t lp_padctl_decodeDpadHat___closed__7_once = LEAN_ONCE_CELL_INITIALIZER;
static lean_object* lp_padctl_decodeDpadHat___closed__7;
static lean_once_cell_t lp_padctl_decodeDpadHat___closed__8_once = LEAN_ONCE_CELL_INITIALIZER;
static lean_object* lp_padctl_decodeDpadHat___closed__8;
static lean_once_cell_t lp_padctl_decodeDpadHat___closed__9_once = LEAN_ONCE_CELL_INITIALIZER;
static lean_object* lp_padctl_decodeDpadHat___closed__9;
LEAN_EXPORT lean_object* lp_padctl_decodeDpadHat(lean_object*);
LEAN_EXPORT lean_object* lp_padctl_decodeDpadHat___boxed(lean_object*);
LEAN_EXPORT lean_object* lp_padctl_List_foldl___at___00decodeButtonGroup_spec__0(lean_object*, lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_List_foldl___at___00decodeButtonGroup_spec__0___boxed(lean_object*, lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_List_foldl___at___00decodeButtonGroup_spec__1(lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_List_foldl___at___00decodeButtonGroup_spec__1___boxed(lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_decodeButtonGroup(lean_object*, lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_decodeButtonGroup___boxed(lean_object*, lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_padctl_readU8(lean_object* x_1, lean_object* x_2) {
_start:
{
uint8_t x_3; lean_object* x_7; uint8_t x_8; 
x_7 = lean_byte_array_size(x_1);
x_8 = lean_nat_dec_lt(x_2, x_7);
if (x_8 == 0)
{
lean_object* x_9; 
x_9 = lean_box(0);
return x_9;
}
else
{
if (x_8 == 0)
{
uint8_t x_10; lean_object* x_11; lean_object* x_12; uint8_t x_13; 
x_10 = l_instInhabitedUInt8;
x_11 = lean_box(x_10);
x_12 = l_outOfBounds___redArg(x_11);
x_13 = lean_unbox(x_12);
lean_dec(x_12);
x_3 = x_13;
goto block_6;
}
else
{
uint8_t x_14; 
x_14 = lean_byte_array_fget(x_1, x_2);
x_3 = x_14;
goto block_6;
}
}
block_6:
{
lean_object* x_4; lean_object* x_5; 
x_4 = lean_uint8_to_nat(x_3);
x_5 = lean_alloc_ctor(1, 1, 0);
lean_ctor_set(x_5, 0, x_4);
return x_5;
}
}
}
LEAN_EXPORT lean_object* lp_padctl_readU8___boxed(lean_object* x_1, lean_object* x_2) {
_start:
{
lean_object* x_3; 
x_3 = lp_padctl_readU8(x_1, x_2);
lean_dec(x_2);
lean_dec_ref(x_1);
return x_3;
}
}
LEAN_EXPORT uint8_t lp_padctl_readU16le___lam__0(lean_object* x_1, lean_object* x_2) {
_start:
{
lean_object* x_3; uint8_t x_4; 
x_3 = lean_byte_array_size(x_1);
x_4 = lean_nat_dec_lt(x_2, x_3);
return x_4;
}
}
LEAN_EXPORT lean_object* lp_padctl_readU16le___lam__0___boxed(lean_object* x_1, lean_object* x_2) {
_start:
{
uint8_t x_3; lean_object* x_4; 
x_3 = lp_padctl_readU16le___lam__0(x_1, x_2);
lean_dec(x_2);
lean_dec_ref(x_1);
x_4 = lean_box(x_3);
return x_4;
}
}
LEAN_EXPORT lean_object* lp_padctl_readU16le(lean_object* x_1, lean_object* x_2) {
_start:
{
lean_object* x_3; uint8_t x_4; lean_object* x_11; lean_object* x_12; lean_object* x_13; uint8_t x_14; 
x_11 = lean_unsigned_to_nat(1u);
x_12 = lean_nat_add(x_2, x_11);
x_13 = lean_byte_array_size(x_1);
x_14 = lean_nat_dec_lt(x_12, x_13);
if (x_14 == 0)
{
lean_object* x_15; 
lean_dec(x_12);
x_15 = lean_box(0);
return x_15;
}
else
{
uint8_t x_16; uint8_t x_17; uint8_t x_25; 
x_16 = l_instInhabitedUInt8;
x_25 = lp_padctl_readU16le___lam__0(x_1, x_2);
if (x_25 == 0)
{
lean_object* x_26; lean_object* x_27; uint8_t x_28; 
x_26 = lean_box(x_16);
x_27 = l_outOfBounds___redArg(x_26);
x_28 = lean_unbox(x_27);
lean_dec(x_27);
x_17 = x_28;
goto block_24;
}
else
{
uint8_t x_29; 
x_29 = lean_byte_array_fget(x_1, x_2);
x_17 = x_29;
goto block_24;
}
block_24:
{
lean_object* x_18; uint8_t x_19; 
x_18 = lean_uint8_to_nat(x_17);
x_19 = lp_padctl_readU16le___lam__0(x_1, x_12);
if (x_19 == 0)
{
lean_object* x_20; lean_object* x_21; uint8_t x_22; 
lean_dec(x_12);
x_20 = lean_box(x_16);
x_21 = l_outOfBounds___redArg(x_20);
x_22 = lean_unbox(x_21);
lean_dec(x_21);
x_3 = x_18;
x_4 = x_22;
goto block_10;
}
else
{
uint8_t x_23; 
x_23 = lean_byte_array_fget(x_1, x_12);
lean_dec(x_12);
x_3 = x_18;
x_4 = x_23;
goto block_10;
}
}
}
block_10:
{
lean_object* x_5; lean_object* x_6; lean_object* x_7; lean_object* x_8; lean_object* x_9; 
x_5 = lean_uint8_to_nat(x_4);
x_6 = lean_unsigned_to_nat(256u);
x_7 = lean_nat_mul(x_5, x_6);
x_8 = lean_nat_add(x_3, x_7);
lean_dec(x_7);
lean_dec(x_3);
x_9 = lean_alloc_ctor(1, 1, 0);
lean_ctor_set(x_9, 0, x_8);
return x_9;
}
}
}
LEAN_EXPORT lean_object* lp_padctl_readU16le___boxed(lean_object* x_1, lean_object* x_2) {
_start:
{
lean_object* x_3; 
x_3 = lp_padctl_readU16le(x_1, x_2);
lean_dec(x_2);
lean_dec_ref(x_1);
return x_3;
}
}
LEAN_EXPORT lean_object* lp_padctl_readU16be(lean_object* x_1, lean_object* x_2) {
_start:
{
lean_object* x_3; uint8_t x_4; lean_object* x_9; lean_object* x_10; lean_object* x_11; uint8_t x_12; 
x_9 = lean_unsigned_to_nat(1u);
x_10 = lean_nat_add(x_2, x_9);
x_11 = lean_byte_array_size(x_1);
x_12 = lean_nat_dec_lt(x_10, x_11);
if (x_12 == 0)
{
lean_object* x_13; 
lean_dec(x_10);
x_13 = lean_box(0);
return x_13;
}
else
{
uint8_t x_14; uint8_t x_15; uint8_t x_25; 
x_14 = l_instInhabitedUInt8;
x_25 = lp_padctl_readU16le___lam__0(x_1, x_2);
if (x_25 == 0)
{
lean_object* x_26; lean_object* x_27; uint8_t x_28; 
x_26 = lean_box(x_14);
x_27 = l_outOfBounds___redArg(x_26);
x_28 = lean_unbox(x_27);
lean_dec(x_27);
x_15 = x_28;
goto block_24;
}
else
{
uint8_t x_29; 
x_29 = lean_byte_array_fget(x_1, x_2);
x_15 = x_29;
goto block_24;
}
block_24:
{
lean_object* x_16; lean_object* x_17; lean_object* x_18; uint8_t x_19; 
x_16 = lean_uint8_to_nat(x_15);
x_17 = lean_unsigned_to_nat(256u);
x_18 = lean_nat_mul(x_16, x_17);
x_19 = lp_padctl_readU16le___lam__0(x_1, x_10);
if (x_19 == 0)
{
lean_object* x_20; lean_object* x_21; uint8_t x_22; 
lean_dec(x_10);
x_20 = lean_box(x_14);
x_21 = l_outOfBounds___redArg(x_20);
x_22 = lean_unbox(x_21);
lean_dec(x_21);
x_3 = x_18;
x_4 = x_22;
goto block_8;
}
else
{
uint8_t x_23; 
x_23 = lean_byte_array_fget(x_1, x_10);
lean_dec(x_10);
x_3 = x_18;
x_4 = x_23;
goto block_8;
}
}
}
block_8:
{
lean_object* x_5; lean_object* x_6; lean_object* x_7; 
x_5 = lean_uint8_to_nat(x_4);
x_6 = lean_nat_add(x_3, x_5);
lean_dec(x_3);
x_7 = lean_alloc_ctor(1, 1, 0);
lean_ctor_set(x_7, 0, x_6);
return x_7;
}
}
}
LEAN_EXPORT lean_object* lp_padctl_readU16be___boxed(lean_object* x_1, lean_object* x_2) {
_start:
{
lean_object* x_3; 
x_3 = lp_padctl_readU16be(x_1, x_2);
lean_dec(x_2);
lean_dec_ref(x_1);
return x_3;
}
}
LEAN_EXPORT lean_object* lp_padctl_readU32le(lean_object* x_1, lean_object* x_2) {
_start:
{
lean_object* x_3; uint8_t x_4; lean_object* x_11; lean_object* x_12; lean_object* x_13; uint8_t x_14; 
x_11 = lean_unsigned_to_nat(3u);
x_12 = lean_nat_add(x_2, x_11);
x_13 = lean_byte_array_size(x_1);
x_14 = lean_nat_dec_lt(x_12, x_13);
if (x_14 == 0)
{
lean_object* x_15; 
lean_dec(x_12);
x_15 = lean_box(0);
return x_15;
}
else
{
uint8_t x_16; lean_object* x_17; uint8_t x_18; lean_object* x_29; uint8_t x_30; uint8_t x_43; uint8_t x_53; 
x_16 = l_instInhabitedUInt8;
x_53 = lp_padctl_readU16le___lam__0(x_1, x_2);
if (x_53 == 0)
{
lean_object* x_54; lean_object* x_55; uint8_t x_56; 
x_54 = lean_box(x_16);
x_55 = l_outOfBounds___redArg(x_54);
x_56 = lean_unbox(x_55);
lean_dec(x_55);
x_43 = x_56;
goto block_52;
}
else
{
uint8_t x_57; 
x_57 = lean_byte_array_fget(x_1, x_2);
x_43 = x_57;
goto block_52;
}
block_28:
{
lean_object* x_19; lean_object* x_20; lean_object* x_21; lean_object* x_22; uint8_t x_23; 
x_19 = lean_uint8_to_nat(x_18);
x_20 = lean_unsigned_to_nat(65536u);
x_21 = lean_nat_mul(x_19, x_20);
x_22 = lean_nat_add(x_17, x_21);
lean_dec(x_21);
lean_dec(x_17);
x_23 = lp_padctl_readU16le___lam__0(x_1, x_12);
if (x_23 == 0)
{
lean_object* x_24; lean_object* x_25; uint8_t x_26; 
lean_dec(x_12);
x_24 = lean_box(x_16);
x_25 = l_outOfBounds___redArg(x_24);
x_26 = lean_unbox(x_25);
lean_dec(x_25);
x_3 = x_22;
x_4 = x_26;
goto block_10;
}
else
{
uint8_t x_27; 
x_27 = lean_byte_array_fget(x_1, x_12);
lean_dec(x_12);
x_3 = x_22;
x_4 = x_27;
goto block_10;
}
}
block_42:
{
lean_object* x_31; lean_object* x_32; lean_object* x_33; lean_object* x_34; lean_object* x_35; lean_object* x_36; uint8_t x_37; 
x_31 = lean_uint8_to_nat(x_30);
x_32 = lean_unsigned_to_nat(256u);
x_33 = lean_nat_mul(x_31, x_32);
x_34 = lean_nat_add(x_29, x_33);
lean_dec(x_33);
lean_dec(x_29);
x_35 = lean_unsigned_to_nat(2u);
x_36 = lean_nat_add(x_2, x_35);
x_37 = lp_padctl_readU16le___lam__0(x_1, x_36);
if (x_37 == 0)
{
lean_object* x_38; lean_object* x_39; uint8_t x_40; 
lean_dec(x_36);
x_38 = lean_box(x_16);
x_39 = l_outOfBounds___redArg(x_38);
x_40 = lean_unbox(x_39);
lean_dec(x_39);
x_17 = x_34;
x_18 = x_40;
goto block_28;
}
else
{
uint8_t x_41; 
x_41 = lean_byte_array_fget(x_1, x_36);
lean_dec(x_36);
x_17 = x_34;
x_18 = x_41;
goto block_28;
}
}
block_52:
{
lean_object* x_44; lean_object* x_45; lean_object* x_46; uint8_t x_47; 
x_44 = lean_uint8_to_nat(x_43);
x_45 = lean_unsigned_to_nat(1u);
x_46 = lean_nat_add(x_2, x_45);
x_47 = lp_padctl_readU16le___lam__0(x_1, x_46);
if (x_47 == 0)
{
lean_object* x_48; lean_object* x_49; uint8_t x_50; 
lean_dec(x_46);
x_48 = lean_box(x_16);
x_49 = l_outOfBounds___redArg(x_48);
x_50 = lean_unbox(x_49);
lean_dec(x_49);
x_29 = x_44;
x_30 = x_50;
goto block_42;
}
else
{
uint8_t x_51; 
x_51 = lean_byte_array_fget(x_1, x_46);
lean_dec(x_46);
x_29 = x_44;
x_30 = x_51;
goto block_42;
}
}
}
block_10:
{
lean_object* x_5; lean_object* x_6; lean_object* x_7; lean_object* x_8; lean_object* x_9; 
x_5 = lean_uint8_to_nat(x_4);
x_6 = lean_unsigned_to_nat(16777216u);
x_7 = lean_nat_mul(x_5, x_6);
x_8 = lean_nat_add(x_3, x_7);
lean_dec(x_7);
lean_dec(x_3);
x_9 = lean_alloc_ctor(1, 1, 0);
lean_ctor_set(x_9, 0, x_8);
return x_9;
}
}
}
LEAN_EXPORT lean_object* lp_padctl_readU32le___boxed(lean_object* x_1, lean_object* x_2) {
_start:
{
lean_object* x_3; 
x_3 = lp_padctl_readU32le(x_1, x_2);
lean_dec(x_2);
lean_dec_ref(x_1);
return x_3;
}
}
LEAN_EXPORT lean_object* lp_padctl_readU32be(lean_object* x_1, lean_object* x_2) {
_start:
{
lean_object* x_3; uint8_t x_4; lean_object* x_9; lean_object* x_10; lean_object* x_11; uint8_t x_12; 
x_9 = lean_unsigned_to_nat(3u);
x_10 = lean_nat_add(x_2, x_9);
x_11 = lean_byte_array_size(x_1);
x_12 = lean_nat_dec_lt(x_10, x_11);
if (x_12 == 0)
{
lean_object* x_13; 
lean_dec(x_10);
x_13 = lean_box(0);
return x_13;
}
else
{
uint8_t x_14; lean_object* x_15; uint8_t x_16; lean_object* x_27; uint8_t x_28; uint8_t x_41; uint8_t x_53; 
x_14 = l_instInhabitedUInt8;
x_53 = lp_padctl_readU16le___lam__0(x_1, x_2);
if (x_53 == 0)
{
lean_object* x_54; lean_object* x_55; uint8_t x_56; 
x_54 = lean_box(x_14);
x_55 = l_outOfBounds___redArg(x_54);
x_56 = lean_unbox(x_55);
lean_dec(x_55);
x_41 = x_56;
goto block_52;
}
else
{
uint8_t x_57; 
x_57 = lean_byte_array_fget(x_1, x_2);
x_41 = x_57;
goto block_52;
}
block_26:
{
lean_object* x_17; lean_object* x_18; lean_object* x_19; lean_object* x_20; uint8_t x_21; 
x_17 = lean_uint8_to_nat(x_16);
x_18 = lean_unsigned_to_nat(256u);
x_19 = lean_nat_mul(x_17, x_18);
x_20 = lean_nat_add(x_15, x_19);
lean_dec(x_19);
lean_dec(x_15);
x_21 = lp_padctl_readU16le___lam__0(x_1, x_10);
if (x_21 == 0)
{
lean_object* x_22; lean_object* x_23; uint8_t x_24; 
lean_dec(x_10);
x_22 = lean_box(x_14);
x_23 = l_outOfBounds___redArg(x_22);
x_24 = lean_unbox(x_23);
lean_dec(x_23);
x_3 = x_20;
x_4 = x_24;
goto block_8;
}
else
{
uint8_t x_25; 
x_25 = lean_byte_array_fget(x_1, x_10);
lean_dec(x_10);
x_3 = x_20;
x_4 = x_25;
goto block_8;
}
}
block_40:
{
lean_object* x_29; lean_object* x_30; lean_object* x_31; lean_object* x_32; lean_object* x_33; lean_object* x_34; uint8_t x_35; 
x_29 = lean_uint8_to_nat(x_28);
x_30 = lean_unsigned_to_nat(65536u);
x_31 = lean_nat_mul(x_29, x_30);
x_32 = lean_nat_add(x_27, x_31);
lean_dec(x_31);
lean_dec(x_27);
x_33 = lean_unsigned_to_nat(2u);
x_34 = lean_nat_add(x_2, x_33);
x_35 = lp_padctl_readU16le___lam__0(x_1, x_34);
if (x_35 == 0)
{
lean_object* x_36; lean_object* x_37; uint8_t x_38; 
lean_dec(x_34);
x_36 = lean_box(x_14);
x_37 = l_outOfBounds___redArg(x_36);
x_38 = lean_unbox(x_37);
lean_dec(x_37);
x_15 = x_32;
x_16 = x_38;
goto block_26;
}
else
{
uint8_t x_39; 
x_39 = lean_byte_array_fget(x_1, x_34);
lean_dec(x_34);
x_15 = x_32;
x_16 = x_39;
goto block_26;
}
}
block_52:
{
lean_object* x_42; lean_object* x_43; lean_object* x_44; lean_object* x_45; lean_object* x_46; uint8_t x_47; 
x_42 = lean_uint8_to_nat(x_41);
x_43 = lean_unsigned_to_nat(16777216u);
x_44 = lean_nat_mul(x_42, x_43);
x_45 = lean_unsigned_to_nat(1u);
x_46 = lean_nat_add(x_2, x_45);
x_47 = lp_padctl_readU16le___lam__0(x_1, x_46);
if (x_47 == 0)
{
lean_object* x_48; lean_object* x_49; uint8_t x_50; 
lean_dec(x_46);
x_48 = lean_box(x_14);
x_49 = l_outOfBounds___redArg(x_48);
x_50 = lean_unbox(x_49);
lean_dec(x_49);
x_27 = x_44;
x_28 = x_50;
goto block_40;
}
else
{
uint8_t x_51; 
x_51 = lean_byte_array_fget(x_1, x_46);
lean_dec(x_46);
x_27 = x_44;
x_28 = x_51;
goto block_40;
}
}
}
block_8:
{
lean_object* x_5; lean_object* x_6; lean_object* x_7; 
x_5 = lean_uint8_to_nat(x_4);
x_6 = lean_nat_add(x_3, x_5);
lean_dec(x_3);
x_7 = lean_alloc_ctor(1, 1, 0);
lean_ctor_set(x_7, 0, x_6);
return x_7;
}
}
}
LEAN_EXPORT lean_object* lp_padctl_readU32be___boxed(lean_object* x_1, lean_object* x_2) {
_start:
{
lean_object* x_3; 
x_3 = lp_padctl_readU32be(x_1, x_2);
lean_dec(x_2);
lean_dec_ref(x_1);
return x_3;
}
}
static lean_object* _init_lp_padctl_toSigned___closed__0(void) {
_start:
{
lean_object* x_1; lean_object* x_2; 
x_1 = lean_unsigned_to_nat(0u);
x_2 = lean_nat_to_int(x_1);
return x_2;
}
}
LEAN_EXPORT lean_object* lp_padctl_toSigned(lean_object* x_1, lean_object* x_2) {
_start:
{
lean_object* x_3; uint8_t x_4; 
x_3 = lean_unsigned_to_nat(0u);
x_4 = lean_nat_dec_eq(x_2, x_3);
if (x_4 == 0)
{
lean_object* x_5; lean_object* x_6; lean_object* x_7; lean_object* x_8; uint8_t x_9; 
x_5 = lean_unsigned_to_nat(2u);
x_6 = lean_unsigned_to_nat(1u);
x_7 = lean_nat_sub(x_2, x_6);
x_8 = lean_nat_pow(x_5, x_7);
lean_dec(x_7);
x_9 = lean_nat_dec_lt(x_1, x_8);
lean_dec(x_8);
if (x_9 == 0)
{
lean_object* x_10; lean_object* x_11; lean_object* x_12; lean_object* x_13; 
x_10 = lean_nat_to_int(x_1);
x_11 = lean_nat_pow(x_5, x_2);
x_12 = lean_nat_to_int(x_11);
x_13 = lean_int_sub(x_10, x_12);
lean_dec(x_12);
lean_dec(x_10);
return x_13;
}
else
{
lean_object* x_14; 
x_14 = lean_nat_to_int(x_1);
return x_14;
}
}
else
{
lean_object* x_15; 
lean_dec(x_1);
x_15 = lean_obj_once(&lp_padctl_toSigned___closed__0, &lp_padctl_toSigned___closed__0_once, _init_lp_padctl_toSigned___closed__0);
return x_15;
}
}
}
LEAN_EXPORT lean_object* lp_padctl_toSigned___boxed(lean_object* x_1, lean_object* x_2) {
_start:
{
lean_object* x_3; 
x_3 = lp_padctl_toSigned(x_1, x_2);
lean_dec(x_2);
return x_3;
}
}
LEAN_EXPORT lean_object* lp_padctl_readField(lean_object* x_1, lean_object* x_2, uint8_t x_3) {
_start:
{
switch (x_3) {
case 0:
{
lean_object* x_4; 
x_4 = lp_padctl_readU8(x_1, x_2);
if (lean_obj_tag(x_4) == 0)
{
lean_object* x_5; 
x_5 = lean_box(0);
return x_5;
}
else
{
uint8_t x_6; 
x_6 = !lean_is_exclusive(x_4);
if (x_6 == 0)
{
lean_object* x_7; lean_object* x_8; 
x_7 = lean_ctor_get(x_4, 0);
x_8 = lean_nat_to_int(x_7);
lean_ctor_set(x_4, 0, x_8);
return x_4;
}
else
{
lean_object* x_9; lean_object* x_10; lean_object* x_11; 
x_9 = lean_ctor_get(x_4, 0);
lean_inc(x_9);
lean_dec(x_4);
x_10 = lean_nat_to_int(x_9);
x_11 = lean_alloc_ctor(1, 1, 0);
lean_ctor_set(x_11, 0, x_10);
return x_11;
}
}
}
case 1:
{
lean_object* x_12; 
x_12 = lp_padctl_readU8(x_1, x_2);
if (lean_obj_tag(x_12) == 0)
{
lean_object* x_13; 
x_13 = lean_box(0);
return x_13;
}
else
{
uint8_t x_14; 
x_14 = !lean_is_exclusive(x_12);
if (x_14 == 0)
{
lean_object* x_15; lean_object* x_16; lean_object* x_17; 
x_15 = lean_ctor_get(x_12, 0);
x_16 = lean_unsigned_to_nat(8u);
x_17 = lp_padctl_toSigned(x_15, x_16);
lean_ctor_set(x_12, 0, x_17);
return x_12;
}
else
{
lean_object* x_18; lean_object* x_19; lean_object* x_20; lean_object* x_21; 
x_18 = lean_ctor_get(x_12, 0);
lean_inc(x_18);
lean_dec(x_12);
x_19 = lean_unsigned_to_nat(8u);
x_20 = lp_padctl_toSigned(x_18, x_19);
x_21 = lean_alloc_ctor(1, 1, 0);
lean_ctor_set(x_21, 0, x_20);
return x_21;
}
}
}
case 2:
{
lean_object* x_22; 
x_22 = lp_padctl_readU16le(x_1, x_2);
if (lean_obj_tag(x_22) == 0)
{
lean_object* x_23; 
x_23 = lean_box(0);
return x_23;
}
else
{
uint8_t x_24; 
x_24 = !lean_is_exclusive(x_22);
if (x_24 == 0)
{
lean_object* x_25; lean_object* x_26; 
x_25 = lean_ctor_get(x_22, 0);
x_26 = lean_nat_to_int(x_25);
lean_ctor_set(x_22, 0, x_26);
return x_22;
}
else
{
lean_object* x_27; lean_object* x_28; lean_object* x_29; 
x_27 = lean_ctor_get(x_22, 0);
lean_inc(x_27);
lean_dec(x_22);
x_28 = lean_nat_to_int(x_27);
x_29 = lean_alloc_ctor(1, 1, 0);
lean_ctor_set(x_29, 0, x_28);
return x_29;
}
}
}
case 3:
{
lean_object* x_30; 
x_30 = lp_padctl_readU16le(x_1, x_2);
if (lean_obj_tag(x_30) == 0)
{
lean_object* x_31; 
x_31 = lean_box(0);
return x_31;
}
else
{
uint8_t x_32; 
x_32 = !lean_is_exclusive(x_30);
if (x_32 == 0)
{
lean_object* x_33; lean_object* x_34; lean_object* x_35; 
x_33 = lean_ctor_get(x_30, 0);
x_34 = lean_unsigned_to_nat(16u);
x_35 = lp_padctl_toSigned(x_33, x_34);
lean_ctor_set(x_30, 0, x_35);
return x_30;
}
else
{
lean_object* x_36; lean_object* x_37; lean_object* x_38; lean_object* x_39; 
x_36 = lean_ctor_get(x_30, 0);
lean_inc(x_36);
lean_dec(x_30);
x_37 = lean_unsigned_to_nat(16u);
x_38 = lp_padctl_toSigned(x_36, x_37);
x_39 = lean_alloc_ctor(1, 1, 0);
lean_ctor_set(x_39, 0, x_38);
return x_39;
}
}
}
case 4:
{
lean_object* x_40; 
x_40 = lp_padctl_readU16be(x_1, x_2);
if (lean_obj_tag(x_40) == 0)
{
lean_object* x_41; 
x_41 = lean_box(0);
return x_41;
}
else
{
uint8_t x_42; 
x_42 = !lean_is_exclusive(x_40);
if (x_42 == 0)
{
lean_object* x_43; lean_object* x_44; 
x_43 = lean_ctor_get(x_40, 0);
x_44 = lean_nat_to_int(x_43);
lean_ctor_set(x_40, 0, x_44);
return x_40;
}
else
{
lean_object* x_45; lean_object* x_46; lean_object* x_47; 
x_45 = lean_ctor_get(x_40, 0);
lean_inc(x_45);
lean_dec(x_40);
x_46 = lean_nat_to_int(x_45);
x_47 = lean_alloc_ctor(1, 1, 0);
lean_ctor_set(x_47, 0, x_46);
return x_47;
}
}
}
case 5:
{
lean_object* x_48; 
x_48 = lp_padctl_readU16be(x_1, x_2);
if (lean_obj_tag(x_48) == 0)
{
lean_object* x_49; 
x_49 = lean_box(0);
return x_49;
}
else
{
uint8_t x_50; 
x_50 = !lean_is_exclusive(x_48);
if (x_50 == 0)
{
lean_object* x_51; lean_object* x_52; lean_object* x_53; 
x_51 = lean_ctor_get(x_48, 0);
x_52 = lean_unsigned_to_nat(16u);
x_53 = lp_padctl_toSigned(x_51, x_52);
lean_ctor_set(x_48, 0, x_53);
return x_48;
}
else
{
lean_object* x_54; lean_object* x_55; lean_object* x_56; lean_object* x_57; 
x_54 = lean_ctor_get(x_48, 0);
lean_inc(x_54);
lean_dec(x_48);
x_55 = lean_unsigned_to_nat(16u);
x_56 = lp_padctl_toSigned(x_54, x_55);
x_57 = lean_alloc_ctor(1, 1, 0);
lean_ctor_set(x_57, 0, x_56);
return x_57;
}
}
}
case 6:
{
lean_object* x_58; 
x_58 = lp_padctl_readU32le(x_1, x_2);
if (lean_obj_tag(x_58) == 0)
{
lean_object* x_59; 
x_59 = lean_box(0);
return x_59;
}
else
{
uint8_t x_60; 
x_60 = !lean_is_exclusive(x_58);
if (x_60 == 0)
{
lean_object* x_61; lean_object* x_62; 
x_61 = lean_ctor_get(x_58, 0);
x_62 = lean_nat_to_int(x_61);
lean_ctor_set(x_58, 0, x_62);
return x_58;
}
else
{
lean_object* x_63; lean_object* x_64; lean_object* x_65; 
x_63 = lean_ctor_get(x_58, 0);
lean_inc(x_63);
lean_dec(x_58);
x_64 = lean_nat_to_int(x_63);
x_65 = lean_alloc_ctor(1, 1, 0);
lean_ctor_set(x_65, 0, x_64);
return x_65;
}
}
}
case 7:
{
lean_object* x_66; 
x_66 = lp_padctl_readU32le(x_1, x_2);
if (lean_obj_tag(x_66) == 0)
{
lean_object* x_67; 
x_67 = lean_box(0);
return x_67;
}
else
{
uint8_t x_68; 
x_68 = !lean_is_exclusive(x_66);
if (x_68 == 0)
{
lean_object* x_69; lean_object* x_70; lean_object* x_71; 
x_69 = lean_ctor_get(x_66, 0);
x_70 = lean_unsigned_to_nat(32u);
x_71 = lp_padctl_toSigned(x_69, x_70);
lean_ctor_set(x_66, 0, x_71);
return x_66;
}
else
{
lean_object* x_72; lean_object* x_73; lean_object* x_74; lean_object* x_75; 
x_72 = lean_ctor_get(x_66, 0);
lean_inc(x_72);
lean_dec(x_66);
x_73 = lean_unsigned_to_nat(32u);
x_74 = lp_padctl_toSigned(x_72, x_73);
x_75 = lean_alloc_ctor(1, 1, 0);
lean_ctor_set(x_75, 0, x_74);
return x_75;
}
}
}
case 8:
{
lean_object* x_76; 
x_76 = lp_padctl_readU32be(x_1, x_2);
if (lean_obj_tag(x_76) == 0)
{
lean_object* x_77; 
x_77 = lean_box(0);
return x_77;
}
else
{
uint8_t x_78; 
x_78 = !lean_is_exclusive(x_76);
if (x_78 == 0)
{
lean_object* x_79; lean_object* x_80; 
x_79 = lean_ctor_get(x_76, 0);
x_80 = lean_nat_to_int(x_79);
lean_ctor_set(x_76, 0, x_80);
return x_76;
}
else
{
lean_object* x_81; lean_object* x_82; lean_object* x_83; 
x_81 = lean_ctor_get(x_76, 0);
lean_inc(x_81);
lean_dec(x_76);
x_82 = lean_nat_to_int(x_81);
x_83 = lean_alloc_ctor(1, 1, 0);
lean_ctor_set(x_83, 0, x_82);
return x_83;
}
}
}
default: 
{
lean_object* x_84; 
x_84 = lp_padctl_readU32be(x_1, x_2);
if (lean_obj_tag(x_84) == 0)
{
lean_object* x_85; 
x_85 = lean_box(0);
return x_85;
}
else
{
uint8_t x_86; 
x_86 = !lean_is_exclusive(x_84);
if (x_86 == 0)
{
lean_object* x_87; lean_object* x_88; lean_object* x_89; 
x_87 = lean_ctor_get(x_84, 0);
x_88 = lean_unsigned_to_nat(32u);
x_89 = lp_padctl_toSigned(x_87, x_88);
lean_ctor_set(x_84, 0, x_89);
return x_84;
}
else
{
lean_object* x_90; lean_object* x_91; lean_object* x_92; lean_object* x_93; 
x_90 = lean_ctor_get(x_84, 0);
lean_inc(x_90);
lean_dec(x_84);
x_91 = lean_unsigned_to_nat(32u);
x_92 = lp_padctl_toSigned(x_90, x_91);
x_93 = lean_alloc_ctor(1, 1, 0);
lean_ctor_set(x_93, 0, x_92);
return x_93;
}
}
}
}
}
}
LEAN_EXPORT lean_object* lp_padctl_readField___boxed(lean_object* x_1, lean_object* x_2, lean_object* x_3) {
_start:
{
uint8_t x_4; lean_object* x_5; 
x_4 = lean_unbox(x_3);
x_5 = lp_padctl_readField(x_1, x_2, x_4);
lean_dec(x_2);
lean_dec_ref(x_1);
return x_5;
}
}
LEAN_EXPORT lean_object* lp_padctl_List_foldl___at___00extractBits_spec__0(lean_object* x_1, lean_object* x_2, lean_object* x_3, lean_object* x_4) {
_start:
{
if (lean_obj_tag(x_4) == 0)
{
return x_3;
}
else
{
lean_object* x_5; lean_object* x_6; lean_object* x_7; lean_object* x_8; uint8_t x_9; 
x_5 = lean_ctor_get(x_4, 0);
x_6 = lean_ctor_get(x_4, 1);
x_7 = lean_nat_add(x_1, x_5);
x_8 = lean_byte_array_size(x_2);
x_9 = lean_nat_dec_lt(x_7, x_8);
if (x_9 == 0)
{
lean_dec(x_7);
x_4 = x_6;
goto _start;
}
else
{
lean_object* x_11; uint8_t x_12; 
x_11 = lean_unsigned_to_nat(8u);
if (x_9 == 0)
{
uint8_t x_21; lean_object* x_22; lean_object* x_23; uint8_t x_24; 
lean_dec(x_7);
x_21 = l_instInhabitedUInt8;
x_22 = lean_box(x_21);
x_23 = l_outOfBounds___redArg(x_22);
x_24 = lean_unbox(x_23);
lean_dec(x_23);
x_12 = x_24;
goto block_20;
}
else
{
uint8_t x_25; 
x_25 = lean_byte_array_fget(x_2, x_7);
lean_dec(x_7);
x_12 = x_25;
goto block_20;
}
block_20:
{
lean_object* x_13; lean_object* x_14; lean_object* x_15; lean_object* x_16; lean_object* x_17; lean_object* x_18; 
x_13 = lean_uint8_to_nat(x_12);
x_14 = lean_unsigned_to_nat(2u);
x_15 = lean_nat_mul(x_5, x_11);
x_16 = lean_nat_pow(x_14, x_15);
lean_dec(x_15);
x_17 = lean_nat_mul(x_13, x_16);
lean_dec(x_16);
x_18 = lean_nat_add(x_3, x_17);
lean_dec(x_17);
lean_dec(x_3);
x_3 = x_18;
x_4 = x_6;
goto _start;
}
}
}
}
}
LEAN_EXPORT lean_object* lp_padctl_List_foldl___at___00extractBits_spec__0___boxed(lean_object* x_1, lean_object* x_2, lean_object* x_3, lean_object* x_4) {
_start:
{
lean_object* x_5; 
x_5 = lp_padctl_List_foldl___at___00extractBits_spec__0(x_1, x_2, x_3, x_4);
lean_dec(x_4);
lean_dec_ref(x_2);
lean_dec(x_1);
return x_5;
}
}
LEAN_EXPORT lean_object* lp_padctl_extractBits(lean_object* x_1, lean_object* x_2, lean_object* x_3, lean_object* x_4) {
_start:
{
lean_object* x_5; uint8_t x_6; 
x_5 = lean_unsigned_to_nat(0u);
x_6 = lean_nat_dec_eq(x_4, x_5);
if (x_6 == 0)
{
lean_object* x_7; lean_object* x_8; lean_object* x_9; lean_object* x_10; lean_object* x_11; lean_object* x_12; lean_object* x_13; lean_object* x_14; lean_object* x_15; lean_object* x_16; lean_object* x_17; lean_object* x_18; 
x_7 = lean_nat_add(x_3, x_4);
x_8 = lean_unsigned_to_nat(7u);
x_9 = lean_nat_add(x_7, x_8);
lean_dec(x_7);
x_10 = lean_unsigned_to_nat(3u);
x_11 = lean_nat_shiftr(x_9, x_10);
lean_dec(x_9);
x_12 = l_List_range(x_11);
x_13 = lp_padctl_List_foldl___at___00extractBits_spec__0(x_2, x_1, x_5, x_12);
lean_dec(x_12);
x_14 = lean_unsigned_to_nat(2u);
x_15 = lean_nat_pow(x_14, x_3);
x_16 = lean_nat_div(x_13, x_15);
lean_dec(x_15);
lean_dec(x_13);
x_17 = lean_nat_pow(x_14, x_4);
x_18 = lean_nat_mod(x_16, x_17);
lean_dec(x_17);
lean_dec(x_16);
return x_18;
}
else
{
return x_5;
}
}
}
LEAN_EXPORT lean_object* lp_padctl_extractBits___boxed(lean_object* x_1, lean_object* x_2, lean_object* x_3, lean_object* x_4) {
_start:
{
lean_object* x_5; 
x_5 = lp_padctl_extractBits(x_1, x_2, x_3, x_4);
lean_dec(x_4);
lean_dec(x_3);
lean_dec(x_2);
lean_dec_ref(x_1);
return x_5;
}
}
LEAN_EXPORT lean_object* lp_padctl_signExtend(lean_object* x_1, lean_object* x_2) {
_start:
{
lean_object* x_3; lean_object* x_4; lean_object* x_5; lean_object* x_6; 
x_3 = lean_unsigned_to_nat(2u);
x_4 = lean_nat_pow(x_3, x_2);
x_5 = lean_nat_mod(x_1, x_4);
lean_dec(x_4);
x_6 = lp_padctl_toSigned(x_5, x_2);
return x_6;
}
}
LEAN_EXPORT lean_object* lp_padctl_signExtend___boxed(lean_object* x_1, lean_object* x_2) {
_start:
{
lean_object* x_3; 
x_3 = lp_padctl_signExtend(x_1, x_2);
lean_dec(x_2);
lean_dec(x_1);
return x_3;
}
}
LEAN_EXPORT lean_object* lp_padctl_ChecksumAlgo_ctorIdx(uint8_t x_1) {
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
LEAN_EXPORT lean_object* lp_padctl_ChecksumAlgo_ctorIdx___boxed(lean_object* x_1) {
_start:
{
uint8_t x_2; lean_object* x_3; 
x_2 = lean_unbox(x_1);
x_3 = lp_padctl_ChecksumAlgo_ctorIdx(x_2);
return x_3;
}
}
LEAN_EXPORT lean_object* lp_padctl_ChecksumAlgo_toCtorIdx(uint8_t x_1) {
_start:
{
lean_object* x_2; 
x_2 = lp_padctl_ChecksumAlgo_ctorIdx(x_1);
return x_2;
}
}
LEAN_EXPORT lean_object* lp_padctl_ChecksumAlgo_toCtorIdx___boxed(lean_object* x_1) {
_start:
{
uint8_t x_2; lean_object* x_3; 
x_2 = lean_unbox(x_1);
x_3 = lp_padctl_ChecksumAlgo_toCtorIdx(x_2);
return x_3;
}
}
LEAN_EXPORT lean_object* lp_padctl_ChecksumAlgo_ctorElim___redArg(lean_object* x_1) {
_start:
{
lean_inc(x_1);
return x_1;
}
}
LEAN_EXPORT lean_object* lp_padctl_ChecksumAlgo_ctorElim___redArg___boxed(lean_object* x_1) {
_start:
{
lean_object* x_2; 
x_2 = lp_padctl_ChecksumAlgo_ctorElim___redArg(x_1);
lean_dec(x_1);
return x_2;
}
}
LEAN_EXPORT lean_object* lp_padctl_ChecksumAlgo_ctorElim(lean_object* x_1, lean_object* x_2, uint8_t x_3, lean_object* x_4, lean_object* x_5) {
_start:
{
lean_inc(x_5);
return x_5;
}
}
LEAN_EXPORT lean_object* lp_padctl_ChecksumAlgo_ctorElim___boxed(lean_object* x_1, lean_object* x_2, lean_object* x_3, lean_object* x_4, lean_object* x_5) {
_start:
{
uint8_t x_6; lean_object* x_7; 
x_6 = lean_unbox(x_3);
x_7 = lp_padctl_ChecksumAlgo_ctorElim(x_1, x_2, x_6, x_4, x_5);
lean_dec(x_5);
lean_dec(x_2);
return x_7;
}
}
LEAN_EXPORT lean_object* lp_padctl_ChecksumAlgo_sum8_elim___redArg(lean_object* x_1) {
_start:
{
lean_inc(x_1);
return x_1;
}
}
LEAN_EXPORT lean_object* lp_padctl_ChecksumAlgo_sum8_elim___redArg___boxed(lean_object* x_1) {
_start:
{
lean_object* x_2; 
x_2 = lp_padctl_ChecksumAlgo_sum8_elim___redArg(x_1);
lean_dec(x_1);
return x_2;
}
}
LEAN_EXPORT lean_object* lp_padctl_ChecksumAlgo_sum8_elim(lean_object* x_1, uint8_t x_2, lean_object* x_3, lean_object* x_4) {
_start:
{
lean_inc(x_4);
return x_4;
}
}
LEAN_EXPORT lean_object* lp_padctl_ChecksumAlgo_sum8_elim___boxed(lean_object* x_1, lean_object* x_2, lean_object* x_3, lean_object* x_4) {
_start:
{
uint8_t x_5; lean_object* x_6; 
x_5 = lean_unbox(x_2);
x_6 = lp_padctl_ChecksumAlgo_sum8_elim(x_1, x_5, x_3, x_4);
lean_dec(x_4);
return x_6;
}
}
LEAN_EXPORT lean_object* lp_padctl_ChecksumAlgo_xor_elim___redArg(lean_object* x_1) {
_start:
{
lean_inc(x_1);
return x_1;
}
}
LEAN_EXPORT lean_object* lp_padctl_ChecksumAlgo_xor_elim___redArg___boxed(lean_object* x_1) {
_start:
{
lean_object* x_2; 
x_2 = lp_padctl_ChecksumAlgo_xor_elim___redArg(x_1);
lean_dec(x_1);
return x_2;
}
}
LEAN_EXPORT lean_object* lp_padctl_ChecksumAlgo_xor_elim(lean_object* x_1, uint8_t x_2, lean_object* x_3, lean_object* x_4) {
_start:
{
lean_inc(x_4);
return x_4;
}
}
LEAN_EXPORT lean_object* lp_padctl_ChecksumAlgo_xor_elim___boxed(lean_object* x_1, lean_object* x_2, lean_object* x_3, lean_object* x_4) {
_start:
{
uint8_t x_5; lean_object* x_6; 
x_5 = lean_unbox(x_2);
x_6 = lp_padctl_ChecksumAlgo_xor_elim(x_1, x_5, x_3, x_4);
lean_dec(x_4);
return x_6;
}
}
LEAN_EXPORT lean_object* lp_padctl_ChecksumAlgo_crc32_elim___redArg(lean_object* x_1) {
_start:
{
lean_inc(x_1);
return x_1;
}
}
LEAN_EXPORT lean_object* lp_padctl_ChecksumAlgo_crc32_elim___redArg___boxed(lean_object* x_1) {
_start:
{
lean_object* x_2; 
x_2 = lp_padctl_ChecksumAlgo_crc32_elim___redArg(x_1);
lean_dec(x_1);
return x_2;
}
}
LEAN_EXPORT lean_object* lp_padctl_ChecksumAlgo_crc32_elim(lean_object* x_1, uint8_t x_2, lean_object* x_3, lean_object* x_4) {
_start:
{
lean_inc(x_4);
return x_4;
}
}
LEAN_EXPORT lean_object* lp_padctl_ChecksumAlgo_crc32_elim___boxed(lean_object* x_1, lean_object* x_2, lean_object* x_3, lean_object* x_4) {
_start:
{
uint8_t x_5; lean_object* x_6; 
x_5 = lean_unbox(x_2);
x_6 = lp_padctl_ChecksumAlgo_crc32_elim(x_1, x_5, x_3, x_4);
lean_dec(x_4);
return x_6;
}
}
LEAN_EXPORT uint8_t lp_padctl_ChecksumAlgo_ofNat(lean_object* x_1) {
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
LEAN_EXPORT lean_object* lp_padctl_ChecksumAlgo_ofNat___boxed(lean_object* x_1) {
_start:
{
uint8_t x_2; lean_object* x_3; 
x_2 = lp_padctl_ChecksumAlgo_ofNat(x_1);
lean_dec(x_1);
x_3 = lean_box(x_2);
return x_3;
}
}
LEAN_EXPORT uint8_t lp_padctl_instDecidableEqChecksumAlgo(uint8_t x_1, uint8_t x_2) {
_start:
{
lean_object* x_3; lean_object* x_4; uint8_t x_5; 
x_3 = lp_padctl_ChecksumAlgo_ctorIdx(x_1);
x_4 = lp_padctl_ChecksumAlgo_ctorIdx(x_2);
x_5 = lean_nat_dec_eq(x_3, x_4);
lean_dec(x_4);
lean_dec(x_3);
return x_5;
}
}
LEAN_EXPORT lean_object* lp_padctl_instDecidableEqChecksumAlgo___boxed(lean_object* x_1, lean_object* x_2) {
_start:
{
uint8_t x_3; uint8_t x_4; uint8_t x_5; lean_object* x_6; 
x_3 = lean_unbox(x_1);
x_4 = lean_unbox(x_2);
x_5 = lp_padctl_instDecidableEqChecksumAlgo(x_3, x_4);
x_6 = lean_box(x_5);
return x_6;
}
}
static lean_object* _init_lp_padctl_instReprChecksumAlgo_repr___closed__6(void) {
_start:
{
lean_object* x_1; lean_object* x_2; 
x_1 = lean_unsigned_to_nat(2u);
x_2 = lean_nat_to_int(x_1);
return x_2;
}
}
static lean_object* _init_lp_padctl_instReprChecksumAlgo_repr___closed__7(void) {
_start:
{
lean_object* x_1; lean_object* x_2; 
x_1 = lean_unsigned_to_nat(1u);
x_2 = lean_nat_to_int(x_1);
return x_2;
}
}
LEAN_EXPORT lean_object* lp_padctl_instReprChecksumAlgo_repr(uint8_t x_1, lean_object* x_2) {
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
x_26 = lean_obj_once(&lp_padctl_instReprChecksumAlgo_repr___closed__6, &lp_padctl_instReprChecksumAlgo_repr___closed__6_once, _init_lp_padctl_instReprChecksumAlgo_repr___closed__6);
x_3 = x_26;
goto block_9;
}
else
{
lean_object* x_27; 
x_27 = lean_obj_once(&lp_padctl_instReprChecksumAlgo_repr___closed__7, &lp_padctl_instReprChecksumAlgo_repr___closed__7_once, _init_lp_padctl_instReprChecksumAlgo_repr___closed__7);
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
x_30 = lean_obj_once(&lp_padctl_instReprChecksumAlgo_repr___closed__6, &lp_padctl_instReprChecksumAlgo_repr___closed__6_once, _init_lp_padctl_instReprChecksumAlgo_repr___closed__6);
x_10 = x_30;
goto block_16;
}
else
{
lean_object* x_31; 
x_31 = lean_obj_once(&lp_padctl_instReprChecksumAlgo_repr___closed__7, &lp_padctl_instReprChecksumAlgo_repr___closed__7_once, _init_lp_padctl_instReprChecksumAlgo_repr___closed__7);
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
x_34 = lean_obj_once(&lp_padctl_instReprChecksumAlgo_repr___closed__6, &lp_padctl_instReprChecksumAlgo_repr___closed__6_once, _init_lp_padctl_instReprChecksumAlgo_repr___closed__6);
x_17 = x_34;
goto block_23;
}
else
{
lean_object* x_35; 
x_35 = lean_obj_once(&lp_padctl_instReprChecksumAlgo_repr___closed__7, &lp_padctl_instReprChecksumAlgo_repr___closed__7_once, _init_lp_padctl_instReprChecksumAlgo_repr___closed__7);
x_17 = x_35;
goto block_23;
}
}
}
block_9:
{
lean_object* x_4; lean_object* x_5; uint8_t x_6; lean_object* x_7; lean_object* x_8; 
x_4 = ((lean_object*)(lp_padctl_instReprChecksumAlgo_repr___closed__1));
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
x_11 = ((lean_object*)(lp_padctl_instReprChecksumAlgo_repr___closed__3));
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
x_18 = ((lean_object*)(lp_padctl_instReprChecksumAlgo_repr___closed__5));
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
LEAN_EXPORT lean_object* lp_padctl_instReprChecksumAlgo_repr___boxed(lean_object* x_1, lean_object* x_2) {
_start:
{
uint8_t x_3; lean_object* x_4; 
x_3 = lean_unbox(x_1);
x_4 = lp_padctl_instReprChecksumAlgo_repr(x_3, x_2);
lean_dec(x_2);
return x_4;
}
}
LEAN_EXPORT lean_object* lp_padctl_List_foldl___at___00checksumSum8_spec__0(lean_object* x_1, lean_object* x_2, lean_object* x_3, lean_object* x_4) {
_start:
{
if (lean_obj_tag(x_4) == 0)
{
return x_3;
}
else
{
lean_object* x_5; lean_object* x_6; uint8_t x_7; lean_object* x_14; lean_object* x_15; uint8_t x_16; 
x_5 = lean_ctor_get(x_4, 0);
x_6 = lean_ctor_get(x_4, 1);
x_14 = lean_nat_add(x_1, x_5);
x_15 = lean_byte_array_size(x_2);
x_16 = lean_nat_dec_lt(x_14, x_15);
if (x_16 == 0)
{
lean_dec(x_14);
x_4 = x_6;
goto _start;
}
else
{
if (x_16 == 0)
{
uint8_t x_18; lean_object* x_19; lean_object* x_20; uint8_t x_21; 
lean_dec(x_14);
x_18 = l_instInhabitedUInt8;
x_19 = lean_box(x_18);
x_20 = l_outOfBounds___redArg(x_19);
x_21 = lean_unbox(x_20);
lean_dec(x_20);
x_7 = x_21;
goto block_13;
}
else
{
uint8_t x_22; 
x_22 = lean_byte_array_fget(x_2, x_14);
lean_dec(x_14);
x_7 = x_22;
goto block_13;
}
}
block_13:
{
lean_object* x_8; lean_object* x_9; lean_object* x_10; lean_object* x_11; 
x_8 = lean_uint8_to_nat(x_7);
x_9 = lean_nat_add(x_3, x_8);
lean_dec(x_3);
x_10 = lean_unsigned_to_nat(256u);
x_11 = lean_nat_mod(x_9, x_10);
lean_dec(x_9);
x_3 = x_11;
x_4 = x_6;
goto _start;
}
}
}
}
LEAN_EXPORT lean_object* lp_padctl_List_foldl___at___00checksumSum8_spec__0___boxed(lean_object* x_1, lean_object* x_2, lean_object* x_3, lean_object* x_4) {
_start:
{
lean_object* x_5; 
x_5 = lp_padctl_List_foldl___at___00checksumSum8_spec__0(x_1, x_2, x_3, x_4);
lean_dec(x_4);
lean_dec_ref(x_2);
lean_dec(x_1);
return x_5;
}
}
LEAN_EXPORT lean_object* lp_padctl_checksumSum8(lean_object* x_1, lean_object* x_2, lean_object* x_3) {
_start:
{
lean_object* x_4; lean_object* x_5; lean_object* x_6; lean_object* x_7; 
x_4 = lean_unsigned_to_nat(0u);
x_5 = lean_nat_sub(x_3, x_2);
x_6 = l_List_range(x_5);
x_7 = lp_padctl_List_foldl___at___00checksumSum8_spec__0(x_2, x_1, x_4, x_6);
lean_dec(x_6);
return x_7;
}
}
LEAN_EXPORT lean_object* lp_padctl_checksumSum8___boxed(lean_object* x_1, lean_object* x_2, lean_object* x_3) {
_start:
{
lean_object* x_4; 
x_4 = lp_padctl_checksumSum8(x_1, x_2, x_3);
lean_dec(x_3);
lean_dec(x_2);
lean_dec_ref(x_1);
return x_4;
}
}
LEAN_EXPORT lean_object* lp_padctl_List_foldl___at___00checksumXor_spec__0(lean_object* x_1, lean_object* x_2, lean_object* x_3, lean_object* x_4) {
_start:
{
if (lean_obj_tag(x_4) == 0)
{
return x_3;
}
else
{
lean_object* x_5; lean_object* x_6; uint8_t x_7; lean_object* x_12; lean_object* x_13; uint8_t x_14; 
x_5 = lean_ctor_get(x_4, 0);
x_6 = lean_ctor_get(x_4, 1);
x_12 = lean_nat_add(x_1, x_5);
x_13 = lean_byte_array_size(x_2);
x_14 = lean_nat_dec_lt(x_12, x_13);
if (x_14 == 0)
{
lean_dec(x_12);
x_4 = x_6;
goto _start;
}
else
{
if (x_14 == 0)
{
uint8_t x_16; lean_object* x_17; lean_object* x_18; uint8_t x_19; 
lean_dec(x_12);
x_16 = l_instInhabitedUInt8;
x_17 = lean_box(x_16);
x_18 = l_outOfBounds___redArg(x_17);
x_19 = lean_unbox(x_18);
lean_dec(x_18);
x_7 = x_19;
goto block_11;
}
else
{
uint8_t x_20; 
x_20 = lean_byte_array_fget(x_2, x_12);
lean_dec(x_12);
x_7 = x_20;
goto block_11;
}
}
block_11:
{
lean_object* x_8; lean_object* x_9; 
x_8 = lean_uint8_to_nat(x_7);
x_9 = lean_nat_lxor(x_3, x_8);
lean_dec(x_3);
x_3 = x_9;
x_4 = x_6;
goto _start;
}
}
}
}
LEAN_EXPORT lean_object* lp_padctl_List_foldl___at___00checksumXor_spec__0___boxed(lean_object* x_1, lean_object* x_2, lean_object* x_3, lean_object* x_4) {
_start:
{
lean_object* x_5; 
x_5 = lp_padctl_List_foldl___at___00checksumXor_spec__0(x_1, x_2, x_3, x_4);
lean_dec(x_4);
lean_dec_ref(x_2);
lean_dec(x_1);
return x_5;
}
}
LEAN_EXPORT lean_object* lp_padctl_checksumXor(lean_object* x_1, lean_object* x_2, lean_object* x_3) {
_start:
{
lean_object* x_4; lean_object* x_5; lean_object* x_6; lean_object* x_7; 
x_4 = lean_unsigned_to_nat(0u);
x_5 = lean_nat_sub(x_3, x_2);
x_6 = l_List_range(x_5);
x_7 = lp_padctl_List_foldl___at___00checksumXor_spec__0(x_2, x_1, x_4, x_6);
lean_dec(x_6);
return x_7;
}
}
LEAN_EXPORT lean_object* lp_padctl_checksumXor___boxed(lean_object* x_1, lean_object* x_2, lean_object* x_3) {
_start:
{
lean_object* x_4; 
x_4 = lp_padctl_checksumXor(x_1, x_2, x_3);
lean_dec(x_3);
lean_dec(x_2);
lean_dec_ref(x_1);
return x_4;
}
}
LEAN_EXPORT uint32_t lp_padctl___private_Padctl_Interpreter_0__crc32Byte___lam__0(uint32_t x_1) {
_start:
{
uint32_t x_2; uint32_t x_3; uint8_t x_4; 
x_2 = 1;
x_3 = lean_uint32_land(x_1, x_2);
x_4 = lean_uint32_dec_eq(x_3, x_2);
if (x_4 == 0)
{
uint32_t x_5; 
x_5 = lean_uint32_shift_right(x_1, x_2);
return x_5;
}
else
{
uint32_t x_6; uint32_t x_7; uint32_t x_8; 
x_6 = lean_uint32_shift_right(x_1, x_2);
x_7 = 3988292384;
x_8 = lean_uint32_xor(x_6, x_7);
return x_8;
}
}
}
LEAN_EXPORT lean_object* lp_padctl___private_Padctl_Interpreter_0__crc32Byte___lam__0___boxed(lean_object* x_1) {
_start:
{
uint32_t x_2; uint32_t x_3; lean_object* x_4; 
x_2 = lean_unbox_uint32(x_1);
lean_dec(x_1);
x_3 = lp_padctl___private_Padctl_Interpreter_0__crc32Byte___lam__0(x_2);
x_4 = lean_box_uint32(x_3);
return x_4;
}
}
LEAN_EXPORT uint32_t lp_padctl___private_Padctl_Interpreter_0__crc32Byte(uint32_t x_1, uint8_t x_2) {
_start:
{
uint32_t x_3; uint32_t x_4; uint32_t x_5; uint32_t x_6; uint32_t x_7; uint32_t x_8; uint32_t x_9; uint32_t x_10; uint32_t x_11; uint32_t x_12; 
x_3 = lean_uint8_to_uint32(x_2);
x_4 = lean_uint32_xor(x_1, x_3);
x_5 = lp_padctl___private_Padctl_Interpreter_0__crc32Byte___lam__0(x_4);
x_6 = lp_padctl___private_Padctl_Interpreter_0__crc32Byte___lam__0(x_5);
x_7 = lp_padctl___private_Padctl_Interpreter_0__crc32Byte___lam__0(x_6);
x_8 = lp_padctl___private_Padctl_Interpreter_0__crc32Byte___lam__0(x_7);
x_9 = lp_padctl___private_Padctl_Interpreter_0__crc32Byte___lam__0(x_8);
x_10 = lp_padctl___private_Padctl_Interpreter_0__crc32Byte___lam__0(x_9);
x_11 = lp_padctl___private_Padctl_Interpreter_0__crc32Byte___lam__0(x_10);
x_12 = lp_padctl___private_Padctl_Interpreter_0__crc32Byte___lam__0(x_11);
return x_12;
}
}
LEAN_EXPORT lean_object* lp_padctl___private_Padctl_Interpreter_0__crc32Byte___boxed(lean_object* x_1, lean_object* x_2) {
_start:
{
uint32_t x_3; uint8_t x_4; uint32_t x_5; lean_object* x_6; 
x_3 = lean_unbox_uint32(x_1);
lean_dec(x_1);
x_4 = lean_unbox(x_2);
x_5 = lp_padctl___private_Padctl_Interpreter_0__crc32Byte(x_3, x_4);
x_6 = lean_box_uint32(x_5);
return x_6;
}
}
LEAN_EXPORT uint32_t lp_padctl_List_foldl___at___00crc32_spec__0(lean_object* x_1, lean_object* x_2, uint32_t x_3, lean_object* x_4) {
_start:
{
if (lean_obj_tag(x_4) == 0)
{
return x_3;
}
else
{
lean_object* x_5; lean_object* x_6; lean_object* x_7; lean_object* x_8; uint8_t x_9; 
x_5 = lean_ctor_get(x_4, 0);
x_6 = lean_ctor_get(x_4, 1);
x_7 = lean_nat_add(x_1, x_5);
x_8 = lean_byte_array_size(x_2);
x_9 = lean_nat_dec_lt(x_7, x_8);
if (x_9 == 0)
{
lean_dec(x_7);
x_4 = x_6;
goto _start;
}
else
{
if (x_9 == 0)
{
uint8_t x_11; lean_object* x_12; lean_object* x_13; uint8_t x_14; uint32_t x_15; 
lean_dec(x_7);
x_11 = l_instInhabitedUInt8;
x_12 = lean_box(x_11);
x_13 = l_outOfBounds___redArg(x_12);
x_14 = lean_unbox(x_13);
lean_dec(x_13);
x_15 = lp_padctl___private_Padctl_Interpreter_0__crc32Byte(x_3, x_14);
x_3 = x_15;
x_4 = x_6;
goto _start;
}
else
{
uint8_t x_17; uint32_t x_18; 
x_17 = lean_byte_array_fget(x_2, x_7);
lean_dec(x_7);
x_18 = lp_padctl___private_Padctl_Interpreter_0__crc32Byte(x_3, x_17);
x_3 = x_18;
x_4 = x_6;
goto _start;
}
}
}
}
}
LEAN_EXPORT lean_object* lp_padctl_List_foldl___at___00crc32_spec__0___boxed(lean_object* x_1, lean_object* x_2, lean_object* x_3, lean_object* x_4) {
_start:
{
uint32_t x_5; uint32_t x_6; lean_object* x_7; 
x_5 = lean_unbox_uint32(x_3);
lean_dec(x_3);
x_6 = lp_padctl_List_foldl___at___00crc32_spec__0(x_1, x_2, x_5, x_4);
lean_dec(x_4);
lean_dec_ref(x_2);
lean_dec(x_1);
x_7 = lean_box_uint32(x_6);
return x_7;
}
}
LEAN_EXPORT uint32_t lp_padctl_crc32(lean_object* x_1, lean_object* x_2, lean_object* x_3, lean_object* x_4) {
_start:
{
uint32_t x_5; uint32_t x_6; 
x_5 = 4294967295;
if (lean_obj_tag(x_4) == 0)
{
x_6 = x_5;
goto block_11;
}
else
{
lean_object* x_12; uint8_t x_13; uint32_t x_14; 
x_12 = lean_ctor_get(x_4, 0);
x_13 = lean_unbox(x_12);
x_14 = lp_padctl___private_Padctl_Interpreter_0__crc32Byte(x_5, x_13);
x_6 = x_14;
goto block_11;
}
block_11:
{
lean_object* x_7; lean_object* x_8; uint32_t x_9; uint32_t x_10; 
x_7 = lean_nat_sub(x_3, x_2);
x_8 = l_List_range(x_7);
x_9 = lp_padctl_List_foldl___at___00crc32_spec__0(x_2, x_1, x_6, x_8);
lean_dec(x_8);
x_10 = lean_uint32_xor(x_9, x_5);
return x_10;
}
}
}
LEAN_EXPORT lean_object* lp_padctl_crc32___boxed(lean_object* x_1, lean_object* x_2, lean_object* x_3, lean_object* x_4) {
_start:
{
uint32_t x_5; lean_object* x_6; 
x_5 = lp_padctl_crc32(x_1, x_2, x_3, x_4);
lean_dec(x_4);
lean_dec(x_3);
lean_dec(x_2);
lean_dec_ref(x_1);
x_6 = lean_box_uint32(x_5);
return x_6;
}
}
LEAN_EXPORT uint8_t lp_padctl_verifyChecksum(lean_object* x_1, uint8_t x_2, lean_object* x_3, lean_object* x_4, lean_object* x_5, lean_object* x_6) {
_start:
{
lean_object* x_7; uint8_t x_8; lean_object* x_17; lean_object* x_18; lean_object* x_19; uint8_t x_20; 
x_17 = lean_byte_array_size(x_1);
x_18 = lean_unsigned_to_nat(3u);
x_19 = lean_nat_add(x_5, x_18);
x_20 = lean_nat_dec_le(x_17, x_19);
if (x_20 == 0)
{
switch (x_2) {
case 0:
{
lean_object* x_21; uint8_t x_22; uint8_t x_26; 
lean_dec(x_19);
x_21 = lp_padctl_checksumSum8(x_1, x_3, x_4);
x_26 = lean_nat_dec_lt(x_5, x_17);
if (x_26 == 0)
{
uint8_t x_27; lean_object* x_28; lean_object* x_29; uint8_t x_30; 
x_27 = l_instInhabitedUInt8;
x_28 = lean_box(x_27);
x_29 = l_outOfBounds___redArg(x_28);
x_30 = lean_unbox(x_29);
lean_dec(x_29);
x_22 = x_30;
goto block_25;
}
else
{
uint8_t x_31; 
x_31 = lean_byte_array_fget(x_1, x_5);
x_22 = x_31;
goto block_25;
}
block_25:
{
lean_object* x_23; uint8_t x_24; 
x_23 = lean_uint8_to_nat(x_22);
x_24 = lean_nat_dec_eq(x_21, x_23);
lean_dec(x_21);
return x_24;
}
}
case 1:
{
lean_object* x_32; uint8_t x_33; uint8_t x_37; 
lean_dec(x_19);
x_32 = lp_padctl_checksumXor(x_1, x_3, x_4);
x_37 = lean_nat_dec_lt(x_5, x_17);
if (x_37 == 0)
{
uint8_t x_38; lean_object* x_39; lean_object* x_40; uint8_t x_41; 
x_38 = l_instInhabitedUInt8;
x_39 = lean_box(x_38);
x_40 = l_outOfBounds___redArg(x_39);
x_41 = lean_unbox(x_40);
lean_dec(x_40);
x_33 = x_41;
goto block_36;
}
else
{
uint8_t x_42; 
x_42 = lean_byte_array_fget(x_1, x_5);
x_33 = x_42;
goto block_36;
}
block_36:
{
lean_object* x_34; uint8_t x_35; 
x_34 = lean_uint8_to_nat(x_33);
x_35 = lean_nat_dec_eq(x_32, x_34);
lean_dec(x_32);
return x_35;
}
}
default: 
{
uint8_t x_43; lean_object* x_44; uint8_t x_45; lean_object* x_56; uint8_t x_57; uint8_t x_70; uint8_t x_80; 
x_43 = l_instInhabitedUInt8;
x_80 = lp_padctl_readU16le___lam__0(x_1, x_5);
if (x_80 == 0)
{
lean_object* x_81; lean_object* x_82; uint8_t x_83; 
x_81 = lean_box(x_43);
x_82 = l_outOfBounds___redArg(x_81);
x_83 = lean_unbox(x_82);
lean_dec(x_82);
x_70 = x_83;
goto block_79;
}
else
{
uint8_t x_84; 
x_84 = lean_byte_array_fget(x_1, x_5);
x_70 = x_84;
goto block_79;
}
block_55:
{
lean_object* x_46; lean_object* x_47; lean_object* x_48; lean_object* x_49; uint8_t x_50; 
x_46 = lean_uint8_to_nat(x_45);
x_47 = lean_unsigned_to_nat(65536u);
x_48 = lean_nat_mul(x_46, x_47);
x_49 = lean_nat_add(x_44, x_48);
lean_dec(x_48);
lean_dec(x_44);
x_50 = lp_padctl_readU16le___lam__0(x_1, x_19);
if (x_50 == 0)
{
lean_object* x_51; lean_object* x_52; uint8_t x_53; 
lean_dec(x_19);
x_51 = lean_box(x_43);
x_52 = l_outOfBounds___redArg(x_51);
x_53 = lean_unbox(x_52);
lean_dec(x_52);
x_7 = x_49;
x_8 = x_53;
goto block_16;
}
else
{
uint8_t x_54; 
x_54 = lean_byte_array_fget(x_1, x_19);
lean_dec(x_19);
x_7 = x_49;
x_8 = x_54;
goto block_16;
}
}
block_69:
{
lean_object* x_58; lean_object* x_59; lean_object* x_60; lean_object* x_61; lean_object* x_62; lean_object* x_63; uint8_t x_64; 
x_58 = lean_uint8_to_nat(x_57);
x_59 = lean_unsigned_to_nat(256u);
x_60 = lean_nat_mul(x_58, x_59);
x_61 = lean_nat_add(x_56, x_60);
lean_dec(x_60);
lean_dec(x_56);
x_62 = lean_unsigned_to_nat(2u);
x_63 = lean_nat_add(x_5, x_62);
x_64 = lp_padctl_readU16le___lam__0(x_1, x_63);
if (x_64 == 0)
{
lean_object* x_65; lean_object* x_66; uint8_t x_67; 
lean_dec(x_63);
x_65 = lean_box(x_43);
x_66 = l_outOfBounds___redArg(x_65);
x_67 = lean_unbox(x_66);
lean_dec(x_66);
x_44 = x_61;
x_45 = x_67;
goto block_55;
}
else
{
uint8_t x_68; 
x_68 = lean_byte_array_fget(x_1, x_63);
lean_dec(x_63);
x_44 = x_61;
x_45 = x_68;
goto block_55;
}
}
block_79:
{
lean_object* x_71; lean_object* x_72; lean_object* x_73; uint8_t x_74; 
x_71 = lean_uint8_to_nat(x_70);
x_72 = lean_unsigned_to_nat(1u);
x_73 = lean_nat_add(x_5, x_72);
x_74 = lp_padctl_readU16le___lam__0(x_1, x_73);
if (x_74 == 0)
{
lean_object* x_75; lean_object* x_76; uint8_t x_77; 
lean_dec(x_73);
x_75 = lean_box(x_43);
x_76 = l_outOfBounds___redArg(x_75);
x_77 = lean_unbox(x_76);
lean_dec(x_76);
x_56 = x_71;
x_57 = x_77;
goto block_69;
}
else
{
uint8_t x_78; 
x_78 = lean_byte_array_fget(x_1, x_73);
lean_dec(x_73);
x_56 = x_71;
x_57 = x_78;
goto block_69;
}
}
}
}
}
else
{
lean_dec(x_19);
if (x_2 == 2)
{
uint8_t x_85; 
x_85 = 0;
return x_85;
}
else
{
uint8_t x_86; 
x_86 = lean_nat_dec_le(x_17, x_5);
if (x_86 == 0)
{
switch (x_2) {
case 0:
{
lean_object* x_87; uint8_t x_88; uint8_t x_92; 
x_87 = lp_padctl_checksumSum8(x_1, x_3, x_4);
x_92 = lean_nat_dec_lt(x_5, x_17);
if (x_92 == 0)
{
uint8_t x_93; lean_object* x_94; lean_object* x_95; uint8_t x_96; 
x_93 = l_instInhabitedUInt8;
x_94 = lean_box(x_93);
x_95 = l_outOfBounds___redArg(x_94);
x_96 = lean_unbox(x_95);
lean_dec(x_95);
x_88 = x_96;
goto block_91;
}
else
{
uint8_t x_97; 
x_97 = lean_byte_array_fget(x_1, x_5);
x_88 = x_97;
goto block_91;
}
block_91:
{
lean_object* x_89; uint8_t x_90; 
x_89 = lean_uint8_to_nat(x_88);
x_90 = lean_nat_dec_eq(x_87, x_89);
lean_dec(x_87);
return x_90;
}
}
case 1:
{
lean_object* x_98; uint8_t x_99; uint8_t x_103; 
x_98 = lp_padctl_checksumXor(x_1, x_3, x_4);
x_103 = lean_nat_dec_lt(x_5, x_17);
if (x_103 == 0)
{
uint8_t x_104; lean_object* x_105; lean_object* x_106; uint8_t x_107; 
x_104 = l_instInhabitedUInt8;
x_105 = lean_box(x_104);
x_106 = l_outOfBounds___redArg(x_105);
x_107 = lean_unbox(x_106);
lean_dec(x_106);
x_99 = x_107;
goto block_102;
}
else
{
uint8_t x_108; 
x_108 = lean_byte_array_fget(x_1, x_5);
x_99 = x_108;
goto block_102;
}
block_102:
{
lean_object* x_100; uint8_t x_101; 
x_100 = lean_uint8_to_nat(x_99);
x_101 = lean_nat_dec_eq(x_98, x_100);
lean_dec(x_98);
return x_101;
}
}
default: 
{
return x_86;
}
}
}
else
{
uint8_t x_109; 
x_109 = 0;
return x_109;
}
}
}
block_16:
{
lean_object* x_9; lean_object* x_10; lean_object* x_11; lean_object* x_12; uint32_t x_13; lean_object* x_14; uint8_t x_15; 
x_9 = lean_uint8_to_nat(x_8);
x_10 = lean_unsigned_to_nat(16777216u);
x_11 = lean_nat_mul(x_9, x_10);
x_12 = lean_nat_add(x_7, x_11);
lean_dec(x_11);
lean_dec(x_7);
x_13 = lp_padctl_crc32(x_1, x_3, x_4, x_6);
x_14 = lean_uint32_to_nat(x_13);
x_15 = lean_nat_dec_eq(x_14, x_12);
lean_dec(x_12);
lean_dec(x_14);
return x_15;
}
}
}
LEAN_EXPORT lean_object* lp_padctl_verifyChecksum___boxed(lean_object* x_1, lean_object* x_2, lean_object* x_3, lean_object* x_4, lean_object* x_5, lean_object* x_6) {
_start:
{
uint8_t x_7; uint8_t x_8; lean_object* x_9; 
x_7 = lean_unbox(x_2);
x_8 = lp_padctl_verifyChecksum(x_1, x_7, x_3, x_4, x_5, x_6);
lean_dec(x_6);
lean_dec(x_5);
lean_dec(x_4);
lean_dec(x_3);
lean_dec_ref(x_1);
x_9 = lean_box(x_8);
return x_9;
}
}
LEAN_EXPORT uint8_t lp_padctl_checkMatch___lam__1(lean_object* x_1, lean_object* x_2, lean_object* x_3, lean_object* x_4, lean_object* x_5) {
_start:
{
uint8_t x_6; uint8_t x_7; lean_object* x_17; lean_object* x_18; uint8_t x_19; 
x_6 = l_instInhabitedUInt8;
x_17 = lean_nat_add(x_3, x_5);
lean_inc_ref(x_1);
lean_inc(x_17);
lean_inc_ref(x_4);
x_18 = lean_apply_2(x_1, x_4, x_17);
x_19 = lean_unbox(x_18);
if (x_19 == 0)
{
lean_object* x_20; lean_object* x_21; uint8_t x_22; 
lean_dec(x_17);
lean_dec_ref(x_4);
x_20 = lean_box(x_6);
x_21 = l_outOfBounds___redArg(x_20);
x_22 = lean_unbox(x_21);
lean_dec(x_21);
x_7 = x_22;
goto block_16;
}
else
{
uint8_t x_23; 
x_23 = lean_byte_array_fget(x_4, x_17);
lean_dec(x_17);
lean_dec_ref(x_4);
x_7 = x_23;
goto block_16;
}
block_16:
{
lean_object* x_8; uint8_t x_9; 
lean_inc(x_5);
lean_inc_ref(x_2);
x_8 = lean_apply_2(x_1, x_2, x_5);
x_9 = lean_unbox(x_8);
if (x_9 == 0)
{
lean_object* x_10; lean_object* x_11; uint8_t x_12; uint8_t x_13; 
lean_dec(x_5);
lean_dec_ref(x_2);
x_10 = lean_box(x_6);
x_11 = l_outOfBounds___redArg(x_10);
x_12 = lean_unbox(x_11);
lean_dec(x_11);
x_13 = lean_uint8_dec_eq(x_7, x_12);
return x_13;
}
else
{
uint8_t x_14; uint8_t x_15; 
x_14 = lean_byte_array_fget(x_2, x_5);
lean_dec(x_5);
lean_dec_ref(x_2);
x_15 = lean_uint8_dec_eq(x_7, x_14);
return x_15;
}
}
}
}
LEAN_EXPORT lean_object* lp_padctl_checkMatch___lam__1___boxed(lean_object* x_1, lean_object* x_2, lean_object* x_3, lean_object* x_4, lean_object* x_5) {
_start:
{
uint8_t x_6; lean_object* x_7; 
x_6 = lp_padctl_checkMatch___lam__1(x_1, x_2, x_3, x_4, x_5);
lean_dec(x_3);
x_7 = lean_box(x_6);
return x_7;
}
}
LEAN_EXPORT uint8_t lp_padctl_checkMatch(lean_object* x_1, lean_object* x_2, lean_object* x_3) {
_start:
{
lean_object* x_4; lean_object* x_5; lean_object* x_6; uint8_t x_7; 
x_4 = lean_byte_array_size(x_1);
x_5 = lean_byte_array_size(x_3);
x_6 = lean_nat_add(x_2, x_5);
x_7 = lean_nat_dec_lt(x_4, x_6);
lean_dec(x_6);
if (x_7 == 0)
{
lean_object* x_8; lean_object* x_9; lean_object* x_10; uint8_t x_11; 
x_8 = ((lean_object*)(lp_padctl_checkMatch___closed__0));
x_9 = lean_alloc_closure((void*)(lp_padctl_checkMatch___lam__1___boxed), 5, 4);
lean_closure_set(x_9, 0, x_8);
lean_closure_set(x_9, 1, x_3);
lean_closure_set(x_9, 2, x_2);
lean_closure_set(x_9, 3, x_1);
x_10 = l_List_range(x_5);
x_11 = l_List_all___redArg(x_10, x_9);
return x_11;
}
else
{
uint8_t x_12; 
lean_dec_ref(x_3);
lean_dec(x_2);
lean_dec_ref(x_1);
x_12 = 0;
return x_12;
}
}
}
LEAN_EXPORT lean_object* lp_padctl_checkMatch___boxed(lean_object* x_1, lean_object* x_2, lean_object* x_3) {
_start:
{
uint8_t x_4; lean_object* x_5; 
x_4 = lp_padctl_checkMatch(x_1, x_2, x_3);
x_5 = lean_box(x_4);
return x_5;
}
}
static lean_object* _init_lp_padctl_decodeDpadHat___closed__0(void) {
_start:
{
lean_object* x_1; lean_object* x_2; 
x_1 = lean_obj_once(&lp_padctl_toSigned___closed__0, &lp_padctl_toSigned___closed__0_once, _init_lp_padctl_toSigned___closed__0);
x_2 = lean_alloc_ctor(0, 2, 0);
lean_ctor_set(x_2, 0, x_1);
lean_ctor_set(x_2, 1, x_1);
return x_2;
}
}
static lean_object* _init_lp_padctl_decodeDpadHat___closed__1(void) {
_start:
{
lean_object* x_1; lean_object* x_2; 
x_1 = lean_obj_once(&lp_padctl_instReprChecksumAlgo_repr___closed__7, &lp_padctl_instReprChecksumAlgo_repr___closed__7_once, _init_lp_padctl_instReprChecksumAlgo_repr___closed__7);
x_2 = lean_int_neg(x_1);
return x_2;
}
}
static lean_object* _init_lp_padctl_decodeDpadHat___closed__2(void) {
_start:
{
lean_object* x_1; lean_object* x_2; 
x_1 = lean_obj_once(&lp_padctl_decodeDpadHat___closed__1, &lp_padctl_decodeDpadHat___closed__1_once, _init_lp_padctl_decodeDpadHat___closed__1);
x_2 = lean_alloc_ctor(0, 2, 0);
lean_ctor_set(x_2, 0, x_1);
lean_ctor_set(x_2, 1, x_1);
return x_2;
}
}
static lean_object* _init_lp_padctl_decodeDpadHat___closed__3(void) {
_start:
{
lean_object* x_1; lean_object* x_2; lean_object* x_3; 
x_1 = lean_obj_once(&lp_padctl_toSigned___closed__0, &lp_padctl_toSigned___closed__0_once, _init_lp_padctl_toSigned___closed__0);
x_2 = lean_obj_once(&lp_padctl_decodeDpadHat___closed__1, &lp_padctl_decodeDpadHat___closed__1_once, _init_lp_padctl_decodeDpadHat___closed__1);
x_3 = lean_alloc_ctor(0, 2, 0);
lean_ctor_set(x_3, 0, x_2);
lean_ctor_set(x_3, 1, x_1);
return x_3;
}
}
static lean_object* _init_lp_padctl_decodeDpadHat___closed__4(void) {
_start:
{
lean_object* x_1; lean_object* x_2; lean_object* x_3; 
x_1 = lean_obj_once(&lp_padctl_instReprChecksumAlgo_repr___closed__7, &lp_padctl_instReprChecksumAlgo_repr___closed__7_once, _init_lp_padctl_instReprChecksumAlgo_repr___closed__7);
x_2 = lean_obj_once(&lp_padctl_decodeDpadHat___closed__1, &lp_padctl_decodeDpadHat___closed__1_once, _init_lp_padctl_decodeDpadHat___closed__1);
x_3 = lean_alloc_ctor(0, 2, 0);
lean_ctor_set(x_3, 0, x_2);
lean_ctor_set(x_3, 1, x_1);
return x_3;
}
}
static lean_object* _init_lp_padctl_decodeDpadHat___closed__5(void) {
_start:
{
lean_object* x_1; lean_object* x_2; lean_object* x_3; 
x_1 = lean_obj_once(&lp_padctl_instReprChecksumAlgo_repr___closed__7, &lp_padctl_instReprChecksumAlgo_repr___closed__7_once, _init_lp_padctl_instReprChecksumAlgo_repr___closed__7);
x_2 = lean_obj_once(&lp_padctl_toSigned___closed__0, &lp_padctl_toSigned___closed__0_once, _init_lp_padctl_toSigned___closed__0);
x_3 = lean_alloc_ctor(0, 2, 0);
lean_ctor_set(x_3, 0, x_2);
lean_ctor_set(x_3, 1, x_1);
return x_3;
}
}
static lean_object* _init_lp_padctl_decodeDpadHat___closed__6(void) {
_start:
{
lean_object* x_1; lean_object* x_2; 
x_1 = lean_obj_once(&lp_padctl_instReprChecksumAlgo_repr___closed__7, &lp_padctl_instReprChecksumAlgo_repr___closed__7_once, _init_lp_padctl_instReprChecksumAlgo_repr___closed__7);
x_2 = lean_alloc_ctor(0, 2, 0);
lean_ctor_set(x_2, 0, x_1);
lean_ctor_set(x_2, 1, x_1);
return x_2;
}
}
static lean_object* _init_lp_padctl_decodeDpadHat___closed__7(void) {
_start:
{
lean_object* x_1; lean_object* x_2; lean_object* x_3; 
x_1 = lean_obj_once(&lp_padctl_toSigned___closed__0, &lp_padctl_toSigned___closed__0_once, _init_lp_padctl_toSigned___closed__0);
x_2 = lean_obj_once(&lp_padctl_instReprChecksumAlgo_repr___closed__7, &lp_padctl_instReprChecksumAlgo_repr___closed__7_once, _init_lp_padctl_instReprChecksumAlgo_repr___closed__7);
x_3 = lean_alloc_ctor(0, 2, 0);
lean_ctor_set(x_3, 0, x_2);
lean_ctor_set(x_3, 1, x_1);
return x_3;
}
}
static lean_object* _init_lp_padctl_decodeDpadHat___closed__8(void) {
_start:
{
lean_object* x_1; lean_object* x_2; lean_object* x_3; 
x_1 = lean_obj_once(&lp_padctl_decodeDpadHat___closed__1, &lp_padctl_decodeDpadHat___closed__1_once, _init_lp_padctl_decodeDpadHat___closed__1);
x_2 = lean_obj_once(&lp_padctl_instReprChecksumAlgo_repr___closed__7, &lp_padctl_instReprChecksumAlgo_repr___closed__7_once, _init_lp_padctl_instReprChecksumAlgo_repr___closed__7);
x_3 = lean_alloc_ctor(0, 2, 0);
lean_ctor_set(x_3, 0, x_2);
lean_ctor_set(x_3, 1, x_1);
return x_3;
}
}
static lean_object* _init_lp_padctl_decodeDpadHat___closed__9(void) {
_start:
{
lean_object* x_1; lean_object* x_2; lean_object* x_3; 
x_1 = lean_obj_once(&lp_padctl_decodeDpadHat___closed__1, &lp_padctl_decodeDpadHat___closed__1_once, _init_lp_padctl_decodeDpadHat___closed__1);
x_2 = lean_obj_once(&lp_padctl_toSigned___closed__0, &lp_padctl_toSigned___closed__0_once, _init_lp_padctl_toSigned___closed__0);
x_3 = lean_alloc_ctor(0, 2, 0);
lean_ctor_set(x_3, 0, x_2);
lean_ctor_set(x_3, 1, x_1);
return x_3;
}
}
LEAN_EXPORT lean_object* lp_padctl_decodeDpadHat(lean_object* x_1) {
_start:
{
lean_object* x_2; uint8_t x_3; 
x_2 = lean_unsigned_to_nat(0u);
x_3 = lean_nat_dec_eq(x_1, x_2);
if (x_3 == 0)
{
lean_object* x_4; uint8_t x_5; 
x_4 = lean_unsigned_to_nat(1u);
x_5 = lean_nat_dec_eq(x_1, x_4);
if (x_5 == 0)
{
lean_object* x_6; uint8_t x_7; 
x_6 = lean_unsigned_to_nat(2u);
x_7 = lean_nat_dec_eq(x_1, x_6);
if (x_7 == 0)
{
lean_object* x_8; uint8_t x_9; 
x_8 = lean_unsigned_to_nat(3u);
x_9 = lean_nat_dec_eq(x_1, x_8);
if (x_9 == 0)
{
lean_object* x_10; uint8_t x_11; 
x_10 = lean_unsigned_to_nat(4u);
x_11 = lean_nat_dec_eq(x_1, x_10);
if (x_11 == 0)
{
lean_object* x_12; uint8_t x_13; 
x_12 = lean_unsigned_to_nat(5u);
x_13 = lean_nat_dec_eq(x_1, x_12);
if (x_13 == 0)
{
lean_object* x_14; uint8_t x_15; 
x_14 = lean_unsigned_to_nat(6u);
x_15 = lean_nat_dec_eq(x_1, x_14);
if (x_15 == 0)
{
lean_object* x_16; uint8_t x_17; 
x_16 = lean_unsigned_to_nat(7u);
x_17 = lean_nat_dec_eq(x_1, x_16);
if (x_17 == 0)
{
lean_object* x_18; 
x_18 = lean_obj_once(&lp_padctl_decodeDpadHat___closed__0, &lp_padctl_decodeDpadHat___closed__0_once, _init_lp_padctl_decodeDpadHat___closed__0);
return x_18;
}
else
{
lean_object* x_19; 
x_19 = lean_obj_once(&lp_padctl_decodeDpadHat___closed__2, &lp_padctl_decodeDpadHat___closed__2_once, _init_lp_padctl_decodeDpadHat___closed__2);
return x_19;
}
}
else
{
lean_object* x_20; 
x_20 = lean_obj_once(&lp_padctl_decodeDpadHat___closed__3, &lp_padctl_decodeDpadHat___closed__3_once, _init_lp_padctl_decodeDpadHat___closed__3);
return x_20;
}
}
else
{
lean_object* x_21; 
x_21 = lean_obj_once(&lp_padctl_decodeDpadHat___closed__4, &lp_padctl_decodeDpadHat___closed__4_once, _init_lp_padctl_decodeDpadHat___closed__4);
return x_21;
}
}
else
{
lean_object* x_22; 
x_22 = lean_obj_once(&lp_padctl_decodeDpadHat___closed__5, &lp_padctl_decodeDpadHat___closed__5_once, _init_lp_padctl_decodeDpadHat___closed__5);
return x_22;
}
}
else
{
lean_object* x_23; 
x_23 = lean_obj_once(&lp_padctl_decodeDpadHat___closed__6, &lp_padctl_decodeDpadHat___closed__6_once, _init_lp_padctl_decodeDpadHat___closed__6);
return x_23;
}
}
else
{
lean_object* x_24; 
x_24 = lean_obj_once(&lp_padctl_decodeDpadHat___closed__7, &lp_padctl_decodeDpadHat___closed__7_once, _init_lp_padctl_decodeDpadHat___closed__7);
return x_24;
}
}
else
{
lean_object* x_25; 
x_25 = lean_obj_once(&lp_padctl_decodeDpadHat___closed__8, &lp_padctl_decodeDpadHat___closed__8_once, _init_lp_padctl_decodeDpadHat___closed__8);
return x_25;
}
}
else
{
lean_object* x_26; 
x_26 = lean_obj_once(&lp_padctl_decodeDpadHat___closed__9, &lp_padctl_decodeDpadHat___closed__9_once, _init_lp_padctl_decodeDpadHat___closed__9);
return x_26;
}
}
}
LEAN_EXPORT lean_object* lp_padctl_decodeDpadHat___boxed(lean_object* x_1) {
_start:
{
lean_object* x_2; 
x_2 = lp_padctl_decodeDpadHat(x_1);
lean_dec(x_1);
return x_2;
}
}
LEAN_EXPORT lean_object* lp_padctl_List_foldl___at___00decodeButtonGroup_spec__0(lean_object* x_1, lean_object* x_2, lean_object* x_3, lean_object* x_4) {
_start:
{
if (lean_obj_tag(x_4) == 0)
{
return x_3;
}
else
{
lean_object* x_5; lean_object* x_6; uint8_t x_7; lean_object* x_17; lean_object* x_18; uint8_t x_19; 
x_5 = lean_ctor_get(x_4, 0);
x_6 = lean_ctor_get(x_4, 1);
x_17 = lean_nat_add(x_1, x_5);
x_18 = lean_byte_array_size(x_2);
x_19 = lean_nat_dec_lt(x_17, x_18);
if (x_19 == 0)
{
lean_dec(x_17);
x_4 = x_6;
goto _start;
}
else
{
if (x_19 == 0)
{
uint8_t x_21; lean_object* x_22; lean_object* x_23; uint8_t x_24; 
lean_dec(x_17);
x_21 = l_instInhabitedUInt8;
x_22 = lean_box(x_21);
x_23 = l_outOfBounds___redArg(x_22);
x_24 = lean_unbox(x_23);
lean_dec(x_23);
x_7 = x_24;
goto block_16;
}
else
{
uint8_t x_25; 
x_25 = lean_byte_array_fget(x_2, x_17);
lean_dec(x_17);
x_7 = x_25;
goto block_16;
}
}
block_16:
{
lean_object* x_8; lean_object* x_9; lean_object* x_10; lean_object* x_11; lean_object* x_12; lean_object* x_13; lean_object* x_14; 
x_8 = lean_uint8_to_nat(x_7);
x_9 = lean_unsigned_to_nat(2u);
x_10 = lean_unsigned_to_nat(8u);
x_11 = lean_nat_mul(x_5, x_10);
x_12 = lean_nat_pow(x_9, x_11);
lean_dec(x_11);
x_13 = lean_nat_mul(x_8, x_12);
lean_dec(x_12);
x_14 = lean_nat_add(x_3, x_13);
lean_dec(x_13);
lean_dec(x_3);
x_3 = x_14;
x_4 = x_6;
goto _start;
}
}
}
}
LEAN_EXPORT lean_object* lp_padctl_List_foldl___at___00decodeButtonGroup_spec__0___boxed(lean_object* x_1, lean_object* x_2, lean_object* x_3, lean_object* x_4) {
_start:
{
lean_object* x_5; 
x_5 = lp_padctl_List_foldl___at___00decodeButtonGroup_spec__0(x_1, x_2, x_3, x_4);
lean_dec(x_4);
lean_dec_ref(x_2);
lean_dec(x_1);
return x_5;
}
}
LEAN_EXPORT lean_object* lp_padctl_List_foldl___at___00decodeButtonGroup_spec__1(lean_object* x_1, lean_object* x_2, lean_object* x_3) {
_start:
{
if (lean_obj_tag(x_3) == 0)
{
return x_2;
}
else
{
lean_object* x_4; lean_object* x_5; lean_object* x_6; lean_object* x_7; lean_object* x_8; lean_object* x_9; lean_object* x_10; lean_object* x_11; lean_object* x_12; uint8_t x_13; 
x_4 = lean_ctor_get(x_3, 0);
x_5 = lean_ctor_get(x_3, 1);
x_6 = lean_ctor_get(x_4, 0);
x_7 = lean_ctor_get(x_4, 1);
x_8 = lean_unsigned_to_nat(2u);
x_9 = lean_nat_pow(x_8, x_6);
x_10 = lean_nat_div(x_1, x_9);
lean_dec(x_9);
x_11 = lean_nat_mod(x_10, x_8);
lean_dec(x_10);
x_12 = lean_unsigned_to_nat(1u);
x_13 = lean_nat_dec_eq(x_11, x_12);
lean_dec(x_11);
if (x_13 == 0)
{
x_3 = x_5;
goto _start;
}
else
{
lean_object* x_15; lean_object* x_16; 
x_15 = lean_nat_pow(x_8, x_7);
x_16 = lean_nat_add(x_2, x_15);
lean_dec(x_15);
lean_dec(x_2);
x_2 = x_16;
x_3 = x_5;
goto _start;
}
}
}
}
LEAN_EXPORT lean_object* lp_padctl_List_foldl___at___00decodeButtonGroup_spec__1___boxed(lean_object* x_1, lean_object* x_2, lean_object* x_3) {
_start:
{
lean_object* x_4; 
x_4 = lp_padctl_List_foldl___at___00decodeButtonGroup_spec__1(x_1, x_2, x_3);
lean_dec(x_3);
lean_dec(x_1);
return x_4;
}
}
LEAN_EXPORT lean_object* lp_padctl_decodeButtonGroup(lean_object* x_1, lean_object* x_2, lean_object* x_3, lean_object* x_4) {
_start:
{
lean_object* x_5; lean_object* x_6; lean_object* x_7; lean_object* x_8; 
x_5 = lean_unsigned_to_nat(0u);
x_6 = l_List_range(x_3);
x_7 = lp_padctl_List_foldl___at___00decodeButtonGroup_spec__0(x_2, x_1, x_5, x_6);
lean_dec(x_6);
x_8 = lp_padctl_List_foldl___at___00decodeButtonGroup_spec__1(x_7, x_5, x_4);
lean_dec(x_7);
return x_8;
}
}
LEAN_EXPORT lean_object* lp_padctl_decodeButtonGroup___boxed(lean_object* x_1, lean_object* x_2, lean_object* x_3, lean_object* x_4) {
_start:
{
lean_object* x_5; 
x_5 = lp_padctl_decodeButtonGroup(x_1, x_2, x_3, x_4);
lean_dec(x_4);
lean_dec(x_2);
lean_dec_ref(x_1);
return x_5;
}
}
lean_object* initialize_Init(uint8_t builtin);
lean_object* initialize_padctl_Padctl_Types(uint8_t builtin);
static bool _G_initialized = false;
LEAN_EXPORT lean_object* initialize_padctl_Padctl_Interpreter(uint8_t builtin) {
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
