libdir = File.join(File.dirname(__FILE__), "lib")
$:.unshift(libdir) unless $:.include?(libdir)

require "agent_client/version"

gemspec = Gem::Specification.new do |s|
  s.name         = "agent_client"
  s.version      = Bosh::Agent::Client::VERSION
  s.platform     = Gem::Platform::RUBY
  s.summary      = "Bosh agent client"
  s.description  = s.summary
  s.authors      = [ "Bosh eng" ]
  s.homepage     = "http://vmware.com"
  s.require_path = "lib"
  s.files        = %w(README Rakefile) + Dir.glob("{lib}/**/*")

  s.add_dependency "httpclient"
  s.add_dependency "yajl-ruby"

  s.add_development_dependency "rspec"
end
