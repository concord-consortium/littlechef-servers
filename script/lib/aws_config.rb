require 'json'

def aws_config(project)
  default_config = JSON.load File.new("aws-config/defaults.json")
  if File.exists? "aws-config/#{project}.json"
    proj_config = JSON.load File.new("aws-config/#{project}.json")
    default_config.merge(proj_config)
  else
    default_config
  end
end