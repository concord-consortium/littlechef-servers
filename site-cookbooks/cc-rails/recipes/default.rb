# make sure our package listing is up-to-date
# this is done when chef-ruby runs
# execute "apt-get update" do
#   action :run
#   user "root"
# end

include_recipe "apache2"
include_recipe "apache2::mod_proxy"
include_recipe "apache2::mod_proxy_http"
include_recipe "apache2::mod_expires"
include_recipe "git"
include_recipe "passenger_apache2::mod_rails"
include_recipe "apache2::disable_default_site"

# this should already be created by the users::sysadmins receipe
# user "deploy" do
#   comment "rails apps user"
# end

approot = node[:cc_rails][:approot]
appshared = node[:cc_rails][:appshared]
docroot = "#{approot}/current/public"
cc_rails = node[:cc_rails]
site_id = cc_rails[:site_id]
site_item = data_bag_item('sites', site_id)

directory "#{approot}" do
  recursive true
  owner "deploy"
end

if cc_rails[:base_uri] != "/"
  docroot = "#{approot}/static"

  # trim the final "/foo" from the path, so we get the parent path
  base_parent = cc_rails[:base_uri].sub(/\/$/, '').sub(/\/[^\/]*$/,'')

  directory "#{approot}/static#{base_parent}" do
    recursive true
  end

  link "#{approot}/static#{cc_rails[:base_uri]}" do
    to "#{approot}/current/public"
  end
end

web_app "portal" do
  cookbook "cc-rails"
  template "rails_app.conf.erb"
  server_name cc_rails[:server_name]
  server_aliases cc_rails[:server_aliases]
  docroot docroot
  rails_env node[:rails][:environment]
  rails_base_uri cc_rails[:base_uri]
  proxies node[:http_proxies]
  extra_config node[:http_extra]
  static_assets cc_rails[:static_assets]
  only_use_ssl cc_rails[:only_use_ssl]
  use_ssl cc_rails[:use_ssl]
  notifies :reload, resources(:service => "apache2"), :delayed
end

if cc_rails[:use_ssl]
  web_app "portal-ssl" do
    cookbook "cc-rails"
    template "rails_app_ssl.conf.erb"
    server_name cc_rails[:server_name]
    server_aliases cc_rails[:server_aliases]
    docroot docroot
    rails_env node[:rails][:environment]
    rails_base_uri cc_rails[:base_uri]
    proxies node[:http_proxies]
    extra_config node[:http_extra]
    static_assets cc_rails[:static_assets]
    only_use_ssl cc_rails[:only_use_ssl]
    use_ssl cc_rails[:use_ssl]
    notifies :reload, resources(:service => "apache2"), :delayed
  end
end

execute "restart webapp" do
  command "touch #{approot}/current/tmp/restart.txt"
  action :nothing
  only_if { ::File.exists?("#{approot}/current/tmp")}
end

directory "#{appshared}" do
  owner "deploy"
end

# directories in the shared folder which are not linked but have links inside of them
%w{
  config
  config/initializers
  public
}.each do |dir|
  directory "#{appshared}/#{dir}" do
    owner "deploy"
    mode 0775
  end
end

# override the database settings
template "#{appshared}/config/database.yml" do
  source "database.yml.erb"
  owner "deploy"

  db = {}

  if cc_rails[:db_host]
    db['host'] = cc_rails[:db_host]
  elsif cc_rails[:db_rds_instance_name]
    rds_data_bag = data_bag_item('rds_domains', cc_rails[:rds_domain])
    db['host'] = "#{cc_rails[:db_rds_instance_name]}.#{rds_data_bag['domain']}"
  else
    raise "no host defined for the database"
  end

  db['database'] = cc_rails[:db_database]
  db['username'] = site_item['db_username']
  db['password'] = site_item['db_password']
  db['pool']     = cc_rails[:db_pool]

  variables(
    :db => db
  )
  notifies :run, "execute[restart webapp]"
end

# override the mailer settings
template "#{appshared}/config/mailer.yml" do
  source "mailer.yml.erb"
  owner "deploy"
  variables(
    :credentials => data_bag_item('credentials', 'smtp')
  )
  notifies :run, "execute[restart webapp]"
end

template "#{appshared}/config/google_analytics.yml" do
  source "google_analytics.yml.erb"
  owner "deploy"
  variables(
    :account_id => cc_rails[:google_analytics_account]
  )
  notifies :run, "execute[restart webapp]"
end

if cc_rails[:google_analytics_account] == "UA-6899787-23"
  log("Using default Google Analytics Account! You might consider setting up your own.") { level :warn }
end

# override the mailer settings
template "/etc/logrotate.d/passenger" do
  source "logrotate_passenger.erb"
end

