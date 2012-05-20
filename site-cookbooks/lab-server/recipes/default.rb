package "rake" do
  action :install
end

git "/var/www/app" do
  user "deploy"
  repository "git://github.com/concord-consortium/lab.server.git"
end

git "/var/www/app/public" do
  user "deploy"
  repository "git://github.com/concord-consortium/lab.git"
  reference "gh-pages"
end

template "/var/www/app/config.coffee" do
  source "config.coffee.erb"
  owner "deploy"
  group "root"
  mode "644"
end

service "couchdb" do
  action :start
end

service "node-couch-webapp" do
  case node[:platform]
  when "ubuntu"
    if node[:platform_version].to_f >= 9.10
      provider Chef::Provider::Service::Upstart
    end
  end
  action :restart
end

# The following is no longer used, but is left for reference b/c that's how the Apache *files*
# got onto genigames.dev.concord.org

# set up resources server w/ proxy server to all of the rest
# include_recipe "apache2::mod_proxy"
# include_recipe "apache2::mod_proxy_http"

# include_recipe "apache2::disable_default_site"

# web_app "genigames-apache" do
#   server_name "genigames.dev.concord.org"
#   cookbook "apache2"
#   docroot "/var/www/static"
#   is_default true
#   proxies [
#     {:path => "/biologica/", :remote => "http://geniverse.dev.concord.org/biologica/"},
#     {:path => "/resources/", :remote => "http://geniverse.dev.concord.org/resources/"}
#   ]
# end
