# GitHub Copilot Instructions for steveng57.github.io

## Big Picture
- Jekyll + Chirpy theme site with heavy image/media tooling, built and developed primarily on Windows.
- Post content lives under `_posts/home-and-garden` and `_posts/woodworking`, with per-post media in `assets/img/posts/{post-name}`.
- Image workflow converts primary JPEG/HEIC assets into AVIF derivatives and drives both in-post figures and a full-screen LightGallery-based gallery.
- Contact form is handled by a Cloudflare-style function in `functions/api/contact.ts` that talks to Cloudflare Turnstile and the Resend email API.

## Core Layout & Data
- Navigation & category tree:
  - `_plugins/category_tree_generator.rb` auto-generates hierarchical index pages (e.g. `/woodworking/`, `/home-and-garden/house-tech/`) from `category` front matter.
  - `_data/category_page.yml` controls default layout/pagination for those generated pages.
  - `_includes/sidebar.html` discovers top-level + second-level categories from posts, orders them via `_data/category_order.yml`, and maps names to icons via `_data/category_icons.yml`.
- Galleries & figures:
  - `_layouts/lightgallery.html` builds a LightGallery instance from `site.static_files` whose paths contain both `tinyfiles` and the page's `albumfolder`.
  - `_includes/html-side.html`, `_includes/html-sxs.html`, and `clear-float.html` are the primary post-level media helpers; they expect `include.img` (usually just a filename) and look up captions in `_data/img-info.json` via that key.
- Shared data:
  - `_data/img-info.json` is the single source of truth for image titles, dates, dimensions, and `gallery` flags.
  - `_data/links.yml` centralizes external/vendor links; posts and includes reference them instead of hard-coding URLs.

## Image & Gallery Workflow (Windows-Only)
- Source media: place JPEG/HEIC (and MP4 clips) under `assets/img/posts/{post-name}`.
- Derivative generation: run `./gen-derived-avif.ps1` to create AVIF derivatives under each post folder:
  - `thumbnails/*.avif` when the EXIF tag list (Shell property index 18) contains `thumbnail`.
  - `tinyfiles/*.avif` when the tag list contains `gallery` (these feed `_layouts/lightgallery.html`).
  - Poster frames for `.mp4` videos are captured as AVIF into `thumbnails/`.
- Metadata extraction: run `./gen-imagecaptions.ps1` to scan `assets/img/posts` (PNG/AVIF) and write `_data/img-info.json` keyed by the bare filename (e.g., `IMG_1927.avif`).
- Contract to preserve when editing automation or includes:
  - `html-side.html` uses `include.img` both as the image URL (or relative path) and as the lookup key into `img-info.json`.
  - `lightgallery.html` expects `tinyfiles/*.avif` plus matching `img-info.json` entries with `gallery: true`.
  - The PowerShell scripts are Windows-only and depend on `Shell.Application` COM and ImageMagick's `magick` binary.

## Post & Media Patterns
- Typical front matter (see recent posts for concrete examples):
  ```yaml
  category: [Home and Garden, House Tech]
  tags: [Computer, PC, House Tech]
  image:
    path: /thumbnails/IMG_1927.avif   # Header image from derived thumbnails
    alt: Booting the OS
  media_subpath: /assets/img/posts/new-pc-build
  favorite: false
  pin: false
  ```
- In-post figures use the shared includes and let captions default from `_data/img-info.json`:
  ```liquid
  {% include html-side.html img="IMG_1915.avif" align="center" %}
  {% include html-side.html img="Fractal-Case.png" align="right-50" %}
  {% include clear-float.html break=1 %}
  ```
- Side-by-side comparisons and material lists follow existing patterns:
  - `{% include html-sxs.html img1="before.avif" img2="after.avif" %}`
  - Use `_data/links.yml` entries (e.g., `{{ site.data.links.kjp }}`) for vendors, often styled with `{: .sjg-list }`.

## Development & CI
- Local development (Windows PowerShell):
  - **IMPORTANT**: This environment is Windows-based. Always use PowerShell commands (e.g. `Set-Content`, `Get-ChildItem`) and avoid Linux-specific tools like `cat`, `grep`, `ls`, or `touch` unless running within a specific WSL context (which is not standard here).
  - Primary entry point is `./serve.ps1`, which wraps `bundle exec jekyll serve` with dependency checks and options like `-RegenerateImages`, `-Production`, `-Clean`, `-Port`, and `-CheckOnly`.
  - For a full refresh of media and captions before serving, prefer running `./gen-derived-avif.ps1` then `./gen-imagecaptions.ps1`, and update `serve.ps1` in tandem if you change that workflow.
- CI/CD:
  - `.github/workflows/jekyll.yml` builds with Ruby 3.4.4, updates submodules to latest, runs `bundle exec jekyll build`, and deploys to GitHub Pages.
  - Link health checks can be run manually via `./check-brokenlinks.ps1 -rootUrl https://www.stevengoulet.com`.

## Contact Function (Cloudflare Pages)
- `functions/api/contact.ts` is the only server-side component and is structured for Cloudflare Pages Functions:
  - Exported `onRequestPost` entry calls an internal handler class.
  - Uses a honeypot `nickname` field, email/subject validation, and Cloudflare Turnstile verification (`TURNSTILE_SECRET_KEY`).
  - Logs messages to a KV namespace `CONTACT_LOG` (when configured) and sends mail via Resend using `RESEND_API_KEY`.
- When editing or extending this file, keep the exported `onRequestPost` signature, KV-based logging pattern, and Turnstile + Resend integration intact unless you are deliberately coordinating infra changes.
