#!/usr/bin/env ruby
require "rubygems"
require "bundler/setup"

require_relative 'lib/chef'
require_relative 'lib/portal_helpers'

# Fog.mock!

proj = 'has'
source_role = load_chef_role "#{proj}-production"
new_role = load_chef_role "#{proj}-staging"

clone_portal_servers({
  source_rds_instance: source_role['override_attributes']['cc_rails_portal']['db_rds_instance_name'],
  source_ec2_name:     "#{proj}-production",
  new_rds_instance:    new_role['override_attributes']['cc_rails_portal']['db_rds_instance_name'],
  new_ec2_name:        "#{proj}-staging",
  new_hostname:        "#{proj}.staging.concord.org."
  })
