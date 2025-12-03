# steveng57.github.io  aka www.stevengoulet.com

## Description

This repository is based off the [jekyll-theme-chirpy](https://github.com/cotes2020/jekyll-theme-chirpy) work done by a lot of fine people.

## Table of Contents

- [Installation](#installation)
- [Usage](#usage)
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

## Contributing

No co-development at this time.  

## License

License under MIT rules for open source.
