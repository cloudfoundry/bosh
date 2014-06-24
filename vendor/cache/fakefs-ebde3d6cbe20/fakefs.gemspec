# -*- encoding: utf-8 -*-
# stub: fakefs 0.5.2 ruby lib

Gem::Specification.new do |s|
  s.name = "fakefs"
  s.version = "0.5.2"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib"]
  s.authors = ["Chris Wanstrath", "Scott Taylor", "Jeff Hodges", "Pat Nakajima", "Brian Donovan"]
  s.date = "2014-06-12"
  s.description = "A fake filesystem. Use it in your tests."
  s.email = ["chris@ozmm.org"]
  s.files = [".autotest", ".gitignore", ".rspec", ".travis.yml", "CONTRIBUTORS", "Gemfile", "LICENSE", "README.markdown", "Rakefile", "fakefs.gemspec", "lib/fakefs.rb", "lib/fakefs/base.rb", "lib/fakefs/dir.rb", "lib/fakefs/fake/dir.rb", "lib/fakefs/fake/file.rb", "lib/fakefs/fake/symlink.rb", "lib/fakefs/file.rb", "lib/fakefs/file_system.rb", "lib/fakefs/file_test.rb", "lib/fakefs/fileutils.rb", "lib/fakefs/pathname.rb", "lib/fakefs/safe.rb", "lib/fakefs/spec_helpers.rb", "lib/fakefs/version.rb", "spec/fakefs/fakefs_bug_ruby_2.1.0-preview2_spec.rb", "spec/fakefs/spec_helpers_spec.rb", "spec/spec.opts", "spec/spec_helper.rb", "test/dir/tempfile_test.rb", "test/fake/file/join_test.rb", "test/fake/file/lstat_test.rb", "test/fake/file/stat_test.rb", "test/fake/file/sysseek_test.rb", "test/fake/file/syswrite_test.rb", "test/fake/file_test.rb", "test/fake/symlink_test.rb", "test/fakefs_test.rb", "test/file/stat_test.rb", "test/safe_test.rb", "test/test_helper.rb", "test/verify.rb"]
  s.homepage = "http://github.com/defunkt/fakefs"
  s.licenses = ["MIT"]
  s.rubygems_version = "2.2.2"
  s.summary = "A fake filesystem. Use it in your tests."
  s.test_files = ["spec/fakefs/fakefs_bug_ruby_2.1.0-preview2_spec.rb", "spec/fakefs/spec_helpers_spec.rb", "spec/spec.opts", "spec/spec_helper.rb", "test/dir/tempfile_test.rb", "test/fake/file/join_test.rb", "test/fake/file/lstat_test.rb", "test/fake/file/stat_test.rb", "test/fake/file/sysseek_test.rb", "test/fake/file/syswrite_test.rb", "test/fake/file_test.rb", "test/fake/symlink_test.rb", "test/fakefs_test.rb", "test/file/stat_test.rb", "test/safe_test.rb", "test/test_helper.rb", "test/verify.rb"]

  if s.respond_to? :specification_version then
    s.specification_version = 4

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_development_dependency(%q<bundler>, ["~> 1.3"])
      s.add_development_dependency(%q<rake>, [">= 0"])
      s.add_development_dependency(%q<rspec>, [">= 0"])
      s.add_development_dependency(%q<rdiscount>, [">= 0"])
    else
      s.add_dependency(%q<bundler>, ["~> 1.3"])
      s.add_dependency(%q<rake>, [">= 0"])
      s.add_dependency(%q<rspec>, [">= 0"])
      s.add_dependency(%q<rdiscount>, [">= 0"])
    end
  else
    s.add_dependency(%q<bundler>, ["~> 1.3"])
    s.add_dependency(%q<rake>, [">= 0"])
    s.add_dependency(%q<rspec>, [">= 0"])
    s.add_dependency(%q<rdiscount>, [">= 0"])
  end
end
