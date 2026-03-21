/* Stub libusb header for musl/no-libusb builds.
   UsbrawDevice is unreachable at runtime when compiled without real libusb;
   this stub satisfies the C preprocessor so the Zig source compiles. */
#pragma once
#include <stdint.h>

typedef struct libusb_context libusb_context;
typedef struct libusb_device_handle libusb_device_handle;

#define LIBUSB_ERROR_NO_DEVICE  (-4)
#define LIBUSB_ERROR_BUSY       (-6)
#define LIBUSB_ERROR_TIMEOUT    (-7)

static inline int libusb_init(libusb_context **ctx) { (void)ctx; return -1; }
static inline void libusb_exit(libusb_context *ctx) { (void)ctx; }
static inline libusb_device_handle *libusb_open_device_with_vid_pid(
    libusb_context *ctx, uint16_t vid, uint16_t pid) {
    (void)ctx; (void)vid; (void)pid; return 0;
}
static inline int libusb_detach_kernel_driver(libusb_device_handle *h, int i) {
    (void)h; (void)i; return -1;
}
static inline int libusb_claim_interface(libusb_device_handle *h, int i) {
    (void)h; (void)i; return -1;
}
static inline int libusb_release_interface(libusb_device_handle *h, int i) {
    (void)h; (void)i; return -1;
}
static inline void libusb_close(libusb_device_handle *h) { (void)h; }
static inline int libusb_interrupt_transfer(
    libusb_device_handle *h, unsigned char ep,
    unsigned char *data, int length, int *transferred, unsigned int timeout) {
    (void)h; (void)ep; (void)data; (void)length; (void)transferred; (void)timeout;
    return -1;
}
