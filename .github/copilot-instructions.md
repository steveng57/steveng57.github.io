# GitHub Copilot Instructions for steveng57.github.io

## Architecture Overview

This is a Jekyll-based GitHub Pages site using the Chirpy theme with a sophisticated image management system. Built for Windows development with PowerShell automation, it combines traditional blogging with advanced media processing and gallery capabilities.

## Key Components

### Shared Theme Structure via Git Submodule
- **`_shared/` submodule**: Contains reusable includes (`_includes/`) and Sass styles (`_sass/`)
- **Theme customization**: Main site imports from `_shared` via `includes_dir: _shared/_includes` and `load_paths: _shared/_sass`
- **Custom namespace**: All site-specific CSS uses `sjg-*` prefix to avoid theme conflicts

### Automated Image Processing Pipeline
- **Pre-build PowerShell scripts** (Windows-specific workflow):
  - `gen-thumbnails.ps1` - Creates `/thumbnails/` and `/tinyfiles/` directories using ImageMagick + FFMPEG
  - `gen-imagecaptions.ps1` - Extracts EXIF metadata to centralized `_data/img-info.json`
- **Dynamic galleries**: `lightgallery.html` layout filters images by `gallery: true` flag in metadata
- **Smart image placement**: Custom includes with automatic caption lookup from EXIF data

### Content Architecture
- **Dual category structure**: `/home-and-garden/` and `/woodworking/` post subdirectories  
- **Media organization**: Each post has `/assets/img/posts/{post-name}/` with auto-generated subdirs
- **Git-based timestamps**: Ruby plugin `_plugins/posts-lastmod-hook.rb` auto-updates `last_modified_at` from git history
- **External links**: Centralized vendor links in `_data/links.yml` for consistent referencing

## Development Workflow

### Enhanced Development Server
```powershell
# Primary development command - comprehensive PowerShell script
./serve.ps1  # Enhanced version with dependency checking, image regeneration options

# Available options:
./serve.ps1 -RegenerateImages  # Run image processing before serving
./serve.ps1 -Production        # Production mode (no drafts/future/livereload)  
./serve.ps1 -CheckOnly         # Validate dependencies only
./serve.ps1 -Clean -Port 3000  # Clean build on custom port
```

### CI/CD Pipeline (GitHub Actions)
- **Automated deployment**: `.github/workflows/jekyll.yml` with submodule handling
- **Ruby caching**: Optimized build with Ruby 3.4.4 and bundle caching
- **Submodule sync**: `git submodule update --remote --recursive` for latest shared assets

### Dependencies & Tools
- **Required**: Ruby Bundler, Jekyll, Git (for submodules)
- **Windows-specific**: FFMPEG (video thumbnails), ImageMagick (image processing)
- **Testing**: `html-proofer` for link validation, `check-brokenlinks.ps1` for site health

## Content Patterns

### Post Structure & Frontmatter
```yaml
# Standard post frontmatter with automatic git timestamp
category: [Home and Garden, House Tech]  # Matches directory structure
tags: [Computer, PC, House Tech]
image:
  path: /thumbnails/IMG_1927.jpeg        # Auto-generated thumbnail path
  alt: Description                       # Manual alt text override
media_subpath: /assets/img/posts/new-pc-build  # Base path for all post images
favorite: false                          # Featured post flag
pin: false                              # Sticky post flag
```

### Advanced Image Includes
```liquid
# Smart positioned images with EXIF-based captions
{% include html-side.html img="IMG_1927.jpeg" align="left-50" %}
{% include html-side.html img="build-complete.jpeg" align="center-wide" caption="Custom caption override" %}

# Side-by-side comparisons with auto-captions
{% include html-sxs.html img1="before.jpeg" img2="after.jpeg" %}

# Material lists with checkmark styling  
- {{ site.data.links.kjp }} lumber
- {{ site.data.links.domino }} joinery system
{: .sjg-list }

# Manual layout control
{% include clear-float.html break=1 %}
```

### Dynamic Gallery System
```yaml
# Gallery page frontmatter
layout: lightgallery
albumfolder: "/assets/img/posts/project-name"  # Target image directory
title: "Project Gallery"
```
- Automatically filters images with `gallery: true` in `_data/img-info.json`
- Generates breadcrumb navigation back to originating blog posts
- Uses LightGallery.js with hash-based deep linking

### External Link Management
```liquid
# Consistent vendor references from _data/links.yml
{{ site.data.links.woodsource }} - expands to formatted link
{{ site.data.links.shaper }} tool references
```

## Critical Development Patterns

### Image Processing Workflow
1. **Place images**: Add to `/assets/img/posts/{post-name}/` directory
2. **Run processing**: `./serve.ps1 -RegenerateImages` or manual PowerShell scripts
3. **Auto-generated assets**: Creates `/thumbnails/` (Jekyll header images) and `/tinyfiles/` (gallery thumbnails)
4. **Metadata extraction**: EXIF data → `_data/img-info.json` with title, date, dimensions, gallery flags

### Git Submodule Workflow  
```powershell
# Update shared theme components
git submodule update --remote --recursive
git add _shared && git commit -m "Update shared components"
```

### CSS Architecture
- **Main entry**: `assets/css/jekyll-theme-chirpy.scss` imports `@use 'sjg-main'`
- **Modular Sass**: `_shared/_sass/sjg-main.scss` imports `post.scss` + `lightgallery.scss`  
- **Responsive positioning**: `.sjg-left-33`, `.sjg-right-50`, `.sjg-center-full` classes
- **Flex containers**: `.flex-container`/`.flex-item` for side-by-side layouts
