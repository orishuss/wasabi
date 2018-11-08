#!/bin/bash

USAGE="USAGE: wasabi [--list] <name>"
CONFIG_FILE="/home/$(whoami)/.wasabi-workspace-names"

VIEWPORT_WIDTH=1920
VIEWPORT_HEIGHT=1200
HORIZONTAL_VIEWPORTS=3
VERTICAL_VIEWPORTS=3
WORKSPACE_NAME_LENGTH=30

set_names() {
    names=()
    viewports="$((VERTICAL_VIEWPORTS * HORIZONTAL_VIEWPORTS))"
    for num in $(seq $viewports); do
        names+=("\"""$(sed ''$num'q;d' $CONFIG_FILE)""\"")
    done

    gsettings set \
        org.gnome.desktop.wm.preferences \
        workspace-names \
        "[""$(echo "${names[@]}" | sed 's|\" \"|\",\"|g')""]"
}

change_name() {
    name="$1"

    viewport="$(get_current_viewport)"

    sed -i "$viewport""s|.*|""$name""|g" "$CONFIG_FILE"
}

change_to_default_name() {
    viewport="$(get_current_viewport)"

    local name="Workspace ""$viewport"

    sed -i "$viewport""s|.*|""$name""|g" "$CONFIG_FILE"
}

get_current_viewport() {
    # Get the location of the viewport.
    location="$(xprop -root -notype _NET_DESKTOP_VIEWPORT)"
    x="$(echo ""$location"" | cut -d' ' -f3 \
        | cut -d',' -f1)"
    y="$(echo ""$location"" | cut -d' ' -f4)"

    row=$((y / $VIEWPORT_HEIGHT))
    column=$((x / $VIEWPORT_WIDTH))

    viewport="$((row * HORIZONTAL_VIEWPORTS))"
    viewport="$((viewport + column))"
    viewport="$((viewport + 1))"

    echo "$viewport"
}

print_usage() {
    echo "$USAGE"
    exit 1
}

print_line_separator() {
    workspace_name_length=$WORKSPACE_NAME_LENGTH

    normal_sep="$1"
    column_sep="$2"

    line_separator="$column_sep"
    for i in $(seq 1 $HORIZONTAL_VIEWPORTS); do
        for j in $(seq 1 $workspace_name_length); do
            line_separator="$line_separator""$normal_sep"
        done
        line_separator="$line_separator""$column_sep"
    done
    echo "$line_separator"
}

list_workspaces() {
    IFS=$'\n' read -d '' -r -a names < "$CONFIG_FILE"
    current_workspace=0
    workspace_name_length="$WORKSPACE_NAME_LENGTH"
    print_line_separator "_" "_"
    echo -n "|"
    # Loop through workspace names.
    for name in "${names[@]}"; do
        current_workspace="$((current_workspace + 1))"
        name="$(echo ""$name"" | tr -d '\n')"
        # Make sure name will be padded with spaces until its length is the needed length.
        spaces_to_pad="$((workspace_name_length - ${#name}))"
        for i in $(seq 1 $spaces_to_pad); do
            if [[ $((i % 2)) -eq 0 ]]; then
                name=" ""$name"
            else
                name="$name"" "
            fi
        done
        # If name is longer than the needed length, remove last letters and end it with
        # '...'
        if [[ ${#name} -gt $workspace_name_length ]]; then
            workspace_name_length_without_three_dots="$((\
                $workspace_name_length - 3))"
            name="${name:0:$workspace_name_length_without_three_dots}""..."
        fi
        if (( $current_workspace % $HORIZONTAL_VIEWPORTS == 0 )); then
            # Jump row if ended it.
            row="$row""$name""|"
            echo "$row"
            row="|"
            print_line_separator "_" "|"
        else
            row="$row""$name""|"
        fi
    done
}

for i in "$@"; do
    if [[ $i = "--help" ]]; then
        echo "$USAGE"
        exit 0
    elif [[ "$i" = "--list" ]]; then
        list_workspaces
        exit 0
    else
        if [[ -n "$name" ]]; then
            echo "Too many arguments given." >&2
            echo "$USAGE"
            exit 1
        fi
        name="$i"
    fi
done

if [[ -z "$name" ]]; then
    # Change to default name.
    change_name "  "
else
    # Change to the name the user entered.
    change_name "$name"
fi

# Set the workspace names.
set_names
