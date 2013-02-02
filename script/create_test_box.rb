#!/usr/bin/env ruby
require "rubygems"
require "bundler/setup"

require 'trollop'

require 'etc'
require_relative 'lib/aws_config'
require_relative 'lib/ec2_helpers'

options = Trollop::options do
  opt :name, "Name of ec2 instance to make", :type => :string
  opt :notes, "Notes about what this box is for", :type => :string, :default => "this is a test box"
  opt :contact, "Name to put in ec2 contacts tag", :type => :string, :default => Etc.getlogin
end
Trollop::die :name, "is required" unless options[:name]

config = aws_config(nil)

server = create_ec2_instance(
  key_name:          config['ec2_key_name'],
  image_id:          config['ec2_image_id'],
  flavor_id:         config['ec2_flavor_id'],
  availability_zone: config['availability_zone'],
  groups:            'default',
  tags: {
    "Name"     => options[:name],
    "Contacts" => options[:contact],
    "Notes"    => options[:notes],
    "Project"  => ''
  }
)

puts server.inspect