#!/bin/bash

# References links:
# https://stackoverflow.com/questions/16483119/an-example-of-how-to-use-getopts-in-bash
# https://www.tutorialkart.com/bash-shell-scripting/bash-split-string/

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
ALL_IT_EBOOKS_BASE_URL=http://www.allitebooks.org
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
            debug "Parameter -> --all|-a"; shift ;;
        
        --category|c)
            debug "Parameter -> --category|-c" ;
            case "$2" in
                "") log_error "Missing argument category. Please, provide a valid ebook category."; exit 1 ;;
                *) EBOOKS_CATEGORY=$2 ; shift 2 ;;
            esac ;;

        --) shift ; break ;;
        
        *) log_error "An error has occurred when handling options string." ; exit 1 ;;
        
    esac
done
# ======================================================================================================================



# Checking mandatory utitlity tools. ===================================================================================
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
# ======================================================================================================================



# Download a desired page from allitebooks.org. ========================================================================
download_html_page() {
    local PAGE_URL=$1
    # TODO: handle empty PAGE_URL here.
    # TODO: method should receive the desired directory to save the downloaded html page
    #([^\/]*)$              regex extract last part from URL
    #[^\/]+(?=\/[^\/]*$)    
    local SUFFIX=`echo $PAGE_URL | grep -oP '([^\/]*)$'`
    #local TMP_HTML_PAGE_FILE_PATH=$(mktemp --tmpdir=$TMP_HTML_DIR --suffix=.$SUFFIX.html)
    local TMP_HTML_PAGE_FILE_PATH="$TMP_HTML_DIR/$SUFFIX.html"

    echo -n "Downloading page $PAGE_URL..." >&2
    
    wget -nv --show-progress --tries=3 --retry-connrefused -O "$TMP_HTML_PAGE_FILE_PATH" "$PAGE_URL"

    echo "$TMP_HTML_PAGE_FILE_PATH"
}
# ======================================================================================================================


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

download_single_file() {
    local FILE_URI=$1
    local DEST_DIR=$2
    local ENCODE_URL_FILE

    mkdir -p "$DEST_DIR"

    log_info -n "Downloading file $FILE_URI..."

    OUTPUT_FILE=$(echo "$FILE_URI" | grep -oP '([^\/]*)$')
    echo $OUTPUT_FILE

    # Encoding space character from file link.
    ENCODE_URL_FILE=${FILE_URI//" "/"%20"}

    wget -bnv --no-warc-keep-log --show-progress --tries=3 --retry-connrefused \
    -O "$DEST_DIR/$OUTPUT_FILE" \
    "$ENCODE_URL_FILE"
}

check_mandatory_utility_tools

CHOOSEN_PAGE_URL="$ALL_IT_EBOOKS_BASE_URL";
[[ ! -z $EBOOKS_CATEGORY ]] && { CHOOSEN_PAGE_URL="$ALL_IT_EBOOKS_BASE_URL/$EBOOKS_CATEGORY"; }
log_debug "CHOOSEN_PAGE_URL -> $CHOOSEN_PAGE_URL"

DOWNLOADED_HTML_PAGE_FILE_PATH=$(download_html_page "$CHOOSEN_PAGE_URL")
log_debug "DOWNLOADED_HTML_PAGE_FILE_PATH -> $DOWNLOADED_HTML_PAGE_FILE_PATH"

PAGES_COUNT=`cat $DOWNLOADED_HTML_PAGE_FILE_PATH | grep -oP '1 / \d+' | grep -oP '\d+$'`
log_debug "PAGES_COUNT -> $PAGES_COUNT"
PAGES_COUNT=2 # Mock. Remove-me!

if [[ ! -z $EBOOKS_CATEGORY ]];
then 
    { 
        log_info "$PAGES_COUNT pages in $EBOOKS_CATEGORY category will be processed.";
        # {variable,,} to lower case
        EBOOKS_CATALOG_FILE_PATH="$SCRIPT_PATH/${$EBOOKS_CATEGORY,,}-catalog.txt";
    }
else
    {
        log_info "$PAGES_COUNT pages will be processed.";
        EBOOKS_CATALOG_FILE_PATH="$SCRIPT_PATH/all-catalog.txt";
    }
fi    

touch $EBOOKS_CATALOG_FILE_PATH
cat /dev/null > $EBOOKS_CATALOG_FILE_PATH

log_debug "$EBOOKS_CATALOG_FILE_PATH"

if [[ $PAGES_COUNT -gt 0 ]];
    then 
        {
            for PAGE_NUMBER in `seq 1 $PAGES_COUNT`
            do
                NEXT_PAGE_TO_DOWNLOAD="$CHOOSEN_PAGE_URL/page/$PAGE_NUMBER"
                DOWNLOADED_HTML_PAGE_FILE_PATH=$(download_html_page $NEXT_PAGE_TO_DOWNLOAD)

                declare -a EBOOK_PAGES=()
                EBOOK_PAGES=($(cat $DOWNLOADED_HTML_PAGE_FILE_PATH | grep -P '<h2 class="entry-title">' | grep -oP 'http:\/\/\S+\w'))
                        
                log_info "Found ${#EBOOK_PAGES[@]} titles in page number: $PAGE_NUMBER."

                for NEXT_PAGE in "${EBOOK_PAGES[@]}"
                do
                    log_debug "NEXT_PAGE: $NEXT_PAGE"
                    HTML_PAGE_FILE_PATH=$(download_html_page $NEXT_PAGE)

                    uri_files_str=$(grep -o 'http:\/\/file[^"]*' "$HTML_PAGE_FILE_PATH" | tr '\n' '|')
                    log_debug "$uri_files_str"
                    
                    IFS='|' # pipe (|) is set as delimiter
                    read -ra ADDR <<< "$uri_files_str" # str is read into an array as tokens separated by IFS
                    for next_uri in "${ADDR[@]}"; do # access each element of array
                        log_debug "Next URI: $next_uri"
                        download_single_file "$next_uri" "output"
                    done
                    IFS=' ' # reset to default value after usage

                    # for NEXT_URI in "${URI_FILES[@]}"
                    # do
                    #     log_info "$NEXT_URI"
                    #     # download_single_file "$NEXT_URI" "output"
                    # done
                    #log_debug `cat "$HTML_PAGE_FILE_PATH" | grep -oP 'http:\/\/file[^"]*'`
                    
                    #URI_FILE=`cat $HTML_PAGE_FILE_PATH | grep -oP 'http:\/\/file[^"]*'`
                    #cat $HTML_PAGE_FILE_PATH | grep -oP 'http:\/\/file[^"]*' >> "$EBOOKS_CATALOG_FILE_PATH"
                    #echo $URI_FILE >> $EBOOKS_CATALOG_FILE_PATH
                done
            done
        }
fi



# Download all files from catalog.
# download_files_from_catalog $EBOOKS_CATALOG_FILE_PATH "$EBOOKS_OUTPUT_DIR/$EBOOKS_CATEGORY"

# Clean up temporary directory.
rm -r "$TMP_HTML_DIR"