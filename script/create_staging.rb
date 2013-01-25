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
  opt :skip_rds, "If true, skip creation of RDS database"
  opt :skip_ec2, "If true, skip creation of EC2 instance"
  opt :build_dev, "If set, will build a 'dev' instance instead of 'staging'"
end
Trollop::die :project, "is required" unless options[:project]

proj = options[:project]
target_stage = options[:build_dev] ? 'dev' : 'staging'
production_role = load_chef_role "#{proj}-production"
staging_role = load_chef_role "#{proj}-#{target_stage}"
config = aws_config(proj)

hostname = config['hostname'] || proj

# you need to make sure the staging rds instance is unique and doesn't conflict with an existing one
staging_rds_name = staging_role['override_attributes']['cc_rails_portal']['db_rds_instance_name']
production_rds_name = production_role['override_attributes']['cc_rails_portal']['db_rds_instance_name']

server = clone_portal_servers({
  source_rds_instance: production_rds_name,
  source_ec2_name:     "#{proj}-production",
  skip_rds:            options[:skip_rds],
  new_rds_instance:    staging_rds_name,
  skip_ec2:            options[:skip_ec2],
  new_ec2_name:        "#{proj}-#{target_stage}",
  new_hostname:        "#{hostname}.#{target_stage}.concord.org.",
  new_server_role:     "#{proj}-#{target_stage}"
  })

puts "the last step is go into a portal checkout and run:"
puts "  cap #{proj}-#{target_stage} deploy deploy:migrate"