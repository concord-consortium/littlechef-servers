$:.push(File.dirname(__FILE__),'script/lib')
require 'wise_helper'

class Wise < Thor
  desc "list", "list existing servers"
  def list
    helper = WiseHelper.new
    helper.list_servers
  end

  desc "new", "create a new server (deprecated)"
  def new
    puts "use script/create_ec2.rb instead"
  end

  desc "provision (id)", "provision an existing server (deprecated)"
  def provision(id=nil)
    puts "use fix node:<x> role:wise4"
  end

  desc "stop (id)", "stop all servers (deprecated)"
  def stop(id=nil)
    puts "use the AWS console to remove servers ... (for now)"
  end

  desc "ssh (id)", "ssh to the machine with [id]"
  def ssh(id=nil)
    helper = WiseHelper.new
    if id
      helper.open_ssh(id)
    else
      helper.open_ssh(id)
    end
  end

  desc "rsync (id)", "push local (wise4-step-types.yml) files to remote machine (id)"
  def rsync(id=nil)
    helper = WiseHelper.new
    helper.rsync(id)
  end

  desc "backup (id)", "create WISE4 backup of remote machine (id)"
  def backup(id=nil)
    helper = WiseHelper.new
    helper.backup(id)
  end

  desc "restore (id)", "push WISE4 backup.tar.gz to remote machine (id)"
  def restore(id=nil)
    helper = WiseHelper.new
    helper.restore(id)
  end

  desc "state [id][state]", "manually set the [state] for machine [id]"
  def state(id,state)
    helper = WiseHelper.new
    helper.set_state(id,state)
  end
end