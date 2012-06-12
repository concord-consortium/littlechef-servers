
# perhaps these should just be put in the runlist instead??

package "python-software-properties"
package "tree"

include_recipe "java"

# maven needs this to work if JAVA_HOME isn't defined
link "/usr/lib/jvm/default-java" do
  to "/usr/lib/jvm/java-6-openjdk-amd64/jre"
end

# we need this concord maven provider to resolve
# some legacy artifacts used by otrunk

directory "/home/deploy/.m2" do
  owner "deploy"
  group "root"
  mode "0755"
  action :create
end

cookbook_file "/home/deploy/.m2/settings.xml" do
  source "settings.xml"
  owner "deploy"
  group "root"
  mode "664"
end

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

# the apt_repository tries to do this itself, but it isn't using
# the root user so it seems to fail
execute "apt-get update" do
  action :run
  user "root"
end

package "nodejs"
package "npm"

# include_recipe "nodejs"
# include_recipe "authbind"

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

service "couchdb" do
  action :start
end

group "rvm" do
  append true
  members ["deploy", "ubuntu"]
end

cookbook_file "/home/deploy/.rvmrc" do
  source "rvmrc"
  owner "deploy"
  group "deploy"
  mode "664"
end

cookbook_file "/home/deploy/.bash_login" do
  source "dot_bash_login"
  owner "deploy"
  group "deploy"
  mode "664"
end

execute "enable the locate database" do
  command "sudo updatedb"
end

git "/var/www/app" do
  user "deploy"
  group "root"
  repository "git://github.com/concord-consortium/lab.git"
end

execute "fix-permissions" do
  user "deploy"
  command <<-COMMAND
  sudo chown -R deploy:root /var/www/app/*
  sudo chmod -R ug+rw /var/www/app/*
  sudo chgrp -R deploy /usr/local/rvm/*
  sudo chmod -R g+w /usr/local/rvm/*
  COMMAND
end

include_recipe "apache2"

# execute "disable-default-apache2-site" do
#   command "sudo a2dissite default"
#   notifies :reload, resources(:service => "apache2"), :delayed
# end

web_app "lab" do
  cookbook "apache2"
  server_name node['lab-hostname']
  server_aliases [node['lab-hostname']]
  docroot "/var/www/app/server/public"
  enable true
  notifies :reload, resources(:service => "apache2"), :delayed
end
