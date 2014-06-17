require "test_helper"

class FileJoin < Test::Unit::TestCase
  def setup
    FakeFS.activate!
  end

  def teardown
    FakeFS.deactivate!
  end

  [
    ["a", "b"],  ["a/", "b"], ["a", "/b"], ["a/", "/b"], ["a", "/", "b"]
  ].each_with_index do |args, i|
    define_method "test_file_join_#{i}" do
      assert_equal RealFile.join(args), File.join(args)
    end
  end
end