package "unzip"
package "libwww-perl"
package "libcrypt-ssleay-perl"

bash "install monitoring scripts" do
  cwd "/home/ubuntu"
  user "ubuntu"
  # this was takine from this page: http://docs.amazonwebservices.com/AmazonCloudWatch/latest/DeveloperGuide/mon-scripts-perl.html
  code <<-SCRIPT
	mkdir aws-scripts-mon
	cd aws-scripts-mon
	wget http://ec2-downloads.s3.amazonaws.com/cloudwatch-samples/CloudWatchMonitoringScripts.zip
	unzip CloudWatchMonitoringScripts.zip
	rm CloudWatchMonitoringScripts.zip	
  SCRIPT
  not_if "test -f /home/ubuntu/aws-scripts-mon/mon-put-instance-data.pl"
end

# setup aws credentials
template "/home/ubuntu/aws-scripts-mon/awscreds.conf" do
  source "awscreds.conf.erb"
  owner "ubuntu"
  item = data_bag_item('credentials', 'cloudwatch')
  variables(
  	:access_key_id => item['access_key_id'],
  	:secret_key => item['secret_key']
  )
end

cron "put-cloudwatch-instance-data" do
  user "ubuntu"
  minute "*/5"
  command "~/aws-scripts-mon/mon-put-instance-data.pl --mem-util --disk-space-util --disk-path=/ --from-cron"
end
