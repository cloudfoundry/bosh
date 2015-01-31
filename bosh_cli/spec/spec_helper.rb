require File.expand_path('../../../spec/shared_spec_helper', __FILE__)

require 'webmock'
require 'timecop'
require 'cli'
require 'fakefs/spec_helpers'

Dir.glob(File.expand_path('../support/**/*.rb', __FILE__)).each { |f| require(f) }

def spec_asset(dir_or_file_name)
  File.expand_path(File.join(File.dirname(__FILE__), 'assets', dir_or_file_name))
end

RSpec.configure do |c|
  c.before do
    Bosh::Cli::Config.interactive = false
    Bosh::Cli::Config.colorize = false
    Bosh::Cli::Config.output = StringIO.new
  end

  c.include WebMock::API

  c.color = true
end

def get_tmp_file_path(content)
  tmp_file = File.open(File.join(Dir.mktmpdir, 'tmp'), 'w')
  tmp_file.write(content)
  tmp_file.close
  tmp_file.path
end

def strip_heredoc(str)
  indent = str.scan(/^[ \t]*(?=\S)/).min.size || 0
  str.gsub(/^[ \t]{#{indent}}/, '')
end
