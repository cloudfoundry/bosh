require "test_helper"

class FileStat < Test::Unit::TestCase
  def setup
    FakeFS.activate!
    FakeFS::FileSystem.clear
  end

  def teardown
    FakeFS.deactivate!
  end

  def test_calling_lstat_should_create_a_new_file_stat_object
    File.open("foo", "w") do |f|
      f << "bar"
    end

    File.open("foo") do |f|
      assert_equal File::Stat, f.lstat.class
    end
  end

  def test_lstat_should_use_correct_file
    File.open("bar", "w") do |f|
      f << "1"
    end

    File.open("bar") do |f|
      assert_equal 1, f.lstat.size
    end
  end

  def test_lstat_should_report_on_symlink_itself
    File.open("foo", "w") { |f| f << "some content" }
    File.symlink "foo", "my_symlink"

    assert_not_equal File.lstat("my_symlink").size, File.lstat("foo").size
  end

  def test_should_report_on_symlink_itself_with_size_instance_method
    File.open("foo", "w") { |f| f << "some content" }
    File.symlink "foo", "my_symlink"

    file = File.open("foo")
    symlink = File.open("my_symlink")

    assert_not_equal file.lstat.size, symlink.lstat.size
  end

  def test_symlink_size_is_size_of_path_pointed_to
    File.open("a", "w") { |x| x << "foobarbazfoobarbaz" }
    File.symlink "a", "one_char_symlink"
    assert_equal 1, File.lstat("one_char_symlink").size

    File.open("ab", "w") { |x| x << "foobarbazfoobarbaz" }
    File.symlink "ab", "two_char_symlink"
    assert_equal 2, File.lstat("two_char_symlink").size
  end
end