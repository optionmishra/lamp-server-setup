#!/bin/bash

# Virtual Host Creation Script
# This script creates a new Apache virtual host and sets up SSL if requested

# Source utility functions if running as standalone script
SCRIPT_DIR=$(dirname "$0")
if [ -f "$SCRIPT_DIR/utils.sh" ]; then
    source "$SCRIPT_DIR/utils.sh"
else
    # If utils.sh is not found in the current directory,
    # it might be running from /usr/local/bin
    source "/usr/local/bin/utils.sh" 2 >/dev/null || {
        # Include utility functions directly as fallback
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
    }
fi

set -e # Exit on error

# Check if script is run as root
check_root

# Welcome message
clear
print_header "Apache Virtual Host Creation"
echo ""

# Get domain name
read -p "Enter your domain name (without www): " domain_name

# Validate domain name format
validate_domain "$domain_name" || exit 1

# Check if site config already exists
if [ -f "/etc/apache2/sites-available/$domain_name.conf" ]; then
    print_message "yellow" "Configuration for $domain_name already exists."
    if ! confirm "Do you want to overwrite it?"; then
        print_message "red" "Setup aborted"
        exit 0
    fi
fi

# Create document root
print_message "green" "Creating document root directory..."
mkdir -p /var/www/$domain_name/public_html

# Create a sample index.html file
cat >/var/www/$domain_name/public_html/index.html <<EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Welcome to $domain_name</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            line-height: 1.6;
            margin: 0;
            padding: 20px;
            text-align: center;
        }
        .container {
            max-width: 800px;
            margin: 0 auto;
            padding: 20px;
            border: 1px solid #ddd;
            border-radius: 5px;
            background-color: #f9f9f9;
        }
        h1 {
            color: #333;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>Welcome to $domain_name!</h1>
        <p>This is a placeholder page. Replace this with your actual website content.</p>
        <p>Your website is now hosted on this server.</p>
    </div>
</body>
</html>
EOF

# Set permissions
chown -R www-data:www-data /var/www/$domain_name
chmod -R 775 /var/www/$domain_name

# Create virtual host configuration
print_message "green" "Creating Apache virtual host configuration..."
cat >/etc/apache2/sites-available/$domain_name.conf <<EOF
<VirtualHost *:80>
    ServerAdmin webmaster@$domain_name
    ServerName $domain_name
    ServerAlias www.$domain_name
    DocumentRoot /var/www/$domain_name/public_html

    <Directory /var/www/$domain_name/public_html>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    ErrorLog \${APACHE_LOG_DIR}/$domain_name-error.log
    CustomLog \${APACHE_LOG_DIR}/$domain_name-access.log combined
</VirtualHost>
EOF

# Enable the site and disable default site if needed
a2ensite $domain_name.conf

# Ask about disabling default site
if [ -f "/etc/apache2/sites-enabled/000-default.conf" ]; then
    if confirm "Do you want to disable the default Apache virtual host?"; then
        a2dissite 000-default.conf
    fi
fi

# Reload Apache
systemctl reload apache2

# Option for setting up SSL with Let's Encrypt
if confirm "Do you want to set up SSL using Let's Encrypt for $domain_name?"; then
    print_message "green" "Installing Let's Encrypt (Certbot)..."

    # Check if certbot is installed
    if ! [ -x "$(command -v certbot)" ]; then
        apt install -y certbot python3-certbot-apache
    fi

    # Get SSL certificate
    print_message "green" "Obtaining SSL certificate for $domain_name..."
    certbot --apache -d $domain_name -d www.$domain_name

    print_message "green" "SSL certificate has been installed."
else
    print_message "yellow" "SSL setup skipped. You can run certbot later to set up SSL."
fi

# Create MySQL database for the site
if confirm "Do you want to create a MySQL database for $domain_name?"; then
    read -p "Enter database name: " db_name
    read -p "Enter database username: " db_user
    read -sp "Enter database password: " db_password
    echo ""

    # Default to using the domain name (without dot) as database name if not specified
    if [ -z "$db_name" ]; then
        db_name=${domain_name//./_}
    fi

    # Default to using the domain name (without dot) as username if not specified
    if [ -z "$db_user" ]; then
        db_user=${domain_name//./_}
    fi

    # Create database and user
    mysql -u root -p <<MYSQL_SCRIPT
CREATE DATABASE IF NOT EXISTS \`$db_name\`;
CREATE USER IF NOT EXISTS '$db_user'@'localhost' IDENTIFIED BY '$db_password';
GRANT ALL PRIVILEGES ON \`$db_name\`.* TO '$db_user'@'localhost';
FLUSH PRIVILEGES;
MYSQL_SCRIPT

    print_message "green" "Database $db_name and user $db_user created."

    # Save database credentials to a file
    if confirm "Do you want to save the database credentials to a file?"; then
        cat >/var/www/$domain_name/db-credentials.txt <<EOF
Database Name: $db_name
Database User: $db_user
Database Password: $db_password
Host: localhost
EOF
        chmod 600 /var/www/$domain_name/db-credentials.txt
        print_message "yellow" "Database credentials saved to /var/www/$domain_name/db-credentials.txt"
        print_message "yellow" "Please remove this file after noting down the information!"
    fi
fi

print_message "green" "Virtual host for $domain_name has been configured successfully!"
print_message "green" "Your website is now accessible at: http://$domain_name/"
if [ -x "$(command -v certbot)" ]; then
    print_message "green" "If SSL was set up, your website is also accessible at: https://$domain_name/"
fi
