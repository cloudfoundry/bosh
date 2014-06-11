require "test_helper"

class FakeSymlinkTest < Test::Unit::TestCase
  include FakeFS

  def test_symlink_has_method_missing_as_private
    methods = FakeSymlink.private_instance_methods.map { |m| m.to_s }
    assert methods.include?("method_missing")
  end
end
