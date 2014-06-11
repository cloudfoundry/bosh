$LOAD_PATH.unshift File.join(File.dirname(__FILE__), '..', 'lib')
require 'fakefs/safe'
require 'test/unit'

begin
  require 'redgreen'
rescue LoadError
end

def act_on_real_fs
  raise ArgumentError unless block_given?
  FakeFS.deactivate!
  yield
  FakeFS.activate!
end

def capture_stderr
  real_stderr, $stderr = $stderr, StringIO.new

  # force FileUtils to use our stderr
  RealFileUtils.instance_variable_set('@fileutils_output', $stderr)

  yield

  return $stderr.string
ensure
  $stderr = real_stderr

  # restore FileUtils stderr
  RealFileUtils.instance_variable_set('@fileutils_output', $stderr)
end
