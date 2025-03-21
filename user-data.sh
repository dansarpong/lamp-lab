#!/bin/bash

# Install dependencies
sudo DEBIAN_FRONTEND=noninteractive apt update -y && \
sudo DEBIAN_FRONTEND=noninteractive apt install -y \
  -o Dpkg::Options::="--force-confdef" \
  -o Dpkg::Options::="--force-confold" \
  git apache2 php libapache2-mod-php php-mysql mysql-server

# Install the CloudWatch Agent
wget https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb
sudo dpkg -i -E ./amazon-cloudwatch-agent.deb

# Create a CloudWatch Agent configuration file
cat <<EOF | sudo tee /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json
{
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/apache2/error.log",
            "log_group_name": "EC2-ApacheError",
            "log_stream_name": "{instance_id}"
          },
          {
            "file_path": "/var/log/apache2/access.log",
            "log_group_name": "EC2-ApacheAccess",
            "log_stream_name": "{instance_id}"
          }
        ]
      }
    }
  }
}
EOF

# Configure application
sudo chown $USER:$USER -R /var/www
cd /var/www
git clone https://github.com/dansarpong/todo-php.git todo-app
cd todo-app
echo "DATABASE_USER=${db_user}
DATABASE_PASSWORD=${db_password}
DATABASE_HOST=${db_host}
DATABASE_PORT=${db_port}
DATABASE_NAME=todo
" | sudo tee .env

# Configure apache
echo "<VirtualHost *:80>
    ServerName localhost
    ServerAdmin webmaster@localhost
    DocumentRoot /var/www/todo-app
    <Directory /var/www/todo-app>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>
    LogLevel debug
    ErrorLog /var/log/apache2/error.log
    CustomLog /var/log/apache2/access.log combined
</VirtualHost>
" | sudo tee /etc/apache2/sites-available/todo-app.conf

# Enable the site
sudo a2dissite 000-default.conf
sudo a2ensite todo-app
sudo service apache2 restart

# Start the CloudWatch Agent
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json -s
