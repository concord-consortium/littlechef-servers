#!/usr/bin/env ruby
require "rubygems"
require "bundler/setup"

require 'trollop'
require 'etc'
require_relative 'lib/mocks'
require_relative 'lib/aws_config'
require_relative 'lib/ec2_helpers'

# Fog.mock!

options = Trollop::options do
  opt :stage, "Stage of instance(production, staging, ...)", :type => :string
  opt :project, "Name of project, it will be used for the aws-config and security group", :type => :string
  opt :notes, "Notes about what this box is for", :type => :string
  opt :contact, "Name to put in ec2 contacts tag", :type => :string, :default => Etc.getlogin
end
Trollop::die :stage, "is required (ex: production, production1, staging)" unless options[:stage]
Trollop::die :project, "is required" unless options[:project]

config = aws_config(options[:project])

find_or_create_ec2_security_group(
  name:        options[:project],
  description: "#{options[:project]} security group"
)

create_ec2_instance(
  key_name:          config['ec2_key_name'],
  image_id:          config['ec2_image_id'],
  flavor_id:         config['ec2_flavor_id'],
  availability_zone: config['availability_zone'],
  groups:            options[:project],
  tags: {
    "Name"     => "#{options[:project]}-#{options[:stage]}",
    "Contacts" => options[:contact],
    "Notes"    => options[:notes] || '',
    "Project"  => options[:project] || ''
  }
)
