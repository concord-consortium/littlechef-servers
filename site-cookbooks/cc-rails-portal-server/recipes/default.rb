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

  # we are going to be doing this bit a lot so it should be pulled out
  site_ids = data_bag('sites')
  if ( node[:cc_rails_portal] && (site_id = node[:cc_rails_portal][:site_id]) &&
    site_ids.include?(site_id) )
    site_item = data_bag_item('sites', site_id) 
  end

  if site_item.nil? && site_ids.include?('default')
    site_item = data_bag_item('sites', 'default')
  end

  if site_item
    site_key = site_item["site_key"]
  else
    site_key = "couldnt find a secret site_key"
  end
    
  variables(
    :site_key => site_key
  )
  notifies :run, "execute[restart webapp]"
end

# override the database settings
template "#{appshared}/config/database.yml" do
  source "database.yml.erb"
  owner "deploy"
  variables(
    :db => data_bag_item('databases', node[:cc_rails_portal][:db])
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

# this is slow and happens every time because the deploy happens everytime
script 'Bundling the gems' do
  interpreter 'bash'
  user "deploy"
  cwd "#{approot}/current"
  path ['/usr/local/bin','/usr/bin']
  code <<-EOS
    bundle install --quiet --deployment --path config/bundle \
      --without development test
  EOS
end

# make a place to store files indicating a step was completed
directory "#{approot}/completed" do
  owner "deploy"
end

# this also should be only be done once to and after that capistrano should
# handle it, however it isn't easy to tell if this has been run before
execute "initialize-cc-rails-app-database" do
  user "deploy"
  cwd "#{approot}/current"
  environment ({'RAILS_ENV' => node[:rails][:environment]})
  command "bundle exec rake db:migrate && touch #{approot}/completed/initial-db-migrate"
  notifies :run, "execute[restart webapp]"
  not_if do
    File.exists?("#{approot}/completed/initial-db-migrate")
  end
end

# run rake setup task
# it isn't clear what the best way to decide to run or not run this task is
execute "portal-setup" do
  user "deploy"
  cwd "#{approot}/current"
  environment ({'RAILS_ENV' => node[:rails][:environment]})
  command "yes | bundle exec rake app:setup:new_app && touch #{approot}/completed/portal-setup"
  notifies :run, "execute[restart webapp]"
  not_if do
    File.exists?("#{approot}/completed/portal-setup")
  end
end

# optional paperclip settings
template "#{appshared}/config/paperclip.yml" do
  source "paperclip.yml.erb"
  owner "deploy"
  notifies :run, "execute[restart webapp]"
  only_if { node[:cc_rails_portal][:s3] }
end

# installer settings TODO: handle non-s3 case?
template "#{appshared}/config/installer.yml" do
  source "installer.yml.erb"
  owner "deploy"
  notifies :run, "execute[restart webapp]"
  only_if { node[:cc_rails_portal][:s3] }
end

# installer settings
template "#{appshared}/config/aws_s3.yml" do
  source "aws_s3.yml.erb"
  owner "deploy"
  variables(
    :s3 => data_bag_item('s3', node[:cc_rails_portal][:s3])
  )
  notifies :run, "execute[restart webapp]"
  only_if { node[:cc_rails_portal][:s3] }
end


