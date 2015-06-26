require 'fog'
def clone_ec2_instance(source_ec2_name, new_ec2_name)
  ec2 = ::Fog::Compute[:aws]

  # find the server this counts on the Name being setup correctly
  # it would be better to use the hostname from the role to find this
  source_ec2_server = ec2.servers.find{|s| s.tags["Name"] == source_ec2_name}

  # create new EC2 instance which copies the important bits from the production server
  ec2_opts = {
    :key_name  => source_ec2_server.key_name,
    :image_id  => source_ec2_server.image_id,
    :flavor_id => source_ec2_server.flavor_id,
    :availability_zone => source_ec2_server.availability_zone,
    :groups    => source_ec2_server.groups,
    :tags => {
      "Name"     => new_ec2_name,
      "Contacts" => '',  # <- should set this based on the current user running this script
      "Notes"    => '',  # <- these are probably different than the production instance
      "Project"  => source_ec2_server.tags["Project"]
    }
  }
  create_ec2_instance ec2_opts
end

def create_ec2_instance(options)
  ec2 = ::Fog::Compute[:aws]

  start = Time.now
  puts "*** creating new server: #{options[:tags]["Name"]}  (usually takes 30 seconds)"
  server = ec2.servers.create(options)
  server.wait_for { ready? }
  server.reload
  puts "    dns name: #{server.dns_name}"
  puts "    finished in #{Time.now - start}s"
  server
end

def find_or_create_ec2_security_group(options)
  ec2 = ::Fog::Compute[:aws]

  puts "*** ensuring ec2 security group is set up: #{options[:name]}"
  # names are not case sensitive
  # we also (unfortunately) seem to have unnamed security groups now?
  # can't find the security group with nil name in the AWS console...
  ec2_sec_group = ec2.security_groups.find do |sg| 
      sg.name &&
      (sg.name.downcase == options[:name].downcase) &&
      (sg.vpc_id == options[:vpc_id])
  end

  unless ec2_sec_group
    ec2_sec_group = ec2.security_groups.create(options)
    ec2_sec_group.authorize_port_range(22..22)
    ec2_sec_group.authorize_port_range(80..80)
    ec2_sec_group.authorize_port_range(443..443)
  end

  ec2_sec_group
end