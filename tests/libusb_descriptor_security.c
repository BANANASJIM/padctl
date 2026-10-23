#include "config.h"
#include <stdio.h>
#include "descriptor.c"

const struct usbi_os_backend usbi_backend = {0};

void usbi_log(struct libusb_context *ctx, enum libusb_log_level level,
              const char *function, const char *format, ...) {
    (void)ctx; (void)level; (void)function; (void)format;
}

int libusb_control_transfer(libusb_device_handle *handle, uint8_t type,
                            uint8_t request, uint16_t value, uint16_t index,
                            unsigned char *data, uint16_t length,
                            unsigned int timeout) {
    (void)handle; (void)type; (void)request; (void)value; (void)index;
    (void)data; (void)length; (void)timeout;
    return LIBUSB_ERROR_NOT_SUPPORTED;
}

int main(void) {
    /* CVE-2026-23679: an interface promises an endpoint, but its descriptor is truncated. */
    const unsigned char malformed[] = {
        9, 2, 25, 0, 1, 1, 0, 0xa0, 0,
        9, 4, 0, 0, 1, 0xff, 0, 0, 0,
        7, 5
    };
    const unsigned char valid[] = {
        9, 2, 25, 0, 1, 1, 0, 0xa0, 0,
        9, 4, 0, 0, 1, 0xff, 0, 0, 0,
        7, 5, 0x81, 3, 64, 0, 1
    };
    struct libusb_config_descriptor config = {0};
    int result = parse_configuration(NULL, &config, malformed, sizeof(malformed));
    if (result >= 0) {
        for (unsigned int i = 0; i < config.bNumInterfaces; ++i) {
            const struct libusb_interface *interface = &config.interface[i];
            for (int j = 0; j < interface->num_altsetting; ++j) {
                const struct libusb_interface_descriptor *alt = &interface->altsetting[j];
                if (alt->bNumEndpoints && !alt->endpoint) {
                    fputs("malformed descriptor exposes a NULL endpoint array\n", stderr);
                    return 1;
                }
            }
        }
        clear_configuration(&config);
    }
    memset(&config, 0, sizeof(config));
    result = parse_configuration(NULL, &config, valid, sizeof(valid));
    if (result < 0 || config.bNumInterfaces != 1 ||
        config.interface[0].num_altsetting != 1 ||
        config.interface[0].altsetting[0].bNumEndpoints != 1 ||
        !config.interface[0].altsetting[0].endpoint ||
        config.interface[0].altsetting[0].endpoint[0].bEndpointAddress != 0x81) {
        fputs("valid endpoint descriptor did not survive parsing\n", stderr);
        return 1;
    }
    clear_configuration(&config);
    return 0;
}
