#!/usr/bin/env bash
# Replace bundled third-party jars listed in jar-overrides.txt (see that file).
# IBC builds Gateway's classpath from jars/*.jar, so a jar under its new file name
# is picked up without touching any launcher.
set -Eeuo pipefail

jars_dir=$1
list=$2
maven=${MAVEN_REPO:-https://repo1.maven.org/maven2}

[ -d "$jars_dir" ] || { echo "no jars dir: $jars_dir" >&2; exit 1; }

grep -Ev '^\s*(#|$)' "$list" | while read -r sum path; do
	file=${path##*/}                 # jackson-core-2.18.12.jar
	want=${file%.jar}; want=${want##*-}  # 2.18.12
	artifact=${file%-"$want".jar}    # jackson-core
	shopt -s nullglob
	bundled=("$jars_dir/$artifact"-[0-9]*.jar)
	shopt -u nullglob
	if [ ${#bundled[@]} -eq 0 ]; then
		echo ".> $artifact: not bundled, skipping"
		continue
	fi
	for old in "${bundled[@]}"; do
		have=${old##*/}; have=${have%.jar}; have=${have##*-}
		newest=$(printf '%s\n%s\n' "$have" "$want" | sort -V | tail -1)
		if [ "$have" = "$want" ] || [ "$newest" = "$have" ]; then
			echo ".> $artifact: bundled $have is not older than $want, keeping it"
			continue 2
		fi
	done
	curl -sSfL -o "/tmp/$file" "$maven/$path"
	echo "$sum  /tmp/$file" | sha256sum --check --quiet -
	for old in "${bundled[@]}"; do
		echo ".> $artifact: ${old##*/} -> $file"
		rm -f "$old"
	done
	mv "/tmp/$file" "$jars_dir/$file"
done
