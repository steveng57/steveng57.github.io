# Repository Instructions

## Scope and priorities

These instructions apply to the entire repository. Follow the user's request first,
then this file. Keep changes narrowly scoped, preserve unrelated working-tree changes,
and do not modify generated output when the source can be changed instead.

This is a Windows-first Jekyll site based on the Chirpy theme. Use PowerShell syntax
and the repository's `.ps1` helpers for local workflows. CI runs the Jekyll build on
Ubuntu, so Ruby, Liquid, HTML, CSS, JavaScript, and paths used by the site must remain
portable and case-correct.

## Repository map

- `_posts/<top-category>/`: Markdown posts. Current top-level categories are
  `woodworking` and `tech-home`.
- `assets/img/posts/<slug>/`: source media and generated derivatives for a post.
- `_data/media/<slug>.yml`: authoritative authoring intent for post images and videos.
- `_data/img-info.json`: generated dimensions, dates, and EXIF fallback metadata.
- `_includes/`, `_layouts/`, `_sass/`, and `assets/`: site presentation and behavior.
- `_plugins/category_tree_generator.rb`: generated hierarchical category pages.
- `_data/category_*.yml`: category ordering, icons, copy, and page defaults.
- `functions/api/contact.ts`: Cloudflare Pages contact endpoint.
- `docs/`: longer operational documentation.
- `deprecated/`: historical helpers; do not use them for new work.

See `README.md` for the detailed post/media workflow and `SERVE_README.md` for local
server options.

## Authoring posts and media

- Prefer `./new-post.ps1` to scaffold a post and `./add-post-media.ps1` to add media to
  an existing post. These keep posts, media folders, manifests, and include blocks in
  sync.
- Post files follow `_posts/<top-category>/YYYY-MM-DD-<slug>.MD`; media lives in
  `assets/img/posts/<slug>/`; its manifest is `_data/media/<slug>.yml`.
- Preserve the front-matter conventions used by recent posts: a two-item `category`
  array where applicable, `tags`, `media_subpath`, and an `image` object with useful
  alt text. Update `last_modified_at` when materially editing published content.
- Use the shared media includes already present in `_includes/` instead of introducing
  one-off markup. Follow a recent post for the current `figure.html`,
  `figure-pair.html`, video, and float-clearing patterns.
- Use `_data/links.yml` for reusable external/vendor links.
- If a category is added or renamed, check `_data/category_order.yml`,
  `_data/category_icons.yml`, and `_data/category_extras.yml` as well as navigation and
  generated category pages.

### Media source of truth

- `_data/media/<slug>.yml` controls published names, captions, inclusion, gallery
  membership, thumbnails, video sources, HLS masters, and posters.
- Source still images are normally HEIC/JPEG/PNG files. Published still images and
  their `thumbnails/`, `thumbnails-2x/`, and `tinyfiles/` variants are AVIF.
- Use `./gen-derived-avif.ps1` to regenerate still-image derivatives,
  `./gen-hls.ps1` for HLS/video posters, and `./gen-img-info.ps1` for
  `_data/img-info.json`.
- Do not hand-edit `_data/img-info.json`, `_site/`, HLS segments/playlists, or generated
  image derivatives. Change the source or manifest and regenerate them.
- Legacy folders without manifests may still fall back to Windows image tags. Do not
  introduce new tag-based intent; use manifests. Convert legacy folders with
  `./convert-media-manifests.ps1` (dry run by default, then `-Apply`).
- Media-generation tools may require ImageMagick (`magick`), ExifTool, and FFmpeg.
  Avoid regenerating large media sets unless the task requires it; target a slug or
  post path where supported.

## Site architecture contracts

- `_plugins/category_tree_generator.rb` derives nested category indexes from post
  front matter. `_data/category_page.yml` supplies their default page/pagination data.
- Gallery behavior combines `_data/media` intent with generated `_data/img-info.json`
  metadata. Keep media paths site-relative and consistent with `media_subpath`.
- Theme files in `_includes/` and `_layouts/` are locally customized. Before replacing
  code with an upstream Chirpy version, compare and preserve local behavior.
- `functions/api/contact.ts` is the only server-side endpoint. Unless an infrastructure
  change is explicitly requested, preserve its `onRequestPost` entry point, honeypot
  and validation behavior, Turnstile verification, optional `CONTACT_LOG` KV logging,
  and Resend integration. Never commit API keys or secrets.

## Validation

Run the smallest relevant checks first, then broaden them in proportion to the change:

```powershell
# One post and its referenced media
./test-post.ps1 -Slug <slug>

# All manifests, or one manifest with -Slug
./test-media-manifests.ps1

# Production-equivalent Jekyll build
bundle exec jekyll build --trace

# Generated HTML (run after a build)
./test-site.ps1
```

- For post-only changes, run `test-post.ps1`; add `-BuildCheck` when Liquid, includes,
  or rendering may be affected.
- For manifest/media automation changes, run `test-media-manifests.ps1` and targeted
  script tests such as `test-post.ps1`; avoid rewriting unrelated derivatives.
- For layouts, includes, plugins, Sass, configuration, or shared data, run the Jekyll
  build and `test-site.ps1`.
- CI performs `bundle exec jekyll build --trace` followed by HTMLProofer with external
  links disabled. Do not rely only on the development server.
- Use `./serve.ps1` for interactive local preview. Do not leave a server running unless
  the user asks for it.

## Editing conventions

- Respect `.editorconfig` and the style of the surrounding file.
- Keep Liquid and YAML indentation stable; quote YAML strings when punctuation or
  implicit YAML types could change their meaning.
- Avoid broad formatting or generated-asset churn in focused changes.
- Do not edit files under `_site/`; it is ignored build output.
- Do not add dependencies or update lockfiles unless the task requires it.
- Never place credentials, contact submissions, or private data in source, logs, test
  fixtures, or responses.

