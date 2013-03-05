require 'fog'
require 'json'
require 'net/scp'
require 'net/ssh'

class WiseHelper
  DefaultPorts    = [22,25,80,8080]
  DefaultUser     = 'ubuntu'

  # TODO: WISE image specific
  VLE_NODE_DIR='/var/lib/tomcat7/webapps/vlewrapper/vle/node/'

  OUR_ROOT        = File.expand_path(File.join(__FILE__, "..", "..",".."))
  CONFIG_FILE     = File.join(OUR_ROOT, "wise-config","wise.json")
  WISE4_STEPS_PATH= File.join(OUR_ROOT, "wise-config","wise4-step-types.json")

  def initialize(configuration_file=CONFIG_FILE)
    @config =  JSON.load File.new(configuration_file)
    @connection = Fog::Compute.new(:provider => 'AWS')
    puts WISE4_STEPS_PATH
    if File.exists?(WISE4_STEPS_PATH)
      @wise4_step_types = JSON.load File.new(WISE4_STEPS_PATH)
    else
      @wise4_step_types = {}
    end
  end

  # opens an interactive ssh console
  def open_ssh(id=@connection.servers.first)
    command = ssh_cli_string(id)
    exec(command)
  end

  def user_for_server(server)
    %w[user User current_user Contacts].each do |user_tag|
      return server.tags[user_tag] unless server.tags[user_tag].nil?
    end
  end

  def filter_for_user(server)
    current_user = Etc.getlogin
    return true if current_user == user_for_server(server)
  end

  def list_servers
    # running_servers.table([:id, :flavor_id, :dns_name, :image_id])
    _format = "%12.11s %12.11s %50.50s %10.10s %10.10s"
    puts sprintf _format,
        "instance id",
        "state",
        "public dns",
        "user",
        "project"
    running_servers.each do |server|
      ssh_cli_string = ssh_cli_string(server.id)
      puts sprintf _format,
          server.id,
          state(server),
          server.dns_name,
          user_for_server(server),
          server.tags['Project']
    end
  end

  def set_state(id,state)
    server = @connection.servers.get(id)
    state(server,state)
  end

  def terminate(id)
    server = @connection.servers.get(id)
    server.destroy
  end

  # wise-cookbooks post 12-13-2012 include scripts
  # to backup and restore wise4 sql and curriculum.
  def backup(_id)
    ssh(_id,'~/backup.sh')
    scp_down(_id, 'backup/current.tar.gz', ".")
  end

  # wise-cookbooks post 12-13-2012 include scripts
  # to backup and restore wise4 sql and curriculum.
  def restore(id,backup_file='backup.tar.gz')
    # copy the local backup file to remote id
    backup_file = './current.tar.gz'
    puts "yes" if (File.exists? backup_file)
    #%x[scp #{backup_file} #{self.login_user}@#{server.dns_name}:~/backup.tar.gz]
    scp_up(id, backup_file, "backup.tar.gz")
    # %x[ssh #{self.login_user}@#{server.dns_name} "~/restore.sh"]
    # run the remote script to do the restore.
    puts ssh(id,'~/restore.sh')
  end

  def scp_up(id,local,remote)
    server  = @connection.servers.get(id)
    Net::SCP.upload!(
      server.dns_name,
      self.login_user,
      local,
      remote);
  end

  def scp_down(id,remote,local)
    server  = @connection.servers.get(id)
    Net::SCP.download!(
      server.dns_name,
      self.login_user,
      remote,
      local);
  end

  def clone(source_id)
    # TODO:
    # 1 create a server (and a handle to it as new_server)
    # 2 backup source_id
    # 3 push changes to new_server
  end

  def rsync(id)
    puts "synching wise 4 steps #{@wise4_step_types.inspect}"
    @wise4_step_types.each{ |name, dir |
      remote_path = "#{VLE_NODE_DIR}#{File.basename(dir)}"
      puts "remote path: #{remote_path}"
      puts "local path : #{dir}"
      server = @connection.servers.get(id)
      # make sure vagrant can write to the file.
      self.sudo id, "mkdir -p #{remote_path}"
      self.sudo id, "chown -R #{self.login_user} #{remote_path}"
      rsync_cmd = %[rsync -rtzPu -e "ssh" #{dir} #{self.login_user}@#{server.dns_name}:#{File.dirname(remote_path)}]
      puts "command: #{rsync_cmd}"
      results = %x[#{rsync_cmd}]
      puts "results: #{results}"
    }
  end

  protected

  def self.dir
    File.dirname(__FILE__)
  end

  def self.config_dir
    File.expand_path(File.join(self.dir,"../config/"))
  end

  def ports
    @config['ports'] || DefaultPorts
  end

  def login_user
    @config['login_user'] || DefaultUser
  end

  def running_servers
    servers = @connection.servers.all.select { |s| s.state == "running" }
    # servers.select { |s| s.key_name == self.key_name }
    if block_given?
      servers.select! { |s| s.yield s }
    else
      servers.select! { |s| filter_for_user(s) }
    end
    return servers
  end

  def servers_with_tag(tag,value)
    @connection.servers.all.select { |s| s.tags[tag] == value }
  end

  # returns the ssh string to connect to the host
  def ssh_cli_string(id)
    server = @connection.servers.get(id)
    "ssh  #{self.login_user}@#{server.dns_name}"
  end

  def ssh(id, command)
    server  = @connection.servers.get(id)
    results = ""
    Net::SSH.start(server.dns_name, self.login_user) do |ssh|
      results = ssh.exec!(command)
    end
    results
  end

  def sudo(server, command)
    ssh(server, "sudo sh -c '#{command}'")
  end


  def _set_state(server,state)
    puts "setting state to #{state}"
    @connection.tags.create(
      :key          => 'cloud-state',
      :resource_id  => server.identity,
      :value        => state
    )
    return state
  end

  def state(server,state=nil)
    return "waiting" unless server.ready?
    results = state
    if state
      results = _set_state(server,state)
    else
      results = server.tags['cloud-state']
    end
    return results
  end


end
