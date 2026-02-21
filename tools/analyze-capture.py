#!/usr/bin/env python3
"""
analyze-capture.py — Fingerprint PGM image stats & visual output

Reports basic image statistics for a capture from the goodixtls511 driver.
The captured PGM is already driver-preprocessed (calibration subtract →
percentile histogram stretch → 2× unsharp mask → crop 88→64).

For actual SIGFM quality metrics (keypoint count, match scores), use
debug-capture.sh which captures libfprint's native debug output.

Usage:
    python3 analyze-capture.py [input.pgm] [--log capture.log]

    gwenview capture-test.pgm   # KDE viewer handles PGM natively
"""

import sys
import os
import argparse
import re
import numpy as np
from PIL import Image, ImageOps


def image_stats(arr):
    """Basic image statistics."""
    from numpy.lib.stride_tricks import sliding_window_view

    stats = {}
    stats['min'] = int(arr.min())
    stats['max'] = int(arr.max())
    stats['mean'] = float(arr.mean())
    stats['std'] = float(arr.std())
    stats['dynamic_range_pct'] = (arr.max() - arr.min()) / 255.0 * 100
    stats['contrast'] = arr.std() / max(arr.mean(), 1)

    # Local variance (3×3) — sharpness proxy
    patches = sliding_window_view(arr.astype(np.float64), (3, 3))
    stats['local_var_3x3'] = float(patches.var(axis=(-1, -2)).mean())

    # Coverage: % of pixels significantly different from border mean
    border = np.concatenate([arr[0, :], arr[-1, :], arr[:, 0], arr[:, -1]])
    bg_mean = border.mean()
    bg_std = max(border.std(), 1)
    finger_mask = np.abs(arr.astype(np.float64) - bg_mean) > 2 * bg_std
    stats['coverage_pct'] = float(finger_mask.sum() / arr.size * 100)

    return stats


def parse_libfprint_log(log_path):
    """Extract SIGFM metrics from libfprint debug log (G_MESSAGES_DEBUG=all)."""
    metrics = {}
    try:
        with open(log_path) as f:
            text = f.read()
    except FileNotFoundError:
        return None

    # sigfm extract completed in 0.001234 secs
    m = re.search(r'sigfm extract completed in ([0-9.]+) secs', text)
    if m:
        metrics['extract_time_ms'] = float(m.group(1)) * 1000

    # sigfm keypoints: 42
    m = re.search(r'sigfm keypoints: (\d+)', text)
    if m:
        metrics['keypoints'] = int(m.group(1))

    # sigfm score 15/40
    scores = re.findall(r'sigfm score (\d+)/(\d+)', text)
    if scores:
        metrics['match_scores'] = [(int(s), int(t)) for s, t in scores]

    # Not enough keypoints found / SIGFM extraction failed
    if 'Not enough keypoints' in text:
        metrics['rejected'] = 'not enough keypoints (<25)'
    elif 'SIGFM extraction failed' in text or 'SIGFM scan failed' in text:
        metrics['rejected'] = 'extraction failed'

    return metrics if metrics else None


def print_report(pgm_path, stats, log_metrics=None):
    """Print analysis report."""
    h, w = stats.pop('height'), stats.pop('width')
    print(f"  Image:       {w}×{h} pixels  ({os.path.basename(pgm_path)})")
    print(f"  Pixel range: {stats['min']}–{stats['max']}  "
          f"(dynamic range {stats['dynamic_range_pct']:.0f}%)")
    print(f"  Mean / Std:  {stats['mean']:.1f} / {stats['std']:.1f}")
    print(f"  Contrast:    {stats['contrast']:.3f}")
    print(f"  Local var:   {stats['local_var_3x3']:.1f}  (higher = sharper)")
    print(f"  Coverage:    {stats['coverage_pct']:.0f}%  (Windows rejects <65%)")

    if log_metrics:
        print(f"\n  ── libfprint SIGFM metrics (from debug log) ──")
        if 'keypoints' in log_metrics:
            kp = log_metrics['keypoints']
            status = '✓' if kp >= 25 else f'✗ (<25, rejected)'
            print(f"  Keypoints:   {kp}  {status}")
        if 'extract_time_ms' in log_metrics:
            print(f"  Extract:     {log_metrics['extract_time_ms']:.1f} ms")
        if 'match_scores' in log_metrics:
            for score, threshold in log_metrics['match_scores']:
                result = '✓ match' if score >= threshold else '✗ no match'
                print(f"  Score:       {score}/{threshold}  {result}")
        if 'rejected' in log_metrics:
            print(f"  Rejected:    {log_metrics['rejected']}")

    # Verdict
    print()
    if stats['std'] < 15:
        print("  ⚠ LOW CONTRAST — image may be blank or no finger present")
    elif stats['coverage_pct'] < 65:
        print(f"  ⚠ LOW COVERAGE — Windows driver would reject")
    else:
        print("  ✓ Image statistics look reasonable")


def save_visuals(img, arr, base):
    """Save upscaled PNGs for visual inspection (8× nearest-neighbour)."""
    h, w = arr.shape
    scale = 8

    # Direct upscale
    big = img.resize((w * scale, h * scale), Image.NEAREST)
    p1 = f"{base}_x{scale}.png"
    big.save(p1)

    # Auto-contrast enhanced
    enhanced = ImageOps.autocontrast(img)
    big_enh = enhanced.resize((w * scale, h * scale), Image.NEAREST)
    p2 = f"{base}_enhanced_x{scale}.png"
    big_enh.save(p2)

    print(f"\n  Visuals ({scale}× nearest-neighbour, for viewing only):")
    print(f"    {os.path.basename(p1)}")
    print(f"    {os.path.basename(p2)}")


def main():
    parser = argparse.ArgumentParser(description='Fingerprint PGM analysis')
    parser.add_argument('pgm', nargs='?', default='capture-test.pgm',
                        help='PGM image file (default: capture-test.pgm)')
    parser.add_argument('--log', '-l', help='libfprint debug log file '
                        '(from debug-capture.sh)')
    args = parser.parse_args()

    img = Image.open(args.pgm)
    arr = np.array(img, dtype=np.uint8)
    stats = image_stats(arr)
    stats['height'], stats['width'] = arr.shape

    # Auto-detect log file: same basename with .log extension
    log_path = args.log
    if not log_path:
        auto_log = args.pgm.rsplit('.', 1)[0] + '.log'
        if os.path.isfile(auto_log):
            log_path = auto_log

    log_metrics = parse_libfprint_log(log_path) if log_path else None

    print()
    print_report(args.pgm, stats, log_metrics)

    base = args.pgm.rsplit('.', 1)[0]
    save_visuals(img, arr, base)

    print(f"\n  View in KDE:  gwenview {args.pgm}")
    print()


if __name__ == '__main__':
    main()
