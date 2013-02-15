#!/usr/bin/env ruby
require "rubygems"
require "bundler/setup"

require 'fog'
require 'trollop'
require 'etc'
require_relative 'lib/mocks'
require_relative 'lib/aws_config'

# Fog.mock!

options = Trollop::options do
  opt :stage, "Stage of instance(production, staging, ...)", :type => :string
  opt :project, "Name of project, it will be used for finding configuration in aws-config/* and data_bags/sites/*", :type => :string
  opt :new_access_key, "Create a new access key for the iam user even if the user has one already"
end
Trollop::die :stage, "is required (ex: production, production1, staging)" unless options[:stage]
Trollop::die :project, "is required" unless options[:project]

project = options[:project]
stage = options[:stage]

proj_data_bag_path = "data_bags/sites/#{project}.json"
proj_data_bag = JSON.load File.new(proj_data_bag_path)
config = aws_config(options[:project])

s3 = ::Fog::Storage[:aws]
iam = ::Fog::AWS[:iam]

# make s3 bucket
bucket_name = "#{project}-#{stage}"
puts "*** creating s3 bucket: #{bucket_name}"
s3.put_bucket(bucket_name, {"x-amz-acl" => "private"})

# track down iam user
iam_user_name = config["iam_user"]
unless iam_user_name
  puts  "*** iam_user not defined in aws-config/#{project}.json"
  puts  "*** the iam_user should be defined there, perhaps the name is #{project}-s3-user, so the defintion should be:"
  puts  "        \"iam_user\": \"#{project}-s3-user\""
  abort "no iam_user defined"
  # It is possible to search for the user given the access key defined in the databag but this is slow
  # and it is also not easy to do from the aws console, so it is better to force the explicit configuration
  # of the user name
end

iam_user = iam.users.get(iam_user_name)
config_access_key_id = proj_data_bag['aws_access_key_id']
if iam_user
  puts "*** using existing iam user: #{iam_user_name}"
else
  puts "*** creating iam user: #{iam_user_name}"
  iam_user = iam.users.create({:id => iam_user_name})
end

if iam_user.access_keys.first && !options[:new_access_key]
  # verify that the key matches what is in the data_bag
  if config_access_key_id.nil?
    puts "*** the iam user '#{iam_user_name}' has at least one access key but #{proj_data_bag_path}"
    puts "    doesn't have any iam_access_keys defined, the script will still configure this user to access the bucket."
    puts "    HOWEVER any server configurations won't have the key so won't be able to access the bucket"
    puts "    if you've lost the key you can run this script again with the option --new-access-key"
  elsif !(iam_user.access_keys.find{|ak| ak.id == config_access_key_id})
    puts "*** the iam user '#{iam_user_name}' doesn't have the access_key defined in #{proj_data_bag_path}"
    puts "    perhaps you have the wrong iam user configured in aws-config/#{project}.json,"
    puts "    the script will still configure this user to access the bucket."
    puts "    HOWEVER any server configurations won't have the correct access key so won't be able to access the bucket"
    puts "    if you want to make a new access key for the iam user '#{iam_user_name}', run this script again with the option --new-access-key"
  end
else
  if config_access_key_id && !options[:new_access_key]
    puts "*** there is an aws_access_key_id defined in #{proj_data_bag_path}, but the iam user '#{iam_user_name}'"
    puts "    doesn't have any access_keys. The script is going to make a new access key for this user."
    puts "    You'll need to replace the aws_access_key definitions with the new ones,"
    puts "    or perhaps you have the wrong user configured in aws-config/#{project}.json"
  end
  puts "*** creating access key for iam user '#{iam_user_name}'"
  iam_access_key = iam_user.access_keys.create
  puts <<-S3DATABAG
    Add these keys to #{proj_data_bag_path}:
      "aws_access_key_id": "#{iam_access_key.id}",
      "aws_secret_access_key": "#{iam_access_key.secret_access_key}"
  S3DATABAG
end

puts "*** giving iam user '#{iam_user_name}' full permissions on bucket 'bucket_name'"
puts "    if this policy is already on the user, it will be udpated"
iam_permissions = {
  :id => "S3-access-#{bucket_name}",
  :document => {
    "Statement" => [
      {
        "Action" => ["s3:*"],
        "Effect" => "Allow",
        "Resource" => ["arn:aws:s3:::#{bucket_name}/*", "arn:aws:s3:::#{bucket_name}"]
      }
    ]
  }
}
iam_user.policies.create(iam_permissions)


