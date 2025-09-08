#!/bin/zsh --no-rcs

readonly documents_file="${alfred_workflow_data}/documents.json"
readonly thumbnail_folder="${alfred_workflow_data}/thumbnails"

# Auto Update
[[ -f "${documents_file}" ]] && [[ "$(date -r "${documents_file}" +%s)" -lt "$(date -v -"${autoUpdate}"H +%s)" && "${autoUpdate}" -ne 0 ]] && reload=$(./reload.sh)

# Favicon Check
[[ "${useThumbnails}" -eq 1 ]] && [[ -f "${documents_file}" && ! -d "${thumbnail_folder}" ]] && reload=$(./reload.sh)

# Placeholder for Empty Search Query
[[ -z "${1}" && -f "${documents_file}" ]] && echo '{"items":[{ "title":"Paperless Direct Search", "subtitle":"Search against the Paperless-ngx API directly", "valid":false }]}' && exit

# Query Paperless-ngx API
autocomplete_query="${1//*(:| |\*|\(|\[|\")/}"
if [[ -n "${1}" ]]; then
    readonly search_result=$(curl -sf --connect-timeout 5 --compressed --parallel -H "Authorization: Token ${token}" -L "${baseUrl}/api/documents/?page=1&page_size=27&truncate_content=true" --url-query "query=${1}" -L "${baseUrl}/api/search/autocomplete/?limit=9" --url-query "term=${autocomplete_query}")
    [[ -z "${search_result}" ]] && echo '{"items":[{ "title":"Paperless Direct Search", "subtitle":"Unable to connect to Paperless-ngx", "valid":false }]}' && exit
fi

# Assemble JSON Objects
readonly paperless_json=(
    "$(jq -cs '(.[] | select(type == "object")), (.[] | select(type == "array"))' <<< ${search_result})"
    "$(cat ${alfred_workflow_data}/correspondents.json ${alfred_workflow_data}/document_types.json ${alfred_workflow_data}/tags.json)"
)

# Load Documents
jq -cs \
   --arg query "${1%%${autocomplete_query}}" \
   --arg fullQuery "${1}" \
   --arg paperless_keyword "${paperless_keyword}" \
   --arg baseUrl "${baseUrl}" \
   --arg useQL "${useQL}" \
   --arg useThumbnails "${useThumbnails}" \
   --arg thumbnail_folder "${thumbnail_folder}" \
'{
    "items": (if (length != 0) and (.[0].results | length > 0) and (.[4].results | length > 0) then
        .[2].results as $correspondents |
        .[3].results as $document_types |
        .[4].results as $tags |
        .[0].results | map(
            ((.correspondent as $id | $correspondents[] | select(.id == $id) | .name) // null) as $correspondent |
            ((.document_type as $id | $document_types[] | select(.id == $id) | .name) // null) as $document_type |
            ((.tags as $id | $tags | map(select(.id == $id[])) | [.[].name] | map("#"+.)) // null) as $tags |
        {
            "title": "\($correspondent | if . then .+"  -  " else "" end)\(.title | select(. != "") // "(no title)")",
            "subtitle": "🗓️ \(.created_date)\($document_type | if . then "  -  📄 "+. else "" end)\($tags | if .[0] then "  -  🏷️ "+join(", ") else "" end)",
            "arg": "\($baseUrl)/api/documents/\(.id)/preview/",
            "quicklookurl": (if ($useQL == "1" and $useThumbnails == "1") then "\($thumbnail_folder)/\(.id).webp" else "" end),
            "icon": (if $useThumbnails == "1" then {
                "path": "\($thumbnail_folder)/\(.id).webp"
            } else {
                "type": "fileicon",
                "path": "filetypes/file.\(.archived_file_name | split(".") | last)"
            } end),
            "mods": {
                "cmd": (if (.mime_type == "application/pdf") then {
					"subtitle": "⌘↩ Open in Alfred",
				    "arg": "\($baseUrl)/api/documents/\(.id)/download/",
					"variables": { "viewInlinePDF": true }
			    } else {
					"arg": "\($baseUrl)/api/documents/\(.id)/preview/"
				} end),
				"alt": {
					"subtitle": "⌥↩ View Details",
					"arg": "\($baseUrl)/documents/\(.id)/details"
				},
				"shift+alt": {
					"subtitle": "⇧⌥↩ View search in web UI",
					"arg": "\($baseUrl)/documents?query=\($fullQuery | @uri)"
				}
			}
        })
    elif (length == 0) or (.[4].results | length == 0) then
		[{
			"title": "No Documents Found",
			"subtitle": "Press ↩ to load documents",
			"arg": "reload",
			"variables": { "reloadKeyword": "\($paperless_keyword)d" }
		}]
    elif (.[0].results | length == 0) and (.[1] | length > 0) then
		.[1] | map({
 			"title": .,
 			"autocomplete": "\($query + .)",
 			"valid": false
        })
    else
        [{
			"title": "No Matches",
			"subtitle": "This query matched 0 documents",
			"valid": "false"
		}]
    end)
}' <<< "${paperless_json[@]}"