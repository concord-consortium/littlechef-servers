#!/usr/bin/env ruby
require 'fog'
require_relative 'lib/mocks'

# Fog.mock!
# mock_aws(ec2_instance_name: "RitesProduction")


ec2 = ::Fog::Compute[:aws]

# find the server this counts on the Name being setup correctly
# it would be better to use the hostname from the role to find this
source_ec2_server = ec2.servers.find{|s| s.tags["Name"] == "RitesProduction"}

# create new EC2 instance which copies the important bits from the production server
ec2_opts = {
  :key_name  => source_ec2_server.key_name,
  :image_id  => source_ec2_server.image_id,
  :flavor_id => "m1.large",
  :availability_zone => source_ec2_server.availability_zone,
  :groups    => source_ec2_server.groups,
  :tags => {
    "Name"     => 'RitesProductionLarge',
    "Contacts" => 'Scott',  # <- should set this based on the current user running this script
    "Notes"    => '',  # <- these are probably different than the production instance
    "Project"  => source_ec2_server.tags["Project"]
  }
}
start = Time.now
puts "*** creating new server"
server = ec2.servers.create(ec2_opts)
server.wait_for { ready? }
server.reload
puts "    finished in #{Time.now - start}s"
server
