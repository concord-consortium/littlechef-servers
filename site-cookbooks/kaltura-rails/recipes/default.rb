# create kaltura.yml file in shared folder
template "/web/portal/shared/config/kaltura.yml" do
  source "kaltura.yml.erb"
  owner "deploy"
  group "deploy"
  mode "0600"

  # need to load in the kaltura credentials from the databags
    variables(
    :credentials => data_bag_item('credentials', 'kaltura')
  )
end

