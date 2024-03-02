#!/bin/bash

# Function to extract fields from a log line
extract_fields() {
    method=$(echo "$1" | awk '{print $6}')
    path=$(echo "$1" | awk '{print $7}')
    status_code=$(echo "$1" | awk '{print $9}')
    user_agent=$(echo "$1" | awk -F'"' '{print $6}')
    echo "$method|$path|$status_code|$user_agent"
}

# Function to combine similar routes into regex pattern
combine_routes() {
    local route_array=("$@")
    local combined_route=""
    for route in "${route_array[@]}"; do
        if [ -z "$combined_route" ]; then
            combined_route="$route"
        else
            combined_route+="|$route"
        fi
    done
    echo "$combined_route"
}

# Prompt the user to enter log lines
echo "Enter log lines. Press Enter after each line. Type 'done' on a new line when finished:"
log_lines=()
while IFS= read -r line; do
    if [ "$line" == "done" ]; then
        break
    fi
    log_lines+=("$line")
done

# Extract prefix from log lines
prefix=$(echo "${log_lines[0]}" | awk '{print $7}' | cut -d'/' -f2)

# Extract fields from each log line
log_fields=()
for log_line in "${log_lines[@]}"; do
    log_fields+=("$(extract_fields "$log_line")")
done

# Group log fields by method, status code, and user agent
declare -A log_groups
for log_field in "${log_fields[@]}"; do
    IFS='|' read -r method path status_code user_agent <<< "$log_field"
    log_groups["$method $status_code $user_agent"]+=" $path"
done

# Generate regex pattern for each log group
for log_group in "${!log_groups[@]}"; do
    IFS=' ' read -r method status_code user_agent <<< "$log_group"
    paths="${log_groups[$log_group]}"
    combined_path="$(combine_routes ${paths[@]})"
    if [ "$combined_path" == "/" ]; then
        combined_path=""
    fi
    regex_pattern="^<HOST> .*"
    if [ "$method" ]; then
        regex_pattern+=" \"$method /$prefix$combined_path .*\""
    fi
    if [ "$status_code" ]; then
        regex_pattern+=" $status_code .*$"
    fi
    echo "Generated regex pattern:"
    echo "$regex_pattern"
done

