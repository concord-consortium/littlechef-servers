
execute "apt-get-update" do
  command "apt-get update"
  action :nothing
end


template "/etc/apt/sources.list" do
  owner  "root"
  group  "root"
  mode   "0700"
  source "sources.list.erb"
  action :create
  notifies :run, resources(:execute => "apt-get-update")
end
