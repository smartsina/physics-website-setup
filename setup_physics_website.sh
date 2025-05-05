#!/bin/bash

# بررسی دسترسی روت
if [ "$EUID" -ne 0 ]; then 
    echo "لطفا اسکریپت را با دسترسی روت اجرا کنید (از sudo استفاده کنید)"
    exit 1
fi

# دریافت اطلاعات دامنه و ایمیل از کاربر
read -p "نام دامنه خود را وارد کنید (مثال: example.com): " domain_name
read -p "آدرس ایمیل خود را وارد کنید: " email_address

# بررسی وضعیت پورت‌های مورد نیاز
echo "در حال بررسی پورت‌های مورد نیاز..."
check_port() {
    if netstat -tuln | grep -q ":$1 "; then
        echo "پورت $1 در حال استفاده است. در حال آزادسازی..."
        # پیدا کردن و متوقف کردن سرویس‌های استفاده کننده از پورت
        if [ "$1" = "80" ]; then
            systemctl stop apache2 2>/dev/null
            systemctl stop nginx 2>/dev/null
        elif [ "$1" = "443" ]; then
            systemctl stop apache2 2>/dev/null
            systemctl stop nginx 2>/dev/null
        fi
        sleep 2
        if netstat -tuln | grep -q ":$1 "; then
            echo "خطا: نتوانستیم پورت $1 را آزاد کنیم. لطفا به صورت دستی پورت را آزاد کنید."
            exit 1
        fi
    fi
}

check_port 80
check_port 443

# به‌روزرسانی سیستم
echo "در حال به‌روزرسانی سیستم..."
apt update && apt upgrade -y

# نصب پکیج‌های مورد نیاز
echo "در حال نصب پکیج‌های مورد نیاز..."
apt install -y nginx certbot python3-certbot-nginx net-tools

# ایجاد دایرکتوری وب‌سایت
echo "در حال ایجاد دایرکتوری وب‌سایت..."
mkdir -p /var/www/$domain_name/html
chown -R www-data:www-data /var/www/$domain_name
chmod -R 755 /var/www/$domain_name

# ایجاد فایل index.html پایه
cat > /var/www/$domain_name/html/index.html << 'EOF'
<!DOCTYPE html>
<html lang="fa" dir="rtl">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>وب‌سایت آزمون فیزیک</title>
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
        <h1>به وب‌سایت آزمون فیزیک خوش آمدید</h1>
        <p>این یک صفحه موقت است. وب‌سایت شما آماده توسعه است!</p>
    </div>
</body>
</html>
EOF

# ایجاد تنظیمات Nginx
echo "در حال ایجاد تنظیمات Nginx..."
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

# فعال‌سازی سایت
echo "در حال فعال‌سازی سایت..."
ln -s /etc/nginx/sites-available/$domain_name /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

# تست تنظیمات Nginx
echo "در حال تست تنظیمات Nginx..."
nginx -t

# راه‌اندازی مجدد Nginx
echo "در حال راه‌اندازی مجدد Nginx..."
systemctl restart nginx

# دریافت گواهی SSL
echo "در حال دریافت گواهی SSL..."
certbot --nginx -d $domain_name -d www.$domain_name --non-interactive --agree-tos --email $email_address

# تنظیم تمدید خودکار گواهی
echo "در حال تنظیم تمدید خودکار گواهی SSL..."
systemctl enable certbot.timer
systemctl start certbot.timer

echo "نصب با موفقیت انجام شد!"
echo "وب‌سایت شما در آدرس زیر قابل دسترسی است: https://$domain_name"
echo "فایل‌های وب‌سایت در مسیر زیر قرار دارند: /var/www/$domain_name/html"
echo "شما می‌توانید با ویرایش فایل‌های موجود در این دایرکتوری، وب‌سایت آزمون فیزیک خود را توسعه دهید." 
