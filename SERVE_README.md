# Jekyll Development Server

This repository now includes an enhanced PowerShell script for running the Jekyll development server with additional features.

## Quick Start

```powershell
# Simple usage (same as before)
.\serve.cmd

# Or use the PowerShell script directly for more options
.\serve.ps1
```

## Enhanced Features

### Basic Usage
```powershell
# Default development server (drafts, future posts, live reload)
.\serve.ps1

# Production mode (no drafts, no future posts, no live reload)
.\serve.ps1 -Production

# Custom port and host
.\serve.ps1 -Port 3000 -HostAddress 0.0.0.0
```

### Image Asset Management
```powershell
# Regenerate derived AVIF assets (thumbnails/tinyfiles) and captions before serving
.\serve.ps1 -RegenerateImages

# Clean build directory and regenerate images
.\serve.ps1 -Clean -RegenerateImages

# (Optional) Also embed an inline base64 LQIP into post front matter
# Writes image.lqip as a data URI: data:image/avif;base64,...
.\serve.ps1 -EmbedLqip

# Overwrite existing image.lqip entries
.\serve.ps1 -EmbedLqip -OverwriteLqip

# Or combine with image regeneration
.\serve.ps1 -RegenerateImages -EmbedLqip

# Or run it for a single post
.\tools\set-post-lqip.ps1 -PostPath .\_posts\home-and-garden\2025-06-20-new-pc-build.MD
```

### Development Options
```powershell
# Disable specific features
.\serve.ps1 -NoDrafts -NoFuture
.\serve.ps1 -NoLiveReload

# Just check if dependencies are available
.\serve.ps1 -CheckOnly
```

## Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `-RegenerateImages` | Run image processing scripts before serving | Off |
| `-EmbedLqip` | Embed base64 LQIP into posts (image.lqip) | Off |
| `-OverwriteLqip` | Overwrite existing image.lqip when embedding | Off (skip existing) |
| `-NoDrafts` | Exclude draft posts | Off (drafts included) |
| `-NoFuture` | Exclude future-dated posts | Off (future posts included) |
| `-NoLiveReload` | Disable live reload | Off (live reload enabled) |
| `-Port` | Server port | 4000 |
| `-HostAddress` | Host address to bind to | localhost |
| `-Clean` | Clean _site directory before building | Off |
| `-Production` | Production mode (implies -NoDrafts -NoFuture -NoLiveReload) | Off |
| `-CheckOnly` | Only check dependencies, don't serve | Off |

## Dependencies

The script checks for:
- **Required:** Ruby Bundler, Jekyll
- **Optional:** FFMPEG and ImageMagick (for image regeneration)

## Backward Compatibility

The original `serve.cmd` file still works and now calls the enhanced PowerShell script with default parameters.