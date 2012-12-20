#!/usr/bin/env ruby
require "rubygems"
require "bundler/setup"
require 'fog'
require 'trollop'
require 'yaml'
require 'uri/open-scp'

require_relative 'lib/chef'
require_relative 'lib/portal_helpers'
require_relative 'lib/aws_config'

# Fog.mock!

options = Trollop::options do
  opt :project, "Name of project, it will be used for the aws-config, security group, and rds id, and databag", :type => :string
  opt :no_destroy, "Find the resources but don't destroy"
end
Trollop::die :project, "is required" unless options[:project]

proj = options[:project]
staging_role = load_chef_role "#{proj}-staging"
config = aws_config(proj)
hostname = config['hostname'] || proj

# this code uses the actual resources in aws as much as possible
# this way it handles the case where the config files are out of date

r53 = ::Fog::DNS[:aws]
zone = r53.zones.find{|zone| zone.domain == "concord.org."}
record = zone.records.all!.find{|record| record.name == "#{hostname}.staging.concord.org."}

if record.type != 'A' || record.value.length != 1
  puts("The staging DNS entry isn't what we expect:")
  puts("  #{record.inspect}")
  exit
end

puts "DNS record: #{record.name}:#{record.value.first} ttl:#{record.ttl}"

ec2 = ::Fog::Compute[:aws]
server = ec2.servers.find{|server| server.public_ip_address == record.value.first}

if server.nil?
	abort("Could not find a server in ec2 which matches this ip address")
end

puts "Server: name:#{server.tags['Name']} created_at:#{server.created_at} state:#{server.state} id:#{server.id}"

# load in the database.yml from the server:
db_settings = open("scp://deploy@#{hostname}.staging.concord.org:/web/portal/shared/config/database.yml")
db_settings = YAML.load db_settings
db_settings = db_settings['production']

puts "DB info: #{db_settings.inspect}"

rds_id = db_settings['host'].split('.').first
rds = ::Fog::AWS[:rds]
rds_server = rds.servers.get(rds_id)

puts "DB Server: name:#{rds_server.id} created_at:#{rds_server.created_at} state:#{rds_server.state}"

if options[:no_destroy]
  puts "Stopping here and not destroying anything"
  exit
end

puts "destroying the ec2, dns, and rds entries"
server.destroy
record.destroy
rds_server.destroy
puts "  done"
