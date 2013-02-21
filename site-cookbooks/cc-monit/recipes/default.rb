include_recipe "monit"

template node["monit"]["main_config_path"] do
  owner  "root"
  group  "root"
  mode   "0644"
  source "monitrc.erb"
  variables(
    :mail  => data_bag_item('credentials', 'smtp'),
    :monit => data_bag_item('credentials', 'monit')
  )
end


# aws additional monit files:
node["cc_monit"]["jobs"].each do |conf|
  base = node["monit"]["includes_dir"]
  Chef::Log.info("MONIT: configuring job '#{conf}'")
  template "#{base}/#{conf}.monitrc" do
    owner  "root"
    group  "root"
    mode   "0500"
    source "#{conf}.monitrc.erb"
    variables({
      :category    => "system",
      :approot     => "/web/portal",
      :rails_user  => "deploy"
    })
    notifies :restart, "service[monit]", :immediately
    action :create
  end
end