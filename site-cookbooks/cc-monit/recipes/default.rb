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
  monit_monitrc conf do
    variables({ :category => "system" })
  end
end