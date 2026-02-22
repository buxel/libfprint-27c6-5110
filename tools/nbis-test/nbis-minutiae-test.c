/*
 * nbis-minutiae-test.c
 *
 * Standalone NBIS minutiae count test for the goodixtls 511 sensor.
 *
 * Reads a raw 8-bit PGM (P5) file and reports the number of minutiae
 * detected by mindtct at a given effective resolution (ppmm).
 *
 * Usage:  nbis-minutiae-test <file.pgm> <ppmm>
 *   ppmm  - pixels per millimetre  (508 DPI native → 20.0)
 *           At Nx upscale report ppmm = 20.0 * N
 *
 * Build:  see Makefile
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* NBIS headers (bundled in libfprint) */
#include <lfs.h>

/* g_lfsparms_V2 is defined in nbis/mindtct/globals.c, which we compile in */
extern LFSPARMS g_lfsparms_V2;

/* ------------------------------------------------------------------ */
/* Minimal P5 (binary PGM) reader                                      */
/* ------------------------------------------------------------------ */
static unsigned char *
read_pgm (const char *path, int *out_w, int *out_h)
{
    FILE *f = fopen (path, "rb");
    if (!f) { perror (path); return NULL; }

    char magic[3];
    int  w, h, maxval;

    if (fscanf (f, "%2s", magic) != 1 || strcmp (magic, "P5") != 0) {
        fprintf (stderr, "Not a binary PGM (P5): %s\n", path);
        fclose (f); return NULL;
    }

    /* Skip lines beginning with '#' (comments) */
    int c;
    while ((c = fgetc (f)) == ' ' || c == '\t' || c == '\r' || c == '\n');

    /* Might be a comment line */
    while (c == '#') {
        while ((c = fgetc (f)) != '\n' && c != EOF);
        while ((c = fgetc (f)) == ' ' || c == '\t' || c == '\r' || c == '\n');
    }
    ungetc (c, f);

    if (fscanf (f, "%d %d %d", &w, &h, &maxval) != 3) {
        fprintf (stderr, "Bad PGM header: %s\n", path);
        fclose (f); return NULL;
    }
    /* consume the single whitespace byte that follows the header */
    fgetc (f);

    if (maxval != 255) {
        fprintf (stderr, "Unsupported bit depth (maxval=%d)\n", maxval);
        fclose (f); return NULL;
    }

    unsigned char *buf = malloc ((size_t)w * h);
    if (!buf) { perror ("malloc"); fclose (f); return NULL; }

    if (fread (buf, 1, (size_t)w * h, f) != (size_t)w * h) {
        fprintf (stderr, "Short read: %s\n", path);
        free (buf); fclose (f); return NULL;
    }

    fclose (f);
    *out_w = w;
    *out_h = h;
    return buf;
}

/* ------------------------------------------------------------------ */
/* Bilinear upscale                                                     */
/* ------------------------------------------------------------------ */
static unsigned char *
upscale_bilinear (unsigned char *src, int sw, int sh, int scale,
                  int *out_w, int *out_h)
{
    int dw = sw * scale;
    int dh = sh * scale;
    unsigned char *dst = malloc ((size_t)dw * dh);
    if (!dst) { perror ("malloc"); return NULL; }

    for (int dy = 0; dy < dh; dy++) {
        double fy = (double)dy / scale;
        int    sy  = (int)fy;
        double wy  = fy - sy;
        int    sy1 = sy + 1 < sh ? sy + 1 : sh - 1;

        for (int dx = 0; dx < dw; dx++) {
            double fx = (double)dx / scale;
            int    sx  = (int)fx;
            double wx  = fx - sx;
            int    sx1 = sx + 1 < sw ? sx + 1 : sw - 1;

            double v =
                src[sy  * sw + sx ] * (1-wx) * (1-wy) +
                src[sy  * sw + sx1] * wx      * (1-wy) +
                src[sy1 * sw + sx ] * (1-wx)  * wy     +
                src[sy1 * sw + sx1] * wx       * wy;

            dst[dy * dw + dx] = (unsigned char)(v + 0.5);
        }
    }

    *out_w = dw;
    *out_h = dh;
    return dst;
}

/* ------------------------------------------------------------------ */
/* Save P5 PGM (for visual inspection)                                 */
/* ------------------------------------------------------------------ */
static void
save_pgm (const char *path, unsigned char *data, int w, int h)
{
    FILE *f = fopen (path, "wb");
    if (!f) { perror (path); return; }
    fprintf (f, "P5\n%d %d\n255\n", w, h);
    fwrite (data, 1, (size_t)w * h, f);
    fclose (f);
}

/* ------------------------------------------------------------------ */
/* main                                                                 */
/* ------------------------------------------------------------------ */
int
main (int argc, char **argv)
{
    if (argc < 3) {
        fprintf (stderr,
                 "Usage: %s <input.pgm> <ppmm> [scale] [save_path.pgm]\n"
                 "  ppmm  pixels per mm of original capture (508 dpi → 20.0)\n"
                 "  scale integer upscale factor (default 1)\n"
                 "  save  optional path to save the (upscaled) image used\n",
                 argv[0]);
        return 1;
    }

    const char *path  = argv[1];
    double      ppmm  = atof (argv[2]);
    int         scale = argc >= 4 ? atoi (argv[3]) : 1;
    const char *save  = argc >= 5 ? argv[4] : NULL;

    int   w, h;
    unsigned char *img = read_pgm (path, &w, &h);
    if (!img) return 1;

    printf ("Loaded %s  %d×%d px\n", path, w, h);

    unsigned char *work = img;
    int ww = w, wh = h;

    if (scale > 1) {
        work = upscale_bilinear (img, w, h, scale, &ww, &wh);
        if (!work) { free (img); return 1; }
        printf ("Upscaled %dx  →  %d×%d px  (ppmm=%.1f)\n",
                scale, ww, wh, ppmm);
    }

    if (save)
        save_pgm (save, work, ww, wh);

    /* --- run mindtct --- */
    MINUTIAE      *minutiae     = NULL;
    int           *quality_map  = NULL;
    int           *dir_map      = NULL;
    int           *lc_map       = NULL;
    int           *lf_map       = NULL;
    int           *hc_map       = NULL;
    int            map_w, map_h;
    unsigned char *bdata        = NULL;
    int            bw, bh, bd;

    LFSPARMS lfsparms = g_lfsparms_V2;
    lfsparms.remove_perimeter_pts = 0; /* full image, not partial */

    int ret = get_minutiae (&minutiae, &quality_map, &dir_map,
                            &lc_map, &lf_map, &hc_map,
                            &map_w, &map_h,
                            &bdata, &bw, &bh, &bd,
                            work, ww, wh, 8, ppmm, &lfsparms);
    if (ret) {
        fprintf (stderr, "get_minutiae failed: code %d\n", ret);
    } else {
        printf ("Minutiae detected: %d\n", minutiae ? minutiae->num : 0);

        /* Print per-minutia detail (type, x, y, direction, reliability) */
        if (minutiae && minutiae->num > 0) {
            printf ("  #    x    y  dir  rel  type\n");
            for (int i = 0; i < minutiae->num && i < 40; i++) {
                MINUTIA *m = minutiae->list[i];
                printf ("  %-3d  %-4d %-4d %-4d %-4.2f %s\n",
                        i, m->x, m->y, m->direction,
                        m->reliability,
                        m->type == RIDGE_ENDING ? "ending" : "bifur");
            }
            if (minutiae->num > 40)
                printf ("  ... (%d more)\n", minutiae->num - 40);
        }
    }

    /* cleanup */
    if (minutiae)   free_minutiae (minutiae);
    if (quality_map) free (quality_map);
    if (dir_map)     free (dir_map);
    if (lc_map)      free (lc_map);
    if (lf_map)      free (lf_map);
    if (hc_map)      free (hc_map);
    if (bdata)       free (bdata);
    if (work != img) free (work);
    free (img);

    return ret ? 1 : 0;
}
