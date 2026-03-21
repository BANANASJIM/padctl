// Nintendo Switch Pro Controller WASM plugin.
// Handles sub-command init, SPI stick calibration, and 12-bit stick extraction.
//
// Build: clang --target=wasm32 -nostdlib -Wl,--no-entry -Wl,--export-all \
//        -Isdk/wasm -O2 -o plugins/nintendo_switch_pro.wasm plugins/nintendo_switch_pro.c

#include "padctl_plugin.h"

// Sub-command IDs
#define SUBCMD_SET_INPUT_MODE   0x03
#define SUBCMD_SPI_READ         0x10
#define SUBCMD_SET_IMU          0x40
#define SUBCMD_SET_VIBRATION    0x48

// Input report mode: standard 0x30 (full input at 60Hz)
#define INPUT_MODE_STANDARD     0x30

// SPI flash addresses
#define SPI_USER_CAL_ADDR       0x8010
#define SPI_USER_CAL_LEN        0x16
#define SPI_FACTORY_CAL_ADDR    0x603D
#define SPI_FACTORY_CAL_LEN     0x12

// Neutral rumble data (8 bytes)
static const uint8_t RUMBLE_NEUTRAL[8] = {
    0x00, 0x01, 0x40, 0x40, 0x00, 0x01, 0x40, 0x40
};

// Calibration state key
#define CAL_KEY     "sc"
#define CAL_KEY_LEN 2

// Stick calibration: center, min_delta, max_delta per axis
typedef struct {
    int16_t center;
    int16_t min_delta;
    int16_t max_delta;
} stick_axis_cal_t;

typedef struct {
    stick_axis_cal_t left_x;
    stick_axis_cal_t left_y;
    stick_axis_cal_t right_x;
    stick_axis_cal_t right_y;
} stick_cal_t;

// Default factory calibration (fallback)
static const stick_cal_t DEFAULT_CAL = {
    .left_x  = { .center = 2048, .min_delta = 512, .max_delta = 512 },
    .left_y  = { .center = 2048, .min_delta = 512, .max_delta = 512 },
    .right_x = { .center = 2048, .min_delta = 512, .max_delta = 512 },
    .right_y = { .center = 2048, .min_delta = 512, .max_delta = 512 },
};

static uint8_t global_counter = 0;

static int16_t read_i16le(const uint8_t *p) {
    return (int16_t)((uint16_t)p[0] | ((uint16_t)p[1] << 8));
}

static void write_i16le(uint8_t *p, int16_t v) {
    uint16_t u = (uint16_t)v;
    p[0] = (uint8_t)(u & 0xFF);
    p[1] = (uint8_t)(u >> 8);
}

// Build a sub-command output report (49 bytes).
// byte 0:     0x01 (output report ID)
// byte 1:     counter (0x0-0xF)
// bytes 2-9:  rumble (neutral fill)
// byte 10:    sub-command ID
// bytes 11+:  sub-command params
static int32_t build_subcmd(uint8_t *buf, uint8_t subcmd_id,
                            const uint8_t *params, int32_t params_len) {
    for (int32_t i = 0; i < 49; i++) buf[i] = 0;
    buf[0] = 0x01;
    buf[1] = global_counter & 0x0F;
    global_counter = (global_counter + 1) & 0x0F;
    for (int32_t i = 0; i < 8; i++) buf[2 + i] = RUMBLE_NEUTRAL[i];
    buf[10] = subcmd_id;
    for (int32_t i = 0; i < params_len && (11 + i) < 49; i++)
        buf[11 + i] = params[i];
    return 49;
}

// Send sub-command and wait for ACK (report 0x21 with matching sub-command ID).
// Returns 0 on success, <0 on failure.
static int32_t send_subcmd(uint8_t subcmd_id,
                           const uint8_t *params, int32_t params_len,
                           uint8_t *resp, int32_t resp_len) {
    uint8_t cmd[49];
    build_subcmd(cmd, subcmd_id, params, params_len);

    int32_t w = device_write(cmd, 49);
    if (w < 0) return w;

    // Wait for sub-command reply (Report ID 0x21, byte 14 = sub-command ID)
    for (int32_t retry = 0; retry < 20; retry++) {
        int32_t n = device_read(0, resp, resp_len);
        if (n < 0) continue;
        if (n >= 15 && resp[0] == 0x21 && resp[14] == subcmd_id)
            return n;
    }
    return -1;
}

// Parse user calibration data from SPI read response.
// SPI user calibration (22 bytes at 0x8010):
//   bytes 0-10:  left stick (max above, max below, center, min below, min above, dead zone)
//   bytes 11-21: right stick (same layout)
// Each axis is 12 bits packed in 3 bytes per pair.
static void parse_user_cal(const uint8_t *data, int32_t len, stick_cal_t *cal) {
    if (len < 22) {
        *cal = DEFAULT_CAL;
        return;
    }

    // Check if user calibration is empty (all 0xFF = not set)
    int all_ff = 1;
    for (int32_t i = 0; i < 22; i++) {
        if (data[i] != 0xFF) { all_ff = 0; break; }
    }
    if (all_ff) {
        *cal = DEFAULT_CAL;
        return;
    }

    // Left stick: bytes 0-8
    // max_above_x = data[0] | (data[1] & 0x0F) << 8
    // max_above_y = (data[1] >> 4) | data[2] << 4
    // center_x    = data[3] | (data[4] & 0x0F) << 8
    // center_y    = (data[4] >> 4) | data[5] << 4
    // min_below_x = data[6] | (data[7] & 0x0F) << 8
    // min_below_y = (data[7] >> 4) | data[8] << 4
    int16_t l_max_x = (int16_t)(data[0] | ((data[1] & 0x0F) << 8));
    int16_t l_max_y = (int16_t)((data[1] >> 4) | (data[2] << 4));
    int16_t l_cx    = (int16_t)(data[3] | ((data[4] & 0x0F) << 8));
    int16_t l_cy    = (int16_t)((data[4] >> 4) | (data[5] << 4));
    int16_t l_min_x = (int16_t)(data[6] | ((data[7] & 0x0F) << 8));
    int16_t l_min_y = (int16_t)((data[7] >> 4) | (data[8] << 4));

    cal->left_x.center    = l_cx;
    cal->left_x.max_delta = l_max_x;
    cal->left_x.min_delta = l_min_x;
    cal->left_y.center    = l_cy;
    cal->left_y.max_delta = l_max_y;
    cal->left_y.min_delta = l_min_y;

    // Right stick: bytes 11-19
    int16_t r_cx    = (int16_t)(data[11] | ((data[12] & 0x0F) << 8));
    int16_t r_cy    = (int16_t)((data[12] >> 4) | (data[13] << 4));
    int16_t r_min_x = (int16_t)(data[14] | ((data[15] & 0x0F) << 8));
    int16_t r_min_y = (int16_t)((data[15] >> 4) | (data[16] << 4));
    int16_t r_max_x = (int16_t)(data[17] | ((data[18] & 0x0F) << 8));
    int16_t r_max_y = (int16_t)((data[18] >> 4) | (data[19] << 4));

    cal->right_x.center    = r_cx;
    cal->right_x.max_delta = r_max_x;
    cal->right_x.min_delta = r_min_x;
    cal->right_y.center    = r_cy;
    cal->right_y.max_delta = r_max_y;
    cal->right_y.min_delta = r_min_y;
}

// Apply calibration to a 12-bit raw stick value.
// Returns calibrated value in -32768..32767 range.
static int16_t calibrate_axis(int16_t raw, const stick_axis_cal_t *cal) {
    int32_t centered = (int32_t)raw - (int32_t)cal->center;
    int32_t delta;

    if (centered > 0) {
        delta = (int32_t)cal->max_delta;
        if (delta == 0) delta = 1;
        int32_t result = (centered * 32767) / delta;
        if (result > 32767) result = 32767;
        return (int16_t)result;
    } else if (centered < 0) {
        delta = (int32_t)cal->min_delta;
        if (delta == 0) delta = 1;
        int32_t result = (centered * 32768) / delta;
        if (result < -32768) result = -32768;
        return (int16_t)result;
    }
    return 0;
}

// Extract a 12-bit value from 3 packed bytes. index: 0 = low, 1 = high.
static int16_t extract_12bit(const uint8_t *p, int index) {
    if (index == 0)
        return (int16_t)(p[0] | ((p[1] & 0x0F) << 8));
    else
        return (int16_t)((p[1] >> 4) | (p[2] << 4));
}

int32_t init_device(void) {
    uint8_t resp[64];

    // 1. Set input report mode to standard (0x30)
    uint8_t mode_param[1] = { INPUT_MODE_STANDARD };
    if (send_subcmd(SUBCMD_SET_INPUT_MODE, mode_param, 1, resp, 64) < 0)
        return -1;

    // 2. Enable IMU
    uint8_t imu_param[1] = { 0x01 };
    if (send_subcmd(SUBCMD_SET_IMU, imu_param, 1, resp, 64) < 0)
        return -2;

    // 3. Enable vibration
    uint8_t vib_param[1] = { 0x01 };
    if (send_subcmd(SUBCMD_SET_VIBRATION, vib_param, 1, resp, 64) < 0)
        return -3;

    // 4. Read user stick calibration from SPI flash
    uint8_t spi_params[5];
    spi_params[0] = (uint8_t)(SPI_USER_CAL_ADDR & 0xFF);
    spi_params[1] = (uint8_t)((SPI_USER_CAL_ADDR >> 8) & 0xFF);
    spi_params[2] = (uint8_t)((SPI_USER_CAL_ADDR >> 16) & 0xFF);
    spi_params[3] = (uint8_t)((SPI_USER_CAL_ADDR >> 24) & 0xFF);
    spi_params[4] = SPI_USER_CAL_LEN;

    int32_t spi_n = send_subcmd(SUBCMD_SPI_READ, spi_params, 5, resp, 64);
    stick_cal_t cal;

    if (spi_n >= 35 + SPI_USER_CAL_LEN) {
        // SPI response data starts at byte 20 in the 0x21 reply
        // (bytes 15-19 = SPI read echo: addr[4] + len[1], data at 20+)
        parse_user_cal(resp + 20, SPI_USER_CAL_LEN, &cal);
    } else {
        // Fall back to factory calibration
        spi_params[0] = (uint8_t)(SPI_FACTORY_CAL_ADDR & 0xFF);
        spi_params[1] = (uint8_t)((SPI_FACTORY_CAL_ADDR >> 8) & 0xFF);
        spi_params[2] = (uint8_t)((SPI_FACTORY_CAL_ADDR >> 16) & 0xFF);
        spi_params[3] = (uint8_t)((SPI_FACTORY_CAL_ADDR >> 24) & 0xFF);
        spi_params[4] = SPI_FACTORY_CAL_LEN;

        spi_n = send_subcmd(SUBCMD_SPI_READ, spi_params, 5, resp, 64);
        if (spi_n >= 35 + SPI_FACTORY_CAL_LEN) {
            parse_user_cal(resp + 20, SPI_FACTORY_CAL_LEN, &cal);
        } else {
            cal = DEFAULT_CAL;
        }
    }

    set_state(CAL_KEY, CAL_KEY_LEN, (const void *)&cal, sizeof(cal));
    return 0;
}

void process_calibration(const void *buf, int32_t len) {
    stick_cal_t cal;
    parse_user_cal((const uint8_t *)buf, len, &cal);
    set_state(CAL_KEY, CAL_KEY_LEN, (const void *)&cal, sizeof(cal));
}

int32_t process_report(const void *raw, int32_t raw_len,
                       void *out, int32_t out_len) {
    if (raw_len < 12 || out_len < raw_len) return -1;

    const uint8_t *src = (const uint8_t *)raw;
    uint8_t *dst = (uint8_t *)out;

    // Copy entire report
    for (int32_t i = 0; i < raw_len; i++) dst[i] = src[i];

    // Only process standard input reports (0x30)
    if (src[0] != 0x30) return 0;
    if (raw_len < 12) return 0;

    // Retrieve calibration state
    stick_cal_t cal;
    int32_t got = get_state(CAL_KEY, CAL_KEY_LEN, (void *)&cal, sizeof(cal));
    if (got < (int32_t)sizeof(cal)) {
        cal = DEFAULT_CAL;
    }

    // Extract 12-bit stick values from bytes 6-11
    // Left stick:  X = bytes[6] | (bytes[7] & 0x0F) << 8
    //              Y = (bytes[7] >> 4) | bytes[8] << 4
    // Right stick: X = bytes[9] | (bytes[10] & 0x0F) << 8
    //              Y = (bytes[10] >> 4) | bytes[11] << 4
    int16_t lx_raw = extract_12bit(src + 6, 0);
    int16_t ly_raw = extract_12bit(src + 6, 1);
    int16_t rx_raw = extract_12bit(src + 9, 0);
    int16_t ry_raw = extract_12bit(src + 9, 1);

    int16_t lx = calibrate_axis(lx_raw, &cal.left_x);
    int16_t ly = calibrate_axis(ly_raw, &cal.left_y);
    int16_t rx = calibrate_axis(rx_raw, &cal.right_x);
    int16_t ry = calibrate_axis(ry_raw, &cal.right_y);

    // Write calibrated 16-bit values back into the output buffer at bytes 6-13
    // (overwriting the raw packed bytes with properly aligned i16le values)
    write_i16le(dst + 6, lx);
    write_i16le(dst + 8, ly);
    write_i16le(dst + 10, rx);
    write_i16le(dst + 12, ry);

    return 0;
}
