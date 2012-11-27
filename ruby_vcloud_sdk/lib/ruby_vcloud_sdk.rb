$:.unshift(File.expand_path("..", __FILE__))

require "rubygems" # Needed for Ruby 1.8
require "logger"

module VCloudSdk; end

require "ruby_vcloud_sdk/xml/constants"
require "ruby_vcloud_sdk/xml/wrapper"
require "ruby_vcloud_sdk/xml/wrapper_classes"

require "ruby_vcloud_sdk/config"
require "ruby_vcloud_sdk/errors"
require "ruby_vcloud_sdk/util"
require "ruby_vcloud_sdk/client"
require "ruby_vcloud_sdk/ovf_directory"

require "ruby_vcloud_sdk/connection/connection"
require "ruby_vcloud_sdk/connection/file_uploader"
