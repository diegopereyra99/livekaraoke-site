Spec Backlog

- Responsive images for photos — Completed
  - Implemented a generation script: `scripts/generate_images.sh` to produce WebP at 800/1200/1600 widths (AVIF optional when supported).
  - Updated `index.html` with `srcset` + `sizes` for the gallery and the "What it is" carousel.
  - Kept `loading="lazy"` and added `decoding="async"`. Explicit `width`/`height` can be added once canonical dimensions are decided; current layout uses fixed heights with object-fit to avoid CLS.
  - AVIF support is opportunistic: created when ImageMagick or `avifenc` supports it.
  - Usage: run `chmod +x scripts/generate_images.sh && scripts/generate_images.sh` to regenerate assets.
