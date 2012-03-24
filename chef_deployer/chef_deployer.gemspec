# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)

Gem::Specification.new do |s|
  s.name        = "chef_deployer"
  s.version     = "0.0.10"
  s.platform    = Gem::Platform::RUBY
  s.summary     = %q{Deploy chef cookbooks}
  s.description  = s.summary
  s.authors      = [ "Vadim Spivak", "Mahesh Patil" ]
  s.email        = "ac-eng@vmware.com"
  s.homepage     = "http://vmware.com"


  s.files         = %w(Rakefile) + `git ls-files -- lib/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.add_dependency("nats")
  s.add_dependency("net-ssh")
  s.add_dependency("net-scp")
  s.add_dependency("net-ssh-gateway")
  s.add_dependency("chef")
  s.add_dependency("thor")
  s.add_dependency("yajl-ruby")
end
