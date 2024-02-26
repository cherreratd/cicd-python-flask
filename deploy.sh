#!/bin/bash

echo "deleting old app"
sudo rm -rf /var/www/

echo "creating app folder"
sudo mkdir -p /var/www/app

echo "moving files to app folder"
sudo mv  * /var/www/app

# Navigate to the app directory
cd /var/www/app/
sudo mv env .env

sudo apt-get update
echo "installing python and pip"
sudo apt-get install -y python3 python3-pip

# Install application dependencies from requirements.txt
echo "Install application dependencies from requirements.txt"
sudo pip install -r requirements.txt

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
    server_name _;

    location / {
        include proxy_params;
        proxy_pass http://unix:/var/www/app/myapp.sock;
    }
}
EOF'

    sudo ln -s /etc/nginx/sites-available/myapp /etc/nginx/sites-enabled
    sudo systemctl restart nginx
else
    echo "Nginx reverse proxy configuration already exists."
fi


# Stop any existing Gunicorn process
sudo systemctl stop gunicorn
sudo systemctl disable gunicorn

sudo rm -rf myapp.sock
sudo mv app.service /etc/systemd/system/gunicorn.service
sudo mkdir /var/log/gunicorn
sudo touch /var/log/gunicorn/access.log
sudo touch /var/log/gunicorn/error.log

# Create a new Gunicorn systemd service file
echo "Creating a new Gunicorn systemd service file"
sudo bash -c 'cat > /etc/systemd/system/gunicorn.service <<EOF
[Unit]
Description=gunicorn daemon
After=network.target

[Service]
User=www-data
Group=www-data
WorkingDirectory=/var/www/app
ExecStart=gunicorn --workers 3 --bind unix:/var/www/app/myapp.sock --capture-output --log-level debug --access-logfile /var/log/gunicorn/access.log --error-logfile /var/log/gunicorn/error.log main:app

[Install]
WantedBy=multi-user.target
EOF'

# # Start Gunicorn with the Flask application
echo "Reloading Gunicorn service"
sudo systemctl daemon-reload
sudo systemctl restart gunicorn
echo "Gunicorn service reloaded 🚀"
