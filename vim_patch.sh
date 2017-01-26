#!/bin/bash

# vim patch
# finds the next unapplied/observed patch in the sequence and launches vim on it


_where=$1

if [ -z "$_where" ]; then
    echo "Missing argument for path to find patches."
    exit 1
fi

_file=`find $_where -name "*.patch" | sort | tail -1`

vim $_file
