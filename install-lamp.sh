#!/bin/bash

# LAMP Stack Installation Script
# This script installs Apache, MySQL, PHP, and phpMyAdmin

# Source utility functions
source "$(dirname "$0")/utils.sh"

# Check if script is run as root
check_root

# Update system packages
print_message "green" "Updating system packages..."
apt update
apt upgrade -y

# Install LAMP stack
print_message "green" "Installing Apache, MySQL, PHP, and phpMyAdmin..."
export DEBIAN_FRONTEND=noninteractive

# Set phpMyAdmin selections before installation
debconf-set-selections <<<"phpmyadmin phpmyadmin/dbconfig-install boolean true"
debconf-set-selections <<<"phpmyadmin phpmyadmin/app-password-confirm password password"
debconf-set-selections <<<"phpmyadmin phpmyadmin/mysql/admin-pass password password"
debconf-set-selections <<<"phpmyadmin phpmyadmin/mysql/app-pass password password"
debconf-set-selections <<<"phpmyadmin phpmyadmin/reconfigure-webserver multiselect apache2"

# Install required packages
apt install -y apache2 mysql-server php libapache2-mod-php php-mysql phpmyadmin php-mbstring php-zip php-gd php-json php-curl composer
wget -qO- https://get.pnpm.io/install.sh | sh -
source ~/.bashrc

# Configure phpMyAdmin
print_message "green" "Configuring phpMyAdmin..."
if [ ! -f /etc/apache2/conf-available/phpmyadmin.conf ]; then
    echo "Include /etc/phpmyadmin/apache.conf" >/etc/apache2/conf-available/phpmyadmin.conf
    a2enconf phpmyadmin
    systemctl reload apache2
fi

# Enable Apache modules
print_message "green" "Enabling Apache modules..."
a2enmod rewrite
a2enmod ssl
systemctl restart apache2

# Enable and start Apache
systemctl start apache2
systemctl enable apache2

print_message "green" "LAMP stack installation completed."
