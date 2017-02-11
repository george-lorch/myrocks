#!/bin/bash

# apply patch
# finds the next unapplied/observed patch in the sequence and runs
# git am <patch>


_where=$1

if [ -z "$_where" ]; then
    echo "Missing argument for path to find patches."
    exit 1
fi

_file=`find $_where -name "*.patch" | sort | tail -1`

git am $_file
if [ $? -eq 0 ]; then
    git log -n 1 --format=oneline
fi
