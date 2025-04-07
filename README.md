# LAMP Stack Server Setup

A collection of scripts to automate the setup of a LAMP (Linux, Apache, MySQL, PHP) stack on Ubuntu/Debian servers.

## Features

- **Full LAMP Stack Installation**: Apache, MySQL, PHP, and phpMyAdmin
- **Virtual Hosts**: Create and manage multiple websites
- **SFTP Access**: Secure file transfer with proper permissions
- **SSL Configuration**: Automatic SSL setup using Let's Encrypt
- **Database Management**: Create databases and users for each site
- **Modular Design**: Split into separate scripts for better maintenance and flexibility

## Requirements

- Ubuntu 20.04+ or Debian 10+
- Root/sudo access
- Domain name(s) pointed to your server (for SSL setup)

## Installation

1. Clone this repository:

   ```
   git clone https://github.com/optionmishra/lamp-server-setup.git
   cd lamp-server-setup
   ```

2. Make the scripts executable:

   ```
   chmod +x *.sh
   ```

3. Run the main setup script:
   ```
   sudo ./setup.sh
   ```

## Usage

### Initial Setup

Run the main setup script to install and configure the LAMP stack:

```
sudo ./setup.sh
```

This will guide you through:

- Installing Apache, MySQL, PHP, and phpMyAdmin
- Setting up SFTP access
- Creating your first virtual host (optional)

### Creating Additional Sites

After initial setup, you can create additional sites using:

```
sudo ./create-site.sh
```

This script will:

- Create virtual host configuration
- Set up document root directory
- Configure SSL with Let's Encrypt (optional)
- Create a MySQL database (optional)

## Scripts Overview

- `setup.sh`: Main installation script
- `create-site.sh`: Script to create and configure virtual hosts
- `utils.sh`: Common utility functions
- `install-lamp.sh`: LAMP stack installation
- `setup-sftp.sh`: SFTP configuration
- `secure-mysql.sh`: MySQL security configuration

## License

MIT

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
