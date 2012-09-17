$:.unshift(File.join(File.dirname(__FILE__), '.'))
$:.unshift(File.join(File.dirname(__FILE__), 'client'))

require 'rubygems' # Needed for Ruby 1.8
require 'logger'
require 'xml'
require 'connection'
require 'config'
require 'client/client'
require 'client/ovf_directory'
