# -*- encoding: utf-8 -*-

lib = File.expand_path('../lib/', __FILE__)
$:.unshift lib unless $:.include?(lib)

require 'blobstore_client/version'

Gem::Specification.new do |s|
  s.name = "blobstore_client"
  s.version = Bosh::Blobstore::Client::VERSION
  s.platform = Gem::Platform::RUBY
  s.authors = [ "vadim" ]
  s.email = "vspivak@vmware.com"
  s.homepage = "http://github.com/someaccount"
  s.summary = "some summary"
  s.description = "some description"

  s.required_rubygems_version = ">= 1.3.6"

  s.add_dependency "httpclient"
  s.add_development_dependency "rspec"
  s.add_development_dependency 'rcov'
  s.add_development_dependency 'ci_reporter'

  s.files = `git ls-files`.split("\n")
  s.executables = `git ls-files`.split("\n").map { |f| f[%r{^bin/(.*)}, 1] }.compact
  s.require_path = 'lib'
end
