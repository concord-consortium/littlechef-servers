include_recipe "python"

# get source
git "/tmp/s3cmd" do
  repository "https://github.com/s3tools/s3cmd.git"
  reference "master"
  action :sync
  not_if "file -f /usr/bin/s3cmd"
end

# compile and install
bash "make_s3cmd" do
  user "root"
  code <<-SCRIPT
  cd /tmp/s3cmd
  cp s3cmd /usr/bin/
  cp -r S3 /usr/bin/
  chmod a+x /usr/bin/s3cmd
  SCRIPT
  not_if "file -f /usr/bin/s3cmd"
end

# configure
# TODO Perhaps we shouldn't rely on the cc_rails_portal config...
template "/root/.s3cfg" do
  owner "root"
  source "s3cfg.erb"
  variables(
    variables(
      :s3 => data_bag_item('s3', node[:cc_rails_portal][:s3])
    )
  )
end

