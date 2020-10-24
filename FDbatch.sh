#!/bin/bash
# Author: rslavin
# Tool for automating FlowDroid analyses with timeouts for multiple (or individual) files

OUT_DIR=fd_out
FD_JAR=/opt/FlowDroid/soot-infoflow-cmd-jar-with-dependencies.jar 
SS_LIST=/opt/FlowDroid/SourcesAndSinks.txt
ANDROID_JAR=/opt/FlowDroid/android.jar
TIME_OUT=0

POSITIONAL=()
while [[ $# -gt 0 ]]
do
    key="$1"

    case $key in
        -o|--output-dir)
            OUT_DIR="$2"
            shift # past argument
            shift # past value
            ;;
        -f|--flowdroid-jar)
            FD_JAR="$2"
            shift # past argument
            shift # past value
            ;;
        -a|--android-jar)
            ANDROID_JAR="$2"
            shift # past argument
            shift # past value
            ;;
        -s|--ss-list)
            SS_LIST="$2"
            shift # past argument
            shift # past value
            ;;
        -t|--timeout)
            if [[ "$2" =~ ^[0-9]+$ ]] ; then
                TIME_OUT="$2"
                echo "Timeout of $2 minutes detected"
            else
                echo "Invalid timeout '$2' - ignoring"
            fi
            shift # past argument
            shift # past value
            ;;
        *)    # unknown option
            POSITIONAL+=("$1") # save it in an array for later
            shift # past argument
            ;;
    esac
done
set -- "${POSITIONAL[@]}" # restore positional parameters


if [[ $# -lt 1 ]] ; then
    echo "Usage: $0 <apk_directory> [-o output_dir] [-f flowdroid_jar] [-a android_jar] [-s source_sink_list] [-t timeout_minutes]"
    exit 1
fi

test -d "$OUT_DIR" || mkdir $OUT_DIR || (echo "Unable to create directory $OUT_DIR" ; exit 1)

# differentiate between single file and directory of files
if [[ -d "$1" ]] ; then # is dir
    echo "Directory detected - analyzing apk files within directory"
    files=$(ls "$1"/*.apk)
elif [[ -f "$1" ]] ; then #exists
    echo "Individual file detected"
    files="$1"
else
    echo "Invalid input file '$1'"
    exit 1
fi

for apk in $files ; do
    apk_name=$(basename "$apk")
    # use -ns (no static) to ignore static files
    # use -layoutmode none to ignore UI elements as sources
    cmd="java -Xms10536m -Xmx20660m -jar $FD_JAR -a $apk -p $ANDROID_JAR -s $SS_LIST -ns --layoutmode none -o $OUT_DIR/$apk_name.xml"
    printf '[%s] Beginning analysis of %s\n' "$(date)" "$apk_name"
    start=$(date +%s) # start timer

    # handle timeout  
    if [[ "$TIME_OUT" -gt 0 ]] ; then
        timeout "$TIME_OUT"m $cmd 2> $OUT_DIR/$apk_name.out
        test $? -eq 124 && echo "Analysis timed out after $TIME_OUT minutes" && continue
    else
        $cmd 2> $OUT_DIR/$apk_name.out
    fi

    end=$(date +%s) # end timer
    runtime=$((end-start)) 
    printf '[%s] Completed analysis of %s in %s seconds\n' "$(date)" "$apk_name" $runtime
done
