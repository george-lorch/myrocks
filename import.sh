#!/bin/bash

#
# Based on git-foo techniques from:
# http://gbayer.com/development/moving-files-from-one-git-repository-to-another-preserving-history/
# http://stackoverflow.com/questions/4042816/how-can-i-rewrite-history-so-that-all-files-except-the-ones-i-already-moved-ar
# http://stackoverflow.com/questions/5189560/squash-my-last-x-commits-together-using-git
#
set -e

#
# upstream_repo
#   a repo that contains the commits to be merged and can be 'git clone'ed
# upstream_commit
#   commit id of the point in time to merge from the upstream repo
# dst_repo
#   local destination repo/directory where to merge into
# dst_branch
#   local branch/commit point to make proposal to
#
# Pulls/merges upstream commits into local percona server repo
# Results in a new branch named ${dst_branch}-merge that contains the contents
# of the original dst_branch plus the merged upstream changes.
#
# If there are conflicts, the ${dst_branch}_merge baranch will be left in an
# uncommitted state for manual resolution.

usage() {
    echo "$@"
    echo "Usage:"
    echo "     $0 upstream_repo upstream_commit dst_repo dst_branch"
}

UPSTREAM_REPO=$1
UPSTREAM_COMMIT=$2
DST_REPO=$3
DST_BRANCH=$4
WORKSPACE=${PWD}

if [ -z "${UPSTREAM_REPO}" ]; then
    usage "Error : No upstream_repo specified"
    exit 1
fi
if [ -z "${UPSTREAM_COMMIT}" ]; then
    usage "Error : No upstream_commit specified"
    exit 1
fi
if [ -z "${DST_REPO}" ]; then
    usage "Error : No dst_repo specified"
    exit 1
fi
if [ -z "${DST_BRANCH}" ]; then
    usage "Error : No dst_branch specified"
    exit 1
fi

# first clone the upstream to a local repo
UPSTREAM_SRC=upstream
git clone --recursive ${UPSTREAM_REPO} ${UPSTREAM_SRC}
# we need to harvest the rocksdb commit pointer for later to manipulate it
# correctly in the final merge branch because the git filter-branch doesn't work
# with submodules.
cd ${UPSTREAM_SRC}
git remote rm origin
ROCKSDB_SUBMODULE_COMMIT=`git submodule status rocksdb`
ROCKSDB_SUBMODULE_COMMIT=${ROCKSDB_SUBMODULE_COMMIT:1:40}
if [ -z "${ROCKSDB_SUBMODULE_COMMIT}" ]; then
    echo "Error : unable to obtain rocksdb submodule commit pointer"
    exit 1
fi
cd ..

# set up an empty staging repo
STAGE_SRC=stage
rm -rf ${STAGE_SRC}
mkdir ${STAGE_SRC}
cd ${STAGE_SRC}
git init
git remote add upstream ../${UPSTREAM_SRC}
cd ..

# strip all non myrocks files and stage the results in the staging repo
SRC_DIRS=( "storage/rocksdb" "mysql-test/suite/rocksdb" "mysql-test/suite/rocksdb_rpl" "mysql-test/suite/rocksdb_stress" "mysql-test/suite/rocksdb_sys_vars" )
DST_DIRS=( "storage/myrocks" "mysql-test/suite/myrocks" "mysql-test/suite/myrocks.rpl" "mysql-test/suite/myrrocks.stress" "mysql-test/suite/myrocks.sys_vars" )
array_size=$(( ${#SRC_DIRS[@]} ))
array_top=$(( ${array_size}-1 ))

for i in `seq 0 ${array_top}`; do
    cd ${UPSTREAM_SRC}
    BRANCH=${DST_DIRS[$i]} # use the internal location as the branch name
    SRC_DIR=${SRC_DIRS[$i]}
    DST_DIR=${DST_DIRS[$i]}
    echo "Processing merge of ${SRC_DIR} to ${DST_DIR}"
    git checkout -b ${BRANCH} ${UPSTREAM_COMMIT}
    git filter-branch -f --subdirectory-filter ${SRC_DIR} -- --all
    DST_DIR=${DST_DIR} git filter-branch -f --prune-empty --tree-filter 'if [ ! -e ${DST_DIR} ]; then mkdir -p ${DST_DIR}; git ls-tree --name-only $GIT_COMMIT | xargs -I files mv files ${DST_DIR}; fi'
    cd ../${STAGE_SRC}
    git pull --no-edit upstream ${BRANCH}
    cd ..
done

# pull the staging repo into the destination branch
cd ${DST_REPO}
git checkout -b ${DST_BRANCH}-merge ${DST_BRANCH}
git remote add stage ../stage
git pull --no-edit stage master
git remote remove stage
# add the submodule commit pointer if there is no submodule,
# else just update it
cd storage/myrocks
if [ ! -d rocksdb ]; then
    git submodule add https://github.com/facebook/rocksdb.git
fi
cd rocksdb
git checkout ${ROCKSDB_SUBMODULE_COMMIT}
cd ../../..
git add -A
git commit -m "Update of storage/myrocks/rocksdb submodule commit pointer to ${ROCKSDB_SUBMODULE_COMMIT}"

cd ..

# leave it behind for not for troubleshooting
#rm -rf ${STAGE}
#rm -rf ${UPSTREAM_SRC}
