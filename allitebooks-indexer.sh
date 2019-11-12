#!/bin/bash

# References links:
# https://stackoverflow.com/questions/16483119/an-example-of-how-to-use-getopts-in-bash

source $(dirname "$0")/util.sh

DEBUG_MODE=true # only for debugging purposes. =========================================================================

debug() { [[ ! -z $DEBUG_MODE && $DEBUG_MODE == true ]] && { log_debug "$1" ; } }
usage() { echo "Usage: $0 --category=<string> | --all" 1>&2; exit 1; } # TODO: improve usage method description.

SCRIPT=$(portable_readlink "$0")
debug "SCRIPT -> $SCRIPT"

SCRIPT_PATH=$(dirname "$SCRIPT")
debug "SCRIPT_PATH -> $SCRIPT_PATH"

SCRIPT_BASE_NAME="$(basename -s .sh $SCRIPT)"
debug "SCRIPT_BASE_NAME -> $SCRIPT_BASE_NAME"
# ======================================================================================================================



# allitebooks URL # ====================================================================================================
ALL_IT_EBOOKS_BASE_URL=http://www.allitebooks.com
debug "ALL_IT_EBOOKS_BASE_URL -> $ALL_IT_EBOOKS_BASE_URL"
# ======================================================================================================================



# Temporary directory to save downloaded html files to be parsed. # ====================================================
TMP_HTML_DIR=$(mktemp -d -t tmp.XXXXXXX)
debug "TMP_HTML_DIR -> $TMP_HTML_DIR"
# ======================================================================================================================



# ebooks output dir ====================================================================================================
EBOOKS_OUTPUT_DIR="$SCRIPT_BASE_NAME/ebooks"
debug "EBOOKS_OUTPUT_DIR -> $EBOOKS_OUTPUT_DIR"
# ======================================================================================================================



# Validate arguments count. Should be only one. ========================================================================
debug "Arguments count -> $#"
[[ $# -gt 1 ]] && { echo "Too many arguments provided!"; usage; }
# ======================================================================================================================



# read the options provided to function build_robot_command. ===========================================================
[[ $? -eq 0 ]] && { echo "Incorrect options provided!"; exit 1; }
debug "OPTIONS -> $@"

# $@ is all command line parameters passed to the script.
# -o is for short options like -v
# -l is for long options with double dash like --version
# the comma separates different long options
# -a is for long options with single dash like -version
# options=$(getopt -l "help,version:,verbose,rebuild,dryrun" -o "hv:Vrd" -a -- "$@")

OPTIONS_STRING=$(getopt -l "category:,all" -o "c:a" -a -- "$@")
eval set -- "$OPTIONS_STRING"

# Extracting options and their arguments into variables.
while true ; do
    case "$1" in
        
        --all|-a)
            debug "Parameter -> --all|-a" ;;
        
        --category|c)
            debug "Parameter -> --category|-c" ;
            case "$2" in
                "") log_error "Missing argument category. Please, provide a valid ebook category."; exit 1 ;;
                *) CATEGORY=$2 ; shift 2 ;;
            esac ;;

        --) shift ; break ;;
        
        *) log_error "An error has occurred when handling options string." ; exit 1 ;;
        
    esac
done
# ======================================================================================================================


check_mandatory_utility_tools() {
    local WGET_PATH=`type -p wget`

    if [[ -z $WGET_PATH ]];
    then
        { 
            log_error "Missing wget utility. Please, make sure that wget is installed and accessible!"; 
            exit 1; 
        }
    fi
}

download_html_page() {
    local URL=$1
    #([^\/]*)$
    #[^\/]+(?=\/[^\/]*$)
    local SUFFIX=`echo $NEXT_PAGE | grep -oP '([^\/]*)$'`
    local TMP_HTML_PAGE_FILE_PATH=$(mktemp --tmpdir=$TMP_DIR --suffix=.$SUFFIX.html)

    echo -n "Downloading html page $URL..." >&2
    
    wget -nv --show-progress --tries=3 --retry-connrefused \
    -O "$TMP_HTML_PAGE_FILE_PATH" \
    "$URL"

    echo $TMP_HTML_PAGE_FILE_PATH
}

download_files_from_catalog() {
    local CATALOG_FILE_PATH=$1
    local DEST_DIR=$2
    local ORIGINAL_FILE_NAME
    local ENCODE_URL_FILE
    
    mkdir -p "$DEST_DIR"

    while read NEXT_LINK;
    do
        echo -n "Downloading file $NEXT_LINK..."
        
        ORIGINAL_FILE_NAME=`echo $NEXT_LINK | grep -oP '([^\/]*)$'`
        
        # Encoding space character from file link.
        ENCODE_URL_FILE=${NEXT_LINK//" "/"%20"}

        wget -nv --show-progress --tries=3 --retry-connrefused \
        -O "$DEST_DIR/$ORIGINAL_FILE_NAME" \
        "$ENCODE_URL_FILE"

    done < $CATALOG_FILE_PATH
}

check_mandatory_utility_tools
exit 1

# {1,,} to lower case
EBOOK_LINKS_CATALOG_FILE_PATH="$SCRIPT_PATH/${1,,}-ebook-links-catalog.txt"
echo $EBOOK_LINKS_CATALOG_FILE_PATH

touch $EBOOK_LINKS_CATALOG_FILE_PATH
cat /dev/null $EBOOK_LINKS_CATALOG_FILE_PATH



URL_CHOOSEN_CATEGORY_PAGE="$ALL_IT_EBOOKS_BASE_URL/$EBOOK_CATEGORY"
DOWNLOADED_HTML_PAGE_FILE_PATH=$(download_html_page $URL_CHOOSEN_CATEGORY_PAGE)

PAGES_COUNT=`cat $DOWNLOADED_HTML_PAGE_FILE_PATH | grep -oP '1 / \d+' | grep -oP '\d+$'`
# PAGES_COUNT=2 # Mock. Remove-me!

log_info "There are $PAGES_COUNT pages for category: $EBOOK_CATEGORY."

for PAGE_NUMBER in `seq 1 $PAGES_COUNT`
do
    if [[ $PAGE_NUMBER -gt 1 ]];
    then 
        { 
            URL_CHOOSEN_CATEGORY_PAGE="$ALL_IT_EBOOKS_BASE_URL/$EBOOK_CATEGORY/page/$PAGE_NUMBER";
            DOWNLOADED_HTML_PAGE_FILE_PATH=$(download_html_page $URL_CHOOSEN_CATEGORY_PAGE);
        }
    fi
    
    declare -a EBOOK_PAGES=()
    EBOOK_PAGES=($(cat $DOWNLOADED_HTML_PAGE_FILE_PATH | grep -P '<h2 class="entry-title">' | grep -oP 'http:\/\/\S+\w'))
            
    log_info "${#EBOOK_PAGES[@]} titles in page $PAGE_NUMBER"

    for NEXT_PAGE in "${EBOOK_PAGES[@]}"
    do
        HTML_PAGE_FILE_PATH=$(download_html_page $NEXT_PAGE)
        cat $HTML_PAGE_FILE_PATH | grep -oP 'http:\/\/file[^"]*' >> "$EBOOK_LINKS_CATALOG_FILE_PATH"             
    done
done

# Download all files from catalog.
download_files_from_catalog $EBOOK_LINKS_CATALOG_FILE_PATH \
                            "$EBOOKS_OUTPUT_DIR/$EBOOK_CATEGORY"

# Clean up temporary directory.
# rm -r "$TMP_DIR"