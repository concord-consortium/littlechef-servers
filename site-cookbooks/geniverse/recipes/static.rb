include_recipe "apache2::mod_proxy"
include_recipe "apache2::mod_proxy_http"

include_recipe "apache2::disable_default_site"

include_recipe "users::sysadmins"

proxy_list = [
  {:path => "/biologica/", :remote => "http://#{node[:geniverse][:proxy][:gwt_host]}/biologica/"},
  {:path => "/resources/", :remote => "http://#{node[:geniverse][:proxy][:resources_host]}/resources/"},
  {:path => "/rails/",     :remote => "http://#{node[:geniverse][:proxy][:database_host]}/rails/"},
  {:path => "/portal/",    :remote => "http://#{node[:geniverse][:proxy][:portal_host]}/portal/"}
]

directory node[:geniverse][:static][:docroot] do
  owner "deploy"
  recursive true
  action :create
end

web_app "geniverse-static" do
  server_name node[:geniverse][:static][:server_name]
  cookbook "apache2"
  docroot node[:geniverse][:static][:docroot]
  is_default true
  proxies proxy_list
end
