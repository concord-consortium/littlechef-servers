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

directory "#{approot}" do
  recursive true
  owner "deploy"
end

if node[:cc_rails_portal][:base_uri] != "/"
  docroot = "#{approot}/static"

  # trim the final "/foo" from the path, so we get the parent path
  base_parent = node[:cc_rails_portal][:base_uri].sub(/\/$/, '').sub(/\/[^\/]*$/,'')

  directory "#{approot}/static#{base_parent}" do
    recursive true
  end

  link "#{approot}/static#{node[:cc_rails_portal][:base_uri]}" do
    to "#{approot}/current/public"
  end
end

web_app "portal" do
  cookbook "cc-rails-portal-server"
  template "rails_app.conf.erb"
  server_name node[:cc_rails_portal][:server_name]
  server_aliases node[:cc_rails_portal][:server_aliases]
  docroot docroot
  rails_env node[:rails][:environment]
  rails_base_uri node[:cc_rails_portal][:base_uri]
  proxies node[:http_proxies]
  extra_config node[:http_extra]
  static_assets node[:cc_rails_portal][:static_assets]
  notifies :reload, resources(:service => "apache2"), :delayed
end

execute "restart webapp" do
  command "touch #{approot}/current/tmp/restart.txt"
  action :nothing
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
  notifies :run, "execute[restart webapp]"
end

template "#{appshared}/config/initializers/site_keys.rb" do
  source "site_keys.rb.erb"
  owner "deploy"

  site_id = node[:cc_rails_portal][:site_id]
  site_item = data_bag_item('sites', site_id)  
    
  variables(
    :site_key => site_item["site_key"]
  )
  notifies :run, "execute[restart webapp]"
end

# override the database settings
template "#{appshared}/config/database.yml" do
  source "database.yml.erb"
  owner "deploy"

  site_id = node[:cc_rails_portal][:site_id]
  site_item = data_bag_item('sites', site_id)  

  db = {}

  if node[:cc_rails_portal][:db_host]
    db['host'] = node[:cc_rails_portal][:db_host]
  elsif node[:cc_rails_portal][:db_rds_instance_name]
    rds_data_bag = data_bag_item('rds_domains', node[:cc_rails_portal][:rds_domain])
    db['host'] = "#{node[:cc_rails_portal][:db_rds_instance_name]}.#{rds_data_bag['domain']}"
  else
    raise "no host defined for the database"
  end

  db['database'] = node[:cc_rails_portal][:db_database]
  db['username'] = site_item['db_username']
  db['password'] = site_item['db_password']

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

#########
## everything below here should only happen once when the server is first provisioned
## after that these things should be done with capistrano
#########

# folders in the shared folder and the links to them in the current release
shared_folders = {
  "config/nces_data" => "config/nces_data",
  "log" => "log",
  "public/otrunk-examples" => "public/otrunk-examples",
  "public/sparks-content" => "public/sparks-content",
  "public/installers" => "public/installers",
  "rinet_data" => "rinet_data",
  "system" => "public/system",
  "pids" => "tmp/pids"
}

# files in the shared folder that are linked in the current release
# TODO: with some chef foo we could have this happen through the template
# definitions above
shared_files = {
  "config/database.yml" => "config/database.yml",
  "config/installer.yml" => "config/installer.yml",
  "config/mailer.yml" => "config/mailer.yml",
  "config/newrelic.yml" => "config/newrelic.yml",
  "config/settings.yml" => "config/settings.yml",
  "config/rinet_data.yml" => "config/rinet_data.yml",
  "config/initializers/site_keys.rb" => "config/initializers/site_keys.rb"
}

deploy "#{approot}" do
  user "deploy"
  repo "git://github.com/concord-consortium/rigse.git"
  branch "master"
  enable_submodules true
  migrate false
  action :deploy
  restart_command "touch tmp/restart.txt"
  before_symlink do
    my_shared_path = new_resource.shared_path

    shared_folders.keys.each do |dir|
      directory "#{my_shared_path}/#{dir}" do
        owner "deploy"
        mode 0775
      end
    end
  end

  symlinks shared_folders.merge(shared_files)

  # only deploy once after that capistrano should be used this might need to be 
  # revisited handle cases where this resource definition changes itself
  not_if do
    File.exists?("#{approot}/current/Gemfile")
  end
end

# optional paperclip settings
template "#{appshared}/config/paperclip.yml" do
  source "paperclip.yml.erb"
  owner "deploy"
  notifies :run, "execute[restart webapp]"
  only_if { node[:cc_rails_portal][:s3] }
end


template "#{appshared}/config/installer.yml" do
  source "installer.yml.erb"
  owner "deploy"
  notifies :run, "execute[restart webapp]"
  variables(
    :installer => node[:cc_rails_portal][:installer]
  )
  only_if { node[:cc_rails_portal][:installer] }
end

# aws settings:
if node[:cc_rails_portal][:s3]
  template "#{appshared}/config/aws_s3.yml" do
    source "aws_s3.yml.erb"
    owner "deploy"

    site_id = node[:cc_rails_portal][:site_id]
    site_item = data_bag_item('sites', site_id)

    s3 = {}
    s3['access_key_id'] = site_item['aws_access_key_id']
    s3['secret_access_key'] = site_item['aws_secret_access_key']
    s3['bucket'] = node[:cc_rails_portal][:s3_bucket]

    variables(
      :s3 => s3
    )
    notifies :run, "execute[restart webapp]"
    only_if { node[:cc_rails_portal][:s3_bucket] }
  end
end

# newrelic rpm settings
template "#{appshared}/config/newrelic.yml" do
  source "newrelic.yml.erb"
  owner "deploy"
  variables(
    :license_key  => data_bag_item('credentials', 'newrelic')["license_key"],
    #:license_key => data_bag_item('credentials', "newrelic"),
    :app_name    => node[:cc_rails_portal][:rpm_name]
  )
  notifies :run, "execute[restart webapp]"
  only_if { node[:cc_rails_portal][:rpm_name] }
end

template "#{appshared}/config/google_analytics.yml" do
  source "google_analytics.yml.erb"
  owner "deploy"
  variables(
    :account_id => node[:cc_rails_portal][:google_analytics_account]
  )
  notifies :run, "execute[restart webapp]"
end

if node[:cc_rails_portal][:google_analytics_account] == "UA-6899787-23"
  log("Using default Google Analytics Account! You might consider setting up your own.") { level :warn }
end
