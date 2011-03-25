$:.push File.expand_path("../lib", __FILE__)

Gem::Specification.new do |s|
  s.name        = "ruby_vim_sdk"
  s.version     = "0.0.1"
  s.platform    = Gem::Platform::RUBY
  s.summary     = %q{VMware VIM Binding for Ruby}

  s.files         = %w(Rakefile) + `git ls-files -- lib/*`.split("\n")
  s.require_paths = ["lib"]

  s.add_dependency("builder")
  s.add_dependency("nokogiri")
  s.add_dependency("httpclient")
end
