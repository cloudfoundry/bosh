require 'rspec/core'

$:.unshift(File.expand_path("../../lib", __FILE__))

require "sequel"
require "sequel/adapters/sqlite"

Sequel.extension :migration
db = Sequel.sqlite(':memory:')
vsphere_cpi_migrations = File.expand_path("../../db/migrations/vsphere_cpi", __FILE__)
Sequel::TimestampMigrator.new(db, vsphere_cpi_migrations, :table => "vsphere_cpi_schema").run

require 'cloud'
require 'cloud/vsphere'

Bosh::Clouds::Config.configure({ "db" => db })

RSpec.configure do |c|
  c.color_enabled = true
end
