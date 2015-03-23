# make sure our package listing is up-to-date
# this is done when chef-ruby runs
# execute "apt-get update" do
#   action :run
#   user "root"
# end

package "unzip"
include_recipe "cc-rails"

cc_rails = node[:cc_rails]
approot = cc_rails[:approot]
appshared = cc_rails[:appshared]
site_id = cc_rails[:site_id]
site_item = data_bag_item('sites', site_id)
lara = node[:lara]

# override the app_environment_variables.rb settings
template "#{appshared}/config/app_environment_variables.rb" do
  @sso_client_id     = lara[:sso_client_id]
  env                = lara[:stage]
  @vars              = site_item['env_vars'][env]
  @sso_client_secret = data_bag_item('credentials', 'sso')[@sso_client_id]
  @rails_cookie_token = data_bag_item('credentials', 'rails_cookie_token')['lara']
  @new_relic_license_key = data_bag_item('credentials', 'newrelic')['free_key']
  source "app_environment_variables.rb.erb"
  owner "deploy"
  variables(
    :env_vars => @vars,
    :sso_client_id     => @sso_client_id,
    :sso_client_secret => @sso_client_secret,
    :rails_cookie_token => @rails_cookie_token,
    :new_relic_license_key => @new_relic_license_key
  )
  notifies :run, "execute[restart webapp]"
end
