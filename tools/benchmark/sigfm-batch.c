/*
 * sigfm-batch.c — Offline SIGFM enrollment + verification benchmark
 *
 * Reads PGM images, simulates the enrollment / verification lifecycle
 * using libfprint's SIGFM library (FAST-9 + BRIEF-256), and reports
 * match scores and FRR.  All processing is offline — no sensor required.
 *
 * Usage:
 *   sigfm-batch --enroll e1.pgm e2.pgm ... --verify v1.pgm v2.pgm ...
 *               [--quality-gate=N] [--score-threshold=N] [--stddev-gate=N]
 *               [--template-study] [--study-threshold=N] [--csv]
 *
 * Build:  see Makefile
 *
 * SPDX-License-Identifier: LGPL-2.1-or-later
 */

#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "sigfm.h"

/* ------------------------------------------------------------------ */
/* Defaults                                                            */
/* ------------------------------------------------------------------ */

/* Match the driver's score_threshold (goodix511.c, img_dev_class->score_threshold) */
#define DEFAULT_SCORE_THRESHOLD  6

/* Keypoint quality gate — matches fp-image.c sigfm_keypoints_count() < 25 check */
#define DEFAULT_QUALITY_GATE     25

/* Pixel stddev quality gate — mirrors goodix5xx.c QUALITY_STDDEV_MIN.
 * Canonical source: libfprint-fork/libfprint/drivers/goodixtls/goodix5xx.c
 * The driver rejects frames with stddev < 25 via RETRY_CENTER_FINGER
 * *before* SIGFM extraction even runs. */
#define DEFAULT_STDDEV_GATE      25

#define MAX_TEMPLATE_ENTRIES    128

/* ------------------------------------------------------------------ */
/* Pixel stddev — mirrors goodix5xx.c quality gate                      */
/* Canonical source: goodix5xx.c scan_on_read_img(), QUALITY_STDDEV_MIN */
/* ------------------------------------------------------------------ */

static int
pixel_stddev(const unsigned char *img, int npx)
{
    long sum = 0;
    for (int i = 0; i < npx; i++)
        sum += img[i];
    int mean = (int)(sum / npx);
    long var = 0;
    for (int i = 0; i < npx; i++) {
        int d = (int)img[i] - mean;
        var += d * d;
    }
    return (int)sqrt((double)var / npx);
}

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

/* Quality-ranked enrollment insertion (E4):
 * Once template has min_fill entries, only add a new frame if its keypoint
 * count exceeds the current weakest entry.  If the template is full,
 * replace the weakest entry.  Effect: enrolled sub-templates converge to
 * the highest-quality captures from the enrollment set. */
static int
template_add_quality(Template *t, SigfmImgInfo *info, int min_fill)
{
    int kp = sigfm_keypoints_count(info);

    /* Phase 1: fill up to min_fill unconditionally */
    if (t->count < min_fill) {
        t->entries[t->count] = info;
        t->scores[t->count] = kp;
        t->count++;
        return 0;
    }

    /* Phase 2: find weakest entry by keypoint count */
    int worst_idx = 0;
    int worst_kp = t->scores[0];
    for (int i = 1; i < t->count; i++) {
        if (t->scores[i] < worst_kp) {
            worst_kp = t->scores[i];
            worst_idx = i;
        }
    }

    /* Only insert if better than worst */
    if (kp <= worst_kp) {
        sigfm_free_info(info);
        return -1; /* rejected */
    }

    if (t->count < MAX_TEMPLATE_ENTRIES) {
        /* Still room — just add */
        t->entries[t->count] = info;
        t->scores[t->count] = kp;
        t->count++;
    } else {
        /* Full — replace worst */
        sigfm_free_info(t->entries[worst_idx]);
        t->entries[worst_idx] = info;
        t->scores[worst_idx] = kp;
    }
    return 0;
}

/* Diversity-based pruning (E5):
 * After enrollment, iteratively remove the entry that is most similar
 * (highest pairwise score) to any other remaining entry, until we reach
 * the target count.  This maximizes placement diversity by eliminating
 * redundant near-duplicate captures. */
static void
template_diversity_prune(Template *t, int target_count, FILE *out)
{
    if (t->count <= target_count) return;

    fprintf(out, "\n  Diversity pruning (keeping %d of %d)...\n",
            target_count, t->count);

    while (t->count > target_count) {
        /* Find the pair (i,j) with the highest match score */
        int best_i = 0, best_j = 1, best_s = -1;
        for (int i = 0; i < t->count; i++) {
            for (int j = i + 1; j < t->count; j++) {
                int s = sigfm_match_score(t->entries[i], t->entries[j]);
                if (s > best_s) {
                    best_s = s;
                    best_i = i;
                    best_j = j;
                }
            }
        }

        /* Of the two most-similar entries, remove the one with fewer keypoints */
        int kp_i = sigfm_keypoints_count(t->entries[best_i]);
        int kp_j = sigfm_keypoints_count(t->entries[best_j]);
        int remove = (kp_i <= kp_j) ? best_i : best_j;

        sigfm_free_info(t->entries[remove]);
        /* Shift remaining entries down */
        for (int k = remove; k < t->count - 1; k++) {
            t->entries[k] = t->entries[k + 1];
            t->scores[k] = t->scores[k + 1];
        }
        t->count--;
    }
    fprintf(out, "  Kept %d diverse subtemplates\n", t->count);
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
/* Template study v2: Windows-driver-inspired multi-layer approach      */
/* Modelled on FUN_18001e110 / FUN_18001f500 in AlgoMilan.c            */
/* ------------------------------------------------------------------ */

/* Minimum probe keypoints for study absorption (mirrors quality > 0x0f) */
#define STUDY_MIN_KP            15

/* Degradation lock: stop studying after this many consecutive failed updates */
#define STUDY_MAX_FAILED        20

/* Minimum total matches before allowing any study update */
#define STUDY_MIN_OBSERVATIONS   5

typedef struct {
    int  hit_counts[MAX_TEMPLATE_ENTRIES]; /* per-entry: times it was best match */
    int  kp_counts[MAX_TEMPLATE_ENTRIES];  /* per-entry: keypoint count */
    int  total_matches;                     /* total successful verifications */
    int  failed_updates;                    /* consecutive failed update attempts */
    int  locked;                            /* 1 = degradation lock active */
} StudyState;

static void
study_state_init(StudyState *s, Template *t)
{
    memset(s, 0, sizeof(*s));
    /* Record initial keypoint counts for enrolled entries */
    for (int i = 0; i < t->count; i++)
        s->kp_counts[i] = sigfm_keypoints_count(t->entries[i]);
}

/* Record a match hit on the best-matching entry */
static void
study_record_hit(StudyState *s, int best_idx)
{
    if (best_idx >= 0 && best_idx < MAX_TEMPLATE_ENTRIES)
        s->hit_counts[best_idx]++;
    s->total_matches++;
}

/* Windows-style template study with multi-layer protection */
static int
template_study_v2(Template *t, SigfmImgInfo *probe, StudyState *state)
{
    if (t->count < 2) return 0;

    /* Layer 6: Degradation lock — stop studying permanently */
    if (state->locked) return 0;

    /* Layer 5: Observation gate — need enough matches before studying */
    if (state->total_matches < STUDY_MIN_OBSERVATIONS) {
        state->failed_updates++;
        if (state->failed_updates > STUDY_MAX_FAILED) state->locked = 1;
        return 0;
    }

    /* Layer 1: Quality gate — probe must have minimum keypoints */
    int probe_kp = sigfm_keypoints_count(probe);
    if (probe_kp < STUDY_MIN_KP) {
        state->failed_updates++;
        if (state->failed_updates > STUDY_MAX_FAILED) state->locked = 1;
        return 0;
    }

    /* Compute pairwise cross-scores for all entries */
    int cross_avg[MAX_TEMPLATE_ENTRIES];
    int anchor_idx = 0;
    int anchor_score = -1;

    for (int i = 0; i < t->count; i++) {
        long total = 0;
        for (int j = 0; j < t->count; j++) {
            if (i == j) continue;
            int s = sigfm_match_score(t->entries[i], t->entries[j]);
            if (s < 0) s = 0;
            total += s;
        }
        cross_avg[i] = (int)(total / (t->count - 1));
        t->scores[i] = cross_avg[i];

        /* Layer 3: Find anchor (best-connected entry) */
        if (cross_avg[i] > anchor_score) {
            anchor_score = cross_avg[i];
            anchor_idx = i;
        }
    }

    /* Layer 4: Find replacement target — entry with lowest hit count,
     *          breaking ties by lowest cross-score. Skip anchor. */
    int target_idx = -1;
    int target_hits = 0x7fffffff;
    int target_score = 0x7fffffff;

    for (int i = 0; i < t->count; i++) {
        if (i == anchor_idx) continue;  /* Layer 3: anchor protection */

        int hits = state->hit_counts[i];
        if (hits < target_hits ||
            (hits == target_hits && cross_avg[i] < target_score)) {
            target_hits = hits;
            target_score = cross_avg[i];
            target_idx = i;
        }
    }

    if (target_idx < 0) {
        state->failed_updates++;
        if (state->failed_updates > STUDY_MAX_FAILED) state->locked = 1;
        return 0;
    }

    /* Layer 2: Quality comparison — probe must be ≥60% of target's quality.
     * Mirrors Windows: probe_quality*10 < matched_quality*6 → reject */
    int target_kp = state->kp_counts[target_idx];
    if (probe_kp * 10 < target_kp * 6) {
        state->failed_updates++;
        if (state->failed_updates > STUDY_MAX_FAILED) state->locked = 1;
        return 0;
    }

    /* Final check: probe must actually score better than the target against
     * the rest of the template (otherwise we'd be making it worse). */
    long probe_total = 0;
    for (int i = 0; i < t->count; i++) {
        if (i == target_idx) continue;
        int s = sigfm_match_score(t->entries[i], probe);
        if (s < 0) s = 0;
        probe_total += s;
    }
    int probe_avg = (int)(probe_total / (t->count - 1));

    if (probe_avg <= cross_avg[target_idx]) {
        state->failed_updates++;
        if (state->failed_updates > STUDY_MAX_FAILED) state->locked = 1;
        return 0;
    }

    /* All layers passed — replace target entry */
    sigfm_free_info(t->entries[target_idx]);
    t->entries[target_idx] = sigfm_copy_info(probe);
    t->scores[target_idx] = probe_avg;
    state->kp_counts[target_idx] = probe_kp;
    state->hit_counts[target_idx] = 0;  /* reset hit count for new entry */
    state->failed_updates = 0;          /* reset degradation counter on success */
    return 1; /* updated */
}

/* ------------------------------------------------------------------ */
/* Usage                                                               */
/* ------------------------------------------------------------------ */

static void
usage(const char *argv0)
{
    fprintf(stderr,
        "Usage: %s --enroll e1.pgm [e2.pgm ...] --verify v1.pgm [v2.pgm ...]\n"
        "          [--quality-gate=N]    keypoint threshold (enroll+verify, default: %d)\n"
        "          [--stddev-gate=N]     pixel stddev threshold (enroll+verify, default: %d)\n"
        "          [--score-threshold=N] match score threshold (default: %d)\n"
        "          [--template-study]    update template after successful verifies\n"
        "          [--study-v2]           use Windows-driver-style multi-layer study\n"
        "          [--quality-enroll]     quality-ranked enrollment insertion (E4)\n"
        "          [--diversity-prune]    diversity-based sub-template pruning (E5)\n"
        "          [--sort-subtemplates] rank enrolled frames, keep best N\n"
        "          [--max-subtemplates=N] max enrolled frames to keep (default: 20)\n"
        "\n"
        "Reads processed PGM images (64×80, as output by img-capture or replay-pipeline),\n"
        "enrolls from the first set, verifies against the second, and reports FRR.\n"
        "\n"
        "Quality gates mirror the driver's two-stage rejection:\n"
        "  1. stddev-gate — goodix5xx.c QUALITY_STDDEV_MIN (pre-SIGFM)\n"
        "  2. quality-gate — fp-image.c keypoint count < N (post-SIGFM)\n"
        "Gated frames are SKIPPED (not counted as failures).\n",
        argv0, DEFAULT_QUALITY_GATE, DEFAULT_STDDEV_GATE, DEFAULT_SCORE_THRESHOLD);
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
    int stddev_gate = DEFAULT_STDDEV_GATE;
    int score_threshold = DEFAULT_SCORE_THRESHOLD;
    int study_threshold = -1;  /* -1 = use score_threshold */
    int do_template_study = 0;
    int do_study_v2 = 0;
    int do_csv = 0;
    int do_sort = 0;
    int do_quality_enroll = 0;
    int do_diversity_prune = 0;
    int max_subtemplates = 20;

    enum { NONE, ENROLL, VERIFY } mode = NONE;

    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "--enroll") == 0) {
            mode = ENROLL;
        } else if (strcmp(argv[i], "--verify") == 0) {
            mode = VERIFY;
        } else if (strncmp(argv[i], "--quality-gate=", 15) == 0) {
            quality_gate = atoi(argv[i] + 15);
        } else if (strncmp(argv[i], "--stddev-gate=", 14) == 0) {
            stddev_gate = atoi(argv[i] + 14);
        } else if (strncmp(argv[i], "--score-threshold=", 18) == 0) {
            score_threshold = atoi(argv[i] + 18);
        } else if (strcmp(argv[i], "--template-study") == 0) {
            do_template_study = 1;
        } else if (strcmp(argv[i], "--study-v2") == 0) {
            do_study_v2 = 1;
            do_template_study = 1; /* v2 implies study */
        } else if (strncmp(argv[i], "--study-threshold=", 18) == 0) {
            study_threshold = atoi(argv[i] + 18);
            do_template_study = 1; /* implies --template-study */
        } else if (strcmp(argv[i], "--csv") == 0) {
            do_csv = 1;
        } else if (strcmp(argv[i], "--sort-subtemplates") == 0) {
            do_sort = 1;
        } else if (strcmp(argv[i], "--quality-enroll") == 0) {
            do_quality_enroll = 1;
        } else if (strcmp(argv[i], "--diversity-prune") == 0) {
            do_diversity_prune = 1;
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

    /* Resolve study_threshold — default to score_threshold if not set */
    if (study_threshold < 0)
        study_threshold = score_threshold;

    /* In CSV mode, human-readable output goes to stderr;
     * stdout is reserved for machine-parseable CSV lines. */
    FILE *out = do_csv ? stderr : stdout;

    if (do_csv)
        printf("idx,file,result,score,kp,study_updated\n");

    /* ── Enrollment ─────────────────────────────────────────────── */

    Template tmpl;
    template_init(&tmpl);

    int enroll_rejected = 0;
    int enroll_stddev_rejected = 0;
    int enroll_kp_min = 999, enroll_kp_max = 0;
    long enroll_kp_total = 0;

    fprintf(out, "Enrollment: %d frames (stddev gate: %d, keypoint gate: %d)\n",
           n_enroll, stddev_gate, quality_gate);

    for (int i = 0; i < n_enroll; i++) {
        int w, h;
        unsigned char *pix = read_pgm(enroll_files[i], &w, &h);
        if (!pix) {
            fprintf(stderr, "  [%02d] SKIP (read failed): %s\n", i, enroll_files[i]);
            enroll_rejected++;
            continue;
        }

        /* Stddev gate — mirrors goodix5xx.c QUALITY_STDDEV_MIN */
        int sd = pixel_stddev(pix, w * h);
        if (sd < stddev_gate) {
            fprintf(out, "  [%02d] REJECT (stddev %d < %d): %s\n",
                   i, sd, stddev_gate, enroll_files[i]);
            free(pix);
            enroll_stddev_rejected++;
            enroll_rejected++;
            continue;
        }

        SigfmImgInfo *info = sigfm_extract(pix, w, h);
        free(pix);

        if (!info) {
            fprintf(out, "  [%02d] REJECT (extraction failed): %s\n", i, enroll_files[i]);
            enroll_rejected++;
            continue;
        }

        int kp = sigfm_keypoints_count(info);
        if (kp < enroll_kp_min) enroll_kp_min = kp;
        if (kp > enroll_kp_max) enroll_kp_max = kp;
        enroll_kp_total += kp;

        if (kp < quality_gate) {
            fprintf(out, "  [%02d] REJECT (keypoints %d < %d): %s\n",
                   i, kp, quality_gate, enroll_files[i]);
            sigfm_free_info(info);
            enroll_rejected++;
            continue;
        }

        if (do_quality_enroll) {
            int rc = template_add_quality(&tmpl, info, max_subtemplates / 2);
            if (rc < 0) {
                fprintf(out, "  [%02d] SKIP   (quality rank %d ≤ worst): %s\n",
                       i, kp, enroll_files[i]);
                /* info already freed by template_add_quality */
            } else {
                fprintf(out, "  [%02d] OK     (keypoints: %d, quality-ranked): %s\n",
                       i, kp, enroll_files[i]);
            }
        } else {
            template_add(&tmpl, info);
            fprintf(out, "  [%02d] OK     (keypoints: %d): %s\n", i, kp, enroll_files[i]);
        }
    }

    int enrolled = tmpl.count;
    fprintf(out, "\n  Enrolled: %d/%d (rejected: %d, stddev-rejected: %d)\n",
           enrolled, n_enroll, enroll_rejected, enroll_stddev_rejected);
    if (enrolled > 0) {
        fprintf(out, "  Keypoints: min=%d max=%d mean=%ld\n",
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
        fprintf(out, "\n  Sorting subtemplates (keeping top %d of %d)...\n",
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

    /* Diversity pruning: remove most-similar pairs until target count */
    if (do_diversity_prune && tmpl.count > max_subtemplates) {
        template_diversity_prune(&tmpl, max_subtemplates, out);
    }

    /* ── Verification ───────────────────────────────────────────── */

    if (n_verify == 0) {
        fprintf(out, "\nNo verification files \xe2\x80\x94 done.\n");
        template_free(&tmpl);
        return 0;
    }

    fprintf(out, "\nVerification: %d frames (threshold: %d, study-threshold: %d, "
           "stddev gate: %d, kp gate: %d)\n",
           n_verify, score_threshold, study_threshold, stddev_gate, quality_gate);

    int match_ok = 0, match_fail = 0, match_error = 0;
    int verify_gated = 0; /* frames skipped by quality gates (not counted in FRR) */
    long score_total = 0;
    int score_min = 999999, score_max = -1;
    int template_updates = 0;

    /* Study v2 state — persists across all verify iterations */
    StudyState study_state;
    if (do_study_v2)
        study_state_init(&study_state, &tmpl);

    for (int i = 0; i < n_verify; i++) {
        int w, h;
        unsigned char *pix = read_pgm(verify_files[i], &w, &h);
        if (!pix) {
            fprintf(stderr, "  [%02d] ERROR (read failed): %s\n", i, verify_files[i]);
            match_error++;
            continue;
        }

        /* Stddev gate — mirrors goodix5xx.c QUALITY_STDDEV_MIN.
         * In the driver this triggers RETRY_CENTER_FINGER which does NOT
         * consume a verify attempt, so we SKIP (not FAIL) here. */
        int sd = pixel_stddev(pix, w * h);
        if (sd < stddev_gate) {
            fprintf(out, "  [%02d] SKIP  (stddev %d < %d): %s\n",
                   i, sd, stddev_gate, verify_files[i]);
            if (do_csv)
                printf("%d,%s,SKIP,0,0,0\n", i, verify_files[i]);
            free(pix);
            verify_gated++;
            continue;
        }

        SigfmImgInfo *info = sigfm_extract(pix, w, h);
        free(pix);

        if (!info) {
            fprintf(out, "  [%02d] SKIP  (extraction failed): %s\n", i, verify_files[i]);
            if (do_csv)
                printf("%d,%s,SKIP,0,0,0\n", i, verify_files[i]);
            verify_gated++;
            continue;
        }

        /* Keypoint gate — mirrors fp-image.c keypoint count < 25 check.
         * In the driver this triggers FP_DEVICE_RETRY_GENERAL, which also
         * does NOT consume a verify attempt. */
        int kp = sigfm_keypoints_count(info);
        if (kp < quality_gate) {
            fprintf(out, "  [%02d] SKIP  (keypoints %d < %d): %s\n",
                   i, kp, quality_gate, verify_files[i]);
            if (do_csv)
                printf("%d,%s,SKIP,0,%d,0\n", i, verify_files[i], kp);
            sigfm_free_info(info);
            verify_gated++;
            continue;
        }

        int best_idx;
        int score = template_match(&tmpl, info, &best_idx);

        if (score < 0) {
            fprintf(out, "  [%02d] ERROR (match error): %s\n", i, verify_files[i]);
            if (do_csv)
                printf("%d,%s,ERROR,0,%d,0\n", i, verify_files[i], kp);
            sigfm_free_info(info);
            match_error++;
            continue;
        }

        if (score < score_min) score_min = score;
        if (score > score_max) score_max = score;
        score_total += score;

        const char *result;
        int study_updated = 0;
        if (score >= score_threshold) {
            result = "MATCH";
            match_ok++;

            /* Record hit for study v2 (track which entry matched) */
            if (do_study_v2)
                study_record_hit(&study_state, best_idx);

            /* Template study: only absorb if score meets the STUDY threshold,
             * which may be higher than the match threshold. This is the key
             * safety mechanism — match at score_threshold, but only learn from
             * high-confidence matches at study_threshold. */
            if (do_template_study && score >= study_threshold) {
                int updated;
                if (do_study_v2)
                    updated = template_study_v2(&tmpl, info, &study_state);
                else
                    updated = template_study(&tmpl, info);
                if (updated) {
                    template_updates++;
                    study_updated = 1;
                    fprintf(out, "  [%02d] %-5s score=%d/%d kp=%d (template updated): %s\n",
                           i, result, score, score_threshold, kp, verify_files[i]);
                    if (do_csv)
                        printf("%d,%s,MATCH,%d,%d,1\n", i, verify_files[i], score, kp);
                    sigfm_free_info(info);
                    continue;
                }
            }
        } else {
            result = "FAIL ";
            match_fail++;
        }

        fprintf(out, "  [%02d] %s score=%d/%d kp=%d: %s\n",
               i, result, score, score_threshold, kp, verify_files[i]);
        if (do_csv)
            printf("%d,%s,%s,%d,%d,%d\n", i, verify_files[i],
                   score >= score_threshold ? "MATCH" : "FAIL",
                   score, kp, study_updated);

        sigfm_free_info(info);
    }

    /* ── Summary ────────────────────────────────────────────────── */

    int total_attempts = match_ok + match_fail;
    fprintf(out, "\n");
    fprintf(out, "═══════════════════════════════════════════\n");
    fprintf(out, "  Results\n");
    fprintf(out, "───────────────────────────────────────────\n");
    fprintf(out, "  Enrolled:          %d subtemplates\n", tmpl.count);
    fprintf(out, "  Verify attempts:   %d\n", total_attempts);
    fprintf(out, "  Quality-gated:     %d (skipped, not in FRR)\n", verify_gated);
    fprintf(out, "  Matches:           %d\n", match_ok);
    fprintf(out, "  Rejections:        %d\n", match_fail);
    fprintf(out, "  Errors:            %d\n", match_error);
    if (total_attempts > 0) {
        double frr = (double)match_fail / total_attempts * 100.0;
        fprintf(out, "  FRR:               %.1f%%\n", frr);
        fprintf(out, "  Score: min=%d max=%d mean=%ld\n",
               score_min, score_max, score_total / total_attempts);
    }
    if (do_template_study)
        fprintf(out, "  Template updates:  %d%s\n", template_updates,
               do_study_v2 ? " (v2/windows-style)" : " (naive)");
    if (study_threshold != score_threshold)
        fprintf(out, "  Study threshold:   %d (match threshold: %d)\n",
               study_threshold, score_threshold);
    fprintf(out, "═══════════════════════════════════════════\n");

    template_free(&tmpl);
    return (match_fail > 0) ? 1 : 0;
}
