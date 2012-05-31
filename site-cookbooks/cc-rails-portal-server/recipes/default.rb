# make sure our package listing is up-to-date
# this is done when chef-ruby runs
# execute "apt-get update" do
#   action :run
#   user "root"
# end

package "unzip"

include_recipe "apache2"
include_recipe "apache2::mod_proxy"
include_recipe "apache2::mod_proxy_http"
include_recipe "git"
include_recipe "passenger_apache2::mod_rails"
include_recipe "apache2::disable_default_site"

# this should already be created by the users::sysadmins receipe
# user "deploy" do
#   comment "rails apps user"
# end

web_app "portal" do
  cookbook "cc-rails-portal-server"
  template "rails_app.conf.erb"
  docroot "/web/portal/current/public"
  rails_env node[:rails][:environment]
  rails_base_uri "/"
  notifies :reload, resources(:service => "apache2"), :delayed
end

directory "/web/portal" do
  recursive true
end

# it isn't clear if this is really needed given the deploy step below
cap_setup "/web/portal"

deploy "/web/portal" do
  repo "git://github.com/concord-consortium/rigse.git"
  branch "rails3.2"
  enable_submodules true
  migrate false
  action :deploy
  restart_command "touch tmp/restart.txt"
  symlink_before_migrate({
    "config/database.yml" => "config/database.yml",
    "config/settings.yml" => "config/settings.yml",
    "config/installer.yml" => "config/installer.yml",
    "config/mailer.yml" => "config/mailer.yml",
    "config/rinet_data.yml" => "config/rinet_data.yml",
    "config/newrelic.yml" => "config/newrelic.yml",
    "config/initializers/site_keys.rb" => "config/initializers/site_keys.rb",
    "config/initializers/subdirectory.rb" => "config/initializers/subdirectory.rb",
    "public/otrunk-examples" => "public/otrunk-examples",
    "public/sparks-content" => "public/sparks-content",
    "public/installers" => "public/installers",
    "config/nces_data" => "config/nces_data",
    "rinet_data" => "rinet_data",
    "system" => "public/system"
  })
  not_if do
    File.exists?(File.join("/web/portal", "skip-provisioning"))
  end
end

# a user can be set on the deploy resource above, so then this might not be necessary
execute "chown -R deploy /web/portal"

# this is really slow and happens every time because the deploy happens everytime
script 'Bundling the gems' do
  interpreter 'bash'
  user "deploy"
  cwd "/web/portal/current"
  path ['/usr/local/bin','/usr/bin']
  code <<-EOS
    bundle install --quiet --deployment --path config/bundle \
      --without development test
  EOS
end

execute "setup-portal-settings" do
  user "deploy"
  cwd "/web/portal/current"
  # note the username and password here don't mater because we are pre-creating the database.yml file
  command "bundle exec ruby config/setup.rb -n 'Cross Project Portal' -D xproject " +
          "-u 'awsuser' -p 'password' -t xproject -y -q -f --states=none"
  not_if do
    File.exists?(File.join("/web/portal", "skip-provisioning"))
  end
end

# override the database settings
template "/web/portal/shared/config/database.yml" do
  source "database.yml.erb"
  owner "deploy"
end

execute "initialize-cc-rails-app-database" do
  user "deploy"
  cwd "/web/portal/current"
  environment ({'RAILS_ENV' => node[:rails][:environment]})
  command "bundle exec rake db:migrate:reset"
  not_if do
    File.exists?(File.join("/web/portal", "skip-provisioning"))
  end
end

# run rake setup task
execute "portal-setup" do
  user "deploy"
  cwd "/web/portal/current"
  environment ({'RAILS_ENV' => node[:rails][:environment]})
  command "yes | bundle exec rake app:setup:new_app"
  not_if do
    File.exists?(File.join("/web/portal/current", "skip-provisioning"))
  end
end
