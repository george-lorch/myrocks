#!/bin/bash

if [ -z "$1" ]; then
    echo "Need an argument for a file with a list of commits to cherry pick"
    exit 1;
fi

for i in `cat $1`; do
    echo "working $i"
    git cherry-pick $i
    if [ $? -ne 0 ]; then
        exit 1
    fi
done
