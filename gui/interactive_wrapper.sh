#!/bin/bash
# interactive_wrapper.sh - Wrapper that makes any script fully GUI-interactive via Zenity
# This script intercepts all read prompts and shows Zenity dialogs instead

# Override the read command to use Zenity
read() {
    local prompt=""
    local var_name=""
    local response=""
    
    # Parse read arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -p)
                prompt="$2"
                shift 2
                ;;
            -r*)
                # Skip -r flag (raw input)
                shift
                ;;
            *)
                var_name="$1"
                shift
                ;;
        esac
    done
    
    # Show Zenity dialog based on prompt content
    if [[ "$prompt" =~ Select\ option.*\[1\] ]]; then
        # Main menu
        response=$(zenity --list \
            --title="Maintenance Mode" \
            --text="Choose maintenance operation:" \
            --column="Option" \
            --column="Description" \
            --width=500 \
            --height=300 \
            "1" "Full maintenance (recommended)" \
            "2" "Custom selection" \
            "3" "Simple mode" \
            "0" "Exit" 2>/dev/null)
        case "$response" in
            "1") response="1" ;;
            "2") response="2" ;;
            "3") response="3" ;;
            "0"|"") response="0" ;;
            *) response="1" ;;
        esac
        
    elif [[ "$prompt" =~ Install.*missing.*required.*packages ]]; then
        if zenity --question \
            --title="Package Installation" \
            --text="Install missing required packages?" \
            --width=400 2>/dev/null; then
            response="Y"
        else
            response="n"
        fi
        
    elif [[ "$prompt" =~ Install.*optional.*packages ]]; then
        if zenity --question \
            --title="Optional Packages" \
            --text="Install optional enhancement packages?" \
            --width=400 2>/dev/null; then
            response="y"
        else
            response="N"
        fi
        
    elif [[ "$prompt" =~ Continue.*low.*memory ]]; then
        if zenity --question \
            --title="Low Memory Warning" \
            --text="System has low available memory. Continue anyway?" \
            --width=400 2>/dev/null; then
            response="y"
        else
            response="N"
        fi
        
    elif [[ "$prompt" =~ Continue.*low.*disk ]]; then
        if zenity --question \
            --title="Low Disk Space Warning" \
            --text="System has low available disk space. Continue anyway?" \
            --width=400 2>/dev/null; then
            response="y"
        else
            response="N"
        fi
        
    elif [[ "$prompt" =~ Show.*detailed.*status ]]; then
        if zenity --question \
            --title="Show Details" \
            --text="Show detailed status information?" \
            --width=400 2>/dev/null; then
            response="y"
        else
            response="N"
        fi
        
    elif [[ "$prompt" =~ Run.*\? ]]; then
        local operation
        operation=$(echo "$prompt" | sed -n 's/.*Run \(.*\)? \[.*/\1/p')
        if zenity --question \
            --title="Confirm Operation" \
            --text="Run: $operation?" \
            --width=400 2>/dev/null; then
            response="Y"
        else
            response="n"
        fi
        
    else
        # Generic prompt - try to extract default from [X] pattern
        if [[ "$prompt" =~ \[([YyNn])\] ]]; then
            local default="${BASH_REMATCH[1]}"
            if zenity --question \
                --title="Confirm" \
                --text="$prompt" \
                --width=400 2>/dev/null; then
                response="Y"
            else
                response="N"
            fi
        else
            # Text input
            response=$(zenity --entry \
                --title="Input Required" \
                --text="$prompt" \
                --width=400 2>/dev/null || echo "")
        fi
    fi
    
    # Set the variable if specified
    if [[ -n "$var_name" ]]; then
        printf -v "$var_name" "%s" "$response"
    else
        echo "$response"
    fi
}

# Export the function so subshells can use it
export -f read

# Execute the original script with all arguments
exec "$@"
