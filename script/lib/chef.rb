require 'json'

def load_chef_role(role_name)
  # we need to turn off create_additions so the JSON parser doesn't look for the Chef::Role class
  JSON.parse File.new("roles/#{role_name}.json").read, create_additions:false
end
