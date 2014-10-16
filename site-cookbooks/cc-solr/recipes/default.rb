
template "/etc/init.d/solr" do 
  source "solr.sh.erb"
  variables :solr_dir => node[:solr][:root_dir],
            :solr_pid_file => node[:solr][:pid_file]
  mode "755"  
end

service "solr" do
  supports :restart => true
  action [ :enable, :start ]
end