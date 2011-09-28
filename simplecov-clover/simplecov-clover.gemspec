# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require 'simplecov-clover/version'

Gem::Specification.new do |s|
  s.name        = %q{simplecov-clover}
  s.version     = SimpleCov::Formatter::CloverFormatter::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Oleg Shaldybin"]
  s.email       = ["olegs@vmware.com"]
  s.summary     = %q{Clover style formatter for SimpleCov}
  s.description = %q{Clover style formatter for SimpleCov}
  s.date        = %q{2011-09-27}

  s.required_rubygems_version = Gem::Requirement.new(">= 1.2") if s.respond_to? :required_rubygems_version=
  s.extra_rdoc_files = ["lib/simplecov-clover.rb"]
  s.rubygems_version = %q{1.3.7}

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.add_dependency 'simplecov', '>= 0.4.1'

  s.add_development_dependency 'bundler', '>= 1.0'
  s.add_development_dependency 'rake'
end
