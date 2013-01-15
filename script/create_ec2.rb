#!/usr/bin/env ruby
require "rubygems"
require "bundler/setup"

require 'fog'
require 'trollop'
require 'json'

require_relative 'lib/mocks'
require_relative 'lib/aws_config'

# Fog.mock!
# mock_aws(ec2_instance_name: "RitesProduction")

options = Trollop::options do
  opt :stage, "Stage of instance(production, staging, ...)", :type => :string
  opt :project, "Name of project, it will be used for the aws-config, security group, and rds id, and databag", :type => :string
end
Trollop::die :stage, "is required (ex: production, production1, staging)" unless options[:stage]
Trollop::die :project, "is required" unless options[:project]

proj = options[:project]
config = aws_config(proj)

ec2 = ::Fog::Compute[:aws]

# create new EC2 instance which copies the important bits from the production server
ec2_opts = {
  :key_name  => config['ec2_key_name'],
  :image_id  => config['ec2_image_id'],
  :flavor_id => config['ec2_flavor_id'],
  :availability_zone => config['availability_zone'],
  :groups    => proj,
  :tags => {
    "Name"     => "#{proj}-#{options[:stage]}",
    "Contacts" => 'Scott',  # <- should set this based on the current user running this script
    "Notes"    => '',  # <- these are probably different than the production instance
    "Project"  => proj
  }
}
start = Time.now
puts "*** creating new server  (usually takes 30 seconds)"
server = ec2.servers.create(ec2_opts)
server.wait_for { ready? }
server.reload
puts "    finished in #{Time.now - start}s"
puts "dns name: #{server.dns_name}"