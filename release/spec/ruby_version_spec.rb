require 'rspec'
require 'yaml'

describe 'ruby version' do
  it 'tests are running with the Ruby version that is included in release' do
    ruby_spec = YAML.load_file(File.join(File.dirname(__FILE__), '../packages/ruby/spec'))
    ruby_spec['files'].find { |f| f =~ /ruby-(.*).tar.gz/ }
    ruby_version_in_release = $1

    # 1.9.3 is allowed since we are running 1.9.3 tests for CLI support
    supported_versions = ['1.9.3', ruby_version_in_release]

    expect(supported_versions).to include(RUBY_VERSION)
  end
end
