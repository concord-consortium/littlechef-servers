#!/usr/bin/env ruby
# create new production has database
require 'fog'
require 'trollop'
require 'json'
rds = ::Fog::AWS[:rds]

proj = 'has'

options = Trollop::options do
	opt :stage, "Stage of instance(production, staging, ...)", :type => :string
end
Trollop::die :stage, "is required (ex: production, production1, staging)" unless options[:stage]

proj_data_bag = JSON.load File.new("data_bags/sites/#{proj}.json")

rds_opts = {
  # this should be taken from the ec2 instance that this will be connected to
  availability_zone: 'us-east-1e',
  backup_retention_period: 7,
  master_username: proj_data_bag['db_username'],
  password: proj_data_bag['db_password'],
  engine: 'mysql',
  engine_version: '5.5',
  parameter_group_name: proj,
  security_group_names: [proj],
  db_name: 'portal',
  id: "#{proj}-#{options[:stage]}",
  flavor_id: 'db.m1.small',
  allocated_storage: 12
}

# make sure seymour can connect to the database
rds_sec_group = rds.security_groups.get(proj)
rds_sec_group.authorize_cidrip("63.138.119.209/32") rescue Fog::AWS::RDS::AuthorizationAlreadyExists

# make sure the parameter group that increases the packet size is setup
rds_param_group = rds.parameter_groups.get(proj)
rds_param_group.modify([{:name => "max_allowed_packet", :value => "16777216", :apply_method => "immediate"}])

puts "*** creating new rds server: #{rds_opts[:id]}"
start = Time.now
rds_server = rds.servers.create(rds_opts)
rds_server.wait_for { ready? }
rds_server.reload
puts "    finished in #{Time.now - start}s"
