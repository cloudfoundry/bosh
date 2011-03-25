$:.unshift(File.expand_path("..", __FILE__))

require "base64"
require "date"
require "delegate"
require "logger"
require "monitor"
require "net/https"
require "pp"
require "set"
require "stringio"
require "time"
require "thread"
require "uri"
require "zlib"

require "rubygems"
require "builder"
require "httpclient"
require "nokogiri"

module VimSdk; end

require "ruby_vim_sdk/const"
require "ruby_vim_sdk/ext"
require "ruby_vim_sdk/vmodl_helper"

require "ruby_vim_sdk/typed_array"
require "ruby_vim_sdk/base_type"
require "ruby_vim_sdk/data_type"
require "ruby_vim_sdk/enum_type"
require "ruby_vim_sdk/managed_type"
require "ruby_vim_sdk/property"
require "ruby_vim_sdk/method"
require "ruby_vim_sdk/types"
require "ruby_vim_sdk/soap_exception"

require "ruby_vim_sdk/vmodl/data_object"
require "ruby_vim_sdk/vmodl/managed_object"
require "ruby_vim_sdk/vmodl/method_name"
require "ruby_vim_sdk/vmodl/property_path"
require "ruby_vim_sdk/vmodl/type_name"

require "ruby_vim_sdk/vmomi_support"

require "ruby_vim_sdk/soap/deserializer"
require "ruby_vim_sdk/soap/serializer"
require "ruby_vim_sdk/soap/stub_adapter"
