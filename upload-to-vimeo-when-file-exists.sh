#!/bin/bash


upload()
{
    local count=0
    echo waiting for file $1
    while [ ! -e \$1 ]; do
        echo -ne "\r$((count / 60 )):$((count % 60))"
        count=$((count + 1))
        sleep 1
    done
    time python ${SCRIPTS}/vimeo-upload.py $1
}
