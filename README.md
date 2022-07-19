# Make a Gallery

This set of Bash scripts generates thumbnails and html galleries
recursively from a directory of images and videos.

Given a directory if images and subdirs, create a `Thumbs` directory
within it containing thumbnails, then for each directory and thumbnail
create an index and full page view html.

## Dependencies

- Bash 4.2 or newer
- The POSIX `find` command with `-print0` support
- /etc/mime.types (for HTML5 video playback mime types)
- ImageMagick (`convert` and `identify` commands)
  - ffmpeg (to write `.webp` thumbnails, and for video inputs get thumbs
    from videos)
  - ImageMagick may have additional external dependencies based on the
    input formats

## Usage

1. Run `makethumbs.sh <image_dir>` to create thumbnails under
   `<image_dir>/Thumbs`.

2. Run `makeindexes.sh <Thumbs_dir>` to create the indexes.

3. Point your browser at `<image_dir>/Thumbs/index.html`

## Extra

For testing I created a sha256sum file, then wanted to grep it in a safe
way. This perl oneliner can filter null-separated filenames and
perlre-escape them for the next step:

    perl -p0e 's/^([^\x0]*)/quotemeta($1)/e'

Full blown example:

    find * -type f -print0 |perl -p0e 's/^([^\x0]*)/quotemeta($1)/e' |while IFS= read -r -d $'\0' file; do LC_ALL=C grep -qP "^[0-9a-f]{64}  $file" ~/Pictures.sha256sum && continue; md5sum "${file//\\}" && break; done

The line above breaks if a file missing from the sha256sum file is
readable (I was reading from Windows cloud-backed storage from WSL and
some files were unreadable despite being present).

## Known issues

- Unimplemented
  - Add image/video metadata
  - Sort by file or EXIF date
- Bugs
  - Some broken links in full image/video pages
  - Inaccurate processing stats
  - TLD dir should be Base image dir name, not "Thumbs"
  - Extremely large single-dir collections may overwhelm the browser and
    need to be split up
- Features
  - Add an overlay icon to video thumbnails to show it's a movie
  - Proper full image display, styles, etc
  - Add navigation to indexes and image pages
  - Display full path in indexes (with links)
  - Convert videos to supported browser format where needed
  - Template html using j2cli (context written using jq)
    - Performance hit? Two jq/j2cli invocations per image vs two printf
    - Or template printf + argument list once, how?

## License

Copyright (C) 2022  Thomas Guyot-Sionnest

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
