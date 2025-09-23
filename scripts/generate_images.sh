#!/usr/bin/env bash
set -euo pipefail

# LiveKaraoke site: generate responsive renditions for photos
# - Inputs: assets/_originals/{gallery,what}/*.jpg
# - Outputs: assets/photos/{gallery,what}/*-{800,1200,1600}.{webp,avif}
#
# Requirements (install one of):
# - ImageMagick 7+ (`magick`) with WebP, and optionally AVIF/HEIF
# - or cwebp/avifenc as fallback encoders

SIZES=(800 1200 1600)
QUALITY_WEBP=82
QUALITY_AVIF=45

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

# Defaults (sections under assets/_originals -> assets/photos)
DEFAULT_SECTIONS=(gallery what)

# CLI options
CUSTOM_SRC=""
CUSTOM_OUT=""
SECTIONS=()
REQUEST_AVIF="auto"   # auto|on|off
FORCE=false

print_usage(){
  cat <<USAGE
Usage:
  $(basename "$0") [--sections name[,name2]] [--no-avif|--avif] [--force]
  $(basename "$0") --src <input_dir> --out <output_dir> [--no-avif|--avif] [--force]

Description:
  - Without arguments, processes default sections: ${DEFAULT_SECTIONS[*]}
  - --sections: list of section names, e.g. --sections gallery,what,how
    Uses inputs from assets/_originals/<section> and outputs to assets/photos/<section>
  - --src/--out: process a specific pair of directories (absolute or relative)
  - --no-avif: disable AVIF generation (WebP only)
  - --avif: require AVIF attempt (warn if unsupported)
  - --force: overwrite existing outputs

Examples:
  # Process only the new 'how' section under project structure
  $(basename "$0") --sections how

  # Process arbitrary directories
  $(basename "$0") --src assets/_originals/how --out assets/photos/how
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --sections)
      if [[ -z "${2:-}" ]]; then echo "--sections requires a value" >&2; exit 1; fi
      IFS=',' read -r -a SECTIONS <<< "$2"; shift 2 ;;
    --src)
      CUSTOM_SRC="${2:-}"; shift 2 ;;
    --out)
      CUSTOM_OUT="${2:-}"; shift 2 ;;
    --no-avif)
      REQUEST_AVIF="off"; shift ;;
    --avif)
      REQUEST_AVIF="on"; shift ;;
    --force)
      FORCE=true; shift ;;
    -h|--help)
      print_usage; exit 0 ;;
    *)
      echo "Unknown argument: $1" >&2; print_usage; exit 1 ;;
  esac
done

has_cmd(){ command -v "$1" >/dev/null 2>&1; }

MAGICK_OK=false
MAGICK_BIN=""
MAGICK_LIST_CMD=()
AVIF_OK=false
if has_cmd magick; then
  MAGICK_OK=true
  MAGICK_BIN="magick"
  MAGICK_LIST_CMD=(magick -list format)
elif has_cmd convert; then
  # ImageMagick 6 compatibility
  MAGICK_OK=true
  MAGICK_BIN="convert"
  MAGICK_LIST_CMD=(convert -list format)
fi

WEBP_FALLBACK=false
AVIF_FALLBACK=false
if ! $MAGICK_OK && has_cmd cwebp; then WEBP_FALLBACK=true; fi
if ! $AVIF_OK && has_cmd avifenc; then AVIF_FALLBACK=true; fi

# Probe AVIF support if ImageMagick present
if $MAGICK_OK; then
  if "${MAGICK_LIST_CMD[@]}" 2>/dev/null | grep -qi "AVIF"; then AVIF_OK=true; fi
fi

if ! $MAGICK_OK && ! $WEBP_FALLBACK; then
  echo "Error: need ImageMagick (magick) or cwebp installed for WebP output." >&2
  exit 1
fi

mkdir -p "$ROOT_DIR/assets/photos" >/dev/null 2>&1 || true

process_dir(){
  local src_dir="$1"; shift
  local out_dir="$1"; shift

  shopt -s nullglob
  for in_path in "$src_dir"/*.jpg "$src_dir"/*.jpeg "$src_dir"/*.png; do
    [ -e "$in_path" ] || continue
    local base
    base=$(basename "$in_path")
    base=${base%.*}

    for w in "${SIZES[@]}"; do
      local out_webp="$out_dir/${base}-${w}.webp"
      local out_avif="$out_dir/${base}-${w}.avif"

      if $FORCE || [ ! -f "$out_webp" ]; then
        if $MAGICK_OK; then
          "$MAGICK_BIN" "$in_path" -auto-orient -resize "${w}x${w}>" -strip \
            -define webp:method=6 -quality "$QUALITY_WEBP" "$out_webp"
        else
          # cwebp fallback
          cwebp -quiet -resize "$w" 0 -q "$QUALITY_WEBP" "$in_path" -o "$out_webp"
        fi
        echo "Wrote $out_webp"
      fi

      # AVIF optional
      if [[ "$REQUEST_AVIF" == "off" ]]; then
        : # skip
      elif $AVIF_OK; then
        if [ ! -f "$out_avif" ]; then
          # ImageMagick AVIF via HEIF coder
          "$MAGICK_BIN" "$in_path" -auto-orient -resize "${w}x${w}>" -strip \
            -define heic:speed=4 -quality "$QUALITY_AVIF" "$out_avif" || true
          if [ -f "$out_avif" ]; then echo "Wrote $out_avif"; fi
        fi
      elif $AVIF_FALLBACK; then
        if [ ! -f "$out_avif" ]; then
          # Use avifenc via a temporary PNG at target size
          tmp_png="$(mktemp).png"
          if $MAGICK_OK; then
            "$MAGICK_BIN" "$in_path" -auto-orient -resize "${w}x${w}>" -strip "$tmp_png"
          else
            # If no magick, try using cwebp resize path then decode back (skip to keep script simple)
            rm -f "$tmp_png"
            continue
          fi
          avifenc --min 0 --max 45 --speed 4 "$tmp_png" "$out_avif" && echo "Wrote $out_avif" || true
          rm -f "$tmp_png"
        fi
      else
        if [[ "$REQUEST_AVIF" == "on" ]]; then
          echo "Warning: AVIF requested but no supported encoder detected (need ImageMagick AVIF or avifenc)." >&2
        fi
      fi
    done
  done
}

# Execution path based on CLI args
if [[ -n "$CUSTOM_SRC" || -n "$CUSTOM_OUT" ]]; then
  if [[ -z "$CUSTOM_SRC" || -z "$CUSTOM_OUT" ]]; then
    echo "Both --src and --out must be provided together." >&2; exit 1
  fi
  mkdir -p "$CUSTOM_OUT"
  echo "Generating renditions: $CUSTOM_SRC -> $CUSTOM_OUT"
  process_dir "$CUSTOM_SRC" "$CUSTOM_OUT"
  echo "Done."
  exit 0
fi

# Use provided sections or defaults
if [[ ${#SECTIONS[@]} -eq 0 ]]; then
  SECTIONS=("${DEFAULT_SECTIONS[@]}")
fi

for section in "${SECTIONS[@]}"; do
  src_dir="$ROOT_DIR/assets/_originals/$section"
  out_dir="$ROOT_DIR/assets/photos/$section"
  if [[ ! -d "$src_dir" ]]; then
    echo "Skip '$section': missing $src_dir" >&2
    continue
  fi
  mkdir -p "$out_dir"
  echo "Generating '$section' renditions..."
  process_dir "$src_dir" "$out_dir"
done
echo "Done."
