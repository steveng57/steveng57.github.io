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

This was built on Windows and there are a couple of pre-jekyll-build steps to run via Windows Powershell
  - To generate thumbnail/tinyfile derivatives and video posters run `./gen-derived-avif.ps1`.  Note that jpeg (and jpg) files are all converted to avif in this process.  The original jpeg's serve as a source file, but are not used directly in the site.  They are excluded (ignored) by the Jekyll compiler.
  - To generate the captions data file (`_data/img-info.json`) run `./gen-imagecaptions.ps1`.

Deprecated helper scripts are archived under `deprecated/` for historical reference.

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
