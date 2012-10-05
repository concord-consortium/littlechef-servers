
def mock_aws(options)
  if Fog.mock?
    rds = ::Fog::AWS[:rds]
    ec2 = ::Fog::Compute[:aws]
    r53 = ::Fog::DNS[:aws]

    r53.zones.create({"domain" => "concord.org."})
    if rds_instance = options[:rds_instance]
      rds.servers.create({
        id: options[:rds_instance],
        engine: 'mysql',
        allocated_storage: 12,
        master_username: 'test',
        password: 'test'
        })
    end
    if ec2_instance_name = options[:ec2_instance_name]
      ec2.key_pairs.create({
        name: 'test_key'
        })
      ec2.servers.create({
        key_name: 'test_key',
        image_id: 'test_image',
        flavor_id: 'test_flavor',
        availability_zone: 'test_az',
        groups: ['test_group'],
        tags: {
          "Name"     => ec2_instance_name,
          "Contacts" => '',  # <- should set this based on the current user running this script
          "Notes"    => '',  # <- these are probably different than the production instance
          "Project"  => 'TestProject'
          }
        })
    end
  end
end