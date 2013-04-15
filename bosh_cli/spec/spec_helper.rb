# Copyright (c) 2009-2012 VMware, Inc.

require "rspec/core"
require "webmock"

require "cli"

def spec_asset(dir_or_file_name)
  File.expand_path(File.join(File.dirname(__FILE__), "assets", dir_or_file_name))
end

RSpec.configure do |c|
  c.before(:each) do
    Bosh::Cli::Config.interactive = false
    Bosh::Cli::Config.colorize = false
    Bosh::Cli::Config.output = StringIO.new
  end

  c.include WebMock::API

  c.color_enabled = true
end

def get_tmp_file_path(content)
  tmp_file = File.open(File.join(Dir.mktmpdir, "tmp"), "w")
  tmp_file.write(content)
  tmp_file.close

  tmp_file.path
end
