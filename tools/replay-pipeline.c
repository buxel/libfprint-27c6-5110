/*
 * replay-pipeline.c — Offline preprocessing replay for Goodix 5xx raw frames
 *
 * Reads raw captured frames (uint16 LE arrays, 88×80 = 14,080 bytes) and
 * an optional calibration.bin, then applies the same preprocessing pipeline
 * as goodix5xx.c:
 *
 *   1. linear_subtract (calibration frame)
 *   2. squash_frame_percentile (P0.1–P99 → 0-255)
 *   3. unsharp_mask (configurable boost factor)
 *   4. crop (88 → target width)
 *
 * Outputs a processed PGM that can be fed to sigfm-batch.
 *
 * Usage:
 *   replay-pipeline --raw frame.bin --cal calibration.bin -o output.pgm
 *                   [--boost=N] [--width=W] [--height=H] [--scan-width=S]
 *
 * Build:  see Makefile
 *
 * SPDX-License-Identifier: LGPL-2.1-or-later
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>

/* ================================================================== */
/* Parameters (matching goodix5xx driver defaults)                     */
/* ================================================================== */

#define DEFAULT_SCAN_WIDTH  88
#define DEFAULT_WIDTH       64
#define DEFAULT_HEIGHT      80
#define DEFAULT_BOOST       2

/* Clamp macro (matching GLib CLAMP) */
#define CLAMP(x, lo, hi) ((x) < (lo) ? (lo) : ((x) > (hi) ? (hi) : (x)))
#define MAX(a, b)         ((a) > (b) ? (a) : (b))

/* ================================================================== */
/* Preprocessing functions (copied from goodix5xx.c, types replaced)   */
/* ================================================================== */

static void
linear_subtract_inplace(uint16_t *src, uint16_t *by, uint16_t len)
{
    const uint16_t mx = 0xffff;
    for (uint16_t n = 0; n != len; ++n)
        src[n] = MAX(0, (int)mx - (((int)mx - (int)src[n]) - ((int)mx - (int)by[n])));
}

static void
squash_frame_linear(uint16_t *frame, uint8_t *squashed, uint16_t frame_size)
{
    uint16_t mn = 0xffff;
    uint16_t mx = 0;

    for (int i = 0; i != frame_size; ++i) {
        if (frame[i] < mn) mn = frame[i];
        if (frame[i] > mx) mx = frame[i];
    }

    for (int i = 0; i != frame_size; ++i) {
        uint16_t pix = frame[i];
        if (pix - mn == 0 || mx - mn == 0)
            squashed[i] = 0;
        else
            squashed[i] = (uint8_t)((pix - mn) * 0xff / (mx - mn));
    }
}

static void
squash_frame_percentile(uint16_t *frame, uint8_t *squashed, uint16_t frame_size)
{
    uint32_t hist[256] = { 0 };
    for (int i = 0; i < frame_size; i++)
        hist[frame[i] >> 8]++;

    /* P0.1 (black level) */
    uint32_t target_lo = (uint32_t)(frame_size * 1u + 999u) / 1000u;
    uint32_t count = 0;
    int bin_lo = 0;
    for (int b = 0; b < 256; b++) {
        count += hist[b];
        if (count >= target_lo) { bin_lo = b; break; }
    }

    /* P99 (white level) */
    uint32_t target_hi = (uint32_t)(frame_size * 99u) / 100u;
    count = 0;
    int bin_hi = 255;
    for (int b = 255; b >= 0; b--) {
        count += hist[b];
        if ((uint32_t)frame_size - count <= target_hi) { bin_hi = b; break; }
    }

    if (bin_hi <= bin_lo) {
        squash_frame_linear(frame, squashed, frame_size);
        return;
    }

    uint16_t plo = (uint16_t)(bin_lo << 8);
    uint16_t phi = (uint16_t)(bin_hi << 8);
    int range = (int)phi - (int)plo;

    for (int i = 0; i < frame_size; i++) {
        int v = (int)frame[i] - (int)plo;
        if (v <= 0)         squashed[i] = 0;
        else if (v >= range) squashed[i] = 255;
        else                squashed[i] = (uint8_t)(v * 255 / range);
    }
}

static void
unsharp_mask_inplace(uint8_t *img, int w, int h, int boost)
{
    uint8_t *blurred = malloc((size_t)w * h);
    if (!blurred) { perror("malloc"); return; }

    for (int y = 0; y < h; y++) {
        for (int x = 0; x < w; x++) {
            int sum = 0, weight = 0;
            for (int dy = -1; dy <= 1; dy++) {
                int ny = y + dy;
                if (ny < 0 || ny >= h) continue;
                for (int dx = -1; dx <= 1; dx++) {
                    int nx = x + dx;
                    if (nx < 0 || nx >= w) continue;
                    int wpx = (dx == 0 ? 2 : 1) * (dy == 0 ? 2 : 1);
                    sum += wpx * img[ny * w + nx];
                    weight += wpx;
                }
            }
            blurred[y * w + x] = (uint8_t)(sum / weight);
        }
    }

    for (int i = 0; i < w * h; i++) {
        int v = boost * (int)img[i] - (boost - 1) * (int)blurred[i];
        img[i] = (uint8_t)CLAMP(v, 0, 255);
    }

    free(blurred);
}

/* ================================================================== */
/* File I/O                                                            */
/* ================================================================== */

static uint16_t *
read_raw(const char *path, int expected_pixels)
{
    FILE *f = fopen(path, "rb");
    if (!f) { perror(path); return NULL; }

    size_t nbytes = (size_t)expected_pixels * 2;
    uint16_t *buf = malloc(nbytes);
    if (!buf) { perror("malloc"); fclose(f); return NULL; }

    size_t got = fread(buf, 1, nbytes, f);
    fclose(f);

    if (got != nbytes) {
        fprintf(stderr, "%s: expected %zu bytes, got %zu\n", path, nbytes, got);
        free(buf);
        return NULL;
    }

    return buf;
}

static int
write_pgm(const char *path, const uint8_t *img, int w, int h)
{
    FILE *f = fopen(path, "wb");
    if (!f) { perror(path); return -1; }
    fprintf(f, "P5\n%d %d\n255\n", w, h);
    fwrite(img, 1, (size_t)w * h, f);
    fclose(f);
    return 0;
}

/* ================================================================== */
/* Usage                                                               */
/* ================================================================== */

static void
usage(const char *argv0)
{
    fprintf(stderr,
        "Usage: %s --raw frame.bin [--cal calibration.bin] -o output.pgm\n"
        "          [--boost=N]       unsharp mask boost factor (default: %d)\n"
        "          [--scan-width=N]  raw frame width (default: %d)\n"
        "          [--height=N]      raw frame height (default: %d)\n"
        "          [--width=N]       output crop width (default: %d)\n"
        "          [--no-crop]       skip cropping step\n"
        "          [--no-unsharp]    skip unsharp mask step\n"
        "          [--batch DIR]     process all raw_*.bin in DIR\n"
        "\n"
        "Replays the goodix5xx preprocessing pipeline offline.\n"
        "Raw .bin files: uint16 LE arrays (%d×%d = %d bytes)\n",
        argv0,
        DEFAULT_BOOST, DEFAULT_SCAN_WIDTH, DEFAULT_HEIGHT, DEFAULT_WIDTH,
        DEFAULT_SCAN_WIDTH, DEFAULT_HEIGHT,
        DEFAULT_SCAN_WIDTH * DEFAULT_HEIGHT * 2);
    exit(1);
}

/* ================================================================== */
/* Process one frame                                                   */
/* ================================================================== */

static int
process_frame(const char *raw_path, const char *cal_path, const char *out_path,
              int scan_width, int height, int out_width, int boost,
              int do_crop, int do_unsharp)
{
    int frame_size = scan_width * height;

    uint16_t *frame = read_raw(raw_path, frame_size);
    if (!frame) return -1;

    /* Step 1: calibration subtract */
    if (cal_path) {
        uint16_t *cal = read_raw(cal_path, frame_size);
        if (!cal) {
            fprintf(stderr, "Warning: cannot read calibration, skipping subtract\n");
        } else {
            linear_subtract_inplace(frame, cal, (uint16_t)frame_size);
            free(cal);
        }
    }

    /* Step 2: percentile stretch → 8-bit */
    uint8_t *squashed = malloc((size_t)frame_size);
    if (!squashed) { perror("malloc"); free(frame); return -1; }
    squash_frame_percentile(frame, squashed, (uint16_t)frame_size);
    free(frame);

    /* Step 3: unsharp mask */
    if (do_unsharp && boost > 0)
        unsharp_mask_inplace(squashed, scan_width, height, boost);

    /* Step 4: crop */
    int final_w = do_crop ? out_width : scan_width;
    uint8_t *output;

    if (do_crop && out_width < scan_width) {
        int offset = (scan_width - out_width) / 2;
        output = malloc((size_t)out_width * height);
        if (!output) { perror("malloc"); free(squashed); return -1; }
        for (int y = 0; y < height; y++)
            memcpy(output + y * out_width,
                   squashed + y * scan_width + offset,
                   (size_t)out_width);
        free(squashed);
    } else {
        output = squashed;
        final_w = scan_width;
    }

    int ret = write_pgm(out_path, output, final_w, height);
    free(output);

    if (ret == 0)
        printf("  %s → %s (%d×%d, boost=%d)\n", raw_path, out_path, final_w, height, boost);

    return ret;
}

/* ================================================================== */
/* Batch mode: process all raw_*.bin in a directory                     */
/* ================================================================== */

#include <dirent.h>

static int
batch_process(const char *dir, const char *cal_path,
              int scan_width, int height, int out_width, int boost,
              int do_crop, int do_unsharp)
{
    DIR *d = opendir(dir);
    if (!d) { perror(dir); return -1; }

    /* Auto-detect calibration.bin in the same directory */
    char auto_cal[1024];
    if (!cal_path) {
        snprintf(auto_cal, sizeof(auto_cal), "%s/calibration.bin", dir);
        FILE *f = fopen(auto_cal, "rb");
        if (f) {
            fclose(f);
            cal_path = auto_cal;
            printf("  Auto-detected calibration: %s\n", cal_path);
        }
    }

    int count = 0, errors = 0;
    struct dirent *ent;
    while ((ent = readdir(d)) != NULL) {
        if (strncmp(ent->d_name, "raw_", 4) != 0) continue;
        size_t len = strlen(ent->d_name);
        if (len < 8 || strcmp(ent->d_name + len - 4, ".bin") != 0) continue;

        char raw_path[1024], out_path[1024];
        snprintf(raw_path, sizeof(raw_path), "%s/%s", dir, ent->d_name);

        /* raw_0001.bin → 0001.pgm */
        char base[256];
        strncpy(base, ent->d_name + 4, sizeof(base) - 1);
        base[sizeof(base) - 1] = '\0';
        char *dot = strrchr(base, '.');
        if (dot) strcpy(dot, ".pgm");
        snprintf(out_path, sizeof(out_path), "%s/%s", dir, base);

        if (process_frame(raw_path, cal_path, out_path,
                          scan_width, height, out_width, boost,
                          do_crop, do_unsharp) == 0)
            count++;
        else
            errors++;
    }

    closedir(d);
    printf("\n  Processed: %d frames (%d errors)\n", count, errors);
    return errors > 0 ? -1 : 0;
}

/* ================================================================== */
/* Main                                                                */
/* ================================================================== */

int
main(int argc, char *argv[])
{
    const char *raw_path = NULL;
    const char *cal_path = NULL;
    const char *out_path = NULL;
    const char *batch_dir = NULL;
    int scan_width = DEFAULT_SCAN_WIDTH;
    int height = DEFAULT_HEIGHT;
    int out_width = DEFAULT_WIDTH;
    int boost = DEFAULT_BOOST;
    int do_crop = 1;
    int do_unsharp = 1;

    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "--raw") == 0 && i + 1 < argc)
            raw_path = argv[++i];
        else if (strcmp(argv[i], "--cal") == 0 && i + 1 < argc)
            cal_path = argv[++i];
        else if (strcmp(argv[i], "-o") == 0 && i + 1 < argc)
            out_path = argv[++i];
        else if (strcmp(argv[i], "--batch") == 0 && i + 1 < argc)
            batch_dir = argv[++i];
        else if (strncmp(argv[i], "--boost=", 8) == 0)
            boost = atoi(argv[i] + 8);
        else if (strncmp(argv[i], "--scan-width=", 13) == 0)
            scan_width = atoi(argv[i] + 13);
        else if (strncmp(argv[i], "--height=", 9) == 0)
            height = atoi(argv[i] + 9);
        else if (strncmp(argv[i], "--width=", 8) == 0)
            out_width = atoi(argv[i] + 8);
        else if (strcmp(argv[i], "--no-crop") == 0)
            do_crop = 0;
        else if (strcmp(argv[i], "--no-unsharp") == 0)
            do_unsharp = 0;
        else if (strcmp(argv[i], "-h") == 0 || strcmp(argv[i], "--help") == 0)
            usage(argv[0]);
        else {
            fprintf(stderr, "Unknown option: %s\n", argv[i]);
            usage(argv[0]);
        }
    }

    printf("replay-pipeline: scan=%d×%d → crop=%d×%d  boost=%d\n",
           scan_width, height, out_width, height, boost);

    if (batch_dir)
        return batch_process(batch_dir, cal_path,
                             scan_width, height, out_width, boost,
                             do_crop, do_unsharp) == 0 ? 0 : 1;

    if (!raw_path || !out_path) {
        fprintf(stderr, "Must specify --raw and -o (or --batch)\n");
        usage(argv[0]);
    }

    return process_frame(raw_path, cal_path, out_path,
                         scan_width, height, out_width, boost,
                         do_crop, do_unsharp) == 0 ? 0 : 1;
}
