#!/usr/bin/env ruby

require 'net/scp'
require 'uri/open-scp'
require 'yaml'
require 'trollop'
require 'json'

options = Trollop::options do
	opt :stage, "Stage of instance(production, staging, ...)", :type => :string
end
Trollop::die :stage, "is required (ex: production, production1, staging)" unless options[:stage]

proj = 'has'
rds_domain = 'us-east-1'
proj_data_bag = JSON.load File.new("data_bags/sites/#{proj}.json")
rds_domain_data_bag = JSON.load File.new("data_bags/rds_domains/cc-#{rds_domain}.json")

rds_id = "#{proj}-#{options[:stage]}"

db_settings = open("scp://deploy@seymour.concord.org/web/production/has/shared/config/database.yml")
db_settings = YAML.load db_settings
db_settings = db_settings['production']

seymour_dump = "mysqldump -u #{db_settings['username']} -p\'#{db_settings['password']}\' " +
               "--lock-tables=false --add-drop-table --quick --extended-insert #{db_settings['database']}"

rds_host = "#{rds_id}.#{rds_domain_data_bag['domain']}"
rds_load = "mysql -C -h #{rds_host} -u #{proj_data_bag['db_username']} -p\'#{proj_data_bag['db_password']}\' portal"

cmd = seymour_dump + " | " + rds_load
puts "Run the following command on seymour:"
puts cmd
