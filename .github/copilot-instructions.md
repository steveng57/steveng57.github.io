# GitHub Copilot Instructions for steveng57.github.io

## Architecture Overview

This is a Jekyll-based GitHub Pages site using the Chirpy theme, enhanced with custom image handling and a Blazor weather app. The site combines a traditional blog with advanced media management capabilities.

## Key Components

### Image Management System
- **Pre-build workflow**: Run PowerShell scripts before Jekyll build:
  - `gen-thumbnails.ps1` - Generates thumbnails and tinyfiles from `/assets/img/posts/*/`
  - `gen-imagecaptions.ps1` - Extracts EXIF metadata to `_data/img-info.json`
- **Custom includes**: Use `{% include html-side.html img="filename.jpeg" align="left-50" %}` for positioned images
- **Gallery system**: `lightgallery.html` layout creates dynamic galleries from `tinyfiles/` folders

### Custom CSS Classes (sjg-* namespace)
- **Image positioning**: `sjg-left`, `sjg-right`, `sjg-center` with variants like `-33`, `-50`, `-full`
- **Typography**: `sjg-bigtext` for emphasis, `sjg-list` for checkmark lists, `sjg-br` for spacing
- **Layout**: `flex-container`/`flex-item` for side-by-side images via `html-sxs.html`

### Content Structure
- **Posts**: Organized in `/home-and-garden/` and `/woodworking/` subdirectories
- **Media**: Each post has corresponding `/assets/img/posts/{post-name}/` folder
- **Metadata**: `media_subpath` in frontmatter sets image base path
- **Auto-timestamps**: Git hook in `_plugins/posts-lastmod-hook.rb` updates `last_modified_at`

## Development Workflow

### Local Development
```bash
# Serve with live reload
./serve.cmd  # or: bundle exec jekyll serve --livereload --drafts --future

# Generate image assets (Windows PowerShell)
./gen-thumbnails.ps1
./gen-imagecaptions.ps1
```

### Dependencies
- **External tools**: FFMPEG, ImageMagick (for PowerShell scripts)
- **Ruby gems**: Chirpy theme, jekyll-redirect-from, html-proofer
- **CDN resources**: LightGallery.js for photo galleries

## Content Patterns

### Blog Posts
```yaml
# Standard frontmatter
categories: [Home & Garden, House Tech]
tags: [Computer, PC, House Tech]
image:
  path: /thumbnails/IMG_1927.jpeg
  alt: Description
media_subpath: /assets/img/posts/new-pc-build
```

### Image Usage
```liquid
# Positioned images with auto-captions from EXIF
{% include html-side.html img="IMG_1927.jpeg" align="center-full" %}

# Side-by-side comparison
{% include html-sxs.html img1="before.jpeg" img2="after.jpeg" %}

# Manual float clearing
{% include clear-float.html break=1 %}
```

### Gallery Pages
- Use `layout: lightgallery` with `albumfolder` parameter
- Filters images marked with `gallery: true` in `img-info.json`
- Supports navigation back to referrer posts

## Custom Styling Guidelines

- Prefix custom classes with `sjg-` to avoid theme conflicts
- Image borders use `border-radius: 10px` consistently
- Responsive design uses flex layouts for multi-column content
- LightGallery animations use CSS transforms for smooth transitions

## File Organization

- **Sass**: Custom styles in `_sass/sjg-main.scss` (imports post.scss, lightgallery.scss)
- **Data**: Image metadata centralized in `_data/img-info.json`
- **Layouts**: Custom `lightgallery.html` for photo galleries
- **Scripts**: PowerShell automation in repository root
