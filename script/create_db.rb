#!/usr/bin/env ruby
require "rubygems"
require "bundler/setup"

require 'fog'
require 'trollop'
require 'json'
require_relative 'lib/chef'
require_relative 'lib/aws_config'

rds = ::Fog::AWS[:rds]

options = Trollop::options do
	opt :stage, "Stage of instance(production, staging, ...)", :type => :string
  opt :project, "Name of project, it will be used for the aws-config, security group, and rds id, and databag", :type => :string
end
Trollop::die :stage, "is required (ex: production, production1, staging)" unless options[:stage]
Trollop::die :project, "is required" unless options[:project]

proj = options[:project]
proj_data_bag = JSON.load File.new("data_bags/sites/#{proj}.json")
stage_role = load_chef_role "#{proj}-#{options[:stage]}"
config = aws_config(proj)

rds_opts = {
  id: stage_role['override_attributes']['cc_rails_portal']['db_rds_instance_name'],
  master_username: proj_data_bag['db_username'],
  password: proj_data_bag['db_password'],
  engine: 'mysql',
  engine_version: config['db_engine_version'],
  availability_zone: config['availability_zone'],
  flavor_id: config['db_flavor_id'],
  allocated_storage: config['db_allocated_storage'],
  backup_retention_period: 7,
  parameter_group_name: proj,
  security_group_names: [proj],
  db_name: 'portal'
}

# make sure seymour can connect to the database
rds_sec_group = rds.security_groups.get(proj)
rds_sec_group.authorize_cidrip("63.138.119.209/32") rescue Fog::AWS::RDS::AuthorizationAlreadyExists

# make sure the parameter group that increases the packet size is setup
rds_param_group = rds.parameter_groups.get(proj)
rds_param_group.modify([{:name => "max_allowed_packet", :value => "16777216", :apply_method => "immediate"}])

puts "*** creating new rds server: #{rds_opts[:id]} (usually takes 10 minutes)"
start = Time.now
rds_server = rds.servers.create(rds_opts)
rds_server.wait_for { ready? }
rds_server.reload
puts "    finished in #{Time.now - start}s"
