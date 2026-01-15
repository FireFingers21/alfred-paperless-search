#!/bin/zsh --no-rcs

readonly documents_file="${alfred_workflow_data}/documents.json"
readonly thumbnail_folder="${alfred_workflow_data}/thumbnails"
readonly correspondents_file="${alfred_workflow_data}/correspondents.json"
readonly document_types_file="${alfred_workflow_data}/document_types.json"
readonly tags_file="${alfred_workflow_data}/tags.json"

# Default to Grid View
[[ "${defaultToGrid}" -eq 1 && "${gridView}" -ne 1 && "${listView}" -ne 1 && $(jq -cs '(length != 0) and (.[0].results | length > 0) and (.[3].results | length > 0)' "${documents_file}" "${correspondents_file}" "${document_types_file}" "${tags_file}") == "true" ]] && ./grid.js && exit

# Auto Update
[[ -f "${documents_file}" ]] && [[ "$(date -r "${documents_file}" +%s)" -lt "$(date -v -"${autoUpdate}"H +%s)" && "${autoUpdate}" -ne 0 ]] && reload=$(./reload.sh)

# Force Thumbnails in Grid View
[[ "${gridView}" -eq 1 && "${useThumbnails}" -eq 0 ]] && useThumbnails=1

# Favicon Check
[[ "${useThumbnails}" -eq 1 ]] && [[ -f "${documents_file}" && ! -d "${thumbnail_folder}" ]] && reload=$(./reload.sh)

# Load Documents
jq -cs \
   --arg paperless_keyword "${paperless_keyword}" \
   --arg baseUrl "${baseUrl}" \
   --arg useCorrespondent "${useCorrespondent}" \
   --arg useTag "${useTag}" \
   --arg useDocumentType "${useDocumentType}" \
   --arg useQL "${useQL}" \
   --arg useThumbnails "${useThumbnails}" \
   --arg gridView "${gridView}" \
   --arg thumbnail_folder "${thumbnail_folder}" \
'{
    "items": (if (length != 0) and (.[0].results | length > 0) and (.[3].results | length > 0) then
        .[1].results as $correspondents |
        .[2].results as $document_types |
        .[3].results as $tags |
        .[0].results | map(
            ((.correspondent as $id | $correspondents[] | select(.id == $id) | .name) // null) as $correspondent |
            ((.document_type as $id | $document_types[] | select(.id == $id) | .name) // null) as $document_type |
            ((.tags as $id | $tags | map(select(.id == $id[])) | [.[].name] | map("#"+.)) // null) as $tags |
        {
            "uid": .id,
            "title": "\($correspondent | if (. and $gridView != "1") then .+"  -  " else "" end)\(.title | select(. != "") // "(no title)")",
            "subtitle": "🗓️ \(.created_date)\($document_type | if . then "  -  📄 "+. else "" end)\($tags | if .[0] then "  -  🏷️ "+join(", ") else "" end)",
            "arg": "\($baseUrl)/api/documents/\(.id)/preview/",
            "match": "\(.title) \(.created_date) \(if $useCorrespondent == "1" then ("\"@"+$correspondent+"\"") else "" end) \(if $useDocumentType == "1" then ("\"$"+$document_type+"\"") else "" end) \($tags | map(select($useTag == "1")))",
            "quicklookurl": (if ($useQL == "1" and $useThumbnails == "1") then "\($thumbnail_folder)/\(.id).webp" else "" end),
            "icon": (if $useThumbnails == "1" then {
                "path": "\($thumbnail_folder)/\(.id).webp"
            } else {
                "type": "fileicon",
                "path": "filetypes/file.\((.archived_file_name // .original_file_name // "file.pdf") | split(".") | last)"
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
				}
			}
        })
    elif (length == 0) or (.[3].results | length == 0) then
		[{
			"title": "No Documents Found",
			"subtitle": "Press ↩ to load documents",
			"arg": "reload",
			"variables": { "reloadKeyword": "\($paperless_keyword)" }
		}]
	else
		[{
			"title": "Search Documents...",
			"subtitle": "You have no documents",
			"valid": "false"
		}]
    end)
}' "${documents_file}" "${correspondents_file}" "${document_types_file}" "${tags_file}"