# steveng57.github.io  aka www.stevengoulet.com

## Description

This repository is based off the [jekyll-theme-chirpy](https://github.com/cotes2020/jekyll-theme-chirpy) work done by a lot of fine people.

## Table of Contents

- [Installation](#installation)
- [Usage](#usage)
- [Categories & Navigation](#categories--navigation)
- [Contributing](#contributing)
- [License](#license)

## Installation

Please fork the repo as you like.  There is no co-development going on in this repo, so not much sense in cloning.

This was built on a windows machine, and requires the following additional apps to be installed.
  - FFMPEG
  - ImageMajick

## Usage

Thats a bit long.  Start with searches on Jekyll and Github Pages.  Go from there.

### Creating a New Post

Use the guided post wizard:

```powershell
.\new-post.ps1
```

The wizard creates both pieces needed for a post:

- `_posts/<top-category>/YYYY-MM-DD-slug.MD`
- `assets/img/posts/<slug>/`

It prompts for title, date, category, tags, description, cover image, and optional pin/favorite/series metadata. It can also copy source media from a folder into the new post media folder. If you pick a HEIC/JPG/PNG cover image, the generated markdown references the matching `.avif` file for the site image and thumbnail. Imported still images are also added to the post body as `html-side.html` include lines.

For a parameter-driven run:

```powershell
.\new-post.ps1 -Title "Shop Cabinet" -Description "A new storage cabinet." -TopCategory Woodworking -Subcategory Workshop -Tags Woodworking,Workshop -CoverImage IMG_1001.avif -CoverAlt "Finished cabinet" -GenerateDerivatives
```

Validate a post at any time:

```powershell
.\test-post.ps1 -PostPath _posts\woodworking\2026-02-26-pen-tray.MD
.\test-post.ps1 -Slug pen-tray
```

The validator checks front matter, category shape, the media folder, cover image, cover thumbnail, in-post image/video include references, and category icon coverage. Add `-BuildCheck` to run `bundle exec jekyll build` after the convention checks.

This was built on Windows and there are a couple of pre-jekyll-build steps to run via Windows Powershell
  - To generate full-size AVIF files plus thumbnail/tinyfile derivatives run `./gen-derived-avif.ps1`.  Note that HEIC, jpeg/jpg, and png files serve as source files, but are not used directly in the site. Full-size AVIF files default to `-MaxDimension 2048`.
    - To process only one post media folder, run `./gen-derived-avif.ps1 -PostSlug pen-tray`, `./gen-derived-avif.ps1 -PostPath assets/img/posts/pen-tray`, or `./gen-derived-avif.ps1 -SourcePath assets/img/posts/pen-tray`.
  - To generate the captions data file (`_data/img-info.json`) run `./gen-imagecaptions.ps1`.

Deprecated helper scripts are archived under `deprecated/` for historical reference.

### DIY Adaptive Video (HLS)

For self-hosted adaptive bitrate streaming with Cloudflare + Jekyll:

- Guide: `docs/hls-diy-cloudflare.md`
- Encoder skeleton script: `gen-hls.ps1`
- Post include: `_includes/embed/video-hls.html`

## Categories & Navigation

Posts use a hierarchical `category` front matter array, for example:

```yaml
category: [Woodworking, Furniture]
```

A custom generator plugin (`_plugins/category_tree_generator.rb`) reads all posts and auto-creates paginated index pages for every category prefix, such as:

- `/woodworking/`
- `/woodworking/furniture/`
- `/home-and-garden/`
- `/home-and-garden/house-tech/`

The generator uses a shared template in `_data/category_page.yml` to control the layout and pagination front matter for these pages (defaults to `layout: home` with jekyll-paginate-v2 settings). Update that data file if you need to change how category pages look or paginate.

The sidebar (`_includes/sidebar.html`) builds navigation dynamically:

- Adds fixed top-level links for **Woodworking** and **Home and Garden**.
- Scans post categories to discover unique second-level subcategories under those two tops.
- Renders one nav item per subcategory, linking to the corresponding generated index page.

Category and subcategory icons are configured in `_data/category_icons.yml`, which maps friendly names (e.g., `Furniture`, `House Tech`) to Font Awesome classes. If a name is missing from that file, the sidebar falls back to a generic folder icon.

## Architectural Details

For detailed architecture notes and coding patterns, see [`.github/copilot-instructions.md`](.github/copilot-instructions.md).

## Contributing

No co-development at this time.  

## License

License under MIT rules for open source.
