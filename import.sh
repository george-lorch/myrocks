#!/bin/bash

#
# Based on git-foo techniques from:
# http://gbayer.com/development/moving-files-from-one-git-repository-to-another-preserving-history/
# http://stackoverflow.com/questions/4042816/how-can-i-rewrite-history-so-that-all-files-except-the-ones-i-already-moved-ar
# http://stackoverflow.com/questions/5189560/squash-my-last-x-commits-together-using-git
#
set -e

usage() {
    echo "Usage:"
    echo "     $0 src dst"
}

SRC=$1
DST=$2

if [ -z "${SRC}" ] || [ -z "${DST}" ]; then
    usage
    exit 1
fi

git clone ${DST} ${DST}-imported
DST=${DST}-imported
cd ${DST}
git checkout -b ps-5.6-rocksdb
cd -

SRC_DIRS=( "storage/rocksdb" "mysql-test/suite/rocksdb" "mysql-test/suite/rocksdb_rpl" "mysql-test/suite/rocksdb_stress" "mysql-test/suite/rocksdb_sys_vars" )
DST_DIRS=( "storage/rocksdb" "mysql-test/suite/rocksdb" "mysql-test/suite/rocksdb.rpl" "mysql-test/suite/rocksdb.stress" "mysql-test/suite/rocksdb.sys_vars" )
array_size=$(( ${#SRC_DIRS[@]} ))
array_top=$(( ${array_size}-1 ))

for i in `seq 0 ${array_top}`; do
    BRANCH=${DST_DIRS[$i]} # use the internal location as the branch name
    SRC_DIR=${SRC_DIRS[$i]}
    DST_DIR=${DST_DIRS[$i]}
    git clone ${SRC} tmp-${i}
    cd tmp-${i}
    git checkout -b ${BRANCH}
    git remote rm origin
    git filter-branch --subdirectory-filter ${SRC_DIR} -- --all
    DST_DIR=${DST_DIR} git filter-branch -f --prune-empty --tree-filter 'if [ ! -e ${DST_DIR} ]; then mkdir -p ${DST_DIR}; git ls-tree --name-only $GIT_COMMIT | xargs -I files mv files ${DST_DIR}; fi'
    cd ..
    cd ${DST}
    git remote add tmp-${i} ../tmp-${i}
    git pull --no-edit tmp-${i} ${BRANCH}
    git remote rm tmp-${i} 
    cd ..
done

cd ${DST}
cd storage/rocksdb
git submodule add https://github.com/facebook/rocksdb.git
cd -
git commit -m "Initial import of MyRocks"
