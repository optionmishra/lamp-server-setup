#!/bin/bash

# SFTP Setup Script
# This script configures SFTP access

# Source utility functions
source "$(dirname "$0")/utils.sh"

# Check if script is run as root
check_root

print_message "green" "Setting up SFTP access..."

# Prompt for SFTP username
read -p "Enter SFTP username: " sftp_user

# Check if user already exists
if id "$sftp_user" &>/dev/null; then
    print_message "yellow" "User $sftp_user already exists."
    if ! confirm "Do you want to reconfigure this user for SFTP?"; then
        exit 0
    fi
else
    # Create new user
    adduser $sftp_user
fi

# Create www-data group if not exists
getent group www-data >/dev/null || groupadd www-data

# Add users to www-data group
usermod -aG www-data $USER
usermod -aG www-data $sftp_user

# Set correct permissions for /var/www
chown root:root /var/www
chmod 755 /var/www

# Create the directory if it doesn't exist
if [ ! -d "/var/www" ]; then
    mkdir -p /var/www
fi

# Give www-data group access to contents
# Only apply if there's content in /var/www
if [ "$(ls -A /var/www 2>/dev/null)" ]; then
    chown -R root:www-data /var/www/*
    chmod -R 775 /var/www/*
fi

# Set SFTP user's home directory
usermod -d /var/www $sftp_user

# Configure SFTP in sshd_config
# First check if the configuration already exists
if grep -q "Match User $sftp_user" /etc/ssh/sshd_config; then
    print_message "yellow" "SFTP configuration for $sftp_user already exists."
else
    # Add configuration to sshd_config
    cat >>/etc/ssh/sshd_config <<EOL

# SFTP configuration for $sftp_user
Match User $sftp_user
    ChrootDirectory /var/www
    ForceCommand internal-sftp
    PasswordAuthentication yes
    AllowTcpForwarding no
    X11Forwarding no
EOL

    # Restart SSH service
    systemctl restart ssh.service
    print_message "green" "SFTP access configured for $sftp_user."
fi
