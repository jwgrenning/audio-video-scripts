#!/bin/bash

usage_error()
{
    echo usage: $0 infile outfile
    exit 1
}

if [ "$#" != "2" ]; then
    usage_error
fi

input=$1
output=$2
output_filtered=${output%.*}_filtered.mp4
output_audio=${output%.*}.mp3

echo "Normalizing ${input}"
start=$(date +"%Y%m%d-%H%M%S")
echo $start "starting ffmpeg-normalize $(basename $input)" >>normalize.log
echo " ---> ${input}" >>normalize.log
echo " ---> -c:a aac -o" >>normalize.log
echo " ---> $(basename $output)" >>normalize.log
if [ -e $output ]; then
    echo " ---> Exists, skipping" >>normalize.log
else
    ffmpeg -i $input \
        -af "highpass=f=100, lowpass=f=5000"\
        $output_filtered   
    ffmpeg-normalize $output_filtered\
        -c:a aac -o $output
    ffmpeg -i $output -q:a 0 -map a $output_audio

fi
echo " ---> finished $(basename $output)" >>normalize.log
echo >>normalize.log
