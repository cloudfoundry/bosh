require "test_helper"

class FakeFileTest < Test::Unit::TestCase
  include FakeFS

  def setup
    FileSystem.clear

    @file = FakeFile.new
  end

  def test_fake_file_has_empty_content_by_default
    assert_equal "", @file.content
  end

  def test_fake_file_can_read_and_write_to_content
    @file.content = "foobar"
    assert_equal "foobar", @file.content
  end

  def test_fake_file_has_1_link_by_default
    assert_equal [@file], @file.links
  end

  def test_fake_file_can_create_link
    other_file = FakeFile.new

    @file.link(other_file)

    assert_equal [@file, other_file], @file.links
  end

  def test_fake_file_wont_add_link_to_same_file_twice
    other_file = FakeFile.new

    @file.link other_file
    @file.link other_file

    assert_equal [@file, other_file], @file.links
  end

  def test_links_are_mutual
    other_file = FakeFile.new

    @file.link(other_file)

    assert_equal [@file, other_file], other_file.links
  end

  def test_can_link_multiple_files
    file_two   = FakeFile.new
    file_three = FakeFile.new

    @file.link file_two
    @file.link file_three

    assert_equal [@file, file_two, file_three], @file.links
    assert_equal [@file, file_two, file_three], file_two.links
    assert_equal [@file, file_two, file_three], file_three.links
  end

  def test_links_share_same_content
    other_file = FakeFile.new

    @file.link other_file

    @file.content = "foobar"

    assert_equal "foobar", other_file.content
  end

  def test_clone_creates_new_inode
    clone = @file.clone
    assert !clone.inode.equal?(@file.inode)
  end

  def test_cloning_does_not_use_same_content_object
    clone = @file.clone

    clone.content = "foo"
    @file.content = "bar"

    assert_equal "foo", clone.content
    assert_equal "bar", @file.content
  end

  def test_raises_an_error_with_the_correct_path
    path = "/some/non/existing/file"
    begin
      FakeFS::File.new path
      msg = nil
    rescue Errno::ENOENT => e
      msg = e.message
    end
    assert_equal "No such file or directory - #{path}", msg
  end
end
