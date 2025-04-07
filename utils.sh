#!/bin/bash

# Utility functions for LAMP stack setup scripts

# Function to display colorful messages
print_message() {
    local color=$1
    local message=$2

    case $color in
    "green") echo -e "\e[32m$message\e[0m" ;;
    "yellow") echo -e "\e[33m$message\e[0m" ;;
    "red") echo -e "\e[31m$message\e[0m" ;;
    "blue") echo -e "\e[34m$message\e[0m" ;;
    *) echo "$message" ;;
    esac
}

# Function to display a header
print_header() {
    local message=$1
    print_message "blue" "=================================================="
    print_message "blue" "    $message"
    print_message "blue" "=================================================="
}

# Function to prompt for yes/no confirmation
confirm() {
    local prompt=$1
    local response

    while true; do
        read -p "$prompt (y/n): " response
        case $response in
        [Yy]*) return 0 ;;
        [Nn]*) return 1 ;;
        *) echo "Please answer yes (y) or no (n)" ;;
        esac
    done
}

# Function to check if script is run as root
check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        print_message "red" "This script must be run as root or with sudo privileges"
        exit 1
    fi
}

# Function to validate domain name
validate_domain() {
    local domain=$1
    if ! [[ $domain =~ ^[a-zA-Z0-9][a-zA-Z0-9-]{1,61}[a-zA-Z0-9]\.[a-zA-Z]{2,}$ ]]; then
        print_message "red" "Invalid domain name format. Please use format like 'example.com'"
        return 1
    fi
    return 0
}
