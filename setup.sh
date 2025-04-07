#!/bin/bash

# Main LAMP Stack Setup Script
# This script orchestrates the installation and configuration of the LAMP stack

# Source utility functions
source "$(dirname "$0")/utils.sh"

# Check if script is run as root
check_root

# Welcome message
clear
print_header "LAMP Stack Server Setup"
print_message "yellow" "This script will install and configure:"
print_message "yellow" "- Apache web server with virtual hosts"
print_message "yellow" "- MySQL/MariaDB database server"
print_message "yellow" "- PHP and required extensions"
print_message "yellow" "- phpMyAdmin"
print_message "yellow" "- SFTP access"
print_message "yellow" "- SSL certificates via Let's Encrypt"
echo ""

if ! confirm "Do you want to continue?"; then
    print_message "red" "Setup aborted"
    exit 0
fi

# Run LAMP installation script
bash "$(dirname "$0")/install-lamp.sh"

# Secure MySQL
bash "$(dirname "$0")/secure-mysql.sh"

# Setup SFTP
bash "$(dirname "$0")/setup-sftp.sh"

# Copy the create-site script to /usr/local/bin
cp "$(dirname "$0")/create-site.sh" /usr/local/bin/create-site
chmod +x /usr/local/bin/create-site

# Set up first site
print_message "blue" "Let's set up your first website"
if confirm "Do you want to set up a virtual host now?"; then
    /usr/local/bin/create-site
fi

print_header "LAMP stack installation completed successfully!"
print_message "yellow" "To create additional virtual hosts in the future, run:"
print_message "yellow" "sudo /usr/local/bin/create-site"
print_message "blue" "=================================================="
