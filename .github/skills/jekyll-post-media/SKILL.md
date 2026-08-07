---
name: jekyll-post-media
description: "Create, revise, validate, or troubleshoot Jekyll posts and manifest-driven post media in this site. Use when adding a post, editing post front matter, adding images or video, updating a media manifest, regenerating targeted derivatives, or checking a post before publication."
argument-hint: "Describe the post slug or path and the requested content or media change"
---

# Jekyll Post and Media Workflow

Use this skill for post content and its associated images or video. Keep authoring intent in the post and `_data/media/<slug>.yml`; do not edit generated site output or image metadata directly.

## Procedure

1. Identify the post path and slug. For a new post, use `./new-post.ps1`; for existing-post media, use `./add-post-media.ps1` when it fits the requested operation.
2. Read the target post, its `_data/media/<slug>.yml` manifest, and a recent comparable post before editing. Use the repository's existing include patterns such as `figure.html`, `figure-pair.html`, and video includes.
3. For post front matter, preserve the current conventions: appropriate two-item `category` array, `tags`, `media_subpath`, and an `image` object with useful alt text. Set `last_modified_at` for material revisions to published posts.
4. Treat the manifest as the source of truth for published filenames, captions, inclusion, gallery membership, thumbnails, video sources, HLS masters, and posters. Use site-relative paths that agree with `media_subpath`.
5. Put source media in `assets/img/posts/<slug>/`. For new still images, update the manifest and run `./gen-derived-avif.ps1` only for the affected slug or post when supported. For video/HLS work, use `./gen-hls.ps1` for the affected content. Regenerate `_data/img-info.json` with `./gen-img-info.ps1` only when the requested change requires it.
6. Never hand-edit generated AVIF derivatives, HLS segments or playlists, `_data/img-info.json`, or `_site/`. Change source files or manifest intent, then regenerate only the needed outputs.
7. Use `_data/links.yml` for reusable vendor or external links. If a category changes, also check `_data/category_order.yml`, `_data/category_icons.yml`, and `_data/category_extras.yml`.

## Validation Decision Tree

- For a post-only change, run `./test-post.ps1 -Slug <slug>`.
- Add `-BuildCheck` when the change affects Liquid, includes, or rendered markup.
- For a manifest or media change, run `./test-media-manifests.ps1` and the target post check.
- For shared includes, layouts, Sass, plugins, or shared data, run `bundle exec jekyll build --trace`, then `./test-site.ps1`.
- Keep validation output scoped to the changed post or media whenever possible. Report any unavailable generator dependencies such as ImageMagick, ExifTool, or FFmpeg.

## Completion Criteria

- The post, media directory, and manifest use the same slug and site-relative paths.
- Captions, alt text, and published media intent are represented through the shared includes and manifest.
- No generated content was edited manually.
- The smallest relevant repository validation passes, with wider checks used for shared rendering behavior.