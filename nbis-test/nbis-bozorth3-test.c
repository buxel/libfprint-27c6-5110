/*
 * nbis-bozorth3-test.c
 *
 * Extract NBIS minutiae from two PGM images and run bozorth3 match.
 * Confirms the bozorth3 score when used on goodixtls511 images.
 *
 * Usage:  nbis-bozorth3-test <enroll.pgm> <verify.pgm> <ppmm> [scale]
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

#include <lfs.h>
#include <bozorth.h>

extern LFSPARMS g_lfsparms_V2;

/* Bozorth3 globals required by the library */
int     bz_verbose = 0;
FILE   *errorfp;

/* bz_drvrs.c entry points (not in bozorth.h) */
extern int bozorth_probe_init  (struct xyt_struct *pstruct);
extern int bozorth_to_gallery  (int probe_len, struct xyt_struct *pstruct,
                                 struct xyt_struct *gstruct);

/* ------------------------------------------------------------------ */
/* PGM reader / bilinear upscaler (same as nbis-minutiae-test.c)       */
/* ------------------------------------------------------------------ */
static unsigned char *
read_pgm (const char *path, int *out_w, int *out_h)
{
    FILE *f = fopen (path, "rb");
    if (!f) { perror (path); return NULL; }
    char magic[3];
    int w, h, maxval, c;
    if (fscanf (f, "%2s", magic) != 1 || strcmp (magic, "P5") != 0) {
        fprintf (stderr, "Not P5: %s\n", path); fclose (f); return NULL;
    }
    while ((c = fgetc (f)) == ' ' || c == '\t' || c == '\r' || c == '\n');
    while (c == '#') { while ((c = fgetc (f)) != '\n' && c != EOF); while ((c = fgetc (f)) == ' ' || c == '\t' || c == '\r' || c == '\n'); }
    ungetc (c, f);
    if (fscanf (f, "%d %d %d", &w, &h, &maxval) != 3 || maxval != 255) {
        fprintf (stderr, "Bad header: %s\n", path); fclose (f); return NULL;
    }
    fgetc (f);
    unsigned char *buf = malloc ((size_t)w * h);
    fread (buf, 1, (size_t)w * h, f);
    fclose (f);
    *out_w = w; *out_h = h;
    return buf;
}

static unsigned char *
upscale (unsigned char *src, int sw, int sh, int scale, int *dw, int *dh)
{
    *dw = sw * scale; *dh = sh * scale;
    unsigned char *dst = malloc ((size_t)*dw * *dh);
    for (int dy = 0; dy < *dh; dy++) {
        double fy = (double)dy / scale; int sy = (int)fy; double wy = fy - sy;
        int sy1 = sy + 1 < sh ? sy + 1 : sh - 1;
        for (int dx = 0; dx < *dw; dx++) {
            double fx = (double)dx / scale; int sx = (int)fx; double wx = fx - sx;
            int sx1 = sx + 1 < sw ? sx + 1 : sw - 1;
            double v = src[sy*sw+sx]*(1-wx)*(1-wy) + src[sy*sw+sx1]*wx*(1-wy)
                     + src[sy1*sw+sx]*(1-wx)*wy    + src[sy1*sw+sx1]*wx*wy;
            dst[dy * *dw + dx] = (unsigned char)(v + 0.5);
        }
    }
    return dst;
}

/* ------------------------------------------------------------------ */
/* Run mindtct and populate xyt_struct                                  */
/* ------------------------------------------------------------------ */
static int
image_to_xyt (const char *path, int scale, double ppmm,
              struct xyt_struct *xyt, int *out_nmin)
{
    int w, h;
    unsigned char *img = read_pgm (path, &w, &h);
    if (!img) return -1;

    int ww = w, wh = h;
    unsigned char *work = img;
    if (scale > 1) {
        work = upscale (img, w, h, scale, &ww, &wh);
    }

    MINUTIAE      *minutiae   = NULL;
    int           *qm = NULL, *dm = NULL, *lc = NULL, *lf = NULL, *hc = NULL;
    int            mw, mh;
    unsigned char *bd = NULL;
    int            bw, bh, bbpp;

    LFSPARMS lfsparms = g_lfsparms_V2;
    lfsparms.remove_perimeter_pts = 0;

    int ret = get_minutiae (&minutiae, &qm, &dm, &lc, &lf, &hc,
                            &mw, &mh, &bd, &bw, &bh, &bbpp,
                            work, ww, wh, 8, ppmm, &lfsparms);
    if (work != img) free (work);
    free (img);

    if (ret) {
        fprintf (stderr, "%s: get_minutiae failed (%d)\n", path, ret);
        return -1;
    }

    *out_nmin = minutiae ? minutiae->num : 0;
    printf ("  %s (%dx): %d minutiae\n", path, scale, *out_nmin);

    int nmin = minutiae ? (minutiae->num < MAX_BOZORTH_MINUTIAE ? minutiae->num
                                                                : MAX_BOZORTH_MINUTIAE)
                       : 0;

    for (int i = 0; i < nmin; i++) {
        MINUTIA *m = minutiae->list[i];
        int nx, ny, nt;
        lfs2nist_minutia_XYT (&nx, &ny, &nt, m, ww, wh);
        xyt->xcol[i]     = nx;
        xyt->ycol[i]     = ny;
        xyt->thetacol[i] = nt > 180 ? nt - 360 : nt;
    }
    xyt->nrows = nmin;

    if (minutiae) free_minutiae (minutiae);
    free (qm); free (dm); free (lc); free (lf); free (hc); free (bd);
    return 0;
}

/* ------------------------------------------------------------------ */
int
main (int argc, char **argv)
{
    if (argc < 4) {
        fprintf (stderr, "Usage: %s <enroll.pgm> <verify.pgm> <ppmm> [scale]\n", argv[0]);
        return 1;
    }

    errorfp = stderr;  /* required by bozorth3 */

    const char *enroll_path = argv[1];
    const char *verify_path = argv[2];
    double      ppmm        = atof (argv[3]);
    int         scale       = argc >= 5 ? atoi (argv[4]) : 1;

    printf ("=== NBIS bozorth3 match test ===\n");
    printf ("  ppmm=%.1f  scale=%dx\n\n", ppmm, scale);

    struct xyt_struct *enroll_xyt = calloc (1, sizeof *enroll_xyt);
    struct xyt_struct *verify_xyt = calloc (1, sizeof *verify_xyt);

    int ne, nv;
    if (image_to_xyt (enroll_path, scale, ppmm, enroll_xyt, &ne) < 0) return 1;
    if (image_to_xyt (verify_path, scale, ppmm, verify_xyt, &nv) < 0) return 1;

    printf ("\nBozorth3 requires ~8 minutiae minimum in each print.\n");
    printf ("Enrolled: %d minutiae,  Verify: %d minutiae\n", ne, nv);

    if (ne < 3 || nv < 3) {
        printf ("RESULT: Skipping bozorth3 — too few minutiae (%d / %d)\n", ne, nv);
        printf ("VERDICT: NBIS not viable for this sensor.\n");
    } else {
        /* bozorth3 API: probe_init on template, then gallery compare */
        int probe_len = bozorth_probe_init (enroll_xyt);
        int score     = bozorth_to_gallery (probe_len, enroll_xyt, verify_xyt);
        printf ("Bozorth3 score: %d\n", score);
        printf ("VERDICT: score %s threshold (40)\n", score >= 40 ? ">=" : "<");
    }

    free (enroll_xyt);
    free (verify_xyt);
    return 0;
}
