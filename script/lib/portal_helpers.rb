require 'fog'
require_relative 'ec2_helpers'
require_relative 'rds_helpers'
require_relative 'mocks'

def clone_portal_servers(options)
  source_rds_instance = options[:source_rds_instance]
  source_ec2_name = options[:source_ec2_name]
  new_rds_instance = options[:new_rds_instance]
  new_ec2_name = options[:new_ec2_name]
  new_hostname = options[:new_hostname]

  mock_aws(rds_instance: source_rds_instance, ec2_instance_name: source_ec2_name)

  # clone the source rds instance by restoring the most recent backup
  clone_rds_instance source_rds_instance, new_rds_instance

  # make a new ec2 instance using the same settings as a source one
  server = clone_ec2_instance source_ec2_name, new_ec2_name

  r53 = ::Fog::DNS[:aws]

  # add dynamic public ip entry to Route53 with short ttl
  zone = r53.zones.all({"name" => "concord.org."}).first
  # desired options:
  new_dns_entry = {
    :name => new_hostname,
    :value => server.public_ip_address,
    :ttl => '120',
    :type => 'A'
  }

  # the zone.records.get method is not mocked in fog yet
  record = Fog.mock? ? nil : zone.records.get(new_dns_entry[:name])
  if record
    puts "Found an existing record for: #{record.name}, more details\n#{record.inspect}"
    puts "You will have to manually update the dns entry for this server!"
    puts "These are the recommended settings:\n#{new_dns_entry.to_yaml}"
  else
    zone.records.create(new_dns_entry)
  end
end

