include_recipe "monit"

template node["monit"]["main_config_path"] do
  owner  "root"
  group  "root"
  mode   "0700"
  source "monitrc.erb"
  variables(
    :mail  => data_bag_item('credentials', 'smtp'),
    :monit => data_bag_item('credentials', 'monit')
  )
end

# aws additional monit files:
node[:cc_monit][:jobs].each do |conf|
  approot    = "/web/portal"  # TODO: nodification in cc_rails_portal
  rails_user = "deploy"       # TODO: nodification in cc_rails_portal

  monit_monitrc conf do
    variables({
      :category    => "system",
      :approot     => approot,
      :rails_user  => rails_user
      })
  end
end