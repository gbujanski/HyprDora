loger() {

    local log_level="$1"
    local log_message="$2"
    local reset='\e[0m'
    local red='\e[1;31m'
    local green='\e[1;32m'
    local yellow='\e[1;33m'
    local blue='\e[1;34m'
    local magenta='\e[1;35m'
    local cyan='\e[1;36m'

    case "$log_level" in
        "INFO") color="$green" ;;
        "WARNING") color="$yellow" ;;
        "ERROR") color="$red" ;;
        "SUCCESS") color="$blue" ;;
        *) color="$reset" ;;
    esac

	echo -e "${color}=================================="
	echo -e "[${log_level}] ${log_message}"
	echo -e "==================================${reset}"
}

log_info() {
    # $1 - log message
    loger "INFO" "$1"
}

log_warning() {
    # $1 - log message
    loger "WARNING" "$1"
}

log_error() {
    # $1 - log message
    loger "ERROR" "$1"
}

log_success() {
    # $1 - log message
    loger "SUCCESS" "$1"
}