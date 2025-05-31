#!/bin/bash

# Update system and install packages
sudo apt update && sudo apt upgrade -y
sudo apt install apache2 ghostscript libapache2-mod-php mysql-server \
    php php-bcmath php-curl php-imagick php-intl php-json php-mbstring \
    php-mysql php-xml php-zip -y

# Create web root and set permissions
sudo mkdir -p /srv/www
sudo chown www-data: /srv/www

# Download and extract WordPress
curl https://wordpress.org/latest.tar.gz | sudo -u www-data tar zx -C /srv/www

# Create Apache site configuration
cat <<EOL | sudo tee /etc/apache2/sites-available/wordpress.conf
<VirtualHost *:80>
    DocumentRoot /srv/www/wordpress
    <Directory /srv/www/wordpress>
        Options FollowSymLinks
        AllowOverride Limit Options FileInfo
        DirectoryIndex index.php
        Require all granted
    </Directory>
    <Directory /srv/www/wordpress/wp-content>
        Options FollowSymLinks
        Require all granted
    </Directory>
</VirtualHost>
EOL

# Enable site, rewrite module, and disable default site
sudo a2ensite wordpress
sudo a2enmod rewrite
sudo a2dissite 000-default
sudo service apache2 reload

# Create WordPress database and user
DB_PASS="admin123"

sudo mysql -u root <<MYSQL_SCRIPT
CREATE DATABASE wordpress;
CREATE USER wordpress@localhost IDENTIFIED BY '$DB_PASS';
GRANT SELECT,INSERT,UPDATE,DELETE,CREATE,DROP,ALTER ON wordpress.* TO wordpress@localhost;
FLUSH PRIVILEGES;
MYSQL_SCRIPT

# Configure WordPress
sudo -u www-data cp /srv/www/wordpress/wp-config-sample.php /srv/www/wordpress/wp-config.php
sudo -u www-data sed -i 's/database_name_here/wordpress/' /srv/www/wordpress/wp-config.php
sudo -u www-data sed -i 's/username_here/wordpress/' /srv/www/wordpress/wp-config.php
sudo -u www-data sed -i "s/password_here/$DB_PASS/" /srv/www/wordpress/wp-config.php

# Replace auth keys with generated salts
SALT=$(curl -s https://api.wordpress.org/secret-key/1.1/salt/)
sudo -u www-data sed -i "/AUTH_KEY/d;/SECURE_AUTH_KEY/d;/LOGGED_IN_KEY/d;/NONCE_KEY/d;/AUTH_SALT/d;/SECURE_AUTH_SALT/d;/LOGGED_IN_SALT/d;/NONCE_SALT/d" /srv/www/wordpress/wp-config.php
sudo -u www-data bash -c "echo "$SALT" >> /srv/www/wordpress/wp-config.php"

echo "WordPress setup completed successfully. Visit your server IP in a browser to complete installation."
