include_recipe "monit"


# remove the default load monitor...
redundant_load_rc_file = "#{node["monit"]["includes_dir"]}/load.monitrc"
file redundant_load_rc_file do
  owner "root"
  group "root"
  mode 00755
  action :delete
  only_if do
    File.exists?(redundant_load_rc_file)
  end
end

template node["monit"]["main_config_path"] do
  owner  "root"
  group  "root"
  mode   "0644"
  source "monitrc.erb"
  server_name = node.name

  # TODO: this might not work in all cases.
  if node[:cc_rails_portal]
    server_name = node[:cc_rails_portal][:site_name]
  end

  variables(
    :mail      => data_bag_item('credentials', 'smtp'),
    :monit     => data_bag_item('credentials', 'monit'),
    :server_name => server_name   )
end

# TODO: This is wrong. We should just use
# the monit_monitrc provider (cookbooks/monit/providers/monitrc)
# see for example: cc-solr default recipe.
# additional monit files:
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
      :rails_user  => "deploy",
      :server_name => node["cc_monit"]["server_name"]
    })
    action :create
    # notifies :restart, "service[monit]"
  end
end

template "/web/portal/delayed_job.sh" do
  owner  "deploy"
  group  "root"
  mode   "0750"
  source "delayed_job.sh.erb"
  variables({
    :approot     => "/web/portal",
    :rails_user  => "deploy"
  })
  action :create
  only_if do
    File.exists?("/etc/passwd")
  end
end

service "monit" do
  action :restart
end
