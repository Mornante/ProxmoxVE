#!/usr/bin/env bash

# Copyright (c) 2021-2026 Mornante ORG
# Author: Kristian Skov
# License: MIT | https://github.com/Mornante/ProxmoxVE/raw/main/LICENSE
# Source: https://learn.microsoft.com/en-us/aspnet/core/host-and-deploy/linux-nginx?view=aspnetcore-9.0&tabs=linux-ubuntu

source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

msg_info "Installing Dependencies"
$STD apt-get update
$STD apt-get install -y \
  ssh \
  vsftpd \
  nginx
msg_ok "Installed Dependencies"

msg_info "Setting up FTP Server"
useradd ftpuser
FTP_PASS=$(openssl rand -base64 18 | tr -dc 'a-zA-Z0-9' | head -c13)
usermod --password $(echo ${FTP_PASS} | openssl passwd -1 -stdin) ftpuser
mkdir -p /var/www/html
usermod -d /var/www/html ftpuser
chown -R ftpuser:www-data /var/www/html
chmod -R 750 /var/www/html
find /var/www/html -type f -exec chmod 640 {} \;
chmod g+s /var/www/html

sed -i "s|#write_enable=YES|write_enable=YES|g" /etc/vsftpd.conf
sed -i "s|#chroot_local_user=YES|chroot_local_user=NO|g" /etc/vsftpd.conf
echo "local_umask=027" >> /etc/vsftpd.conf

systemctl restart -q vsftpd.service

{
  echo "FTP-Credentials"
  echo "Username: ftpuser"
  echo "Password: $FTP_PASS"
} >>~/ftp.creds

msg_ok "FTP server setup completed"

msg_info "Setting up Nginx Server"
rm -f /var/www/html/index.nginx-debian.html

cat >/etc/nginx/sites-available/default <<EOF
server {
  listen        80;
  server_name   _;
  root          /var/www/html;
  index         index.html;

  location / {
      try_files \$uri \$uri/ /index.html;
  }

  location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
      expires 1y;
      add_header Cache-Control "public, immutable";
  }
}
EOF

systemctl reload nginx
msg_ok "Nginx Server Created"

motd_ssh
customize
cleanup_lxc
