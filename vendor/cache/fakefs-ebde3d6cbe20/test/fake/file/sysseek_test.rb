require "test_helper"

class FileSysSeek < Test::Unit::TestCase
  def setup
    FakeFS.activate!
    FakeFS::FileSystem.clear
  end

  def teardown
    FakeFS.deactivate!
  end

  def test_should_seek_to_position
    file = File.open("foo", "w") do |f|
      f << "0123456789"
    end

    File.open("foo", "r") do |f|
      f.sysseek(3)
      assert_equal 3, f.pos

      f.sysseek(0)
      assert_equal 0, f.pos
    end
  end

  def test_seek_returns_offset_into_file
    File.open("foo", "w") do |f|
      # 66 chars long
      str = "0123456789" +
            "0123456789" +
            "0123456789" +
            "0123456789" +
            "0123456789" +
            "0123456789" +
            "012345"

      f << str
    end

    f = File.open("foo")
    assert_equal 53, f.sysseek(-13, IO::SEEK_END)
  end
end