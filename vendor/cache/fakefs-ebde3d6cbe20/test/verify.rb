# Figure out what's missing from fakefs
#
# USAGE
#
#   $ RUBYLIB=test ruby test/verify.rb | grep "not implemented"

require "test_helper"

class FakeFSVerifierTest < Test::Unit::TestCase
  class_mapping = {
    RealFile       => FakeFS::File,
    RealFile::Stat => FakeFS::File::Stat,
    RealFileUtils  => FakeFS::FileUtils,
    RealDir        => FakeFS::Dir,
    RealFileTest   => FakeFS::FileTest
  }

  class_mapping.each do |real_class, fake_class|
    real_class.methods.each do |method|
      define_method "test #{method} class method" do
        assert fake_class.respond_to?(method), "#{fake_class}.#{method} not implemented"
      end
    end

    real_class.instance_methods.each do |method|
      define_method("test #{method} instance method") do
        assert fake_class.instance_methods.include?(method), "#{fake_class}##{method} not implemented"
      end
    end
  end
end
