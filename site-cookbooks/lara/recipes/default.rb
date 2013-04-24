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
include_recipe "apache2::mod_expires"
include_recipe "git"
include_recipe "passenger_apache2::mod_rails"
include_recipe "apache2::disable_default_site"

# this should already be created by the users::sysadmins receipe
# user "deploy" do
#   comment "rails apps user"
# end

approot = "/web/portal"
appshared = "#{approot}/shared"
docroot = "#{approot}/current/public"
portal = node[:lara]
site_id = portal[:site_id]
site_item = data_bag_item('sites', site_id)

directory "#{approot}" do
  recursive true
  owner "deploy"
end

if portal[:base_uri] != "/"
  docroot = "#{approot}/static"

  # trim the final "/foo" from the path, so we get the parent path
  base_parent = portal[:base_uri].sub(/\/$/, '').sub(/\/[^\/]*$/,'')

  directory "#{approot}/static#{base_parent}" do
    recursive true
  end

  link "#{approot}/static#{portal[:base_uri]}" do
    to "#{approot}/current/public"
  end
end

web_app "portal" do
  cookbook "lara"
  template "rails_app.conf.erb"
  server_name portal[:server_name]
  server_aliases portal[:server_aliases]
  docroot docroot
  rails_env node[:rails][:environment]
  rails_base_uri portal[:base_uri]
  proxies node[:http_proxies]
  extra_config node[:http_extra]
  static_assets portal[:static_assets]
  notifies :reload, resources(:service => "apache2"), :delayed
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

template "#{appshared}/config/settings.yml" do
  source "settings.yml.erb"
  owner "deploy"
  variables(
    :site_key => site_item["site_key"],
    :default_password => data_bag_item('credentials','default_password')['default_password']
  )
  notifies :run, "execute[restart webapp]"
end

template "#{appshared}/config/initializers/site_keys.rb" do
  source "site_keys.rb.erb"
  owner "deploy"
  variables(
    :site_key => site_item["site_key"]
  )
  notifies :run, "execute[restart webapp]"
end

# override the database settings
template "#{appshared}/config/database.yml" do
  source "database.yml.erb"
  owner "deploy"

  db = {}

  if portal[:db_host]
    db['host'] = portal[:db_host]
  elsif portal[:db_rds_instance_name]
    rds_data_bag = data_bag_item('rds_domains', portal[:rds_domain])
    db['host'] = "#{portal[:db_rds_instance_name]}.#{rds_data_bag['domain']}"
  else
    raise "no host defined for the database"
  end

  db['database'] = portal[:db_database]
  db['username'] = site_item['db_username']
  db['password'] = site_item['db_password']
  db['pool']     = portal[:db_pool]

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

# Padlet.com used to be wallwisher.
# Their product is an online whiteboard. Interactions thinks
# other projects will like it.
template "#{appshared}/config/padlet.yml" do
  source "padlet.yml.erb"
  owner "deploy"
  variables(
    :credentials => data_bag_item('credentials', 'ccpadlet')
  )
  notifies :run, "execute[restart webapp]"
end


# optional paperclip settings
template "#{appshared}/config/paperclip.yml" do
  source "paperclip.yml.erb"
  owner "deploy"
  notifies :run, "execute[restart webapp]"
  only_if { portal[:s3_bucket] }
end

template "#{appshared}/config/installer.yml" do
  source "installer.yml.erb"
  owner "deploy"
  notifies :run, "execute[restart webapp]"
  variables(
    :installer => portal[:installer]
  )
  only_if { portal[:installer] }
end

# aws settings:
if portal[:s3_bucket]
  template "#{appshared}/config/aws_s3.yml" do
    source "aws_s3.yml.erb"
    owner "deploy"

    s3 = {}
    s3['access_key_id'] = site_item['aws_access_key_id']
    s3['secret_access_key'] = site_item['aws_secret_access_key']
    s3['bucket'] = portal[:s3_bucket]

    variables(
      :s3 => s3
    )
    notifies :run, "execute[restart webapp]"
    only_if { portal[:s3_bucket] }
  end
end

template "#{appshared}/config/google_analytics.yml" do
  source "google_analytics.yml.erb"
  owner "deploy"
  variables(
    :account_id => portal[:google_analytics_account]
  )
  notifies :run, "execute[restart webapp]"
end

if portal[:google_analytics_account] == "UA-6899787-23"
  log("Using default Google Analytics Account! You might consider setting up your own.") { level :warn }
end
