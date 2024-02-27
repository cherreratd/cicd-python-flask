#!/bin/bash

echo "deleting old app"
sudo rm -rf /home/ubuntu/www/

echo "creating app folder"
sudo mkdir -p /home/ubuntu/www/app
sudo chown -R ubuntu:www-data /home/ubuntu/www
sudo chmod -R 750 /home/ubuntu/www

echo "moving files to app folder"
# sudo mv  * /home/ubuntu/www/app

# Navigate to the app directory
cd /home/ubuntu/www/app
sudo mv env .env

if [ -d .git ]; then
    git pull
else
   git clone git@github.com:cherreratd/cicd-python-flask.git .
fi

sudo apt-get update
echo "installing python and pip"
sudo apt-get install -y python3 python3-pip

# Install application dependencies from requirements.txt
echo "Install application dependencies from requirements.txt"
sudo pip install -r requirements.txt

# Stop any existing Gunicorn process
sudo systemctl stop gunicorn
sudo systemctl disable gunicorn

sudo rm -rf myapp.sock

# Create a new Gunicorn systemd service file
echo "Creating a new Gunicorn systemd service file"
sudo bash -c 'cat > /etc/systemd/system/gunicorn.service <<EOF
[Unit]
Description=gunicorn daemon
After=network.target

[Service]
User=ubuntu
Group=www-data
WorkingDirectory=/home/ubuntu/www/app
ExecStart=gunicorn --workers 2 --bind unix:myapp.sock --capture-output --log-level debug --access-logfile /home/ubuntu/guniacces.log --error-logfile /home/ubuntu/guni.log -m 007 main:app

[Install]
WantedBy=multi-user.target
EOF'

# # Start Gunicorn with the Flask application
echo "Reloading Gunicorn service"
sudo systemctl daemon-reload
sudo systemctl restart gunicorn
echo "Gunicorn service reloaded 🚀"


# Update and install Nginx if not already installed
if ! command -v nginx > /dev/null; then
    echo "Installing Nginx"
    sudo apt-get update
    sudo apt-get install -y nginx
fi

# Configure Nginx to act as a reverse proxy if not already configured
if [ ! -f /etc/nginx/sites-available/myapp ]; then
    sudo rm -f /etc/nginx/sites-enabled/default
    sudo bash -c 'cat > /etc/nginx/sites-available/myapp <<EOF
server {
    listen 80;
    server_name 127.0.0.1 localhost;

    location / {
        include proxy_params;
        proxy_pass http://unix:/home/ubuntu/www/app/myapp.sock;
    }
}
EOF'

    sudo ln -s /etc/nginx/sites-available/myapp /etc/nginx/sites-enabled
    sudo systemctl restart nginx
else
    echo "Nginx reverse proxy configuration already exists."
fi

