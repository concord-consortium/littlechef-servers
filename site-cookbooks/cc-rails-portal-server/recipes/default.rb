# make sure our package listing is up-to-date
# this is done when chef-ruby runs
# execute "apt-get update" do
#   action :run
#   user "root"
# end

package "unzip"
package "libfreetype6-dev"
include_recipe "imagemagick"
include_recipe "cc-rails"

# this should already be created by the users::sysadmins receipe
# user "deploy" do
#   comment "rails apps user"
# end

cc_rails = node[:cc_rails]
approot = cc_rails[:approot]
appshared = cc_rails[:appshared]
site_id = cc_rails[:site_id]
site_item = data_bag_item('sites', site_id)
portal = node[:cc_rails_portal]

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

# override the app_environment_variables.rb settings
template "#{appshared}/config/app_environment_variables.rb" do
  @portal_features  = portal[:portal_features]
  @cors_origins     = portal[:cors_origins]
  @cors_resources   = portal[:cors_resources]

  env                = portal[:stage]
  @vars              = (env ? site_item['env_vars'][env] : {}) || {}

  source "app_environment_variables.rb.erb"
  owner "deploy"
  variables(
    :env_vars          => @vars,
    :portal_features   => @portal_features,
    :cors_origins      => @cors_origins,
    :cors_resources    => @cors_resources
  )
  notifies :run, "execute[restart webapp]"
end

# Solr assumes that cc-rails-portal has been setup first....
include_recipe "cc-solr"
