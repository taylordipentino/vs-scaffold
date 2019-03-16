#!/usr/bin/env bash

# The name of the project being set up
# This will be used to set up the database, etc
project_name="scaffold"

# The type of project to be set up
# Possible values are wordpress, laravel
project_type="laravel"

# The type of database to be set up
# Possible values are mysql, none
database_type="mysql"

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

# Determine what packages need to be installed
msg "Determining packages to be installed based on project type"
install_packages=(
  apache2
  php
  libapache2-mod-php
)
if [ $database_type = "mysql" ]; then
  install_packages+=('mysql-server')
  install_packages+=('php-mysql')
fi
if [ $project_type = "laravel" ]; then
  install_packages+=('php-tokenizer')
  install_packages+=('php-mbstring')
  install_packages+=('php-bcmath')
  install_packages+=('php-json')
  install_packages+=('php-xml')
fi

# Install required packages
msg "Installing the required packages..."
if ! apt install -y ${install_packages[@]}; then
  msg "ERROR: Failed to install required packages!"
  exit 1
fi

# If applicable, set up a MySQL database
if [ $database_type = "mysql" ]; then
  msg "Setting up a MySQL database..."

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

if [ $project_type = "laravel" ]; then
  # Change the document root
  msg "Changing the document root..."
  sed -i 's/DocumentRoot \/var\/www\/html/DocumentRoot \/var\/www\/html\/public/' /etc/apache2/sites-available/000-default.conf
fi

# Change some PHP settings
msg "Changing some PHP settings..."
sed -i 's/memory_limit = 128M/memory_limit = 768M/' /etc/php/7.2/apache2/php.ini
sed -i 's/error_reporting = E_ALL & ~E_NOTICE & ~E_STRICT & ~E_DEPRECATED/error_reporting = E_ALL/' /etc/php/7.2/apache2/php.ini
sed -i 's/display_errors = Off/display_errors = On/' /etc/php/7.2/apache2/php.ini
# Enable the PDO extension if mysql is in use
if [ $database_type = "mysql" ]; then
  sed -i 's/;extension=pdo_mysql/extension=pdo_mysql/' /etc/php/7.2/apache2/php.ini
fi

# Make the document root a symlink to the Vagrant shared folder
if ! [ -L /var/www/html ]; then
  msg "Making the document root a symbolic link to the Vagrant shared folder..."
  rm -rf /var/www/html
  ln -fs /vagrant /var/www/html
fi

# Enable URL rewrites for Apache and restart it
msg "Enabling URL rewrites and restarting Apache..."
a2enmod rewrite
systemctl restart apache2

# If necessary, install Composer
if [ $project_type = "laravel" ]; then 
  msg "Installing Composer..."
  EXPECTED_SIGNATURE="$(wget -q -O - https://composer.github.io/installer.sig)"
  php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
  ACTUAL_SIGNATURE="$(php -r "echo hash_file('sha384', 'composer-setup.php');")"

  if [ $EXPECTED_SIGNATURE != $ACTUAL_SIGNATURE ]; then
    msg "ERROR: Invalid installer signature"
    rm composer-setup.php
    exit 1
  fi

  php composer-setup.php --quiet
  rm composer-setup.php
  mv composer.phar /usr/local/bin/composer.phar
fi

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

# If applicable, get the latest version of Laravel
if [ $project_type = "laravel" ]; then
  cd /var/www/html
  composer.phar create-project --quiet --prefer-dist laravel/laravel laravel
  mv laravel/* .
  mv laravel/.* .
  rm -r laravel
  php artisan key:generate
  cd ~/
fi

msg "All done! :)"


