// padctl WASM plugin SDK
#pragma once

#include <stdint.h>

// Host functions (imported from "env" module)
// Declare as extern -- padctl provides these at load time.

// Read a HID Feature Report. Returns bytes read, <0 on error.
extern int32_t device_read(int32_t report_id, void *buf, int32_t len);

// Write an HID Output Report. Returns bytes written, <0 on error.
extern int32_t device_write(const void *buf, int32_t len);

// Write a log message. level: 0=debug, 1=error. Truncated at 256 bytes.
// C name padctl_log; WASM import name is env.log (avoids math.h collision).
#ifdef __wasm__
__attribute__((import_module("env"), import_name("log")))
#endif
extern void padctl_log(int32_t level, const char *msg, int32_t len);

// Read a device config field value as UTF-8. Returns byte count, <0 on error.
extern int32_t get_config(const char *key, int32_t key_len,
                          void *out, int32_t out_len);

// Write a cross-frame persistent key-value entry.
extern void set_state(const char *key, int32_t key_len,
                      const void *val, int32_t val_len);

// Read a persistent key-value entry. Returns byte count, 0 if not found.
extern int32_t get_state(const char *key, int32_t key_len,
                         void *out, int32_t out_len);

// Plugin exports (implement these -- all optional)

// Called once after device open. Return 0 on success.
int32_t init_device(void);

// Called with calibration Feature Report data.
void process_calibration(const void *buf, int32_t len);

// Called per input frame (when wasm.overrides.process_report = true).
// Return >= 0 to override with output buffer, < 0 to drop frame.
int32_t process_report(const void *raw, int32_t raw_len,
                       void *out, int32_t out_len);
