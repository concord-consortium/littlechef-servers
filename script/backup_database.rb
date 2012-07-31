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

@options = Trollop::options do
  version "backup_database.rb 1.0"
  banner <<-BANNER
A simple script for backing up RDS databases without impacting the main instance.

Usage:
  backup_database.rb [--all | [options]]
where [options] are:
BANNER
  # shared options
  opt :verbose,  "Enable or disable detailed output",     :default => true
  opt :debug,    "Enable extra detailed output",          :default => false
  opt :names,    "Database names",                        :type => :strings
  opt :all,      "Back up all databases",                 :default => false
  opt :dir,      "Directory to keep backup files",        :default => "."
end

Trollop::die "Can't specify both --name and --all" if @options[:names] && @options[:all]
Trollop::die :dir, "must be an existing directory" unless File.exist?(@options[:dir]) && File.directory?(@options[:dir])
Trollop::die :dir, "directory must be writable" unless File.writable?(@options[:dir])

dbs = []
if @options[:all]
  # TODO load all databases
else
  dbs = @options[:names]
end

@rds = ::Fog::AWS[:rds]

# for each database, save it
dbs.each do |db|
  puts "Backing up db: #{db}" if @options[:verbose]
  temp_db = db+"-temp"+SecureRandom.hex(6)
  source_db = @rds.servers.get(db)

  # TODO A newer version of fog might support getting automated snapshots (1.5.0 does not).
  # snaps = source_db.snapshots.all
  # snap = snaps.sort {|sn| sn.created_at.utc.to_i }.last

  # until then create our own (which is really slow)
  puts "Creating instance snapshot" if @options[:verbose]
  snap = source_db.snapshots.create(:id => "snap-"+temp_db)
  snap.wait_for { ready? }
  snap.reload

  # spin up temp instance from snapshot
  puts "Restoring from snapshot: #{snap.id}" if @options[:verbose]
  rds_opts = {
    'AvailabilityZone' => "us-east-1e",
    'DBInstanceClass' => "db.m1.large"
  }
  @rds.restore_db_instance_from_db_snapshot(snap.id, temp_db, rds_opts)
  rds_server = @rds.servers.get(temp_db)
  rds_server.wait_for { ready? }
  rds_server.reload

  puts "Resetting master password and opening up access" if @options[:verbose]
  # TODO Can we auto-add our current public ip to the backup-inprogress security group?
  temp_pw = SecureRandom.hex(10)
  rds_opts = {
    :password => "pw#{temp_pw}",
    :security_group_names => ['backup-inprogress'],
  }
  rds_server.modify(true, rds_opts)
  rds_server.wait_for { ready? }
  rds_server.reload

  # backup db to local file
  file = "#{@options[:dir]}/#{db}.sql"
  puts "Dumping to file: #{file}" if @options[:verbose]
  # TODO Perhaps we should dump each db within the instance separately?
  cmd = "mysqldump -u #{rds_server.master_username} -ppw#{temp_pw} -h #{rds_server.endpoint["Address"]} --all-databases > #{file}"
  puts "cmd: #{cmd}" if @options[:debug]
  puts `#{cmd}`

  # destroy temp instance
  rds_server.destroy
  snap.destroy
end
