# encoding: utf-8
require 'fog'
require 'highline/import'

class Opts
  def initialize(keys)
    @opts = {}
    @keys = keys
  end

  def [](key)
    return @opts[key]
  end

  def ask_option(key)
    default = ENV["db_#{key}"] || '✖'
    @opts[key] = ask("#{key}: ") { |q| q.default = default }
  end

  def get_options
    @keys.each do |key|
      ask_option(key)
    end
  end

  def method_missing(m, *args, &block)
    maybe_key = m.to_s
    if @opts[maybe_key]
      return @opts[maybe_key]
    end
    super
  end
end

ENV['db_user']||= "master"
ENV['db_name']||= "lara"
ENV['db_pass']||= "(lookup db_password in databags/sites)"

opts = Opts.new(%w[user pass name])
opts.get_options

@rds = ::Fog::AWS[:rds]

rds_server = @rds.servers.get(opts['name'])
server = rds_server.endpoint["Address"]

cmd = "mysqldump portal --opt --compress -u #{opts.user} -p#{opts.pass} -h #{server} > #{opts.name}.sql"
puts cmd
%x[#{cmd}]
unless $?.success?
  puts <<-ERROR_MSG
    Something bad seems to have happend.  Check that the username and password are correct.
    Also check the CIDR settings for the security group associated with your RDS server.
    You need to have your current IP address in the CIDR range.
  ERROR_MSG
end
