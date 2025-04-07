#!/bin/bash

# MySQL Security Configuration Script
# This script secures the MySQL installation

# Source utility functions
source "$(dirname "$0")/utils.sh"

# Check if script is run as root
check_root

# Secure MySQL installation
print_message "green" "Securing MySQL installation..."
read -sp "Enter a password for MySQL root user: " mysql_root_password
echo ""
read -sp "Confirm MySQL root password: " mysql_root_password_confirm
echo ""

if [ "$mysql_root_password" != "$mysql_root_password_confirm" ]; then
    print_message "red" "Passwords do not match. Aborting."
    exit 1
fi

# Secure MySQL installation
mysql --user=root <<_EOF_
ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '${mysql_root_password}';
DELETE FROM mysql.user WHERE User='';
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
FLUSH PRIVILEGES;
_EOF_

print_message "green" "MySQL has been secured."
