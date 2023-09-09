require File.expand_path('../shared/spec_helper', __FILE__)

require 'fileutils'
require 'digest/sha1'
require 'tmpdir'
require 'tempfile'
require 'set'
require 'yaml'
require 'nats/client'
require 'restclient'
require 'bosh/director'
require 'blue-shell'
require 'bosh/dev/postgres_version'

Dir.glob(File.expand_path('../support/**/*.rb', __FILE__)).each {|f| require(f)}
Dir.glob(File.expand_path('../shared/support/**/*.rb', __FILE__)).each {|f| require(f)}
