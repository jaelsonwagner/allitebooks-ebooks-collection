#!/bin/bash

# Utility functions.
# Import this file to use all functions in that script.


# Workaround to solves the `readlink -f` incompatibility issue on Mac OS.
portable_readlink() {
    [[ -z $1 ]] && { echo "Missing target file path argument. Usage: portable_readlink <file-path>"; exit 1; }
    local TARGET_FILE=$1

    cd `dirname $TARGET_FILE`
    local TARGET_FILE=`basename $TARGET_FILE`

    # Iterate down a (possible) chain of symlinks
    while [ -L "$TARGET_FILE" ]
    do
        TARGET_FILE=`readlink $TARGET_FILE`
        cd `dirname $TARGET_FILE`
        TARGET_FILE=`basename $TARGET_FILE`
    done

    # Compute the canonicalized name by finding the physical path 
    # for the directory we're in and appending the target file.
    local PHYS_DIR=`pwd -P`
    local RESULT=$PHYS_DIR/$TARGET_FILE

    echo $RESULT
}

# Log a message on console in red color for better emphasis.
log_error() {
    [[ -z $1 ]] && { echo "Missing 'message' argument. Usage: log_error $0 <file-path>"; exit 1; }
    local message=$1
    echo -e "\033[31m$message\033[0m";
}

log_info() {
    [[ -z $1 ]] && { echo "Missing 'message' argument. Usage: log_error $0 <file-path>"; exit 1; }
    local message=$1
    echo -e "\033[96m$message\033[0m";
}

log_debug() {
    [[ -z $1 ]] && { echo "Missing 'message' argument. Usage: log_debug $0 <file-path>"; exit 1; }
    local message="$1"
    echo -e "debug: \033[32m$message\033[0m";
}