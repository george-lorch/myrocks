#!/bin/bash

# This script exports commits as patches from the current git repository
# starting from the head and working backwards to the commit id given in the
# first argument.
#
# The patches are named as ordinal.commit.patch where the ordinal is an
# increasing id with the head bing id 1. The commit is the commit hash/id.
#
# The patches are placed in the directory given as the second argument.
#
# Patches can be tested against the receiving repo by issuing 
# git apply --check <patch>
# and applied by issuing
# git am <patch>

_to=$1
_current=`git log --pretty=format:"%H" -n 1`
_where=$2

echo "Searching from $_current to $_to and putting patches in $_where"

if [ -z "$_to" ]; then
    echo "Missing argument for commit id to search to."
    exit 1
fi

if [ -z "$_where" ]; then
    echo "Missing argument for path to place patches."
    exit 1
fi

if [ -d "$_where" ]; then
    rm -rf $_where/*
else
    mkdir $_where
fi

_id=0
while [ "$_current" != "$_to" ]; do
    _id=`expr $_id + 1`
    _out=`git log --pretty=oneline -n 1 $_current`
    _name=`printf "%s/%06u.%s.patch" "$_where" $_id "$_current"`
    echo "$_name : $_out"
    git format-patch -M -C --stdout $_current~1..$_current > $_name
    _current=`git log --pretty=format:"%H" -n 1 $_current~1`
done

echo "There were $_id commits found since $_to"
