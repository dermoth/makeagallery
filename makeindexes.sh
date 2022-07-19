#!/bin/bash
#
# makeindexes - HTML Index generation script
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
# shellcheck disable=2059 # (printf templates)

set -eu
trap 'echo "Error at line $LINENO"' ERR

DRYRUN=0

# Map ext to type. Can pe pre-set else updated on use from /etc/mime.types
declare -A MIMEMAP=()

HTMLHEAD=$'<!DOCTYPE html>
<html>
<head>
<title>%s</title>
</head>
<body>
<h1>%s</h1><p>
'

HTMLINDEXBODY=$'<a href="%s">%s</a>
</p><p>
'

HTMLTHUMBBODY=$'<a href="%s"><img src="%s" alt="%s"></a>
'

HTMLIMGBODY=$'<img src="%s" alt="%s">
</p><h2>Image Extended Metadata</h2><p>
%s
'

# width/height needed? Alt possible?
HTMLVIDBODY=$'<video controls alt="%s"><source src="%s" type="%s"</video>
</p><h2>Image Extended Metadata</h2><p>
%s
'

HTMLTAIL=$'</p></body>
</html>
'

getmime() {
	local ext=${1,,} mimetype mimext
	[ -v "MIMEMAP[$ext]" ] && retval=${MIMEMAP[$ext]} && return 0

	retval=
	locale -a mimeinfo
	while read -ra mimeinfo
	do
		[ -z "${mimeinfo:-}" ] || [ "${mimeinfo:0:1}" = '#' ] && continue
		mimetype=${mimeinfo[0]}
		unset "mimeinfo[0]"
		for mimext in "${mimeinfo[@]}"
		do
			[ "$ext" = "$mimext" ] || continue
			MIMEMAP[$ext]=$mimetype
			retval=$mimetype
			break 2
		done
	done </etc/mime.types
}

relpath() {
	local name=$1 i=$2 tmp='' start last
	#local -a candidates

	local base=${name%.webp}
	base=${base%.video}

	for ((; i>1; i--))
	do
		tmp+='../'
	done

	# The start and current directories
	printf -v start "${DIRSTACK[-2]}"
	printf -v last "${DIRSTACK[0]}"
	tmp=${tmp%/}
	tmp+=${last#"$start"}
	#candidates=("../$tmp/$base".*)
	#if [ ${#candidates[@]} -gt 1 ]
	#then
	#	echo "Got ${#candidates[@]} match(es) for $tmp/$base.*" >&2
	#	return 1
	#elif ! [ -e "${candidates[0]}" ]
	#then
	#	echo "No file found for ${candidates[0]}" >&2
	#	return 1
	#fi
	#retval="$tmp/${candidates[0]}"
	if [ -e "../$tmp/$base" ]
	then
		retval="../$tmp/$base"
		return 0
	fi
	echo "Original path not found: ../$tmp/$base" >&2
	retval="about:blank"
}

printhead() {
	local title=$1
	# TODO: html-excape $title
	printf "$HTMLHEAD" "$title" "$title"
}

printtail() {
	printf "$HTMLTAIL"
}

printindex() {
	local subdir=$1
	# TODO: urlencode $subdir
	printf "$HTMLINDEXBODY" "$subdir/index.html" "$subdir"
}

printthumb() {
	local tn=$1 oname=$2
	# TODO: urlencode $tn, escape $oname (alt)
	printf "$HTMLTHUMBBODY" "${tn%.*}.html" "$tn" "$oname"
}

printimg() {
	local tn=$1 depth=$2 oname vmime
	relpath "$tn" "$depth" || return 1
	local relimg=$retval
	oname=${relimg##*/}
	printhead "$oname"
	# TODO: urlencode, html-encode, etc
	case $tn in
		*.video.webp)
			getmime "${oname##*/}"
			vmime=$retval
			printf "$HTMLVIDBODY" "$oname" "$relimg" "$vmime" "TODO METADATA"
			;;
		*.webp)
			printf "$HTMLIMGBODY" "$relimg" "$oname" "TODO METADATA"
			;;
		*)
			echo "Unexpected file: $tn"
			exit 1
	esac
	printtail
	retval=$oname
}

walk() {
	local curdir=$1 depth=$2 ent idxfh imgfh imgname

	echo "Processing $curdir at depth $depth"
	trap 'popd >/dev/null' RETURN
	pushd "$curdir" >/dev/null
	((DRYRUN)) && return

	exec {idxfh}>"index.html"
	printhead "Index of $curdir" >&$idxfh

	for ent in *
	do
		if [ -d "$ent" ]
		then
			walk "$ent" $((depth+1))
			printindex "$ent" >&$idxfh
		fi
	done
	for ent in *
	do
		if [ -d "$ent" ]
		then
			:
		elif [ -e "$ent" ]
		then
			case $ent in
				*.webp) ;;
				*.html) continue;;
				*)
					echo "Unexpected file: $ent"
					continue
			esac
			exec {imgfh}>"${ent%.*}.html"
			printimg "$ent" "$depth" >&$imgfh
			imgname=$retval
			exec {imgfh}>&-
			printthumb "$ent" "$imgname" >&$idxfh
			((++doimg))
		else
			echo "Unexpected $ent"
			((++unknown))
		fi
	done

	printtail >&$idxfh
	exec {idxfh}>&-
	((++dodir))
	echo "Finished $curdir"
}

if [ $# -ne 1 ] || [ ! -d "$1" ]
then
	echo "Usage: $0 <thumbs_dir>" >&2
	exit 1
fi

doimg=0
dodir=0
unknown=0
walk "$1" 1

echo "Generated $dodir inxedes for $doimg thumbs ($unknown skipped)"
