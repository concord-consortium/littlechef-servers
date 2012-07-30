#!/usr/bin/env ruby

def depend(name)
  begin
    require name
  rescue LoadError
    puts "#{name} not installed! Run 'gem install #{name}' and try again."
    exit
  end
end

depend 'trollop'
depend 'fog'
# depend 'resolv'

@options = Trollop::options do
  version "setup_ec2_portal_instance.rb 1.0"
  banner <<-BANNER
A simple script for setting up and configuring the various AWS moving parts which
a new portal instance require.

Usage:
  setup_ec2_portal_instance.rb [options] <session_file>
where [options] are:
BANNER
  # shared options
  opt :verbose,  "Enable or disable detailed output",     :default => true
  opt :name,     "Instance name",                         :type => :string
  opt :security_group, "Security group",                  :type => :string
  opt :az,       "Server availability zone",              :default => "us-east-1e"

  # EC2 Options
  opt :ami,      "AMI id to use as a base",               :default => 'ami-685bfa01'
  opt :flavor,   "EC2 instance type",                     :default => 'c1.medium'
  opt :pem,      "PEM file for connecting",               :default => "~/.ssh/identities/genigames.pem"
  opt :contacts, "Contacts for EC2 instance",             :type => :string
  opt :notes,    "Notes for EC2 instance",                :default => ""
  opt :project,  "Project string for EC2 instance",       :default => ""
  opt :server_id, "Server id to use instead of creating one", :default => ""

  # RDS options
  opt :db_storage, "Amount of disk storage for RDS (in GB)",     :default => 12
  opt :db_master_username, "Master username for DB instance",    :default => "master"
  opt :db_master_password, "Master password for DB instance",    :default => SecureRandom.hex(12)
  opt :db_engine, "Engine for the RDS instance",                 :default => "mysql"
  opt :db_engine_version, "Engine version for the RDS instance", :default => "5.5"
  opt :db_flavor, "Flavor for the RDS instance", :default => "db.t1.micro"
  opt :db_name, "Database name",                                 :default => "portal"

  # Route53 options
  opt :dns_zone, "Zone domain name in which records will be created", :default => "concord.org."
  opt :hostname, "Host name for the new server",                      :type => :string
  opt :dns_ttl,  "Time-to-live value for dns record",                 :default => 10400

  # S3 bucket options
  opt :s3_bucket, "Name of the S3 bucket",                    :type => :string, :default => nil
  opt :s3_iam_user, "Name of the IAM user for the S3 bucket", :type => :string, :default => nil
  opt :couchdb_backups, "Enable permissions for backing up CouchDB", :type => :boolean, :default => false
end
Trollop::die :name, "must provide an instance name" unless @options[:name]
Trollop::die :security_group, "must provide an instance security group" unless @options[:security_group]
Trollop::die :contacts, "must provide instance contacts" unless @options[:contacts]
Trollop::die :hostname, "must provide a host name for a dns entry" unless @options[:hostname]

def cleanup(name, type = :db)
  specials = case type
            when :db
              ['_']
            when :rds_id, :s3_user
              ['\-']
            when :bucket
              ['\-','\.']
            else
              []
            end
  allowed = 'a-zA-Z0-9' + specials.join('')
  name = name.gsub(/[^#{allowed}]+/, '')
  specials.each do |special|
    name = name.gsub(/[#{special}]+/, special)
  end
  name.gsub(/^[^a-zA-Z]+/, '')
end

@options[:s3_bucket] ||= cleanup(@options[:name], :bucket)
@options[:s3_iam_user] ||= cleanup(@options[:name], :s3_user) + "-s3-user"


begin
  @aws_ec2 = ::Fog::Compute[:aws]
  @aws_rds = ::Fog::AWS[:rds]
  @aws_r53 = ::Fog::DNS[:aws]
  @aws_s3  = ::Fog::Storage[:aws]
  @aws_iam = ::Fog::AWS[:iam]
rescue ArgumentError => e
  if e.message[/aws_access_key_id/]
    puts <<-MSG

*** #{e.message}
*** Create the file ~/.fog with your Amazon Web Services API Access Keys

file: ~/.fog
:default:
  :aws_access_key_id: YOUR_AWS_ACCESS_KEY
  :aws_secret_access_key: YOUR_AWS_SECRET_ACCESS_KEY

MSG
  else
    puts "An error occurred: #{e.message}"
  end
  exit 1
end

# find/create security group for EC2 instance
puts "*** ensuring ec2 security group is set up: #{@options[:security_group]}" if @options[:verbose]
ec2_sec_group = @aws_ec2.security_groups.get(@options[:security_group])
unless ec2_sec_group
  ec2_sec_group_opts = {
    :name => @options[:security_group],
    :description => "#{@options[:security_group]} security group"
  }
  ec2_sec_group = @aws_ec2.security_groups.create(ec2_sec_group_opts)
  ec2_sec_group.authorize_port_range(22..22)
  ec2_sec_group.authorize_port_range(80..80)
  ec2_sec_group.authorize_port_range(443..443)
end

# find/create security group for RDS instance
# make sure EC2 security group is in RDS security group
puts "*** ensuring rds security group is set up: #{@options[:security_group]}" if @options[:verbose]
rds_sec_group = @aws_rds.security_groups.get(@options[:security_group])
unless rds_sec_group
  rds_sec_group_opts = {
    :id => @options[:security_group],
    :description => "#{@options[:security_group]} security group"
  }
  rds_sec_group = @aws_rds.security_groups.create(rds_sec_group_opts)
  rds_sec_group.wait_for { ready? }
  rds_sec_group.reload
end
rds_sec_group.authorize_ec2_security_group(@options[:security_group]) rescue Fog::AWS::RDS::AuthorizationAlreadyExists

# create an RDS parameter group which increases the max packet size
puts "*** ensuring max_allowed_packet is increased..." if @options[:verbose]
rds_param_group = @aws_rds.parameter_groups.get(@options[:security_group])
unless rds_param_group
  rds_param_group_opts = {
    :id => @options[:security_group],
    :family => "#{@options[:db_engine]}#{@options[:db_engine_version]}",
    :description => "increased max_packet_size"
  }
  rds_param_group = @aws_rds.parameter_groups.create(rds_param_group_opts)
end
rds_param_group.modify([{:name => "max_allowed_packet", :value => "16777216", :apply_method => "immediate"}])

# create RDS instance
rds_id = cleanup(@options[:name], :rds_id)
puts "*** creating new rds server: #{rds_id}" if @options[:verbose]
rds_opts = {
  :availability_zone => @options[:az],
  :backup_retention_period => 7,
  :master_username => @options[:db_master_username],
  :password => @options[:db_master_password],
  :engine => @options[:db_engine],
  :engine_version => @options[:db_engine_version],
  :parameter_group_name => @options[:security_group],
  :security_group_names => [@options[:security_group]],
  :db_name => cleanup(@options[:db_name], :db),
  :id => rds_id,
  :flavor_id => @options[:db_flavor],
  :allocated_storage => @options[:db_storage]
}
rds_server = @aws_rds.servers.create(rds_opts)

# make s3 bucket
puts "*** creating new s3 bucket for paperclip: #{@options[:s3_bucket]}" if @options[:verbose]
bucket = @aws_s3.get_bucket(@options[:s3_bucket]) rescue @aws_s3.put_bucket(@options[:s3_bucket], {"x-amz-acl" => "private"})
# make new IAM user for s3 bucket
iam_opts = {
  :id => @options[:s3_iam_user]
}
iam_user = @aws_iam.users.get(@options[:s3_iam_user]) || @aws_iam.users.create(iam_opts)
iam_access_key = iam_user.access_keys.first || iam_user.access_keys.create

# add railsportal group to IAM user
@aws_iam.add_user_to_group('railsportal', @options[:s3_iam_user]) rescue nil
(@aws_iam.add_user_to_group('couchdbbackups', @options[:s3_iam_user]) rescue nil) if @options[:couchdb_backups]

# give IAM user permissions for new s3 bucket
iam_permissions = {
  :id => "S3-access-#{@options[:s3_bucket]}",
  :document => {
    "Statement" => [
      {
        "Action" => ["s3:*"],
        "Effect" => "Allow",
        "Resource" => ["arn:aws:s3:::#{@options[:s3_bucket]}/*"]
      }
    ]
  }
}
iam_user.policies.create(iam_permissions)

# create new EC2 instance in same AZ as RDS instance
ec2_opts = {
  :key_name  => @options[:pem][/\/([^\/]*).pem/,1],
  :image_id  => @options[:ami],
  :flavor_id => @options[:flavor],
  :availability_zone => @options[:az],
  :groups    => [@options[:security_group]],
  :tags => {
    "Name"     => @options[:name],
    "Contacts" => @options[:contacts],
    "Notes"    => @options[:notes],
    "Project"  => @options[:project]
  }
}
puts "*** creating new server: #{@options[:name]}" if @options[:verbose]
server = @options[:server_id].empty? ? @aws_ec2.servers.create(ec2_opts) : @aws_ec2.servers.get(@options[:server_id])
puts "*** waiting for server: #{server.id} to be ready ..." if @options[:verbose]
server.wait_for { ready? }
server.reload

# create elastic IP for new EC2 instance
available_addresses = @aws_ec2.addresses.all({"instance-id" => ""})
if available_addresses.empty?
  ipaddress = @aws_ec2.allocate_address.body["publicIp"]
else
  ipaddress = available_addresses.last.public_ip
end
puts "*** associating server: #{server.id}, #{server.dns_name} with ipaddress: #{ipaddress}" if @options[:verbose]
@aws_ec2.associate_address(server.id, ipaddress)

# add DNS entry to Route53
@options[:hostname] += '.' unless @options[:hostname].end_with?('.')
zones = @aws_r53.zones.all({"name" => @options[:dns_zone]})
if zone = zones.first
  record = zone.records.get(@options[:hostname])
  if record
    puts "Found an existing record for this hostname!\n#{record.inspect}"
    puts "You will have to manually update the dns entry for this server!"
  else
    # create a record
    r53_opts = {
      :name => @options[:hostname],
      :value => ipaddress,
      :ttl => @options[:dns_ttl].to_s,
      :type => 'A'
    }
    zone.records.create(r53_opts)
  end
else
  puts "Couldn't find DNS zone: #{@options[:dns_zone]}!"
  puts "You will have to manually create the dns entry for this server!"
end

# spinning up an RDS instance takes forever, but we have to wait in order to get the host name
puts "*** waiting for rds server: #{rds_server.id} to be ready ..." if @options[:verbose]
rds_server.wait_for { ready? }
rds_server.reload

# create data_bags config for RDS db
puts <<-DATABAG
RDS Database data bag:
{
  "id": "#{rds_server.id}",
  "host": "#{rds_server.endpoint["Address"]}",
  "database": "#{rds_server.db_name}",
  "username": "#{rds_server.master_username}",
  "password": "#{@options[:db_master_password]}"
}
DATABAG

# add S3 credentials to data_bags
puts <<-S3DATABAG
S3 User data bag:
{
  "id": "#{@options[:s3_iam_user]}",
  "access_key_id": "#{iam_access_key.id}",
  "secret_access_key": "#{iam_access_key.secret_access_key}",
  "bucket": "#{@options[:s3_bucket]}"
}
S3DATABAG

# TODOLATER create littlechef role for new instance
# TODO create capistrano deploy config
# TODO kick off littlechef deployment
