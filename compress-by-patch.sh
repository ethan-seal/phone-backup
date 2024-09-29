#!/bin/sh

set -eu
# diff $(fd "sms*" | sort | head -n 1) $(fd "sms*" | sort -r | head -n 1)
# assumptions:
#   - only files at top level, no directories or symlinks
# TODO: check for max file name length

# accepts one param, what filename to look for
get() {
  # check newest patch
  prefix="$1"
  shift
  f="$1"
  shift
  if [[ -z "$f" ]]; then
    echo "get requires an argument"
    exit 1
  fi
  newest=$(
    find . -maxdepth 1 -name "*.patch" \
    | sort -r \
    | head -n 1
  )
  if [[ "$newest" == *"-${f}.patch" ]]; then
    cat "all-${prefix}"
  fi
  tmpfile=$(mktemp)
  cat "all-${prefix}" > "$tmpfile"
  for file in $(find . -maxdepth 1 -name "*.patch" | sort -r); do
    echo "$file"
    patch "$tmpfile" -R "$file"
    if [[ "$file" == *"${f}-"* ]]; then
      cat "$tmpfile";
      rm "$tmpfile";
      exit 0;
    fi
  done
  rm "$tmpfile";
  echo "${f} not found"
  exit 1;
}

# accepts one param, the prefix to use
compress() {
  # put everything in all-sms
  # if not exists
  # grap oldest, copy it there,
  prefix="$1"
  shift
  if [[ -z "$prefix" ]]; then
    echo "compress requires an argument"
    exit 1
  fi
  oldest=$(
    find . -maxdepth 1 -name "${prefix}*" ! -name "*.patch" \
    | sort \
    | head -n 1
  )
  if [[ ! -f "all-$prefix" ]]; then
    cp "$oldest" "all-$prefix"
  fi
  last="$oldest"
  for file in $(find . -maxdepth 1 -name "${prefix}*" ! -name "*.patch" | sort); do
    [ "$file" == "$oldest" ] && continue
    # generate patch, apply it and compare with s
    if [ -f "${last##*/}-${file##*/}" ]; then
      echo "A patch with the same name already exists"
      exit 1
    fi
    # TODO: redirect to output
    if ! xmllint --nowarning --noout --push "$file"; then
      echo "Invalid file: $file"
      rm "$file"
      continue
    fi

    export patch_file="${last##*/}-${file##*/}.patch" 
    diff "all-$prefix" "$file" > "$patch_file" \
      && echo "no differences between ${last##*/} and ${file##*/}" \
      || echo "differences found between ${last##*/} and ${file##*/}!";
    export ct=$(wc -c $patch_file | cut -d' ' -f1)
    if [[ 200000000 -lt "$ct" ]]; then
      echo "${last##*/}-${file##*/}.patch"
      exit 1
    fi
    patch "all-$prefix" "${last##*/}-${file##*/}.patch"

    if ! diff "all-$prefix" "$file"; then
      echo "A patch didn't work as expected, undoing"
      patch "all-$prefix" -R "${last##*/}-${file##*/}.patch"
      exit 1
    fi
    last="${file}"
    rm "$file";
  done
  # should end up with 
  # - a series of patches
  # - all-sms
}

command="$1"
shift

case "$command" in
    compress) compress "$@" ;;
    get) get "$@" ;;
    *) echo "Usage: $0 compress|get" >&2; exit 1 ;;
esac
