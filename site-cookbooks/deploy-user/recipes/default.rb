# Create user object.
user 'deploy' do
  shell "/bin/bash"
  home "/home/deploy"
  supports :manage_home => true
end

directory "/home/deploy/.ssh" do
  owner "deploy"
  group "deploy"
  mode "0700"
end

# this uses a attribute structure like this:
# {
#   "deploy-user-keys": {
#     "group_definitions": {
#        "internal_developers": ["scytacki", "aunger"]
#     },
#     "users": [ "internal_developers", "imoncada", "piotr"]
#   }
# }
# in this case the final deploy user will have public keys from:
#   scytacki, aunger, imoncada, and piotr

template "/home/deploy/.ssh/authorized_keys" do
  source "authorized_keys.erb"
  owner "deploy"
  group "deploy"
  mode "0600"
  # build up an ssh_keys array from a list of users
  # hardcode this for now:
  ssh_keys = []
  keys_config = node[:deploy_user_keys]
  group_defs = keys_config[:group_definitions]
  keys_config[:users].each{|item|
    if(group_defs[item.to_sym])
      group_defs[item.to_sym].each{|guser|
        ssh_keys << data_bag_item('ssh_keys', guser)['public_keys']
      }
    else
      ssh_keys << data_bag_item('ssh_keys', item)['public_keys']
    end
  }

  variables :ssh_keys => ssh_keys
end

