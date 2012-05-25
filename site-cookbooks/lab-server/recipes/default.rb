# perhaps these should just be put in the runlist instead??

# add the node repository here so we can make sure that apt-get update
# runs correctly
apt_repository 'node.js' do
  uri 'http://ppa.launchpad.net/chris-lea/node.js/ubuntu'
  distribution node['lsb']['codename']
  components ['main']
  keyserver "keyserver.ubuntu.com"
  key "C7917B12"
  action :add
end

# ppa for the couchdb repository
apt_repository 'couchdb' do
  # https://launchpad.net/~longsleep/+archive/couchdb
  uri 'http://ppa.launchpad.net/longsleep/couchdb/ubuntu'
  distribution node['lsb']['codename']
  components ['main']
  keyserver "keyserver.ubuntu.com"
  key "56A3D45E "
  action :add
end

# the apt_repository tries to do this itself, but it isn't usign the root user 
# so it seems to fail
execute "apt-get update" do
  action :run
  user "root"
end

include_recipe "nodejs"

# perhaps these should just be put in the runlist instead??

# add the node repository here so we can make sure that apt-get update
# runs correctly
apt_repository 'node.js' do
  uri 'http://ppa.launchpad.net/chris-lea/node.js/ubuntu'
  distribution node['lsb']['codename']
  components ['main']
  keyserver "keyserver.ubuntu.com"
  key "C7917B12"
  action :add
end

# ppa for the couchdb repository
apt_repository 'couchdb' do
  # https://launchpad.net/~longsleep/+archive/couchdb
  uri 'http://ppa.launchpad.net/longsleep/couchdb/ubuntu'
  distribution node['lsb']['codename']
  components ['main']
  keyserver "keyserver.ubuntu.com"
  key "56A3D45E "
  action :add
end

# the apt_repository tries to do this itself, but it isn't usign the root user 
# so it seems to fail
execute "apt-get update" do
  action :run
  user "root"
end

include_recipe "nodejs"
include_recipe "authbind"

# I might need to setup a user and group here
# also this should be pulled out into its own cookbook with a switch 
# for source versus package mode just like node.js
# and of course there might be a chef cookbook that does this already
# also might need to setup the couchdb service
package "couchdb"

# the couchdb service script creates this folder but does so as root
# instead of the couchdb user
directory "/var/run/couchdb" do
  owner "couchdb"
  group "root"
  mode "755"
end

directory "/var/www" do
  owner "deploy"
  group "root"
  mode "755"
end

directory "/var/www/log" do
  owner "www-data"
  group "www-data"
  mode "755"
end

script "update_npm" do
  interpreter "bash"
  user "deploy"
  code "sudo npm update -g npm"
end

script "setup_coffee" do
  interpreter "bash"
  user "deploy"
  code "sudo npm install -g coffee-script"
end

package "rake" do
  action :install
end

git "/var/www/app" do
  user "deploy"
  repository "git://github.com/concord-consortium/lab.git"
end

script "setup-and-build-app" do
  interpreter "bash"
  user "deploy"
  code "cd /var/www/app"
  code "bundle install"
  code "cd /var/www/app/server"
  code "bundle install"
  code "cp config/couchdb.sample.yml config/couchdb.yml"
  code "cd /var/www/app"
  code "make clean; make"
  code "cd /var/www/app"
  code "cd /var/www/app"
  code "cd /var/www/app"
end

git "/var/www/app/public" do
  user "deploy"
  repository "git://github.com/concord-consortium/lab.git"
  reference "gh-pages"
end

template "/var/www/app/config.coffee" do
  source "config.coffee.erb"
  owner "deploy"
  group "root"
  mode "644"
end

service "couchdb" do
  action :start
end

# include_recipe "apache2::passenger"

web_app "lab-apache2-passenger-webapp" do
  server_name "lab.dev.concord.org"
  cookbook "apache2"
  docroot "/var/www/static"
  is_default true
  proxies [
    {:path => "/biologica/", :remote => "http://geniverse.dev.concord.org/biologica/"},
    {:path => "/resources/", :remote => "http://geniverse.dev.concord.org/resources/"}
  ]
end
