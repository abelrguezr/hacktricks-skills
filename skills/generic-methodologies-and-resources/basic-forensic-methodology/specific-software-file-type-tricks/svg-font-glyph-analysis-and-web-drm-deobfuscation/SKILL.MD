---
name: svg-glyph-deobfuscation
description: Recover text from web readers that use randomized SVG glyph IDs and per-request vector glyph definitions. Use this skill whenever you need to extract readable text from DRM-protected web readers (like Kindle Cloud Reader) that return positioned glyph runs with numeric IDs instead of Unicode characters. Trigger this skill for any task involving: extracting text from web book readers, deobfuscating randomized glyph mappings, converting SVG path data to readable text, or recovering content from systems that use perceptual glyph obfuscation. Make sure to use this skill when you see TAR archives with glyphs.json and page_data files, or when dealing with web readers that randomize glyph IDs per request.
---

# SVG Glyph Deobfuscation & Text Recovery

This skill recovers readable text from web readers that use randomized glyph IDs and SVG path definitions to prevent scraping. The core technique uses **raster hashing** to fingerprint visual glyph shapes and **SSIM** (Structural Similarity Index) to match them against reference font atlases.

## When to Use This Skill

Use this skill when you encounter:
- Web readers returning TAR archives with `glyphs.json` and `page_data_*.json`
- Text runs containing numeric glyph IDs instead of Unicode characters
- Per-request randomized glyph mappings that change between batches
- SVG path definitions for glyphs with anti-scraping tricks (micro relative moves)
- Any system that ships positioned glyph runs with request-scoped numeric IDs

## Prerequisites

```bash
pip install cairosvg pillow imagehash scikit-image numpy
```

## Core Workflow

### 1. Acquire the Data

Capture the renderer endpoint requests from your browser's DevTools. Typical structure:

```bash
curl 'https://read.amazon.com/renderer/render' \
  -H 'Cookie: session-id=...; at-main=...; sess-at-main=...' \
  -H 'x-adp-session: <ADP_SESSION_TOKEN>' \
  -H 'authorization: Bearer <RENDERING_TOKEN>' \
  -H 'User-Agent: <from browser>' \
  -H 'Accept: application/x-tar' \
  --compressed --output batch_000.tar
```

**TAR contents:**
- `page_data_0_4.json` — positioned text runs with glyph IDs
- `glyphs.json` — SVG path definitions per glyph ID
- `toc.json` — table of contents
- `metadata.json` — book metadata

### 2. Process the Batches

Run the main pipeline script:

```bash
python scripts/process_batch.py \
  --tar-dir ./batches/ \
  --font-dir ./fonts/ \
  --output ./output/
```

This will:
1. Rasterize all SVG glyphs to images
2. Compute perceptual hashes for cross-request identity
3. Match glyphs against reference font atlases using SSIM
4. Decode text runs and reconstruct layout
5. Output HTML/EPUB with preserved styling

### 3. Review Results

Check the output directory for:
- `reconstructed.html` — full text with layout
- `glyph_mapping.json` — hash → character mappings
- `stats.json` — SSIM scores, coverage metrics

## Understanding the Technique

### Why Naïve Decoding Fails

- **Randomized IDs**: Glyph ID→character mapping changes every request
- **Path variations**: Identical shapes differ in numeric coordinates per batch
- **Anti-scraping tricks**: Micro relative moves (`m3,1 m1,6 m-4,-7`) confuse parsers
- **OCR limitations**: ~50% accuracy on isolated glyphs, misses ligatures

### The Working Solution

1. **Rasterize** SVG paths to fixed-size images (512×512) using CairoSVG
2. **Hash** each glyph with perceptual hashing (pHash) — same shape = same hash
3. **Match** against reference atlas using SSIM — absorbs antialiasing differences
4. **Cache** by hash — future batches reuse known mappings

### Reference Atlas Generation

The atlas includes:
- A–Z, a–z, 0–9, basic ASCII (0x20–0x7F)
- Punctuation: `–`, `—`, `"`, `"`, `'`, `'`, `•`
- Ligatures: `ff`, `fi`, `fl`, `ffi`, `ffl`
- Separate atlases per font variant (normal, italic, bold, bold-italic)

## Scripts Reference

### `scripts/rasterize_glyphs.py`
Convert SVG path definitions to raster images.

```bash
python scripts/rasterize_glyphs.py \
  --glyphs-json glyphs.json \
  --output-dir ./rasterized/
```

### `scripts/build_atlas.py`
Generate reference font atlas from TTF/OTF files.

```bash
python scripts/build_atlas.py \
  --fonts Bookerly-Regular.ttf Bookerly-Italic.ttf \
  --output-dir ./atlases/
```

### `scripts/match_glyphs.py`
Match unknown glyphs against atlas using SSIM.

```bash
python scripts/match_glyphs.py \
  --raster-dir ./rasterized/ \
  --atlas-dir ./atlases/ \
  --output ./mappings.json
```

### `scripts/process_batch.py`
End-to-end pipeline for processing TAR batches.

```bash
python scripts/process_batch.py \
  --tar-dir ./batches/ \
  --font-dir ./fonts/ \
  --output ./output/
```

### `scripts/reconstruct_epub.py`
Reconstruct layout from decoded text runs.

```bash
python scripts/reconstruct_epub.py \
  --runs ./output/decoded_runs.json \
  --output ./book.epub
```

## Layout Reconstruction Heuristics

The reconstruction script applies these rules:

- **Paragraph breaks**: New paragraph when Y delta > 1.5× font size
- **Alignment**: Group by similar left X (left), symmetric margins (center), right edges (right)
- **Styling**: Preserve `fontStyle`, `fontWeight`, `fontSize` as CSS classes
- **Links**: Emit anchors for runs with `positionId` metadata

## Performance Tips

- **Cache by hash**: Books converge to ~300–400 unique glyphs; cache SSIM results
- **High-quality raster**: Use 256–512 px for better discrimination
- **SSIM threshold**: Average ~0.95 is strong; flag <0.85 for manual review
- **Batch processing**: Process multiple TAR files together to build cache

## Troubleshooting

### Low SSIM Scores

If matches score <0.85:
1. Check font variant (italic vs normal, bold vs regular)
2. Verify ligatures are in the atlas
3. Increase raster size to 512 px
4. Manually review flagged glyphs in `stats.json`

### Missing Characters

If some glyphs don't match:
1. Add missing characters to `CANDIDATES` in `build_atlas.py`
2. Check for special marks (em/en dashes, quotes, bullets)
3. Verify font file includes the character

### Path Rendering Issues

If glyphs render incorrectly:
1. Use CairoSVG (not basic SVG parsers)
2. Set `fill-rule: nonzero` in SVG
3. Avoid stroke rendering; use filled paths only
4. Keep stable viewBox across renders

## Legal Notice

Only use these techniques to back up content you legitimately own and in compliance with applicable laws and terms of service. This skill is for educational purposes and personal backup of legally acquired content.

## References

- [CairoSVG](https://cairosvg.org/) — SVG to PNG renderer
- [imagehash](https://pypi.org/project/ImageHash/) — Perceptual hashing
- [scikit-image SSIM](https://scikit-image.org/) — Structural Similarity Index
- [Pixelmelt blog](https://blog.pixelmelt.dev/kindle-web-drm/) — Original technique documentation
