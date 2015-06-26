#!/usr/bin/env ruby
require "rubygems"
require "bundler/setup"

require 'fog'
require 'trollop'
require 'json'
require_relative 'lib/chef'
require_relative 'lib/aws_config'
require_relative 'lib/ec2_helpers'

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

# get the ec2 security group
ec2_security_group = find_or_create_web_app_security_group(
  name:        options[:project],
  vpc_id:      config['vpc_id'],
  description: "#{options[:project]} security group"
)

# make sure the security_group exists
puts "*** ensuring rds security group exists..."
# names are not case sensitive, and they can have null names
rds_sec_group_name = "#{options[:project].downcase}.db"

# because we are in a vpc now we need to make a vpc security group in ec2
# instead of using RDS security groups
# more info: http://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/Overview.RDSSecurityGroups.html

rds_sec_group = find_or_create_security_group(
  name:        rds_sec_group_name,
  vpc_id:      config['vpc_id'],
  description: "#{options[:project]} database security group"
)
rds_sec_group.authorize_port_range(3306..3306, :group => ec2_security_group.group_id) rescue Fog::AWS::RDS::AuthorizationAlreadyExists
rds_sec_group.authorize_port_range(3306..3306, :cidr_ip => "63.138.119.208/32") rescue Fog::AWS::RDS::AuthorizationAlreadyExists
rds_sec_group.authorize_port_range(3306..3306, :cidr_ip => "63.138.119.209/32") rescue Fog::AWS::RDS::AuthorizationAlreadyExists

# create an RDS parameter group which increases the max packet size
# this is probably only needed for our portal servers
puts "*** ensuring max_allowed_packet is increased..."
rds_param_group = rds.parameter_groups.get(proj)
unless rds_param_group
  rds_param_group_opts = {
    :id => proj,
    :family => "mysql#{config['db_engine_version']}",
    :description => "increased max_packet_size"
  }
  rds_param_group = rds.parameter_groups.create(rds_param_group_opts)
end
rds_param_group.modify([{:name => "max_allowed_packet", :value => "16777216", :apply_method => "immediate"}])

rds_opts = {
  id: stage_role['override_attributes']['cc_rails']['db_rds_instance_name'],
  master_username: proj_data_bag['db_username'],
  password: proj_data_bag['db_password'],
  engine: 'mysql',
  engine_version: config['db_engine_version'],
  availability_zone: config['availability_zone'],
  flavor_id: config['db_flavor_id'],
  allocated_storage: config['db_allocated_storage'],
  backup_retention_period: 7,
  parameter_group_name: proj,
  db_subnet_group_name: "rds.vpc.subnet.group1",
  vpc_security_groups: [rds_sec_group.group_id],
  db_name: 'portal'
}

puts "*** creating new rds server: #{rds_opts[:id]} (usually takes 10 minutes)"
start = Time.now
rds_server = rds.servers.create(rds_opts)
# the default wait time of 10 minutes wasn't long enough
rds_server.wait_for 15*60, { ready? }
rds_server.reload
puts "    finished in #{Time.now - start}s"
