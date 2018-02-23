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
#   3 - optional git 'since' specifier'
set -e

fb_path=${1}
ps_path=${2}
git_since=${3}
original_path=${PWD}

tmp_history=/tmp/fbmysql.history

if [ -e ${tmp_history} ]; then
    rm ${tmp_history}
fi

cd ${fb_path}

if [ -n "${git_since}" ]; then
    git log --pretty=format:"%ci %H %s" --since="${git_since}" ./storage/rocksdb ./mysql-test/suite/rocksdb ./mysql-test/suite/rocksdb_rpl ./mysql-test/suite/rocksdb_sys_vars ./mysql-test/suite/rocksdb_stress ./scripts/myrocks_hotbackup >> ${tmp_history}
else
    git log --pretty=format:"%ci %H %s" ./storage/rocksdb ./mysql-test/suite/rocksdb ./mysql-test/suite/rocksdb_rpl ./mysql-test/suite/rocksdb_sys_vars ./mysql-test/suite/rocksdb_stress ./scripts/myrocks_hotbackup >> ${tmp_history}
fi



cd -

cd ${ps_path}

while read line; do
    commit_date=${line:0:25}
    commit_id=${line:26:40}
    commit_title=${line:67}
#    echo "[${commit_id}] [${commit_date}] [${commit_title}]"
    if [ -n "${git_since}" ]; then
        result=`git log --fixed-strings --grep="${commit_title}"`
    else
        result=`git log --fixed-strings --grep="${commit_title}" --since="${git_since}"`
    fi
    if [ ${#result} -lt 2 ]; then
        if [ -n "${git_since}" ]; then
            result=`git log --fixed-strings --grep="${commit_id}"`
        else
            result=`git log --fixed-strings --grep="${commit_id}" --since="${git_since}"`
        fi
        if [ ${#result} -lt 2 ]; then
            echo "${commit_id} ${commit_date} \"${commit_title}\""
        else
            echo "${commit_id} ${commit_date} \"${commit_title}\"    <<< POSSIBLE FALSE HIT >>>"
        fi
    fi
done < $tmp_history

cd -

rm ${tmp_history}
