require "test_helper"

class FakeFSSafeTest < Test::Unit::TestCase
  def setup
    FakeFS.deactivate!
  end

  def teardown
    FakeFS.activate!
  end

  def test_FakeFS_activated_is_accurate
    2.times do
      FakeFS.deactivate!
      assert !FakeFS.activated?
      FakeFS.activate!
      assert FakeFS.activated?
    end
  end

  def test_FakeFS_method_does_not_intrude_on_global_namespace
    path = 'file.txt'

    FakeFS do
      File.open(path, 'w') { |f| f.write "Yatta!" }
      assert File.exists?(path)
    end

    assert ! File.exists?(path)
  end

  def test_FakeFS_method_returns_value_of_yield
    result = FakeFS do
      File.open('myfile.txt', 'w') { |f| f.write "Yatta!" }
      File.read('myfile.txt')
    end

    assert_equal result, "Yatta!"
  end

  def test_FakeFS_method_does_not_deactivate_FakeFS_if_already_activated
    FakeFS.activate!
    FakeFS {}

    assert FakeFS.activated?
  end

  def test_FakeFS_method_can_be_nested
    FakeFS do
      assert FakeFS.activated?
      FakeFS do
        assert FakeFS.activated?
      end
      assert FakeFS.activated?
    end

    assert !FakeFS.activated?
  end

  def test_FakeFS_method_can_be_nested_with_FakeFS_without
    FakeFS do
      assert FakeFS.activated?
      FakeFS.without do
        assert !FakeFS.activated?
      end
      assert FakeFS.activated?
    end

    assert !FakeFS.activated?
  end

  def test_FakeFS_method_deactivates_FakeFS_when_block_raises_exception
    begin
      FakeFS do
        raise 'boom!'
      end
    rescue
    end

    assert !FakeFS.activated?
  end
end
