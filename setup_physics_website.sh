#!/bin/bash

# Check for root privileges
if [ "$EUID" -ne 0 ]; then 
    echo "Please run this script as root (use sudo)"
    exit 1
fi

# Get domain and email from user
read -p "Enter your domain name (e.g. example.com): " domain_name
read -p "Enter your email address: " email_address

# Check required ports
echo "Checking required ports..."
check_port() {
    if netstat -tuln | grep -q ":$1 "; then
        echo "Port $1 is in use. Attempting to free it..."
        # Find and stop services using the port
        if [ "$1" = "80" ]; then
            systemctl stop apache2 2>/dev/null
            systemctl stop nginx 2>/dev/null
        elif [ "$1" = "443" ]; then
            systemctl stop apache2 2>/dev/null
            systemctl stop nginx 2>/dev/null
        fi
        sleep 2
        if netstat -tuln | grep -q ":$1 "; then
            echo "Error: Could not free port $1. Please free it manually."
            exit 1
        fi
    fi
}

check_port 80
check_port 443

# Update system
echo "Updating system..."
apt update && apt upgrade -y

# Install required packages
echo "Installing required packages..."
apt install -y nginx certbot python3-certbot-nginx net-tools

# Create website directory
echo "Creating website directory..."
mkdir -p /var/www/$domain_name/html
chown -R www-data:www-data /var/www/$domain_name
chmod -R 755 /var/www/$domain_name

# Create base index.html
cat > /var/www/$domain_name/html/index.html << 'EOF'
<!DOCTYPE html>
<html lang="en" dir="ltr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Physics Exam Website</title>
    <style>
        body {
            font-family: 'Tahoma', Arial, sans-serif;
            line-height: 1.6;
            margin: 0;
            padding: 20px;
            background-color: #f4f4f4;
        }
        .container {
            max-width: 800px;
            margin: 0 auto;
            background: white;
            padding: 20px;
            border-radius: 5px;
            box-shadow: 0 0 10px rgba(0,0,0,0.1);
        }
        h1 {
            color: #333;
            text-align: center;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>Welcome to the Physics Exam Website</h1>
        <p>This is a temporary page. Your website is ready for development!</p>
    </div>
</body>
</html>
EOF

# Create Nginx configuration
echo "Creating Nginx configuration..."
cat > /etc/nginx/sites-available/$domain_name << EOF
server {
    listen 80;
    listen [::]:80;
    server_name $domain_name www.$domain_name;
    root /var/www/$domain_name/html;
    index index.html;

    location / {
        try_files \$uri \$uri/ =404;
    }
}
EOF

# Enable site
echo "Enabling site..."
ln -s /etc/nginx/sites-available/$domain_name /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

# Test Nginx configuration
echo "Testing Nginx configuration..."
nginx -t

# Restart Nginx
echo "Restarting Nginx..."
systemctl restart nginx

# Obtain SSL certificate
echo "Obtaining SSL certificate..."
certbot --nginx -d $domain_name -d www.$domain_name --non-interactive --agree-tos --email $email_address

# Enable automatic certificate renewal
echo "Enabling automatic SSL certificate renewal..."
systemctl enable certbot.timer
systemctl start certbot.timer

echo "Installation completed successfully!"
echo "Your website is available at: https://$domain_name"
echo "Website files are located at: /var/www/$domain_name/html"
echo "You can develop your physics exam website by editing the files in this directory." 
