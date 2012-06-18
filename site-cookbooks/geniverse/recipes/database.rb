package "unzip"

include_recipe "apache2"
include_recipe "apache2::mod_proxy"
include_recipe "apache2::mod_proxy_http"
include_recipe "git"
include_recipe "passenger_apache2::mod_rails"
include_recipe "apache2::disable_default_site"
include_recipe "users::sysadmins"

web_app "database" do
  cookbook "cc-rails-portal-server"
  template "rails_app.conf.erb"
  docroot "/web/database/static"
  server_name node[:geniverse][:database][:server_name]
  rails_env node[:rails][:environment]
  rails_base_uri "/rails"
  notifies :reload, resources(:service => "apache2"), :delayed
end

directory "/web/database" do
  owner "deploy"
  recursive true
end

directory "/web/database/static" do
  owner "deploy"
  recursive true
end

git "/web/database/Geniverse-Sproutcore" do
  repository "git://github.com/concord-consortium/Geniverse-SproutCore.git"
  reference node[:geniverse][:database][:branch]
  enable_submodules true
  action :sync
  user "deploy"
end

link "/web/database/current" do
  to "/web/database/Geniverse-Sproutcore/rails/geniverse-3.2"
end

link "/web/database/static/rails" do
  to "/web/database/current/public"
end

execute "restart webapp" do
  command "touch /web/database/current/tmp/restart.txt"
  action :nothing
end

# this is slow and happens every time because the deploy happens everytime
script 'Bundling the gems' do
  interpreter 'bash'
  user "deploy"
  cwd "/web/database/current"
  path ['/usr/local/bin','/usr/bin']
  code <<-EOS
    bundle install --quiet --path /web/database/bundled_gems \
      --without development test
  EOS
end

# override the database settings
template "/web/database/current/config/database.yml" do
  cookbook "cc-rails-portal-server"
  source "database.yml.erb"
  owner "deploy"
  variables(
    :db => data_bag_item('databases', node[:geniverse][:database][:db])
  )
  notifies :run, "execute[restart webapp]"
end

execute "initialize-rails-app-database" do
  user "deploy"
  cwd "/web/database/current"
  environment ({'RAILS_ENV' => node[:rails][:environment]})
  command "bundle exec rake db:migrate"
  path ['/usr/local/bin','/usr/bin']
  notifies :run, "execute[restart webapp]"
end
