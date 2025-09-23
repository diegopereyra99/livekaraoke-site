# Responsive Image Generation

This directory contains a tiny tool to generate responsive image renditions for the site’s photos.

Script: `scripts/generate_images.sh`

## What it does

- Reads original JPEGs from `assets/_originals/<section>`
- Writes WebP (and optionally AVIF) renditions to `assets/photos/<section>`
- Generates three widths by default: `800`, `1200`, `1600`
- Skips images that already exist (safe to re-run)

The HTML in `index.html` expects files named like:

- `assets/photos/<section>/<name>-800.webp`
- `assets/photos/<section>/<name>-1200.webp`
- `assets/photos/<section>/<name>-1600.webp`

## Requirements

Install at least one WebP encoder:

- ImageMagick 6 or 7: `convert`/`magick` (preferred)
  - Ubuntu/Debian: `sudo apt-get install imagemagick`
  - macOS (Homebrew): `brew install imagemagick`
  - Fedora: `sudo dnf install imagemagick`

Optional AVIF support:

- Via ImageMagick HEIF/AVIF coder (if built with it), or
- `avifenc` (libavif-bin):
  - Ubuntu/Debian: `sudo apt-get install libavif-bin`
  - macOS: `brew install libavif`

Fallback WebP encoder if you don’t use ImageMagick:

- `cwebp` (from the WebP tools)
  - Ubuntu/Debian: `sudo apt-get install webp`
  - Fedora: `sudo dnf install libwebp-tools`
  - macOS: `brew install webp`

## Usage

Make it executable (once):

```bash
chmod +x scripts/generate_images.sh
```

Run with defaults (processes `gallery` and `what`):

```bash
scripts/generate_images.sh
```

Process a specific site section under the project structure (e.g. your new `how` section):

```bash
scripts/generate_images.sh --sections how
# Reads:  assets/_originals/how/*.jpg
# Writes: assets/photos/how/<name>-{800,1200,1600}.webp
```

Process multiple sections at once:

```bash
scripts/generate_images.sh --sections gallery,what,how
```

Process arbitrary directories (explicit input/output):

```bash
scripts/generate_images.sh --src assets/_originals/how --out assets/photos/how
```

Show help:

```bash
scripts/generate_images.sh --help
```

Flags:

```bash
# Disable AVIF entirely (WebP only)
scripts/generate_images.sh --no-avif --sections how

# Require AVIF attempt (warn if unsupported)
scripts/generate_images.sh --avif --sections gallery,what

# Overwrite existing outputs (regenerate)
scripts/generate_images.sh --force --sections how
```

## How to add a new section

1) Create a folder under `assets/_originals/<your-section>` and drop your `.jpg` files there.

2) Generate renditions:

```bash
scripts/generate_images.sh --sections <your-section>
```

3) Reference the images in HTML using `srcset`/`sizes` and the `-800/-1200/-1600` naming convention.

Example snippet:

```html
<img src="assets/photos/how/example-1200.webp"
     srcset="assets/photos/how/example-800.webp 800w,
             assets/photos/how/example-1200.webp 1200w,
             assets/photos/how/example-1600.webp 1600w"
     sizes="(min-width: 900px) 33vw, (min-width: 560px) 50vw, 100vw"
     alt="" loading="lazy" decoding="async">
```

## Notes & tips

- AVIF is generated only if supported by your toolchain. WebP is always produced when `magick` or `cwebp` is available.
- You can fully disable AVIF with `--no-avif`, or force regeneration with `--force`.
- The script is idempotent: it won’t overwrite existing outputs; delete them if you want to regenerate with new settings.
- Quality defaults: WebP `-q 82`, AVIF `-q 45` (balanced for web). Tweak inside the script if needed.
- The site CSS sets fixed heights with `object-fit: cover` for gallery images to minimize CLS. If you prefer intrinsic sizing, you can add `width`/`height` once you finalize renditions.

## Troubleshooting

- “need ImageMagick (magick) or cwebp installed”: install one of the prerequisites above.
- AVIF not produced: your ImageMagick build might lack HEIF/AVIF; install `libavif-bin` and the script will try `avifenc`.
- Very large originals: consider pre-trimming or lowering quality to speed up processing.
