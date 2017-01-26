#!/bin/bash

# check patch
# finds the next unapplied/observed patch in the sequence and does a
# git apply --check <patch>


_where=$1

if [ -z "$_where" ]; then
    echo "Missing argument for path to find patches."
    exit 1
fi

_file=`find $_where -name "*.patch" | sort | tail -1`

git apply --check $_file
