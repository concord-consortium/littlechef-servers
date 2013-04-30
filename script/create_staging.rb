#!/usr/bin/env ruby
require "rubygems"
require "bundler/setup"

require 'trollop'

require_relative 'lib/chef'
require_relative 'lib/portal_helpers'
require_relative 'lib/aws_config'

# Fog.mock!

options = Trollop::options do
  opt :project, "Name of project, it will be used for the aws-config, security group, and rds id, and databag", :type => :string
  opt :skip_rds, "If true, skip creation of RDS database"
  opt :skip_ec2, "If true, skip creation of EC2 instance"
  opt :build_dev, "If set, will build a 'dev' instance instead of 'staging'"
end
Trollop::die :project, "is required" unless options[:project]

proj = options[:project]
target_stage = options[:build_dev] ? 'dev' : 'staging'
production_role = load_chef_role "#{proj}-production"
staging_role = load_chef_role "#{proj}-#{target_stage}"
config = aws_config(proj)

hostname = config['hostname'] || proj

# you need to make sure the staging rds instance is unique and doesn't conflict with an existing one
staging_rds_name = staging_role['override_attributes']['cc_rails']['db_rds_instance_name']
production_rds_name = production_role['override_attributes']['cc_rails']['db_rds_instance_name']

server = clone_portal_servers({
  source_rds_instance: production_rds_name,
  source_ec2_name:     "#{proj}-production",
  skip_rds:            options[:skip_rds],
  new_rds_instance:    staging_rds_name,
  skip_ec2:            options[:skip_ec2],
  new_ec2_name:        "#{proj}-#{target_stage}",
  new_hostname:        "#{hostname}.#{target_stage}.concord.org.",
  new_server_role:     "#{proj}-#{target_stage}"
  })

if production_portal_role = production_role['override_attributes']['cc_rails_portal'] &&
   production_s3_bucket = production_portal_role['s3_bucket']
  target_s3_bucket = staging_role['override_attributes']['cc_rails_portal']['s3_bucket']
  unless target_s3_bucket
    puts "There is a production s3 bucket defined in roles/#{proj}-production.json, but there is NOT "
    puts " a s3 bucket defined in roles/#{proj}-#{target_stage}.json"
    puts "If you need to make a bucket run:"
    puts "   script/create_bucket.rb -p #{proj} -s #{target_stage}"
    target_s3_bucket = "#{proj}-#{target_stage}"
  end
  puts "If you want copy the s3 resources from the production bucket, this will do the trick:"
  puts "   s3cmd cp --acl-public --recursive s3://#{production_s3_bucket} s3://#{target_s3_bucket}"
end

puts "the last step is to deploy the code from your application with capistrano. For example:"
puts "  cap #{proj}-#{target_stage} deploy deploy:migrate"