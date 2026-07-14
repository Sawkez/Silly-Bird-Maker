#!/bin/sh
printf '\033c\033]0;%s\a' Silly Bird Maker
base_path="$(dirname "$(realpath "$0")")"
"$base_path/Silly Bird Maker.x86_64" "$@"
