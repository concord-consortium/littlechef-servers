
# perhaps these should just be put in the runlist instead??

include_recipe "java"

java_ark "maven2" do
    url "http://www.apache.org/dist/maven/binaries/apache-maven-2.2.1-bin.tar.gz"
    checksum  "b9a36559486a862abfc7fb2064fd1429f20333caae95ac51215d06d72c02d376"
    app_home "/usr/local/maven/default"
    bin_cmds ["mvn"]
    action :install
end

package "python-software-properties"

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

directory "/usr/local/rvm" do
  owner "root"
  group "rvm"
  mode "0775"
  action :create
end

group "rvm" do
  append true
  members ["deploy"]
end

# template "/home/deploy/rvm-settings.sh" do
#   source "rvm-settings.sh"
#   owner "deploy"
#   group "root"
#   mode "644"
# end
# 
# script "update_rvm_settings" do
#   user "deploy"
#   interpreter "bash"
#   flags "-l"
#   code "echo 'source rvm-settings.sh' >> /home/deploy/.bash_login"
# end

git "/var/www/app" do
  user "deploy"
  group "root"
  repository "git://github.com/concord-consortium/lab.git"
end

execute "fix-permissions" do
  user "deploy"
  command <<-COMMAND
  sudo chown -R deploy:root /var/www/app/*
  sudo chmod -R og+rw /var/www/app/*
  COMMAND
end

cookbook_file "/home/deploy/setup-lab.sh" do
  source "setup-lab.sh"
  owner "deploy"
  group "root"
  mode "775"
end

execute "setup-and-build-app" do
  user "deploy"
  command <<-COMMAND
  export HOME=/home/deploy
  export TERM=vt100
  export SHELL=/bin/bash
  export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games
  export LANG=en_US.UTF-8
  export LC_TYPE=en_US.UTF-8
  cd $HOME
  source .bash_login
  ./setup-lab.sh
  COMMAND
end

# script "setup-and-build-app" do
#   user "deploy"
#   interpreter "bash"
#   flags "-l"
#   environment ({'HOME' => '/var/www/app'})
#   cwd "/var/www/app"
#   code <<-EOH
#   bundle install
#   cd server
#   bundle install
#   cp config/couchdb.sample.yml config/couchdb.ym
#   cd ..
#   make clean
#   make
#   EOH
# end


include_recipe "apache2"

web_app "lab-apache2-passenger-webapp" do
  cookbook "apache2"
  server_name "lab.dev.concord.org"
  server_aliases ["lab.dev.concord.org"]
  docroot "/var/www/app/public"
end
