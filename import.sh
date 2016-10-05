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
# upstream_branch
#   branch name to merge from the upstream repo
# dst_repo
#   local destination repo/directory where to merge into
# dst_branch
#   local branch to make proposal on
#
# Pulls/merges upstream commits into local percona server repo
# Results in a new branch named merge_${upstream_branch}_to_${dst_branch} that
# contains the contents of the original dst_branch plus the merged upstream
# changes.
#
# If there are conflicts, the merge_${upstream_branch}_to_${dst_branch} branch
# will be left in an uncommitted state for manual resolution.
#
# Since this script assumes only certain specific directories within the repo
# are rocksdb/myrocks, repo changes must be monitored closely so the script can
# be updated to include any new/renamed source

usage() {
    echo "$@"
    echo "Usage:"
    echo "     $0 upstream_repo upstream_commit dst_repo dst_branch"
}

NOTES=""
CLEAN_EXIT="There were errors!!!"
addnote() {
    echo $@
    NOTES="${NOTES}\n$@"
}
printnotes() {
    echo -e "\n\n*************** NOTES *******************"
    echo -e ${CLEAN_EXIT}
    echo -e ${NOTES}
}
trap printnotes exit

UPSTREAM_REPO=$1
UPSTREAM_BRANCH=$2
DST_REPO=$3
DST_BRANCH=$4
WORKSPACE=${PWD}

if [ -z "${UPSTREAM_REPO}" ]; then
    usage "Error : No upstream_repo specified"
    exit 1
fi
if [ -z "${UPSTREAM_BRANCH}" ]; then
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
UPSTREAM_CLONE=upstream-clone
UPSTREAM_WORKING=upstream-working
git clone --branch ${UPSTREAM_BRANCH} ${UPSTREAM_REPO} ${UPSTREAM_CLONE}
# we need to harvest the rocksdb commit pointer for later to manipulate it
# correctly in the final merge branch because the git filter-branch doesn't work
# with submodules.
cd ${UPSTREAM_CLONE}
git remote remove origin
ROCKSDB_SUBMODULE_COMMIT=`git submodule status rocksdb`
ROCKSDB_SUBMODULE_COMMIT=${ROCKSDB_SUBMODULE_COMMIT:1:40}
if [ -z "${ROCKSDB_SUBMODULE_COMMIT}" ]; then
    echo "Error : unable to obtain rocksdb submodule commit pointer"
    exit 1
fi
cd ..

# lets note the submodule commit id for ease of manually finishing the process
# in case of an early exit
addnote "ROCKSDB_SUBMODULE_COMMIT is ${ROCKSDB_SUBMODULE_COMMIT}"

# set up an empty staging repo
STAGING=staging
rm -rf ${STAGING}
mkdir ${STAGING}
cd ${STAGING}
git init
cd ..

# this loop is the real meat of the process, it strips all of the non myrocks
# files and directories out, restructures the files and directories, then pulls
# the result into a staging repo that contains only the myrocks files in the
# structure that we want.
SRC_DIRS=( "storage/rocksdb" "mysql-test/suite/rocksdb" "mysql-test/suite/rocksdb_rpl" "mysql-test/suite/rocksdb_stress" "mysql-test/suite/rocksdb_sys_vars" )
DST_DIRS=( "storage/rocksdb" "mysql-test/suite/rocksdb" "mysql-test/suite/rocksdb.rpl" "mysql-test/suite/rocksdb.stress" "mysql-test/suite/rocksdb.sys_vars" )
array_size=$(( ${#SRC_DIRS[@]} ))
array_top=$(( ${array_size}-1 ))

for i in `seq 0 ${array_top}`; do
    BRANCH=${DST_DIRS[$i]} # use the internal location as the branch name
    SRC_DIR=${SRC_DIRS[$i]}
    DST_DIR=${DST_DIRS[$i]}
    addnote "Processing merge of ${SRC_DIR} to ${DST_DIR}"
    # if directory doesn't exist in the upstream-lone, skip it as it might not
    # have existed in that version
    if [ ! -e "${UPSTREAM_CLONE}/${SRC_DIR}" ]; then
        addnote "Processing merge of ${SRC_DIR} to ${DST_DIR} : ${UPSTREAM_CLONE}/${SRC_DIR} WAS NOT FOUND!!! SKIPPING"
        continue
    fi
    git clone --branch ${UPSTREAM_BRANCH} ${UPSTREAM_CLONE} ${UPSTREAM_WORKING}
    addnote "Processing merge of ${SRC_DIR} to ${DST_DIR} 2"
    cd ${UPSTREAM_WORKING}
    git checkout -b ${BRANCH} ${UPSTREAM_BRANCH}
    addnote "Processing merge of ${SRC_DIR} to ${DST_DIR} 3"
    git filter-branch -f --subdirectory-filter ${SRC_DIR} -- --all
    addnote "Processing merge of ${SRC_DIR} to ${DST_DIR} 4"
    DST_DIR=${DST_DIR} git filter-branch -f --prune-empty --tree-filter 'if [ ! -e ${DST_DIR} ]; then mkdir -p ${DST_DIR}; git ls-tree --name-only $GIT_COMMIT | xargs -I files mv files ${DST_DIR}; fi'
    addnote "Processing merge of ${SRC_DIR} to ${DST_DIR} 5"
    cd ../${STAGING}
    git remote add upstream ../${UPSTREAM_WORKING}
    addnote "Processing merge of ${SRC_DIR} to ${DST_DIR} 6"
    git pull --no-edit upstream ${BRANCH}
    addnote "Processing merge of ${SRC_DIR} to ${DST_DIR} 7"
    git remote remove upstream
    cd ..
    rm -rf ${UPSTREAM_WORKING}
    addnote "Processing merge of ${SRC_DIR} to ${DST_DIR} 8"
done

# at this point, we could stop the automated process and do the rest manually
# but I let the script continue to illustrate what should be done

# pull the staging repo into the destination branch
cd ${DST_REPO}
addnote "Results will be in branch merge_${UPSTREAM_BRANCH}_to_${DST_BRANCH}"
git checkout -b merge_${UPSTREAM_BRANCH}_to_${DST_BRANCH} ${DST_BRANCH}
git remote add staging ../staging

# if there are conflicts, this should halt the script for manual intervention
git pull --no-edit staging master

git remote remove staging

# add the submodule commit pointer if there is no submodule,
# else just update it
cd storage/rocksdb
if [ ! -e rocksdb ]; then
    git submodule add -f https://github.com/facebook/rocksdb.git
fi
git submodule init
git submodule update
cd rocksdb
git checkout ${ROCKSDB_SUBMODULE_COMMIT}
cd ../../..
git add -A
git commit -m "Update of storage/myrocks/rocksdb submodule commit pointer to ${ROCKSDB_SUBMODULE_COMMIT}"

cd ..

CLEAN_EXIT="Completed successfully!!!"
# leave it behind for not for troubleshooting
#rm -rf ${STAGING}
#rm -rf ${UPSTREAM_CLONE}
#rm -rf ${UPSTREAM_WORKING}
