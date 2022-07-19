#!/bin/bash
#
# makethumbs - Thumbnails conversion script
#
# Copyright (C) 2022  Thomas Guyot-Sionnest
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

set -eEu
trap 'echo "Error at line $LINENO"' ERR

DRYRUN=0

# Exts must be lowercase (will match case-incensitive)
KNOWN_IMG=(
	bmp
	cr2
	gif
	heic
	ico
	jpg
	jpeg
	png
	tif
	tiff
	webp
	xcf
)

KNOWN_VID=(
	3gp # vid (motorola)
	avi # vid
	dng # pixel6 raw
	mov # vid
	mp4 # vid
	mpg # vid
	mpeg # vid
	pdf # doc
	qt  # vid
	qtff # vid
	ts # vid
	webm # vid
)

KNOWN_SKIP=(
	db
	ini
	sh
	txt
)

declare -A IMG
for ext in "${KNOWN_IMG[@]}"
do
	IMG[$ext]=1
done

for ext in "${KNOWN_VID[@]}"
do
	IMG[$ext]=2
done

for ext in "${KNOWN_SKIP[@]}"
do
	IMG[$ext]=0
done

procfile() {
	((DRYRUN)) && return 0
	local base=${1%/}
	local file=${2#"$base/"}
	local framespec=$3
	src="$base/$file"

	trap $'echo "Error processing \'$src\'" >&2' RETURN
	[ -d "$base" ] || return 1
	[ -f "$src" ] || return 1

	local dst="$base/Thumbs/${file}.webp"
	[ -e "$dst" ] && ((++skipi)) && trap - RETURN && return 0

	local ddir=${dst%/*}
	[ -d "$ddir" ] || mkdir -p "$ddir"

	convert -auto-orient -thumbnail 320x320 "$src$framespec" "$dst" || return 0 # TODO: count notconv
	trap - RETURN
}

if [ $# -ne 1 ] || [ ! -d "$1" ]
then
	echo "Usage: $0 <src_dir>" >&2
	exit 1
fi

doimg=0
skipf=0
skipi=0
while IFS= read -r -d $'\0' file
do
	base=${file%.*}
	ext=${file##*.}

	if [ "$base" = "$ext" ]
	then
		echo "No ext: $file"
	elif [ ! -v "IMG[${ext,,}]" ]
	then
		echo "Unknown ext: ${ext,,} (first match: $file)"
		IMG[${ext,,}]=0
	elif ((type=${IMG[${ext,,}]}))
	then
		[ $type -eq 2 ] && framenum='[1]' || framenum=''
		procfile "$1" "$file" "$framenum"
		((++doimg))
	else
		((++skipf))
	fi
done < <(find "$1" -path "${1%/}/Thumbs" -prune -o -type f -print0)

echo "Processed $doimg/$(($doimg+$skipi)) pict ($skipi exists, $skipf skipped)"
