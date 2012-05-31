define :cap_setup do
  directory params[:name] do
    mode 0755
  end

  # after chef-174 fixed, change mode to 2775
  %w{ releases shared }.each do |dir|
    directory "#{params[:name]}/#{dir}" do
      mode 0775
    end
  end

  %w{ log system pids config public rinet_data }.each do |dir|
    directory "#{params[:name]}/shared/#{dir}" do
      mode 0775
    end
  end

  %w{ nces_data initializers }.each do |dir|
    directory "#{params[:name]}/shared/config/#{dir}" do
      mode 0775
    end
  end

  %w{ otrunk-examples sparks-content installers }.each do |dir|
    directory "#{params[:name]}/shared/public/#{dir}" do
      mode 0775
    end
  end

  %w{ attachments }.each do |dir|
    directory "#{params[:name]}/shared/system/#{dir}" do
      mode 0775
    end
  end

  ## files
  %w{ database.yml settings.yml installer.yml rinet_data.yml mailer.yml initializers/site_keys.rb initializers/subdirectory.rb }.each do |dir|
    file "#{params[:name]}/shared/config/#{dir}" do
      action :touch
    end
  end

end

