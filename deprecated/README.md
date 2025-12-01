# Deprecated Utilities

The scripts under this directory are no longer part of the active tooling for the site. They
remain available for historical reference but should not be used in day-to-day workflows.

## Current Replacement

- `gen-derived-avif.ps1` (root folder) generates all AVIF thumbnails, tinyfiles, and video
  poster frames directly from primary JPEG/HEIC assets using ImageMagick.

## Archived Scripts

- `scripts/gen-thumbnails.ps1`
- `scripts/convert-to-avif.ps1`

If you still rely on any of the archived utilities, migrate to the new pipeline and remove any
external automation that invokes the retired scripts.
