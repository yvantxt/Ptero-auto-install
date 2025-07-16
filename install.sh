#!/bin/bash

apt update -y && apt upgrade -y

apt install -y nginx mysql-server php php-cli php-mysql php-gd php-mbstring php-xml php-bcmath php-curl php-zip unzip curl tar git redis composer ufw

DB_NAME="admin"
DB_USER="admin"
DB_PASS="admin"
mysql -u root <<EOF
CREATE DATABASE ${DB_NAME};
CREATE USER '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';
GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'localhost';
FLUSH PRIVILEGES;
EOF

mkdir -p /var/www/pterodactyl
cd /var/www/pterodactyl
curl -Lo panel.tar.gz https://github.com/pterodactyl/panel/releases/latest/download/panel.tar.gz
tar -xzvf panel.tar.gz
composer install --no-dev --optimize-autoloader

cp .env.example .env
php artisan key:generate --force
php artisan p:environment:setup --email="admin@example.com" --username=admin --password="admin" --db_host="127.0.0.1" --db_port="3306" --db_database="${DB_NAME}" --db_username="${DB_USER}" --db_password="${DB_PASS}"
php artisan migrate --seed --force
chown -R www-data:www-data /var/www/pterodactyl
chmod -R 755 /var/www/pterodactyl/storage/* /var/www/pterodactyl/bootstrap/cache/

cat > /etc/nginx/sites-available/pterodactyl <<EOF
server {
    listen 80 default_server;
    server_name _;
    root /var/www/pterodactyl/public;
    index index.php;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php\$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php8.1-fpm.sock;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOF

ln -s /etc/nginx/sites-available/pterodactyl /etc/nginx/sites-enabled/
nginx -t && systemctl reload nginx

curl -sSL https://get.docker.com/ | CHANNEL=stable bash
systemctl enable --now docker

mkdir -p /etc/pterodactyl
curl -Lo /etc/pterodactyl/config.yml https://raw.githubusercontent.com/pterodactyl/wings/master/config.yml
curl -Lo /usr/local/bin/wings https://github.com/pterodactyl/wings/releases/latest/download/wings_linux_amd64
chmod +x /usr/local/bin/wings

echo "Install Complete. Access the panel via your server IP. Login with admin / admin"