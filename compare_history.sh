#!/bin/bash

history_file=$1

while read line; do
    commit_id=${line:0:40}
    commit_date=${line:41:25}
    commit_title=${line:67}
    #echo "[${commit_id}] [${commit_date}] [${commit_title}]"
    result=`git log --fixed-strings --grep="${commit_title}"`
    if [ ${#result} -lt 2 ]; then
        echo "${commit_id} ${commit_date} ${commit_title}"
    fi
done < $history_file
