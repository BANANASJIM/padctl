/* Linux configuration for the static libusb build (glibc and musl). */
#define _GNU_SOURCE 1
#define PLATFORM_POSIX 1
#define DEFAULT_VISIBILITY __attribute__((visibility("default")))
#define PRINTF_FORMAT(a, b) __attribute__((format(printf, a, b)))
#define ENABLE_LOGGING 1
#define HAVE_CLOCK_GETTIME 1
#define HAVE_NFDS_T 1
#define HAVE_PTHREAD_CONDATTR_SETCLOCK 1
#define HAVE_STDINT_H 1
#define HAVE_STDIO_H 1
#define HAVE_STDLIB_H 1
#define HAVE_STRING_H 1
#define HAVE_STRINGS_H 1
#define HAVE_STRUCT_TIMESPEC 1
#define HAVE_SYSLOG 1
#define HAVE_SYS_STAT_H 1
#define HAVE_SYS_TIME_H 1
#define HAVE_SYS_TYPES_H 1
#define HAVE_UNISTD_H 1
