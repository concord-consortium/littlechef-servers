#!/usr/bin/env ruby
require "rubygems"
require "bundler/setup"

require 'trollop'

require_relative 'lib/chef'
require_relative 'lib/portal_helpers'
require_relative 'lib/aws_config'

# Fog.mock!

options = Trollop::options do
  opt :project, "Name of project, it will be used for the aws-config, security group, and rds id, and databag", :type => :string
end
Trollop::die :project, "is required" unless options[:project]

proj = options[:project]
production_role = load_chef_role "#{proj}-production"
staging_role = load_chef_role "#{proj}-staging"
config = aws_config(proj)

hostname = config['hostname'] || proj

# you need to make sure the staging rds instance is unique and doesn't conflict with an existing one
staging_rds_name = staging_role['override_attributes']['cc_rails_portal']['db_rds_instance_name']
production_rds_name = production_role['override_attributes']['cc_rails_portal']['db_rds_instance_name']

server = clone_portal_servers({
  source_rds_instance: production_rds_name,
  source_ec2_name:     "#{proj}-production",
  new_rds_instance:    staging_rds_name,
  new_ec2_name:        "#{proj}-staging",
  new_hostname:        "#{hostname}.staging.concord.org.",
  new_server_role:     "#{proj}-staging"
  })

puts "the last step is go into a portal checkout and run:"
puts "  cap #{proj}-staging deploy deploy:migrate"