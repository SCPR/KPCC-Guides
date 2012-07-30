## Setup RVM/Ruby, Nginx/Passenger, and Rails in minutes on vanilla CentOS (5 or 6)
###### July 1, 2012

Based on articles at <http://articles.slicehost.com/centos>

This gist only covers the steps that are necessary to get a Rails app running quickly via 
RVM, nginx and Passenger. It disregards security in many cases (such as RVM & iptables)! 
Go through the articles above for more on that.

Please note that I wrote this after I had already got it all working, so I apologize if 
there is anything missing. If you get a permission error from the OS, I may have left 
off a `sudo`, so try running the command with that. Please comment if you have any issues, 
if I left something out, or if you can recommend any improvements.

These commands were used on a fresh rebuild of `CentOS release 6.2 (Final)` on a Rackspace 
server.

**If you don't need the explanations, 
[see below](https://gist.github.com/3069680#file_z_rundown) for a tl;dr.**

## Basic server setup

SSH in as root and immediately change the password:

    ssh root@x.x.x.x
    passwd

### Permissions

Allow users of `wheel` group to issue all commands:

    /usr/sbin/visudo

Uncomment (near bottom of file):

    %wheel  ALL=(ALL)       ALL

Make sure *not* to uncomment the one with `NOPASSWD`

Add a user & add to `wheel` group:

    /usr/sbin/adduser edward
    passwd edward
    /usr/sbin/usermod -a -G wheel edward

### SSH Keys

Recommended, but not *necessary* to get the Rails app running. This provides added security 
and also keeps you (or any user with properly installed keys) from having to type in a 
password on every login. Read 
[this article](http://articles.slicehost.com/2010/5/15/centos-5-5-setup-part-1) for how to 
set up SSH keys.

### IP Tables

Flush IP tables so nginx can connect to port 80 (default for HTTP connections):

    /sbin/iptables -F

For a production server, iptables should be configured securely. See 
[this article](http://articles.slicehost.com/2010/5/15/centos-5-5-setup-part-1) 
for how to do that.

Logout & login as the newly created user:

    exit
    ssh edward@x.x.x.x


## Yum

[Yum](http://yum.baseurl.org/) is a package management system that uses 
[RPM](http://www.rpm.org/). Yum is to RPM what Bundler is to RubyGems, and in fact its 
commands are very similar to Bundler's. For example, you can run this to update any 
installed packages to the latest possible versions:

    sudo yum update

To make sure you already have Yum, simply run:

    yum -h

If your build of CentOS didn't already have Yum installed (most will already have it), 
then you can use `rpm` to install it. Start with [this article](http://wiki.openvz.org/Install_yum).
 

## EPEL/remi

Not necessary, but it's a good idea to have these installed, which provide a larger 
amount of packages, as well as more current versions of each. Read 
[this article](http://www.rackspace.com/knowledge_center/content/installing-rhel-epel-repo-centos-5x-or-6x) 
for how to set it up (it's easy and quick).


## Ruby Version Manager (RVM)

[RVM](https://rvm.io/) is the "Ruby Version Manager", and makes it easy to upgrade 
and downgrade Ruby, as well as maintain gemsets for different users or applications. 

There are two options: Install RVM user-by-user, or install it globally. I will show how 
to install it globally here (for faster setup), but 
[RVM recommends the first option](https://rvm.io/rvm/install/) because installing globally 
can be a security risk.

Install RVM globally:

    curl -L https://get.rvm.io | sudo bash -s stable

Install dependencies (as listed by RVM after you run the command above):

    sudo yum install -y gcc-c++ git patch readline readline-devel zlib zlib-devel libyaml-devel libffi-devel openssl-devel make bzip2 autoconf automake libtool bison iconv-devel

Add users to the `rvm` group created by rvm, and load the RVM script:

    su root
    /usr/sbin/usermod -a -G rvm edward
    source /etc/profile.d/rvm.sh
    exit

Install Ruby & set as default:

    rvm install 1.9.3
    rvm use 1.9.3 --default


## RubyGems

RVM Installs [RubyGems](http://rubygems.org/) (i.e. the `gem` cli) for you.
Run this command to make sure it's at the latest version:

    gem update --system


## SQLite3

[SQLite3](http://www.sqlite.org/) is the database that Rails applications use by default. 
To install the package and its dependencies, run:

    sudo yum install sqlite-devel

Optionally, you can install the sqlite3 gem at the system level, but your application's 
Gemfile will tell Bundler to install it by default. It might be a good idea to run 
`gem install sqlite3` now, though, just to make sure the SQLite3 library is properly 
installed on the system.


## MySQL

If you need or want to use [MySQL](http://www.mysql.com/) instead of SQLite, start with 
[this article](http://articles.slicehost.com/2011/3/10/installing-mysql-server-on-centos) 
for how to install and configure.

 
## Passenger & Nginx

[Passenger](http://www.modrails.com/) runs Rack applications (like Rails), and 
[nginx](http://nginx.org/) proxies HTTP requests. We're going to use them over the alternatives 
because together they are easy and quick to setup, powerful, and production-ready.

First, install `curl-devel`, as the installer requires it:

    sudo yum install curl-devel

Passenger will install nginx, so no need to do it via yum.

Install the gem and run the installer:

    gem install passenger
    sudo passenger-install-nginx-module


Follow the instructions. Notes:

* Use Option 1 (allowing the installer to download & compile Nginx itself) for quicker setup
* When prompted for Nginx prefix directory, you can just hit `[Return]`, and it will be 
installed to `/opt/nginx`.
* If there are any missing dependencies at this point, the installer will very clearly 
explain what to do. It's fail-safe and idiot-proof! Perfect for me and you.

Rerun `sudo passenger-install-nginx-module` if necessary after installing dependencies

### Add nginx convenience scripts

This step isn't totally necessary but I'm putting it in here because it's quick and easy and 
will help you in working working with nginx.

Installing nginx via Yum (which we didn't do) does this automatically, so we have it do 
it ourselves:

    vi /etc/init.d/nginx

Copy and paste the script in [the file below](https://gist.github.com/3069680#file_zz_nginx_init.sh). 
Be sure to modify the paths to nginx if you didn't use the `/opt/nginx` default!

Make it executable:

    sudo chmod +x /etc/init.d/nginx

Add nginx to server startup commands:

    /sbin/chkconfig nginx on

### Configure nginx

First, add a user, `www-data`, which will be used by nginx & Passenger 
(based on the nginx config file, below):

    su root
    /usr/sbin/adduser www-data
    exit

Edit the nginx config file:

    vi /opt/nginx/conf/nginx.conf

The passenger installer will create this file with a bunch of useful stuff in it 
(as long as you didn't already have an `nginx.conf` in the same place). We just 
need to change and add a few things to get it setup for Rails on our server.

First, change `# user nobody;` to:

    user www-data;

Then, inside of the `http` directive (which Passenger adds by default), 
define your server:

    http { # You only need one of these in the nginx config file
        server {
            listen 80;
            server_name yourdomain.com; # Or the server's IP if you don't have a domain yet
            root /web/rails/demo_app/public; # `demo_app` is the root of your rails app
            passenger_enabled on;
            rails_env development;
        }
    }

A couple things to note:

* Although we haven't created a Rails app yet, put where you think it will be in the 
`root` directive. Of course, you can always come back and change that path after you've 
setup the Rails application. After you change the path, reload the config with 
`/etc/init.d/nginx reload`.

* I have the `rails_env` option set to `development` just so we can get the Rails app 
running as quickly as possible. In the production environment (with the default Rails 
production config), we would have to worry about precompiling assets, the classes and 
views would all be cached (which would require us to restart Passenger every time we 
made a change), and the error messages would be "User-Friendly" (i.e. "Useless"). 
You'll need to deal with all of these things at some point, and change the `rails_env` 
option in your nginx config to `production`, but for now let's just get something working!

Restart nginx:

    /etc/init.d/nginx restart
 

## Apache

[Apache](http://httpd.apache.org/) is an HTTP proxy (an alternative to nginx), and can 
be installed with Passenger similarly to how it is done with nginx. Start with 
[this article](http://articles.slicehost.com/2009/4/7/centos-mod_rails-installation) 
if you decide to use Apache instead of nginx.


## Thin and Unicorn

[Thin](http://code.macournoyer.com/thin/) and [Unicorn](http://unicorn.bogomips.org/) 
are HTTP servers for Rack applications (alternatives to Passenger). Each one has 
advantages and disadvantages, which you can research yourself. If you decide to use 
something besides the nginx + Passenger method described in this gist, browse through 
[this list of articles](http://articles.slicehost.com/centos) to find a combination of 
Thin, Passenger, Apache, and Nginx that suits your needs.

For Unicorn + nginx, read [this article](http://sirupsen.com/setting-up-unicorn-with-nginx/).

You might also consider [Mongrel2](http://mongrel2.org/), new but promising.

## Node

Install Node for JS runtime. This is an alternative to adding `execjs` and `therubyracer` 
to your app's Gemfile. I prefer this method because all of your applications will need it, 
and [Node.js](http://nodejs.org/) is very cool and useful for many purposes. 
Plus, this will also install `npm` which is very useful:

    cd /tmp/
    wget http://nodejs.tchol.org/repocfg/el/nodejs-stable-release.noarch.rpm
    yum localinstall --nogpgcheck nodejs-stable-release.noarch.rpm
    yum install nodejs-compat-symlinks npm


## Rails

    gem install rails
    mkdir -p /web/rails
    cd /web/rails/
    rails new demo_app

Give user `www-data` owner permissions for anything already under `/web`:

    chown -R www-data /web

### Scaffold a quick resource to test everything out

I don't recommend using Rails' `scaffold` generator (you don't learn anything except how 
to run the `scaffold` command), but for our purposes, to get a quick demo app up and running 
(what `scaffold` is really meant for), let's do it!

    cd demo_app
    rails g scaffold post title:string body:text

Create and migrate the database:

    rake db:create
    rake db:migrate

Edit your `routes.rb` file:

    vi config/routes.rb

And add (right below `resource :posts`, which `scaffold` added automagically):

```ruby
root to: "posts#index"
```

Restart Passenger (Might not be necessary but it doesn't hurt):

    touch tmp/restart.txt

Now visit your website! If you don't have a domain or you haven't setup the DNS for it, 
you can just visit the IP address of your server (from your browser).

###### Tags: rails, nginx, passenger, thin, unicorn, node, yum, centos, linux, unix, ruby, rvm
