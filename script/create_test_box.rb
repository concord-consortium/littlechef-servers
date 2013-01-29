#!/usr/bin/env ruby
require "rubygems"
require "bundler/setup"

require 'fog'
require 'trollop'

require 'etc'

options = Trollop::options do
  opt :name, "Name of ec2 instance to make", :type => :string
  opt :notes, "Notes about what this box is for", :type => :string, :default => "this is a test box"
  opt :contact, "Name to put in ec2 contacts tag", :type => :string, :default => Etc.getlogin
end
Trollop::die :name, "is required" unless options[:name]

require_relative 'lib/aws_config'

aws_conf = aws_config(nil)

ec2 = ::Fog::Compute[:aws]

start = Time.now
puts "*** creating new server"
server = ec2.servers.create({
  key_name: aws_conf['ec2_key_name'],
  image_id: aws_conf['ec2_image_id'],
  flavor_id: aws_conf['ec2_flavor_id'],
  availability_zone: aws_conf['availability_zone'],
  groups: 'default',
  tags: {
    "Name"     => options[:name],
    "Contacts" => options[:contact],  # <- should set this based on the current user running this script
    "Notes"    => options[:notes],  # <- these are probably different than the production instance
    "Project"  => ''
  }
})
server.wait_for { ready? }
server.reload
puts "    finished in #{Time.now - start}s"
puts server.inspect