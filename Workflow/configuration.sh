#!/bin/zsh --no-rcs

# Get lastest cache timestamp
readonly documents_file="${alfred_workflow_data}/documents.json"
readonly lastUpdated=$(date -r "${documents_file}" +"%A, %B %d %Y at %I:%M%p" || printf "Never")

cat << EOB
{"items": [
	{
		"title": "Reload Documents",
		"subtitle": "Last Updated: ${lastUpdated}",
		"variables": { "pref_id": "reload", "reloadKeyword": "${paperless_keyword}" }
	},
	{
		"title": "Open Paperless-ngx",
		"variables": { "pref_id": "open" }
	},
	{
		"title": "Browser Settings",
		"subtitle": "Select the default browser for ${alfred_workflow_name}",
		"variables": { "pref_id": "browser" }
	}
]}
EOB