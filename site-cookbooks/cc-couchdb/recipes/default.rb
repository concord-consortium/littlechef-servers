include_recipe "couchdb"
include_recipe "s3cmd"

if node[:cc_couchdb][:id].empty?
  # raise "Can't assign a random id if an id was already assigned!" if File.exist?("/etc/sudoers_edited")
  node.set[:cc_couchdb][:id] = "couchdb-%012d" % rand(999999999999)
end

# set up the dbs and views
puts "Copying design docs is currently not supported and will have to be done manually."

# set up a cron tab to backup the database nightly to S3
cron "backup_couchdb" do
  hour "23"
  command "s3cmd put --recursive --preserve --force /var/lib/couchdb/ s3://couchdb-backups/#{node[:cc_couchdb][:id]}/"
  not_if "test -f /etc/sudoers_edited"
end

# set up a restore script
template "/usr/bin/restore_couchdb.sh" do
  source "restore_couchdb.sh.erb"
  owner "root"
  group "root"
  mode "0700"
  variables(
    :couchdb_id => node[:cc_couchdb][:id]
  )
end

# make sure the deploy user can run the restore script through sudo
bash "setup_sudo_for_restore" do
  user "root"
  cwd "/tmp"
  code <<-SCRIPT
  echo "deploy  ALL = (root)  NOPASSWD: /usr/bin/restore_couchdb.sh" >> /etc/sudoers
  touch /etc/sudoers_edited
  SCRIPT
  not_if "test -f /etc/sudoers_edited"
end

if node[:cc_couchdb][:restore]
  execute "restore_couchdb.sh" do
    user "root"
  end
  node.set[:cc_couchdb][:restore] = false
end
