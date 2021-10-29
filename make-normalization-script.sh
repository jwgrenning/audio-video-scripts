#!/bin/bash

VERBOSE=N
missing_count=0
AV_SCRIPTS=$(dirname $(realpath $0))

usage_error()
{
    echo "run from camtasia/"
    echo usage: $0 [-v] dir
    exit 1
}

if [ ! -d "2020" ]; then
    usage_error
fi

# one or two args only
if [[ "$#" != "1" && "$#" != "2" ]]; then
    usage_error
fi

# when there is two, the first must be -v
if [[ "$#" == "2" && "$1" != "-v" ]]; then
    usage_error
fi

if [ "$#" == "2" ]; then 
    VERBOSE=Y
    shift
fi

DIR=2020/exported/$1

# fail when the directory does not exist
if [ ! -e $DIR ]; then
    echo "$1 does not exist"
    exit 1
fi

normalize_list=
skip_count=0
normalize_count=0

normalize_name()
{
    local file=$1
    echo ${file}.$(ls -l --time-style="+%Y%m%d-%H%M%S" $file | awk '{print $6}').mp4
}

SCRIPT_DATE=$(date '+%Y%m%d%_H%M%S')
NORMALIZE_TODO_SCRIPT=$DIR/$SCRIPT_DATE-normalize-todo.sh
VIMEO_UPLOAD_TODO_SCRIPT=$DIR/$SCRIPT_DATE-vimeo-upload-todo.sh
VIMEO_UPLOAD_SIZE_SCRIPT=$DIR/$SCRIPT_DATE-vimeo-upload-size.sh

show_name_mapping()
{
    if [ "${VERBOSE}" == "Y" ]; then
        echo Normalize $1
        echo "----> $2" 
        echo "----> $3"
    fi
}

add_unnormalized_name_to_list()
{
    local file=$1
    local name=$(normalize_name $file)
    if [ -e $name ]; then 
        exists="Exists"
        ((skip_count++))
    else
        exists="Does not exist"
        normalize_list+=($file)
        ((normalize_count++))
    fi
    show_name_mapping $file $name "$exists"
}

make_normalize_list()
{
    local dir=$1
    echo "Normalize all new mp4/mov in $1"
    local f1=$(find $dir -name "*.mp4" | grep -v "mp4.20.*mp4" | grep -v "mov.20.*.mp4" | sort)
    local f2=$(find $dir -name "*.mov")
    local files=$f1
    files+=" ${f2}"

    for file in $files; do
        add_unnormalized_name_to_list $file
    done
}

init_script()
{
    echo "#!/bin/bash" >$1
    echo "# Generated script" >>$1
    echo "AV_SCRIPTS=${AV_SCRIPTS}" >>$1
    echo "echo Starting $(basename $1) \$(date)" >>$1
    echo "" >>$1
    chmod +x $1
}

finalize_script()
{
    echo "echo Ending $(basename $1) \$(date)" >>$1
    echo "echo ------" >>$1
}

init_upload_script()
{
    init_script $VIMEO_UPLOAD_TODO_SCRIPT
    cat <<EOF >>$VIMEO_UPLOAD_TODO_SCRIPT
upload()
{
    local count=0
    echo waiting for file \$1
    while [ ! -e \$1 ]; do
        echo -n "."
        sleep 1
        if [ "\${count}" == "60" ]; then
            echo
            count=0
        fi
    done
    time python \${AV_SCRIPTS}/vimeo-upload.py \$1
}

EOF
}

init_upload_size_script()
{
    init_script $VIMEO_UPLOAD_SIZE_SCRIPT
    cat <<EOF >>$VIMEO_UPLOAD_SIZE_SCRIPT
total=0

size_of()
{
    local size=\$(du \$1)
    echo \$size
    local parts=(\$size)
    total=\$((\${total}+\${parts[0]})) 
}

EOF
}

finalize_upload_size_script()
{
    echo >>$VIMEO_UPLOAD_SIZE_SCRIPT
    echo echo Total upload size \$total >>$VIMEO_UPLOAD_SIZE_SCRIPT
    echo >>$VIMEO_UPLOAD_SIZE_SCRIPT
}

add_to_vimeo_upload()
{
    local name=$1
    local thumb=$2
    local vimeo=$3

    echo "# Upload to vimeo: ${name}" >> $VIMEO_UPLOAD_TODO_SCRIPT
    add_comment_to_vimeo_upload $thumb
    add_comment_to_vimeo_upload $vimeo
     
    if [[ -e $thumb && -e $vimeo ]]; then
        echo "upload ${name}" >> $VIMEO_UPLOAD_TODO_SCRIPT
        echo "size_of ${name}" >> $VIMEO_UPLOAD_SIZE_SCRIPT
    else
        echo "# Can't upload file (missing thumb or vimeo)" >> $VIMEO_UPLOAD_TODO_SCRIPT
        missing_count=$((missing_count+1))
    fi
    echo "#------------------------------------------------" >> $VIMEO_UPLOAD_TODO_SCRIPT
    echo "" >> $VIMEO_UPLOAD_TODO_SCRIPT
}

add_comment_to_vimeo_upload()
{
    if [ ! -e $1 ]; then
        echo "# Does not exist: $1" >> $VIMEO_UPLOAD_TODO_SCRIPT
    fi
}


make_normalize_script()
{
    echo "Normalizing ${normalize_count} files. Skipping ${skip_count}"
    for infile in ${normalize_list[@]}; do
        local outfile=${PWD}/$(normalize_name $infile)
        local thumb=${PWD}/${infile%.*}-thumb.png
        local vimeo=${PWD}/${infile%.*}-vimeo.json
        echo "Normalizing ${infile}"
        echo "----> ${outfile}"
        echo "\${AV_SCRIPTS}/normalize-audio.sh ${infile} ${outfile}" >> $NORMALIZE_TODO_SCRIPT
        add_to_vimeo_upload $outfile $thumb $vimeo
    done
}

init_script $NORMALIZE_TODO_SCRIPT
init_upload_size_script
init_upload_script
make_normalize_list $DIR
make_normalize_script
finalize_script $NORMALIZE_TODO_SCRIPT
finalize_script $VIMEO_UPLOAD_TODO_SCRIPT
finalize_upload_size_script

echo echo "# Inspect and run upload script" >> $NORMALIZE_TODO_SCRIPT
echo echo ./${VIMEO_UPLOAD_SIZE_SCRIPT} >> $NORMALIZE_TODO_SCRIPT
echo echo ./${VIMEO_UPLOAD_TODO_SCRIPT} >> $NORMALIZE_TODO_SCRIPT
echo Inspect and run normalize script
echo ./${NORMALIZE_TODO_SCRIPT}
if [ "${missing_count}" != "0" ]; then
    echo "Error *** There are $missing_count incomplete vimeo uploads."
    echo See $VIMEO_UPLOAD_TODO_SCRIPT for details 
fi
