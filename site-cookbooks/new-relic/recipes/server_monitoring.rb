# newrelic repository
bash "add newrelic apt repository" do
  user "root"
  code <<-SCRIPT
    wget -O /etc/apt/sources.list.d/newrelic.list http://download.newrelic.com/debian/newrelic.list
    apt-key adv --keyserver hkp://subkeys.pgp.net --recv-keys 548C16BF
    apt-get update
  SCRIPT
  not_if "test -f /etc/apt/sources.list.d/newrelic.list"
end

package "newrelic-sysmond"

service "newrelic-sysmond" do
  supports [ :restart, :status ]
  action :enable
end

bash "config newrelic sysmon" do
  rpm_key = node[:new_relic][:rpm_account_type]
  user "root"
  code <<-SCRIPT
    nrsysmond-config --set license_key=#{data_bag_item('credentials', 'newrelic')[rpm_key]}
  SCRIPT
  notifies :restart, resources(:service => "newrelic-sysmond")
end

