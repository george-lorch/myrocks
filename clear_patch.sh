#!/bin/bash

# clear patch
# 'clears' the current patch to not it as being observed or applied.
# In other words, just renames the 'current' active (highest ordinal)
# <ordinal>.<commit>.patch to <ordinal>.<commit>.patch.clear
# 

_where=$1
shift 1

if [ -z "$_where" ]; then
    echo "Missing argument for path to find patches."
    exit 1
fi

_file=`find $_where -name "*.patch" | sort | tail -1`

if [ -z "$1" ]; then
    mv $_file $_file.clear
else
    mv $_file $_file.$1
fi
