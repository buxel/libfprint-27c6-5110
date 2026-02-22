/*
 * sigfm-batch.c — Offline SIGFM enrollment + verification benchmark
 *
 * Reads PGM images, simulates the enrollment / verification lifecycle
 * using libfprint's SIGFM library (FAST-9 + BRIEF-256), and reports
 * match scores and FRR.  All processing is offline — no sensor required.
 *
 * Usage:
 *   sigfm-batch --enroll e1.pgm e2.pgm ... --verify v1.pgm v2.pgm ...
 *               [--quality-gate=N] [--score-threshold=N] [--template-study]
 *
 * Build:  see Makefile
 *
 * SPDX-License-Identifier: LGPL-2.1-or-later
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "sigfm.h"

/* ------------------------------------------------------------------ */
/* Defaults                                                            */
/* ------------------------------------------------------------------ */

#define DEFAULT_SCORE_THRESHOLD  40
#define DEFAULT_QUALITY_GATE     25
#define MAX_TEMPLATE_ENTRIES    128

/* ------------------------------------------------------------------ */
/* PGM reader (binary P5)                                              */
/* ------------------------------------------------------------------ */

static unsigned char *
read_pgm(const char *path, int *out_w, int *out_h)
{
    FILE *f = fopen(path, "rb");
    if (!f) { perror(path); return NULL; }

    char magic[3];
    if (fscanf(f, "%2s", magic) != 1 || strcmp(magic, "P5") != 0) {
        fprintf(stderr, "Not a binary PGM (P5): %s\n", path);
        fclose(f); return NULL;
    }

    int c;
    while ((c = fgetc(f)) == ' ' || c == '\t' || c == '\r' || c == '\n');
    while (c == '#') {
        while ((c = fgetc(f)) != '\n' && c != EOF);
        while ((c = fgetc(f)) == ' ' || c == '\t' || c == '\r' || c == '\n');
    }
    ungetc(c, f);

    int w, h, maxval;
    if (fscanf(f, "%d %d %d", &w, &h, &maxval) != 3) {
        fprintf(stderr, "Bad PGM header: %s\n", path);
        fclose(f); return NULL;
    }
    fgetc(f); /* consume trailing whitespace */

    if (maxval != 255) {
        fprintf(stderr, "Unsupported bit depth (maxval=%d): %s\n", maxval, path);
        fclose(f); return NULL;
    }

    unsigned char *buf = malloc((size_t)w * h);
    if (!buf) { perror("malloc"); fclose(f); return NULL; }

    if (fread(buf, 1, (size_t)w * h, f) != (size_t)w * h) {
        fprintf(stderr, "Short read: %s\n", path);
        free(buf); fclose(f); return NULL;
    }

    fclose(f);
    *out_w = w;
    *out_h = h;
    return buf;
}

/* ------------------------------------------------------------------ */
/* Template management                                                 */
/* ------------------------------------------------------------------ */

typedef struct {
    SigfmImgInfo *entries[MAX_TEMPLATE_ENTRIES];
    int            scores[MAX_TEMPLATE_ENTRIES]; /* best match score against rest */
    int            count;
} Template;

static void
template_init(Template *t)
{
    memset(t, 0, sizeof(*t));
}

static void
template_free(Template *t)
{
    for (int i = 0; i < t->count; i++)
        sigfm_free_info(t->entries[i]);
    t->count = 0;
}

static int
template_add(Template *t, SigfmImgInfo *info)
{
    if (t->count >= MAX_TEMPLATE_ENTRIES) return -1;
    t->entries[t->count] = info;
    t->scores[t->count] = 0;
    t->count++;
    return 0;
}

/* Match a probe against the template, return best score */
static int
template_match(Template *t, SigfmImgInfo *probe, int *best_idx)
{
    int best = -1;
    int bidx = -1;
    for (int i = 0; i < t->count; i++) {
        int score = sigfm_match_score(t->entries[i], probe);
        if (score > best) {
            best = score;
            bidx = i;
        }
    }
    if (best_idx) *best_idx = bidx;
    return best;
}

/* Template study: replace weakest entry if probe is better */
static int
template_study(Template *t, SigfmImgInfo *probe)
{
    if (t->count < 2) return 0;

    /* Find probe's average score against template */
    long probe_total = 0;
    for (int i = 0; i < t->count; i++) {
        int s = sigfm_match_score(t->entries[i], probe);
        if (s < 0) s = 0;
        probe_total += s;
    }
    int probe_avg = (int)(probe_total / t->count);

    /* Find each entry's average score against the rest */
    int worst_idx = 0;
    int worst_avg = 0x7fffffff;
    for (int i = 0; i < t->count; i++) {
        long total = 0;
        for (int j = 0; j < t->count; j++) {
            if (i == j) continue;
            int s = sigfm_match_score(t->entries[i], t->entries[j]);
            if (s < 0) s = 0;
            total += s;
        }
        int avg = (int)(total / (t->count - 1));
        t->scores[i] = avg;
        if (avg < worst_avg) {
            worst_avg = avg;
            worst_idx = i;
        }
    }

    /* Replace weakest if probe is better */
    if (probe_avg > worst_avg) {
        sigfm_free_info(t->entries[worst_idx]);
        t->entries[worst_idx] = sigfm_copy_info(probe);
        t->scores[worst_idx] = probe_avg;
        return 1; /* updated */
    }
    return 0; /* no update */
}

/* ------------------------------------------------------------------ */
/* Usage                                                               */
/* ------------------------------------------------------------------ */

static void
usage(const char *argv0)
{
    fprintf(stderr,
        "Usage: %s --enroll e1.pgm [e2.pgm ...] --verify v1.pgm [v2.pgm ...]\n"
        "          [--quality-gate=N]    keypoint threshold for enrollment (default: %d)\n"
        "          [--score-threshold=N] match score threshold (default: %d)\n"
        "          [--template-study]    update template after successful verifies\n"
        "          [--sort-subtemplates] rank enrolled frames, keep best N\n"
        "          [--max-subtemplates=N] max enrolled frames to keep (default: 20)\n"
        "\n"
        "Reads processed PGM images (64×80, as output by img-capture or replay-pipeline),\n"
        "enrolls from the first set, verifies against the second, and reports FRR.\n",
        argv0, DEFAULT_QUALITY_GATE, DEFAULT_SCORE_THRESHOLD);
    exit(1);
}

/* ------------------------------------------------------------------ */
/* Main                                                                */
/* ------------------------------------------------------------------ */

int
main(int argc, char *argv[])
{
    /* Parse arguments */
    const char *enroll_files[512];
    const char *verify_files[512];
    int n_enroll = 0, n_verify = 0;
    int quality_gate = DEFAULT_QUALITY_GATE;
    int score_threshold = DEFAULT_SCORE_THRESHOLD;
    int do_template_study = 0;
    int do_sort = 0;
    int max_subtemplates = 20;

    enum { NONE, ENROLL, VERIFY } mode = NONE;

    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "--enroll") == 0) {
            mode = ENROLL;
        } else if (strcmp(argv[i], "--verify") == 0) {
            mode = VERIFY;
        } else if (strncmp(argv[i], "--quality-gate=", 15) == 0) {
            quality_gate = atoi(argv[i] + 15);
        } else if (strncmp(argv[i], "--score-threshold=", 18) == 0) {
            score_threshold = atoi(argv[i] + 18);
        } else if (strcmp(argv[i], "--template-study") == 0) {
            do_template_study = 1;
        } else if (strcmp(argv[i], "--sort-subtemplates") == 0) {
            do_sort = 1;
        } else if (strncmp(argv[i], "--max-subtemplates=", 19) == 0) {
            max_subtemplates = atoi(argv[i] + 19);
        } else if (strcmp(argv[i], "--help") == 0 || strcmp(argv[i], "-h") == 0) {
            usage(argv[0]);
        } else if (argv[i][0] == '-') {
            fprintf(stderr, "Unknown option: %s\n", argv[i]);
            usage(argv[0]);
        } else {
            if (mode == ENROLL && n_enroll < 512)
                enroll_files[n_enroll++] = argv[i];
            else if (mode == VERIFY && n_verify < 512)
                verify_files[n_verify++] = argv[i];
            else if (mode == NONE) {
                fprintf(stderr, "Specify --enroll or --verify before filenames\n");
                usage(argv[0]);
            }
        }
    }

    if (n_enroll == 0) {
        fprintf(stderr, "No enrollment files specified\n");
        usage(argv[0]);
    }

    /* ── Enrollment ─────────────────────────────────────────────── */

    Template tmpl;
    template_init(&tmpl);

    int enroll_rejected = 0;
    int enroll_kp_min = 999, enroll_kp_max = 0;
    long enroll_kp_total = 0;

    printf("Enrollment: %d frames (quality gate: %d keypoints)\n", n_enroll, quality_gate);

    for (int i = 0; i < n_enroll; i++) {
        int w, h;
        unsigned char *pix = read_pgm(enroll_files[i], &w, &h);
        if (!pix) {
            fprintf(stderr, "  [%02d] SKIP (read failed): %s\n", i, enroll_files[i]);
            enroll_rejected++;
            continue;
        }

        SigfmImgInfo *info = sigfm_extract(pix, w, h);
        free(pix);

        if (!info) {
            printf("  [%02d] REJECT (extraction failed): %s\n", i, enroll_files[i]);
            enroll_rejected++;
            continue;
        }

        int kp = sigfm_keypoints_count(info);
        if (kp < enroll_kp_min) enroll_kp_min = kp;
        if (kp > enroll_kp_max) enroll_kp_max = kp;
        enroll_kp_total += kp;

        if (kp < quality_gate) {
            printf("  [%02d] REJECT (keypoints %d < %d): %s\n",
                   i, kp, quality_gate, enroll_files[i]);
            sigfm_free_info(info);
            enroll_rejected++;
            continue;
        }

        template_add(&tmpl, info);
        printf("  [%02d] OK     (keypoints: %d): %s\n", i, kp, enroll_files[i]);
    }

    int enrolled = tmpl.count;
    printf("\n  Enrolled: %d/%d (rejected: %d)\n", enrolled, n_enroll, enroll_rejected);
    if (enrolled > 0) {
        printf("  Keypoints: min=%d max=%d mean=%ld\n",
               enroll_kp_min, enroll_kp_max,
               enroll_kp_total / (n_enroll - enroll_rejected > 0 ? n_enroll - enroll_rejected : 1));
    }

    if (enrolled == 0) {
        fprintf(stderr, "\nNo frames enrolled — cannot verify.\n");
        template_free(&tmpl);
        return 1;
    }

    /* Sort subtemplates: compute pairwise scores, keep top N */
    if (do_sort && tmpl.count > max_subtemplates) {
        printf("\n  Sorting subtemplates (keeping top %d of %d)...\n",
               max_subtemplates, tmpl.count);

        /* Compute average pairwise score for each entry */
        for (int i = 0; i < tmpl.count; i++) {
            long total = 0;
            for (int j = 0; j < tmpl.count; j++) {
                if (i == j) continue;
                int s = sigfm_match_score(tmpl.entries[i], tmpl.entries[j]);
                if (s < 0) s = 0;
                total += s;
            }
            tmpl.scores[i] = (int)(total / (tmpl.count - 1));
        }

        /* Bubble sort by score (descending), then truncate */
        for (int i = 0; i < tmpl.count - 1; i++) {
            for (int j = i + 1; j < tmpl.count; j++) {
                if (tmpl.scores[j] > tmpl.scores[i]) {
                    SigfmImgInfo *tmp_e = tmpl.entries[i];
                    tmpl.entries[i] = tmpl.entries[j];
                    tmpl.entries[j] = tmp_e;
                    int tmp_s = tmpl.scores[i];
                    tmpl.scores[i] = tmpl.scores[j];
                    tmpl.scores[j] = tmp_s;
                }
            }
        }

        /* Free excess entries */
        for (int i = max_subtemplates; i < tmpl.count; i++)
            sigfm_free_info(tmpl.entries[i]);
        tmpl.count = max_subtemplates;

        printf("  Kept %d subtemplates (score range: %d–%d)\n",
               tmpl.count, tmpl.scores[tmpl.count - 1], tmpl.scores[0]);
    }

    /* ── Verification ───────────────────────────────────────────── */

    if (n_verify == 0) {
        printf("\nNo verification files — done.\n");
        template_free(&tmpl);
        return 0;
    }

    printf("\nVerification: %d frames (threshold: %d)\n", n_verify, score_threshold);

    int match_ok = 0, match_fail = 0, match_error = 0;
    long score_total = 0;
    int score_min = 999999, score_max = -1;
    int template_updates = 0;

    for (int i = 0; i < n_verify; i++) {
        int w, h;
        unsigned char *pix = read_pgm(verify_files[i], &w, &h);
        if (!pix) {
            fprintf(stderr, "  [%02d] ERROR (read failed): %s\n", i, verify_files[i]);
            match_error++;
            continue;
        }

        SigfmImgInfo *info = sigfm_extract(pix, w, h);
        free(pix);

        if (!info) {
            printf("  [%02d] FAIL  (extraction failed): %s\n", i, verify_files[i]);
            match_fail++;
            continue;
        }

        int kp = sigfm_keypoints_count(info);
        int best_idx;
        int score = template_match(&tmpl, info, &best_idx);

        if (score < 0) {
            printf("  [%02d] ERROR (match error): %s\n", i, verify_files[i]);
            sigfm_free_info(info);
            match_error++;
            continue;
        }

        if (score < score_min) score_min = score;
        if (score > score_max) score_max = score;
        score_total += score;

        const char *result;
        if (score >= score_threshold) {
            result = "MATCH";
            match_ok++;

            if (do_template_study) {
                int updated = template_study(&tmpl, info);
                if (updated) {
                    template_updates++;
                    printf("  [%02d] %-5s score=%d/%d kp=%d (template updated): %s\n",
                           i, result, score, score_threshold, kp, verify_files[i]);
                    sigfm_free_info(info);
                    continue;
                }
            }
        } else {
            result = "FAIL ";
            match_fail++;
        }

        printf("  [%02d] %s score=%d/%d kp=%d: %s\n",
               i, result, score, score_threshold, kp, verify_files[i]);

        sigfm_free_info(info);
    }

    /* ── Summary ────────────────────────────────────────────────── */

    int total_attempts = match_ok + match_fail;
    printf("\n");
    printf("═══════════════════════════════════════════\n");
    printf("  Results\n");
    printf("───────────────────────────────────────────\n");
    printf("  Enrolled:          %d subtemplates\n", tmpl.count);
    printf("  Verify attempts:   %d\n", total_attempts);
    printf("  Matches:           %d\n", match_ok);
    printf("  Rejections:        %d\n", match_fail);
    printf("  Errors:            %d\n", match_error);
    if (total_attempts > 0) {
        double frr = (double)match_fail / total_attempts * 100.0;
        printf("  FRR:               %.1f%%\n", frr);
        printf("  Score: min=%d max=%d mean=%ld\n",
               score_min, score_max, score_total / total_attempts);
    }
    if (do_template_study)
        printf("  Template updates:  %d\n", template_updates);
    printf("═══════════════════════════════════════════\n");

    template_free(&tmpl);
    return (match_fail > 0) ? 1 : 0;
}
