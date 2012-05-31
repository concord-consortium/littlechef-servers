# update the list of packages
include_recipe "apt"

# build and install ruby version specified by attributes
include_recipe "chef-ruby"

# patch gem_package so future calls will use our updated ruby
include_recipe "chef-ruby::gem_package"

# install ohai which is used by chef and littlechef and is useful 
# to have in this general ruby install, note we are explicitly
# setting the gem_binary, that technically isn't necessary with the gem_package
# patch applied above.
gem_package "ohai" do 
  action :install
  gem_binary('/usr/local/bin/gem')	
end