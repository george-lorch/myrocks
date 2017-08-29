#!/bin/bash

# This script finds commits in Facebook MySQL MyRocks that do not appear to
# exist in Percona Server. It uses the commit 'title' or 'subject' from
# Facebook MySQL to search the Percona Server history for a matching commit.
#
# The result is written to stdout and is sorted by commit date from oldest
# missing to newest.

# Input parameters are
#   1 - path to Facebook MySQL git source tree
#   2 - path to Percona Server git source tree
set -e

fb_path=${1}
ps_path=${2}
original_path=${PWD}

tmp_history=/tmp/fbmysql.history

if [ -e ${tmp_history} ]; then
    rm ${tmp_history}
fi

cd ${fb_path}
git log --pretty=format:"%ci %H %s" ./storage/rocksdb ./mysql-test/suite/rocksdb ./mysql-test/suite/rocksdb_rpl ./mysql-test/suite/rocksdb_sys_vars ./mysql-test/suite/rocksdb_stress >> ${tmp_history}

cd -

cd ${ps_path}

while read line; do
    commit_date=${line:0:25}
    commit_id=${line:26:40}
    commit_title=${line:67}
#    echo "[${commit_id}] [${commit_date}] [${commit_title}]"
    result=`git log --fixed-strings --grep="${commit_title}"`
    if [ ${#result} -lt 2 ]; then
        echo "${commit_id} ${commit_date} ${commit_title}"
    fi
done < $tmp_history

cd -

rm ${tmp_history}
