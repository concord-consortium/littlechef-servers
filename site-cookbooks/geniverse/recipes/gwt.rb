# Cookbook Name:: geniverse-gwt
# Recipe:: default

include_recipe "tomcat"

# download the current gwt code
git "/tmp/Geniverse-GWT" do
  repository "git://github.com/psndcsrv/Geniverse-GWT.git"
  reference "master"
  enable_submodules true
  action :sync
end

# remove the current install
execute "remove-current-gwt" do
  user node[:tomcat][:user]
  command "rm -rf #{node[:tomcat][:webapp_dir]}/biologica && mkdir #{node[:tomcat][:webapp_dir]}/biologica"
  notifies :restart, resources(:service => "tomcat"), :delayed
end

#copy the compiled code to the tomcat install
execute "copy-gwt-to-tomcat" do
  user node[:tomcat][:user]
  command "cp -r /tmp/Geniverse-GWT/war/* #{node[:tomcat][:webapp_dir]}/biologica/"
  notifies :restart, resources(:service => "tomcat"), :delayed
end
