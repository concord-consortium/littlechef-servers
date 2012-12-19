#!/usr/bin/env ruby
require "rubygems"
require "bundler/setup"

require 'fog'

ec2 = ::Fog::Compute[:aws]

start = Time.now
puts "*** creating new server"
server = ec2.servers.create({
  key_name: 'genigames',
  image_id: 'ami-685bfa01',
  flavor_id: "c1.medium",
  availability_zone: "us-east-1e",
  groups: 'default',
  tags: {
    "Name"     => 'DeployUserTest',
    "Contacts" => 'Scott',  # <- should set this based on the current user running this script
    "Notes"    => '',  # <- these are probably different than the production instance
    "Project"  => ''
  }
})
server.wait_for { ready? }
server.reload
puts "    finished in #{Time.now - start}s"
puts server.inspect