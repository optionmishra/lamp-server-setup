#!/bin/bash

# LAMP Stack Setup Script
# This script automates the setup of a LAMP (Linux, Apache, MySQL, PHP) stack with:
# - Apache virtual hosts configuration
# - MySQL setup
# - PHP installation and configuration
# - phpMyAdmin installation
# - SFTP user creation
# - SSL certificates via Let's Encrypt

set -e # Exit on error

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

# Check if script is run as root
if [ "$(id -u)" -ne 0 ]; then
    print_message "red" "This script must be run as root or with sudo privileges"
    exit 1
fi

# Welcome message
clear
print_message "blue" "=================================================="
print_message "blue" "    LAMP Stack Server Setup Script"
print_message "blue" "=================================================="
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

# Update system packages
print_message "green" "Updating system packages..."
apt update
apt upgrade -y

# Install LAMP stack
print_message "green" "Installing Apache, MySQL, PHP, and phpMyAdmin..."
# Use DEBIAN_FRONTEND to handle automated installation
export DEBIAN_FRONTEND=noninteractive

# Set phpMyAdmin selections before installation
debconf-set-selections <<<"phpmyadmin phpmyadmin/dbconfig-install boolean true"
debconf-set-selections <<<"phpmyadmin phpmyadmin/app-password-confirm password password"
debconf-set-selections <<<"phpmyadmin phpmyadmin/mysql/admin-pass password password"
debconf-set-selections <<<"phpmyadmin phpmyadmin/mysql/app-pass password password"
debconf-set-selections <<<"phpmyadmin phpmyadmin/reconfigure-webserver multiselect apache2"

# Install required packages
apt install -y apache2 mysql-server php libapache2-mod-php php-mysql phpmyadmin php-mbstring php-zip php-gd php-json php-curl

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

# Configure SFTP users
setup_sftp() {
    print_message "green" "Setting up SFTP access..."

    # Prompt for SFTP username
    read -p "Enter SFTP username: " sftp_user

    # Check if user already exists
    if id "$sftp_user" &>/dev/null; then
        print_message "yellow" "User $sftp_user already exists."
        if ! confirm "Do you want to reconfigure this user for SFTP?"; then
            return
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

    # Give www-data group access to contents
    chown -R root:www-data /var/www/*
    chmod -R 775 /var/www/*

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
}

# Run SFTP setup
setup_sftp

# Save site configuration script
print_message "green" "Creating site configuration script..."
cat >/usr/local/bin/create-site <<'EOL'
#!/bin/bash

# Virtual Host Creation Script
# This script creates a new Apache virtual host and sets up SSL if requested

set -e # Exit on error

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

# Function to prompt for yes/no confirmation
confirm() {
    local prompt=$1
    local response

    while true; do
        read -p "$prompt (y/n): " response
        case $response in
            [Yy]* ) return 0 ;;
            [Nn]* ) return 1 ;;
            * ) echo "Please answer yes (y) or no (n)" ;;
        esac
    done
}

# Check if script is run as root
if [ "$(id -u)" -ne 0 ]; then
    print_message "red" "This script must be run as root or with sudo privileges"
    exit 1
fi

# Welcome message
clear
print_message "blue" "=================================================="
print_message "blue" "    Apache Virtual Host Creation"
print_message "blue" "=================================================="
echo ""

# Get domain name
read -p "Enter your domain name (without www): " domain_name

# Validate domain name format
if ! [[ $domain_name =~ ^[a-zA-Z0-9][a-zA-Z0-9-]{1,61}[a-zA-Z0-9]\.[a-zA-Z]{2,}$ ]]; then
    print_message "red" "Invalid domain name format. Please use format like 'example.com'"
    exit 1
fi

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
mkdir -p /var/www/$domain_name
mkdir -p /var/www/$domain_name/public_html

# Create a sample index.html file
cat > /var/www/$domain_name/public_html/index.html <<EOF
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
cat > /etc/apache2/sites-available/$domain_name.conf <<EOF
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
        cat > /var/www/$domain_name/db-credentials.txt <<EOF
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
EOL

# Make site creation script executable
chmod +x /usr/local/bin/create-site

# Set up first site
print_message "blue" "Let's set up your first website"
if confirm "Do you want to set up a virtual host now?"; then
    /usr/local/bin/create-site
fi

print_message "blue" "=================================================="
print_message "green" "LAMP stack installation completed successfully!"
print_message "blue" "=================================================="
print_message "yellow" "To create additional virtual hosts in the future, run:"
print_message "yellow" "sudo /usr/local/bin/create-site"
print_message "blue" "=================================================="
