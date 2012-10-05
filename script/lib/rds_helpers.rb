require 'fog'
require 'fog/aws/models/rds/server'

def clone_rds_instance(source_rds_instance, new_rds_instance)
  rds = ::Fog::AWS[:rds]

  source_rds_server = rds.servers.get(source_rds_instance)
  if source_rds_server.nil?
  	puts "*** can't find rds instance with name #{source_rds_instance}"
  	return
  end

  puts "*** creating new rds server from rds #{source_rds_instance} latest restore point"
  start = Time.now

  new_rds_server = source_rds_server.restore_most_recent(new_rds_instance)

  # not sure if we need to wait here or not
  new_rds_server.wait_for { ready? }
  # update the security group
  new_rds_server.modify(true, {
    security_group_names: source_rds_server.security_group_names
    })
  puts "    finished in #{Time.now - start}s"

  new_rds_server.reload
end

# monkey patch Server, we should clean this up and submit it to fog
class Fog::AWS::RDS::Server
  def restore_most_recent(destination_instance_name)
    if Fog.mock?
      opts = {
        id: destination_instance_name,
        engine: engine,
        allocated_storage: allocated_storage,
        master_username: master_username,
        password: "test" # <- for some reason the password isn't accessible from the rds.server model
      }
      connection.servers.create(opts)
    else
      restore_result = connection.restore_db_instance_to_point_in_time(identity, destination_instance_name, {
          'UseLatestRestorableTime' => true
        })
      if restore_result.status != 200
        raise "Failed to restore db instance to make staging: #{restore_result.inspect}"
      end
    end
    connection.servers.get(destination_instance_name)
  end
end