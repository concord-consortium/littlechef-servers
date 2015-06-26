require 'json'

def aws_config(project)
  default_config = aws_config_defaults
  if File.exists? "aws-config/#{project}.json"
    proj_config = JSON.load File.new("aws-config/#{project}.json")
    default_config.merge(proj_config)
  else
    default_config
  end
end

def aws_config_defaults
  JSON.load File.new("aws-config/defaults.json")
end