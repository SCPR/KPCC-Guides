# If you're *really* in a hurry, here are all the commands without any explanation. Good luck!
# This is *not* a copy-and-paste list. You need to change things like your server's IP, usernames, and paths.

# User Setup
ssh root@x.x.x.x
passwd
# type new root password twice

/usr/sbin/visudo
# Uncomment (near bottom of file):
# %wheel  ALL=(ALL)       ALL

/usr/sbin/adduser edward
passwd edward
# type new password twice
/usr/sbin/usermod -a -G wheel edward

# iptables
/sbin/iptables -F

exit
ssh edward@x.x.x.x


# RVM
curl -L https://get.rvm.io | sudo bash -s stable
sudo yum install -y gcc-c++ git patch readline readline-devel zlib zlib-devel libyaml-devel libffi-devel openssl-devel make bzip2 autoconf automake libtool bison iconv-devel

su root
/usr/sbin/usermod -a -G rvm edward
source /etc/profile.d/rvm.sh
exit
rvm install 1.9.3
rvm use 1.9.3 --default


# RubyGems
gem update --system


# SQLite3
sudo yum install sqlite-devel


# Passenger & nginx
sudo yum install curl-devel
gem install passenger
sudo passenger-install-nginx-module
# Select Option 1, hit [Return] when prompted for prefix path

vi /etc/init.d/nginx
# Copy in script from z_nginx_init.sh
sudo chmod +x /etc/init.d/nginx
/sbin/chkconfig nginx on

su root
/usr/sbin/adduser www-data
exit

vi /opt/nginx/conf/nginx.conf
# Change user to `www-data`, add server directive (as describe in the markdown)
/etc/init.d/nginx restart
 

# Node
cd /tmp/
wget http://nodejs.tchol.org/repocfg/el/nodejs-stable-release.noarch.rpm
yum localinstall --nogpgcheck nodejs-stable-release.noarch.rpm
yum install nodejs-compat-symlinks npm


# Rails
gem install rails
mkdir -p /web/rails
cd /web/rails/
rails new demo_app
chown -R www-data /web

cd demo_app
rails g scaffold post title:string body:text
rake db:create
rake db:migrate

vi config/routes.rb
# add `root to: "posts#index"`
touch tmp/restart.txt

# Done!