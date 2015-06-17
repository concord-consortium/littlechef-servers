#!/usr/bin/env ruby
# updated base_ruby_box with latest ubuntu ami

require "rubygems"
require "bundler/setup"

require 'fog'
require 'trollop'
require 'json'

require_relative 'lib/mocks'

# Fog.mock!
# mock_aws(ec2_instance_name: "RitesProduction")

ec2 = ::Fog::Compute[:aws]

start = Time.now
puts "*** creating new server"
server = ec2.servers.create({
  key_name: 'genigames',
  # the latest version can be looked up here:
  # http://cloud-images.ubuntu.com/locator/ec2/
  # ideally this could be automatically pulled from here:
  # https://help.ubuntu.com/community/UEC/Images#Machine_Consumable_Ubuntu_Cloud_Guest_images_Availability_Data

  # This is 14.10, amd64, hvm:ebs
  image_id: 'ami-59807632',
  # because we are building ruby lets make this big so it is fast
  # it is likely that building is a single threaded thing so what matter is the single core
  # performance
  flavor_id: 'c4.large',

  # Need to put it in a VPC
  subnet_id: 'subnet-7fb16326',

  # this doesn't mater perhaps we can leave it blank, it does need to be
  # in the east though so we get the right ami and the saved image is in the right place
  # :availability_zone => config['availability_zone'],

  # seems to need an explicity security group id because it is in a VPC
  security_group_ids: ['sg-53f1a237'],
  tags: {
    "Name"     => "base-ruby-box",
    "Contacts" => 'Scott',  # <- should set this based on the current user running this script
    "Notes"    => ''  # <- these are probably different than the production instance
  }
})
server.wait_for { ready? }
server.reload
puts "    finished in #{Time.now - start}s"

puts server.inspect

# ssh isn't available right away when the server is started
# fog has a setup command that waits for it up to 6 minutes
sleep 60

# ssh in and update the packages
# possibly use ruby ssh to do this instead
# add the host key to known hosts
system "ssh -o StrictHostKeyChecking=no #{server.dns_name} exit"
system "ssh #{server.dns_name} sudo apt-get update"
system "ssh #{server.dns_name} sudo apt-get -y upgrade"

# install chef on the sever
system "fix node:#{server.dns_name} deploy_chef:ask=no"

# now run the base ruby build on this thing
system "fix node:#{server.dns_name} role:base-ruby-1_9_3"

# puts "stoping server"
# shut it down
server.stop
server.wait_for { state == "stopped" }
puts "server stopped"

# puts "making ami"
# make an image
timestamp = DateTime.now.rfc3339.gsub('-','').gsub(':','')
image_name = "ruby_base_image_#{timestamp}"
image_description = 'built by automated script'
data = ec2.create_image(server.identity, image_name, image_description)
image_id = data.body['imageId']

Fog.wait_for do
  ec2.describe_images('ImageId' => image_id).body['imagesSet'].first['imageState'] == "available"
end
puts "made ami: #{image_id}"

puts "destroying server"
server.destroy

# update the aws-config/default.json file with this updated ami