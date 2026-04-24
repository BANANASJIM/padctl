#!/usr/bin/env bash
# Probe: does UHID_CREATE2 inside the container actually spawn an evdev node
# we can see via `/dev/input/eventN`? Run a minimal C program that opens
# /dev/uhid, sends UHID_CREATE2, waits, and lists /dev/input.
set -euo pipefail
cat > /tmp/uhid_probe.c <<'EOF'
#include <errno.h>
#include <fcntl.h>
#include <linux/uhid.h>
#include <stdio.h>
#include <string.h>
#include <sys/ioctl.h>
#include <unistd.h>

static const unsigned char RDESC[] = {
    0x05,0x01, 0x09,0x05, 0xA1,0x01,
    0x05,0x09, 0x19,0x01, 0x29,0x01,
    0x15,0x00, 0x25,0x01, 0x75,0x01, 0x95,0x01, 0x81,0x02,
    0x75,0x07, 0x95,0x01, 0x81,0x03,
    0x05,0x01, 0x09,0x30, 0x15,0x00, 0x26,0xFF,0x00,
    0x75,0x08, 0x95,0x01, 0x81,0x02,
    0xC0
};

int main(void) {
    int fd = open("/dev/uhid", O_RDWR | O_CLOEXEC);
    if (fd < 0) { perror("open /dev/uhid"); return 2; }
    struct uhid_event ev = {0};
    ev.type = UHID_CREATE2;
    strcpy((char*)ev.u.create2.name, "wave5-probe");
    strcpy((char*)ev.u.create2.uniq, "wave5-probe-uniq");
    strcpy((char*)ev.u.create2.phys, "wave5-probe-phys");
    ev.u.create2.rd_size = sizeof(RDESC);
    ev.u.create2.bus = 0x03;
    ev.u.create2.vendor = 0xFADE;
    ev.u.create2.product = 0xBEEF;
    memcpy(ev.u.create2.rd_data, RDESC, sizeof(RDESC));
    ssize_t n = write(fd, &ev, sizeof(ev));
    if (n < 0) { perror("write UHID_CREATE2"); return 3; }
    printf("UHID_CREATE2 wrote %zd bytes\n", n);
    fflush(stdout);
    /* Block reading events — non-blocking, a few polls */
    fcntl(fd, F_SETFL, O_NONBLOCK);
    for (int i = 0; i < 5; i++) {
        usleep(100000);
        while (read(fd, &ev, sizeof(ev)) > 0) {
            printf("uhid event type=%u\n", ev.type);
            fflush(stdout);
        }
    }
    /* Poll /dev/input for matching evdev node, up to 2s */
    for (int sec = 0; sec < 20; sec++) {
        for (int i = 0; i < 128; i++) {
            char path[64];
            snprintf(path, sizeof(path), "/dev/input/event%d", i);
            int efd = open(path, O_RDONLY | O_NONBLOCK);
            if (efd < 0) continue;
            unsigned short id[4] = {0};
            if (ioctl(efd, 0x80084502, id) == 0 && id[1] == 0xFADE) {
                printf("  FOUND %s: bus=%04x vid=%04x pid=%04x\n",
                       path, id[0], id[1], id[2]);
                close(efd);
                return 0;
            }
            close(efd);
        }
        usleep(100000);
    }
    printf("NOT FOUND after 2s poll\n");
    return 1;
}
EOF
gcc -o /tmp/uhid_probe /tmp/uhid_probe.c
/tmp/uhid_probe
