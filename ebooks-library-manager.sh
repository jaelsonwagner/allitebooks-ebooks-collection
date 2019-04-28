#!/bin/bash
source $(dirname "$0")/util.sh

SCRIPT=$(portable_readlink "$0")
SCRIPT_PATH=$(dirname "$SCRIPT")

URL_ALL_IT_EBOOKS=http://www.allitebooks.com
TMP_DIR=$(mktemp -d --suffix=.ebooks-library-builder)
TMP_EBOOK_LINKS_FILE_PATH="$TMP_DIR/ebook-file-links.txt"
touch $TMP_EBOOK_LINKS_FILE_PATH

validate_input_argument() {
    CATEGORY_NAME=$1

    if [[ -z $CATEGORY_NAME || $CATEGORY_NAME == "" ]];
    then
        { 
            log_error "Missing argument category name. Please, provide a valid category name."; 
            exit 1; 
        }
    fi
}

verify_mandatory_utitilies() {
    local WGET_PATH=`type -p wget`
    if [[ -z $WGET_PATH ]];
    then
        { 
            log_error "Missing wget utility. Please, make sure that wget is installed!"; 
            exit 1; 
        }
    fi
}

download_html_page() {
    local URL=$1
    local TMP_HTML_PAGE_FILE_PATH=$(mktemp --tmpdir=$TMP_DIR --suffix=.page.html)

    echo "Saving html page $URL..." >&2
    wget -nv --show-progress --tries=3 --retry-connrefused -O "$TMP_HTML_PAGE_FILE_PATH" "$URL"

    echo $TMP_HTML_PAGE_FILE_PATH
}

download_ebooks() {
    while read NEXT_LINK;
    do
        log_info "Downloading file $NEXT_LINK..."
        local ORIGINAL_FILE_NAME=`echo $NEXT_LINK | grep -oP '([^\/]*)$'`
        local ENCODE_URL_FILE=${NEXT_LINK//" "/"%20"}
        wget -nv --show-progress --tries=3 --retry-connrefused -O "$TMP_DIR/$ORIGINAL_FILE_NAME" "$ENCODE_URL_FILE"
    done < "$1"
}

validate_input_argument $1
verify_mandatory_utitilies

URL_CHOOSEN_CATEGORY_PAGE="$URL_ALL_IT_EBOOKS/$CATEGORY_NAME"
DOWNLOADED_HTML_PAGE_FILE_PATH=$(download_html_page $URL_CHOOSEN_CATEGORY_PAGE)

PAGES_COUNT=`cat $DOWNLOADED_HTML_PAGE_FILE_PATH | grep -oP '1 / \d+' | grep -oP '\d+$'`
log_info "There are $PAGES_COUNT pages for category: $CATEGORY_NAME."

for PAGE_NUMBER in `seq 1 $PAGES_COUNT`
do
    if [[ $PAGE_NUMBER -gt 1 ]];
    then 
        { 
            URL_CHOOSEN_CATEGORY_PAGE="$URL_ALL_IT_EBOOKS/$CATEGORY_NAME/page/$PAGE_NUMBER";
            DOWNLOADED_HTML_PAGE_FILE_PATH=$(download_html_page $URL_CHOOSEN_CATEGORY_PAGE);
        }
    fi
    
    declare -a EBOOK_PAGES=()
    EBOOK_PAGES=($(cat $DOWNLOADED_HTML_PAGE_FILE_PATH | grep -P '<h2 class="entry-title">' | grep -oP 'http:\/\/\S+\w'))
            
    log_info "${#EBOOK_PAGES[@]} titles in page $PAGE_NUMBER"

    for NEXT_PAGE in "${EBOOK_PAGES[@]}"
    do
        HTML_PAGE_FILE_PATH=$(download_html_page $NEXT_PAGE)
        cat $HTML_PAGE_FILE_PATH | grep -oP 'http:\/\/file[^"]*' >> "$TMP_EBOOK_LINKS_FILE_PATH"             
    done
done

# while read NEXT_LINK;
# do
#     log_info "Downloading file $NEXT_LINK..."
#     ORIGINAL_FILE_NAME=`echo $NEXT_LINK | grep -oP '([^\/]*)$'`
#     ENCODE_URL_FILE=${NEXT_LINK//" "/"%20"}
#     wget -nv --show-progress --tries=3 --retry-connrefused -O "$TMP_DIR/$ORIGINAL_FILE_NAME" "$ENCODE_URL_FILE"
# done < $TMP_EBOOK_LINKS_FILE_PATH

# rm -r /tmp/*.ebooks-library-builder