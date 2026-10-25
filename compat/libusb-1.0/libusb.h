/* Stub libusb header for musl/no-libusb builds.
   UsbrawDevice is unreachable at runtime when compiled without real libusb;
   this stub satisfies the C preprocessor so the Zig source compiles. */
#pragma once
#include <stdint.h>

typedef struct libusb_context libusb_context;
typedef struct libusb_device_handle libusb_device_handle;
typedef struct libusb_device libusb_device;
struct libusb_endpoint_descriptor {
    uint8_t bLength, bDescriptorType, bEndpointAddress, bmAttributes;
    uint16_t wMaxPacketSize;
    uint8_t bInterval, bRefresh, bSynchAddress;
    const unsigned char *extra;
    int extra_length;
};
struct libusb_interface_descriptor {
    uint8_t bLength, bDescriptorType, bInterfaceNumber, bAlternateSetting;
    uint8_t bNumEndpoints, bInterfaceClass, bInterfaceSubClass, bInterfaceProtocol, iInterface;
    const struct libusb_endpoint_descriptor *endpoint;
    const unsigned char *extra;
    int extra_length;
};
struct libusb_interface {
    const struct libusb_interface_descriptor *altsetting;
    int num_altsetting;
};
struct libusb_config_descriptor {
    uint8_t bLength, bDescriptorType;
    uint16_t wTotalLength;
    uint8_t bNumInterfaces, bConfigurationValue, iConfiguration, bmAttributes, MaxPower;
    const struct libusb_interface *interface;
    const unsigned char *extra;
    int extra_length;
};
static inline libusb_device *libusb_get_device(libusb_device_handle *h) { (void)h; return 0; }
static inline int libusb_get_active_config_descriptor(libusb_device *d, struct libusb_config_descriptor **cfg) {
    (void)d; (void)cfg; return -1;
}
static inline void libusb_free_config_descriptor(struct libusb_config_descriptor *cfg) { (void)cfg; }
static inline int libusb_control_transfer(libusb_device_handle *h, uint8_t type, uint8_t request,
    uint16_t value, uint16_t index, unsigned char *data, uint16_t length, unsigned int timeout) {
    (void)h; (void)type; (void)request; (void)value; (void)index; (void)data; (void)length; (void)timeout; return -1;
}

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
static inline int libusb_attach_kernel_driver(libusb_device_handle *h, int i) {
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
