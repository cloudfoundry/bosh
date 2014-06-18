require "test_helper"

class FileStat < Test::Unit::TestCase
  def setup
    FakeFS.activate!
    FakeFS::FileSystem.clear
  end

  def teardown
    FakeFS.deactivate!
  end

  def test_calling_stat_should_create_a_new_file_stat_object
    File.open("foo", "w") do |f|
      f << "bar"
    end

    File.open("foo") do |f|
      assert_equal File::Stat, f.stat.class
    end
  end

  def test_stat_should_use_correct_file
    File.open("bar", "w") do |f|
      f << "1"
    end

    File.open("bar") do |f|
      assert_equal 1, f.stat.size
    end
  end

  def test_stat_should_report_on_symlink_pointer
    File.open("foo", "w") { |f| f << "some content" }
    File.symlink "foo", "my_symlink"

    assert_equal File.stat("my_symlink").size, File.stat("foo").size
  end
end