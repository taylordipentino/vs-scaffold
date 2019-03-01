#!/usr/bin/env bash

# The name of the project being set up
# This will be used to set up the database, etc
project_name="scaffold"

# The type of project to be set up
# Possible values are wordpress, laravel
project_type="wordpress"

# Function to print messages along the way
msg() {
  echo ""
  echo " $1"
  echo ""
}

# Update the repositories and upgrade packages
msg "Updating the repositories and upgrading packages..."
apt update
apt upgrade -y

# Install required packages
msg "Installing the required packages..."
apt install -y apache2 mysql-server php php-mysql libapache2-mod-php

# If applicable, set up the database to be used by Wordpress
if [ $project_type = "wordpress" ]; then
  msg "Setting up a database for Wordpress..."

  # Generate the SQL to be executed
  sql="CREATE DATABASE $project_name; CREATE USER '$project_name'@'localhost' IDENTIFIED BY '$project_name'; GRANT ALL ON $project_name.* TO '$project_name'@'localhost'; FLUSH PRIVILEGES;"

  # Push the previously generated SQL to a file
  echo $sql >> /vagrant/provision/init.sql

  # Import the resulting SQL file to set up the database
  sudo mysql < "/vagrant/provision/init.sql"

  # Delete the file afterwards
  rm /vagrant/provision/init.sql

  msg "The database name, MySQL user, and password are all set to $project_name..."
fi

# Change the run user and group for Apache
msg "Changing the user and group that Apache runs as..."
sed -i 's/www-data/vagrant/g' /etc/apache2/envvars

# Change some PHP settings
msg "Changing some PHP settings..."
sed -i 's/memory_limit = 128M/memory_limit = 768M/' /etc/php/7.2/apache2/php.ini
sed -i 's/error_reporting = E_ALL & ~E_NOTICE & ~E_STRICT & ~E_DEPRECATED/error_reporting = E_ALL/' /etc/php/7.2/apache2/php.ini
sed -i 's/display_errors = Off/display_errors = On/' /etc/php/7.2/apache2/php.ini

# Make the document root a symlink to the Vagrant shared folder
if ! [ -L /var/www/html ]; then
  msg "Making the document root a symbolic root to the Vagrant shared folder..."
  rm -rf /var/www/html
  ln -fs /vagrant /var/www/html
fi

# Enable URL rewrites for Apache and restart it
msg "Enabling URL rewrites and restarting Apache..."
a2enmod rewrite
systemctl restart apache2

# If applicable, get the latest version of Wordpress
if [ $project_type = "wordpress" ]; then
  msg "Getting the latest version of Wordpress..."

  cd /var/www/html
  # Silently download the latest tarball, extract it, and clean up the mess afterwards
  curl -sS https://wordpress.org/latest.tar.gz -o wordpress.tar.gz
  tar -xzf wordpress.tar.gz
  rm wordpress.tar.gz
  mv wordpress/* .
  rm -r wordpress/
  cd ~/
fi

msg "All done! :)"
