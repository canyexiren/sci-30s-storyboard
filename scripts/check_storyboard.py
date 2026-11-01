#!/usr/bin/env python3
"""Check a 30-second storyboard against the sci-30s-storyboard contract.

Usage:
    python3 check_storyboard.py <storyboard.md> [--shots 6] [--duration 30]

Verifies:
  - shot count and numbering
  - total duration equals the target and shots are contiguous
  - per-shot duration window (4-6s by default)
  - each shot carries all four fields
  - narration length roughly matches the shot duration (4-5 CJK chars/second)
  - a negative-prompt clause is present

Exit code 1 when any FAIL is reported.
Output is ASCII only so it stays readable in any console encoding.
"""

import argparse
import re
import sys

SHOT_RE = re.compile(
    r"^[\s#>*\-]*\u955c\u5934\s*(\d+)\s*[(\uff08]\s*(\d+)\s*[-~\u2013\u2014]\s*(\d+)\s*s\s*[)\uff09]"
)
FIELDS = [
    ("script", "\u5bf9\u5e94\u6587\u6848"),          # 对应文案
    ("prompt", "\u753b\u9762\u63d0\u793a\u8bcd"),    # 画面提示词
    ("voice", "\u89e3\u8bf4\u53f0\u8bcd"),           # 解说台词
]
NEGATIVE_HINTS = ["\u8d1f\u9762", "\u7981\u6b62", "\u65e0\u4efb\u4f55\u6587\u5b57"]  # 负面 / 禁止 / 无任何文字
CJK_RE = re.compile(r"[\u4e00-\u9fff]")

failures = []
warnings = []


def fail(msg):
    failures.append(msg)


def warn(msg):
    warnings.append(msg)


def split_shots(text):
    """Return [(index, start, end, body)] in document order."""
    lines = text.splitlines()
    marks = []
    for i, line in enumerate(lines):
        m = SHOT_RE.match(line)
        if m:
            marks.append((i, int(m.group(1)), int(m.group(2)), int(m.group(3))))
    shots = []
    for k, (i, idx, start, end) in enumerate(marks):
        stop = marks[k + 1][0] if k + 1 < len(marks) else len(lines)
        shots.append((idx, start, end, "\n".join(lines[i:stop])))
    return shots


def field_value(body, label):
    """Extract the text following a label on its own line (inline or after a dash)."""
    pattern = re.compile(r"^[^\n]*?" + re.escape(label) + r"\s*[:\uff1a]\s*(.*)$", re.M)
    m = pattern.search(body)
    return m.group(1).strip() if m else ""


def main():
    ap = argparse.ArgumentParser(add_help=True)
    ap.add_argument("path")
    ap.add_argument("--shots", type=int, default=6)
    ap.add_argument("--duration", type=int, default=30)
    ap.add_argument("--min-shot", type=int, default=4)
    ap.add_argument("--max-shot", type=int, default=6)
    args = ap.parse_args()

    try:
        with open(args.path, "r", encoding="utf-8-sig") as fh:
            text = fh.read()
    except OSError as exc:
        print("FAIL  cannot read %s: %s" % (args.path, exc))
        return 1

    shots = split_shots(text)
    if not shots:
        print("FAIL  no shot headers found (expected a line like: **JingTou 1 (0-5s)** using the CJK shot marker)")
        return 1

    # --- count ---
    if len(shots) != args.shots:
        if 5 <= len(shots) <= 7:
            warn("shot count is %d, spec default is %d" % (len(shots), args.shots))
        else:
            fail("shot count is %d, expected %d" % (len(shots), args.shots))

    indices = [s[0] for s in shots]
    if indices != list(range(1, len(shots) + 1)):
        fail("shot numbering is not 1..%d: %s" % (len(shots), indices))

    # --- duration ---
    total = sum(end - start for _, start, end, _ in shots)
    if total != args.duration:
        fail("total duration is %ds, expected %ds" % (total, args.duration))

    prev_end = None
    for idx, start, end, _ in shots:
        dur = end - start
        if dur <= 0:
            fail("shot %d has non-positive duration (%d-%d)" % (idx, start, end))
        elif dur < args.min_shot or dur > args.max_shot:
            warn("shot %d lasts %ds, outside %d-%ds" % (idx, dur, args.min_shot, args.max_shot))
        if prev_end is not None and start != prev_end:
            warn("shot %d starts at %ds but previous shot ended at %ds (gap or overlap)" % (idx, start, prev_end))
        prev_end = end

    # --- fields ---
    for idx, start, end, body in shots:
        missing = []
        for key, label in FIELDS:
            value = field_value(body, label)
            if not value:
                missing.append(label)
                continue
            if key == "prompt" and len(value) < 40:
                warn("shot %d prompt is only %d chars - too thin for an AI generator" % (idx, len(value)))
            if key == "voice":
                chars = len(CJK_RE.findall(value))
                dur = max(1, end - start)
                rate = chars / float(dur)
                if chars and (rate < 2.5 or rate > 7.0):
                    warn("shot %d voice is %d chars over %ds (%.1f chars/s, target 4-5)" % (idx, chars, dur, rate))
        if missing:
            fail("shot %d missing field(s): %s" % (idx, ", ".join(missing)))

    # --- negative clause ---
    if not any(h in text for h in NEGATIVE_HINTS):
        warn("no negative-prompt clause found (add: no text / no watermark / no cartoon)")

    # --- report ---
    print("shots        : %d" % len(shots))
    print("total        : %ds" % total)
    print("durations    : %s" % ", ".join("%d-%ds" % (s, e) for _, s, e, _ in shots))
    for w in warnings:
        print("WARN  %s" % w)
    for f in failures:
        print("FAIL  %s" % f)
    if failures:
        print("RESULT: FAIL (%d failure, %d warning)" % (len(failures), len(warnings)))
        return 1
    print("RESULT: %s (%d warning)" % ("WARN" if warnings else "PASS", len(warnings)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
