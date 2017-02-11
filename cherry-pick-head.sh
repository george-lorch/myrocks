#!/bin/bash
branch=$1
shift 1
extras=$@
commit=`git log --pretty=format:"%H" -n 1 $branch`
echo "Cherry pick merging commit $commit from $branch"
git cherry-pick $extras $commit
