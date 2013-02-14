# newrelic rpm settings
template "/web/portal/shared/config/newrelic.yml" do
  source "newrelic.yml.erb"
  owner "deploy"
  rpm_key = node[:new_relic][:rpm_account_type]
  variables(
    :license_key  => data_bag_item('credentials', 'newrelic')[rpm_key],
    :app_name    => node[:new_relic][:app_name]
  )
  notifies :run, "execute[restart webapp]"
  only_if { node[:new_relic][:app_name] }
end

