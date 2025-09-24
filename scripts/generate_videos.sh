#!/usr/bin/env bash
set -euo pipefail

# LiveKaraoke site: generate lightweight, loop-friendly background videos
# - Inputs: a source video (e.g., assets/_originals/what/yourvideo.mp4)
# - Outputs: assets/videos/<section>/<name>-{800,1200,1600}.{webm,mp4}
#   - webm: VP9/Opus
#   - mp4: H.264/AAC (Safari compatibility)
# - Adds fade in/out to smooth the loop

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

SIZES=(800 1200 1600)
FADE_SEC=1.0

SECTION="what"
NAME="what-loop"         # base output name; can override
SRC=""
FORCE=false

print_usage(){
  cat <<USAGE
Usage:
  $(basename "$0") --src <input_video> [--section <name>] [--name <basename>] [--sizes 800,1200,1600] [--fade 1.0] [--force]

Description:
  Encodes a source video into multiple resolutions and formats (webm/mp4),
  adding a fade in/out to make looping less jarring.

Options:
  --src       Path to input video (e.g., assets/_originals/what/clip.mp4)
  --section   Output under assets/videos/<section> (default: what)
  --name      Output base name (default: what-loop)
  --sizes     Comma-separated widths (default: 800,1200,1600)
  --fade      Fade in/out duration seconds (default: 1.0)
  --force     Overwrite existing outputs

Examples:
  $(basename "$0") --src assets/_originals/what/clip.mov
  $(basename "$0") --src assets/_originals/what/clip.mp4 --name what-loop --sizes 720,1080 --fade 0.8
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --src) SRC="${2:-}"; shift 2 ;;
    --section) SECTION="${2:-}"; shift 2 ;;
    --name) NAME="${2:-}"; shift 2 ;;
    --sizes) IFS=',' read -r -a SIZES <<< "${2:-}"; shift 2 ;;
    --fade) FADE_SEC="${2:-}"; shift 2 ;;
    --force) FORCE=true; shift ;;
    -h|--help) print_usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; print_usage; exit 1 ;;
  esac
done

if [[ -z "$SRC" ]]; then
  echo "Error: --src <input_video> is required" >&2
  print_usage
  exit 1
fi
if [[ ! -f "$SRC" ]]; then
  echo "Error: input not found: $SRC" >&2; exit 1
fi

has_cmd(){ command -v "$1" >/dev/null 2>&1; }
if ! has_cmd ffmpeg || ! has_cmd ffprobe; then
  echo "Error: ffmpeg and ffprobe are required." >&2
  exit 1
fi

OUT_DIR="$ROOT_DIR/assets/videos/$SECTION"
mkdir -p "$OUT_DIR"

# Probe duration to compute fade-out start (force C locale for decimal dot)
export LC_ALL=C
DUR="$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$SRC" | tr -d '\r')"
if [[ -z "$DUR" ]]; then
  echo "Error: could not determine duration via ffprobe." >&2; exit 1
fi

# Calculate fade-out start = duration - FADE_SEC (clamped >= 0) with dot decimal
FADE_OUT_START=$(python3 - "$DUR" "$FADE_SEC" <<'PY'
import sys
d=float(sys.argv[1]); f=float(sys.argv[2])
s=max(0.0, d-f)
print(f"{s:.3f}")
PY
)

encode_variant(){
  local width="$1"; shift
  local out_webm="$OUT_DIR/${NAME}-${width}.webm"
  local out_mp4="$OUT_DIR/${NAME}-${width}.mp4"

  local vf="format=yuv420p,fade=t=in:st=0:d=${FADE_SEC},fade=t=out:st=${FADE_OUT_START}:d=${FADE_SEC},scale=${width}:-2:flags=lanczos"
  local af="afade=t=in:st=0:d=${FADE_SEC},afade=t=out:st=${FADE_OUT_START}:d=${FADE_SEC}"

  if [[ ! -f "$out_webm" || $FORCE == true ]]; then
    ffmpeg -y -i "$SRC" \
      -an -sn \
      -c:v libvpx-vp9 -row-mt 1 -b:v 0 -crf 33 -pix_fmt yuv420p -deadline good -cpu-used 4 \
      -vf "$vf" \
      "$out_webm"
    echo "Wrote $out_webm"
  fi

  if [[ ! -f "$out_mp4" || $FORCE == true ]]; then
    ffmpeg -y -i "$SRC" \
      -an -sn \
      -c:v libx264 -preset medium -crf 23 -pix_fmt yuv420p \
      -vf "$vf" \
      -movflags +faststart \
      "$out_mp4"
    echo "Wrote $out_mp4"
  fi
}

for w in "${SIZES[@]}"; do
  encode_variant "$w"
done

echo "Done. Outputs in: $OUT_DIR"
