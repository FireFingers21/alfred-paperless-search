#!/bin/zsh --no-rcs

readonly documents_file="${alfred_workflow_data}/documents.json"
readonly thumbnail_folder="${alfred_workflow_data}/thumbnails"

mkdir -p "${alfred_workflow_data}"
readonly oldModified=$(jq -cs '.[].results[].modified' ${documents_file})
http_code=($(curl -sf --connect-timeout 5 --max-time 15 --compressed --parallel -w "%{http_code} " --output-dir "${alfred_workflow_data}" -H "Authorization: Token ${token}" -L "${baseUrl}/api/documents/?page=1&page_size=100000&truncate_content=true" -o "documents.json" -L "${baseUrl}/api/{correspondents,document_types,tags}/" -o "#1.json"))
readonly newModified=$(jq -cs '.[].results[].modified' ${documents_file})

typeset -U http_code
if [[ "${http_code}" -eq 200 ]]; then
    # Refresh Thumbnail cache
    if [[ "${useThumbnails}" -eq 1 && ("${oldModified}" != "${newModified}" || ! -d "${thumbnail_folder}") ]]; then
        mkdir -p "${thumbnail_folder}"
        readonly idList=$(jq -sr '.[].all | @csv' ${documents_file})
    	curl -sf --compressed --parallel --output-dir "${thumbnail_folder}" -H "Authorization: Token ${token}" -L "${baseUrl}/api/documents/{${idList}}/thumb/" -o "#1.webp"
    	find "${thumbnail_folder}" -type f -maxdepth 1 ! -newer "${documents_file}" -delete
    elif [[ "${useThumbnails}" -eq 0 && -d "${thumbnail_folder}" ]]; then
        rm -r "${thumbnail_folder}"
    fi
    printf "Documents Updated"
elif [[ "${http_code}" -eq 401 ]]; then
	printf "Invalid API Token"
else
    printf "Paperless-ngx server not found"
fi