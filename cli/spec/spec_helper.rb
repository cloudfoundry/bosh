# Copyright (c) 2009-2012 VMware, Inc.

require "rspec/core"

$:.unshift(File.expand_path("../../lib", __FILE__))
require "cli"

def spec_asset(filename)
  File.expand_path(File.join(File.dirname(__FILE__), "assets", filename))
end

RSpec.configure do |c|
  c.before(:each) do
    Bosh::Cli::Config.interactive = false
    Bosh::Cli::Config.colorize = false
    Bosh::Cli::Config.output = StringIO.new
  end

  c.color_enabled = true
end

def get_tmp_file_path(content)
  tmp_file = Tempfile.new("")
  File.open(tmp_file.path, "w") do |f|
    f.write(content)
  end
  tmp_file.path
end
