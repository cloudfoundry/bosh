require "test_helper"

class FakeFSTest < Test::Unit::TestCase
  include FakeFS

  def setup
    FakeFS.activate!
    FileSystem.clear
  end

  def teardown
    FakeFS.deactivate!
  end

  def test_can_be_initialized_empty
    fs = FileSystem
    assert_equal 0, fs.files.size
  end

  def xtest_can_be_initialized_with_an_existing_directory
    fs = FileSystem
    fs.clone(File.expand_path(File.dirname(__FILE__))).inspect
    assert_equal 1, fs.files.size
  end

  def test_can_create_directories_with_file_utils_mkdir_p
    FileUtils.mkdir_p("/path/to/dir")
    assert_kind_of FakeDir, FileSystem.fs['path']['to']['dir']
  end

  def test_can_cd_to_directory_with_block
    FileUtils.mkdir_p("/path/to/dir")
    new_path = nil
    FileUtils.cd("/path/to") do
      new_path = Dir.getwd
    end

    assert_equal new_path, "/path/to"
  end

  def test_can_create_a_list_of_directories_with_file_utils_mkdir_p
    FileUtils.mkdir_p(["/path/to/dir1", "/path/to/dir2"])
    assert_kind_of FakeDir, FileSystem.fs['path']['to']['dir1']
    assert_kind_of FakeDir, FileSystem.fs['path']['to']['dir2']
  end

  def test_can_create_directories_with_options
    FileUtils.mkdir_p("/path/to/dir", :mode => 0755)
    assert_kind_of FakeDir, FileSystem.fs['path']['to']['dir']
  end

  def test_can_create_directories_with_file_utils_mkdir
    FileUtils.mkdir_p("/path/to/dir")
    FileUtils.mkdir("/path/to/dir/subdir")
    assert_kind_of FakeDir, FileSystem.fs['path']['to']['dir']['subdir']
  end

  def test_can_create_a_list_of_directories_with_file_utils_mkdir
    FileUtils.mkdir_p("/path/to/dir")
    FileUtils.mkdir(["/path/to/dir/subdir1", "/path/to/dir/subdir2"])
    assert_kind_of FakeDir, FileSystem.fs['path']['to']['dir']['subdir1']
    assert_kind_of FakeDir, FileSystem.fs['path']['to']['dir']['subdir2']
  end

  def test_raises_error_when_creating_a_new_dir_with_mkdir_in_non_existent_path
    assert_raises Errno::ENOENT do
      FileUtils.mkdir("/this/path/does/not/exists/newdir")
    end
  end

  def test_raises_error_when_creating_a_new_dir_over_existing_file
    File.open("file", "w") {|f| f << "This is a file, not a directory." }

    assert_raise Errno::EEXIST do
      FileUtils.mkdir_p("file/subdir")
    end

    FileUtils.mkdir("dir")
    File.open("dir/subfile", "w") {|f| f << "This is a file inside a directory." }

    assert_raise Errno::EEXIST do
      FileUtils.mkdir_p("dir/subfile/subdir")
    end
  end

  def test_can_create_directories_with_mkpath
    FileUtils.mkpath("/path/to/dir")
    assert_kind_of FakeDir, FileSystem.fs['path']['to']['dir']
  end

  def test_can_create_directories_with_mkpath_and_options
    FileUtils.mkpath("/path/to/dir", :mode => 0755)
    assert_kind_of FakeDir, FileSystem.fs['path']['to']['dir']
  end

  def test_can_create_directories_with_mkdirs
    FileUtils.makedirs("/path/to/dir")
    assert_kind_of FakeDir, FileSystem.fs['path']['to']['dir']
  end

  def test_can_create_directories_with_mkdirs_and_options
    FileUtils.makedirs("/path/to/dir", :mode => 0755)
    assert_kind_of FakeDir, FileSystem.fs['path']['to']['dir']
  end

  def test_unlink_errors_on_file_not_found
    assert_raise Errno::ENOENT do
      FileUtils.rm("/foo")
    end
  end

  def test_unlink_doesnt_error_on_file_not_found_when_forced
    assert_nothing_raised do
      FileUtils.rm("/foo", :force => true)
    end
  end

  def test_can_delete_directories
    FileUtils.mkdir_p("/path/to/dir")
    FileUtils.rmdir("/path/to/dir")
    assert File.exists?("/path/to/")
    assert File.exists?("/path/to/dir") == false
  end

  def test_can_delete_multiple_files
    FileUtils.touch(["foo", "bar"])
    FileUtils.rm(["foo", "bar"])
    assert File.exists?("foo") == false
    assert File.exists?("bar") == false
  end

  def test_aliases_exist
    assert File.respond_to?(:unlink)
    assert FileUtils.respond_to?(:rm_f)
    assert FileUtils.respond_to?(:rm_r)
    assert FileUtils.respond_to?(:rm)
    assert FileUtils.respond_to?(:rm_rf)
    assert FileUtils.respond_to?(:symlink)
    assert FileUtils.respond_to?(:move)
    assert FileUtils.respond_to?(:copy)
    assert FileUtils.respond_to?(:remove)
    assert FileUtils.respond_to?(:rmtree)
    assert FileUtils.respond_to?(:safe_unlink)
    assert FileUtils.respond_to?(:remove_entry_secure)
    assert FileUtils.respond_to?(:cmp)
    assert FileUtils.respond_to?(:identical?)
  end

  def test_knows_directories_exist
    FileUtils.mkdir_p(path = "/path/to/dir")
    assert File.exists?(path)
  end

  def test_knows_directories_are_directories
    FileUtils.mkdir_p(path = "/path/to/dir")
    assert File.directory?(path)
  end

  def test_knows_directories_are_directories_with_periods
    FileUtils.mkdir_p(period_path = "/path/to/periodfiles/one.one")
    FileUtils.mkdir("/path/to/periodfiles/one-one")

    assert File.directory?(period_path)
  end

  def test_knows_symlink_directories_are_directories
    FileUtils.mkdir_p(path = "/path/to/dir")
    FileUtils.ln_s path, sympath = '/sympath'
    assert File.directory?(sympath)
  end

  def test_knows_non_existent_directories_arent_directories
    path = 'does/not/exist/'
    assert_equal RealFile.directory?(path), File.directory?(path)
  end

  def test_doesnt_overwrite_existing_directories
    FileUtils.mkdir_p(path = "/path/to/dir")
    assert File.exists?(path)
    FileUtils.mkdir_p("/path/to")
    assert File.exists?(path)
    assert_raises Errno::EEXIST do
      FileUtils.mkdir("/path/to")
    end
    assert File.exists?(path)
  end

  def test_file_utils_mkdir_takes_options
    FileUtils.mkdir("/foo", :some => :option)
    assert File.exists?("/foo")
  end

  def test_symlink_with_missing_refferent_does_not_exist
    File.symlink('/foo', '/bar')
    assert !File.exists?('/bar')
  end

  def test_can_create_symlinks
    FileUtils.mkdir_p(target = "/path/to/target")
    FileUtils.ln_s(target, "/path/to/link")
    assert_kind_of FakeSymlink, FileSystem.fs['path']['to']['link']

    assert_raises(Errno::EEXIST) do
      FileUtils.ln_s(target, '/path/to/link')
    end
  end

  def test_can_force_creation_of_symlinks
    FileUtils.mkdir_p(target = "/path/to/first/target")
    FileUtils.ln_s(target, "/path/to/link")
    assert_kind_of FakeSymlink, FileSystem.fs['path']['to']['link']
    FileUtils.ln_s(target, '/path/to/link', :force => true)
  end

  def test_create_symlink_using_ln_sf
    FileUtils.mkdir_p(target = "/path/to/first/target")
    FileUtils.ln_s(target, "/path/to/link")
    assert_kind_of FakeSymlink, FileSystem.fs['path']['to']['link']
    FileUtils.ln_sf(target, '/path/to/link')
  end

  def test_can_follow_symlinks
    FileUtils.mkdir_p(target = "/path/to/target")
    FileUtils.ln_s(target, link = "/path/to/symlink")
    assert_equal target, File.readlink(link)
  end

  def test_symlinks_in_different_directories
    FileUtils.mkdir_p("/path/to/bar")
    FileUtils.mkdir_p(target = "/path/to/foo/target")

    FileUtils.ln_s(target, link = "/path/to/bar/symlink")
    assert_equal target, File.readlink(link)
  end

  def test_symlink_with_relative_path_exists
    FileUtils.touch("/file")
    FileUtils.mkdir_p("/a/b")
    FileUtils.ln_s("../../file", link = "/a/b/symlink")
    assert File.exist?('/a/b/symlink')
  end

  def test_symlink_with_relative_path_and_nonexistant_file_does_not_exist
    FileUtils.touch("/file")
    FileUtils.mkdir_p("/a/b")
    FileUtils.ln_s("../../file_foo", link = "/a/b/symlink")
    assert !File.exist?('/a/b/symlink')
  end

  def test_symlink_with_relative_path_has_correct_target
    FileUtils.touch("/file")
    FileUtils.mkdir_p("/a/b")
    FileUtils.ln_s("../../file", link = "/a/b/symlink")
    assert_equal "../../file", File.readlink(link)
  end

  def test_symlinks_to_symlinks
    FileUtils.mkdir_p(target = "/path/to/foo/target")
    FileUtils.mkdir_p("/path/to/bar")
    FileUtils.mkdir_p("/path/to/bar2")

    FileUtils.ln_s(target, link1 = "/path/to/bar/symlink")
    FileUtils.ln_s(link1, link2 = "/path/to/bar2/symlink")
    assert_equal link1, File.readlink(link2)
  end

  def test_symlink_to_symlinks_should_raise_error_if_dir_doesnt_exist
    FileUtils.mkdir_p(target = "/path/to/foo/target")

    assert !Dir.exists?("/path/to/bar")

    assert_raise Errno::ENOENT do
      FileUtils.ln_s(target, "/path/to/bar/symlink")
    end
  end

  def test_knows_symlinks_are_symlinks
    FileUtils.mkdir_p(target = "/path/to/target")
    FileUtils.ln_s(target, link = "/path/to/symlink")
    assert File.symlink?(link)
  end

  def test_can_create_files_in_current_dir
    path = 'file.txt'
    File.open(path, 'w') do |f|
      f.write "Yatta!"
    end

    assert File.exists?(path)
    assert File.readable?(path)
    assert File.writable?(path)
  end

  def test_can_create_files_in_existing_dir
    FileUtils.mkdir_p "/path/to"
    path = "/path/to/file.txt"

    File.open(path, 'w') do |f|
      f.write "Yatta!"
    end

    assert File.exists?(path)
    assert File.readable?(path)
    assert File.writable?(path)
  end

  def test_raises_ENOENT_trying_to_create_files_in_nonexistent_dir
    path = "/path/to/file.txt"

    assert_raises(Errno::ENOENT) {
      File.open(path, 'w') do |f|
        f.write "Yatta!"
      end
    }
  end

  def test_raises_ENOENT_trying_to_create_files_in_relative_nonexistent_dir
    FileUtils.mkdir_p "/some/path"

    Dir.chdir("/some/path") {
      assert_raises(Errno::ENOENT) {
        File.open("../foo") {|f| f.write "moo" }
      }
    }
  end

  def test_raises_ENOENT_trying_to_create_files_in_obscured_nonexistent_dir
    FileUtils.mkdir_p "/some/path"

    assert_raises(Errno::ENOENT) {
      File.open("/some/path/../foo") {|f| f.write "moo" }
    }
  end

  def test_raises_ENOENT_trying_to_create_tilde_referenced_nonexistent_dir
    path = "~/fakefs_test_#{$$}_0000"

    while File.exist? path
      path = path.succ
    end

    assert_raises(Errno::ENOENT) {
      File.open("#{path}/foo") {|f| f.write "moo" }
    }
  end

  def test_raises_EISDIR_if_trying_to_open_existing_directory_name
    path = "/path/to"

    FileUtils.mkdir_p path

    assert_raises(Errno::EISDIR) {
      File.open(path, 'w') do |f|
        f.write "Yatta!"
      end
    }
  end

  def test_can_create_files_with_bitmasks
    FileUtils.mkdir_p("/path/to")

    path = '/path/to/file.txt'
    File.open(path, File::RDWR | File::CREAT) do |f|
      f.write "Yatta!"
    end

    assert File.exists?(path)
    assert File.readable?(path)
    assert File.writable?(path)
  end

  def test_file_opens_in_read_only_mode
    File.open("foo", "w") { |f| f << "foo" }

    f = File.open("foo")

    assert_raises(IOError) do
      f << "bar"
    end
  end

  def test_file_opens_in_read_only_mode_with_bitmasks
    File.open("foo", "w") { |f| f << "foo" }

    f = File.open("foo", File::RDONLY)

    assert_raises(IOError) do
      f << "bar"
    end
  end

  def test_file_opens_in_invalid_mode
    FileUtils.touch("foo")

    assert_raises(ArgumentError) do
      File.open("foo", "an_illegal_mode")
    end
  end

  def test_raises_error_when_cannot_find_file_in_read_mode
    assert_raises(Errno::ENOENT) do
      File.open("does_not_exist", "r")
    end
  end

  def test_raises_error_when_cannot_find_file_in_read_write_mode
    assert_raises(Errno::ENOENT) do
      File.open("does_not_exist", "r+")
    end
  end

  def test_creates_files_in_write_only_mode
    File.open("foo", "w")
    assert File.exists?("foo")
  end

  def test_creates_files_in_write_only_mode_with_bitmasks
    File.open("foo", File::WRONLY | File::CREAT)
    assert File.exists?("foo")
  end

  def test_raises_in_write_only_mode_without_create_bitmask
    assert_raises(Errno::ENOENT) do
      File.open("foo", File::WRONLY)
    end
  end

  def test_creates_files_in_read_write_truncate_mode
    File.open("foo", "w+")
    assert File.exists?("foo")
  end

  def test_creates_files_in_append_write_only
    File.open("foo", "a")
    assert File.exists?("foo")
  end

  def test_creates_files_in_append_read_write
    File.open("foo", "a+")
    assert File.exists?("foo")
  end

  def test_file_in_write_only_raises_error_when_reading
    FileUtils.touch("foo")

    f = File.open("foo", "w")

    assert_raises(IOError) do
      f.read
    end
  end

  def test_file_in_write_mode_truncates_existing_file
    File.open("foo", "w") { |f| f << "contents" }

    f = File.open("foo", "w")

    assert_equal "", File.read("foo")
  end

  def test_file_in_read_write_truncation_mode_truncates_file
    File.open("foo", "w") { |f| f << "foo" }

    f = File.open("foo", "w+")

    assert_equal "", File.read("foo")
  end

  def test_file_in_append_write_only_raises_error_when_reading
    FileUtils.touch("foo")

    f = File.open("foo", "a")

    assert_raises(IOError) do
      f.read
    end
  end

  def test_can_read_files_once_written
    path = 'file.txt'
    File.open(path, 'w') do |f|
      f.write "Yatta!"
    end

    assert_equal "Yatta!", File.read(path)
  end

  def test_file_read_accepts_hashes
    path = 'file.txt'
    File.open(path, 'w') do |f|
      f.write 'Yatta!'
    end

    assert_nothing_raised { File.read(path, :mode => 'r:UTF-8:-') }
  end

  def test_can_write_to_files
    path = 'file.txt'
    File.open(path, 'w') do |f|
      f << 'Yada Yada'
    end
    assert_equal 'Yada Yada', File.read(path)
  end

  def test_raises_error_when_opening_with_binary_mode_only
    assert_raise ArgumentError do
      File.open("/foo", "b")
    end
  end

  def test_can_open_file_in_binary_mode
    File.open("foo", "wb") { |x| x << "a" }
    assert_equal "a", File.read("foo")
  end

  def test_can_chunk_io_when_reading
    FileUtils.mkdir_p "/path/to"
    path = '/path/to/file.txt'
    File.open(path, 'w') do |f|
      f << 'Yada Yada'
    end
    file = File.new(path, 'r')
    assert_equal 'Yada', file.read(4)
    assert_equal ' Yada', file.read(5)
    assert_equal '', file.read
    file.rewind
    assert_equal 'Yada Yada', file.read
  end

  def test_can_get_size_of_files
    path = 'file.txt'
    File.open(path, 'w') do |f|
      f << 'Yada Yada'
    end
    assert_equal 9, File.size(path)
  end

  def test_can_get_correct_size_for_files_with_multibyte_characters
    path = 'file.txt'
    File.open(path, 'wb') do |f|
      f << "Y\xC3\xA1da" # Yáda
    end
    assert_equal 5, File.size(path)
  end

  def test_can_check_if_file_has_size?
    path = 'file.txt'
    File.open(path, 'w') do |f|
      f << 'Yada Yada'
    end
    assert_equal 9, File.size?(path)
    assert_nil File.size?("other.txt")
  end

  def test_can_check_size_of_empty_file
    path = 'file.txt'
    File.open(path, 'w') do |f|
      f << ''
    end
    assert_nil File.size?("file.txt")
  end

  def test_zero_on_empty_file
    path = 'file.txt'
    File.open(path, 'w') do |f|
      f << ''
    end
    assert_equal true, File.zero?(path)
  end

  def test_zero_on_non_empty_file
    path = 'file.txt'
    File.open(path, 'w') do |f|
      f << 'Not empty'
    end
    assert_equal false, File.zero?(path)
  end

  def test_zero_on_non_existent_file
    path = 'file_does_not_exist.txt'
    assert_equal false, File.zero?(path)
  end

  def test_raises_error_on_mtime_if_file_does_not_exist
    assert_raise Errno::ENOENT do
      File.mtime('/path/to/file.txt')
    end
  end

  if RUBY_VERSION >= "1.9"
    def test_can_set_mtime_on_new_file_touch_with_param
      time = Time.new(2002, 10, 31, 2, 2, 2, "+02:00")
      FileUtils.touch("foo.txt", :mtime => time)

      assert_equal File.mtime("foo.txt"), time
    end

    def test_can_set_mtime_on_existing_file_touch_with_param
      FileUtils.touch("foo.txt")

      time = Time.new(2002, 10, 31, 2, 2, 2, "+02:00")
      FileUtils.touch("foo.txt", :mtime => time)

      assert_equal File.mtime("foo.txt"), time
    end
  end

  def test_can_return_mtime_on_existing_file
    path = 'file.txt'
    File.open(path, 'w') do |f|
      f << ''
    end
    assert File.mtime('file.txt').is_a?(Time)
  end

  def test_raises_error_on_ctime_if_file_does_not_exist
    assert_raise Errno::ENOENT do
      File.ctime('file.txt')
    end
  end

  def test_can_return_ctime_on_existing_file
    File.open("foo", "w") { |f| f << "some content" }
    assert File.ctime('foo').is_a?(Time)
  end

  def test_raises_error_on_atime_if_file_does_not_exist
    assert_raise Errno::ENOENT do
      File.atime('file.txt')
    end
  end

  def test_can_return_atime_on_existing_file
    File.open("foo", "w") { |f| f << "some content" }
    assert File.atime('foo').is_a?(Time)
  end

  def test_ctime_mtime_and_atime_are_equal_for_new_files
    FileUtils.touch('foo')

    ctime = File.ctime("foo")
    mtime = File.mtime("foo")
    atime = File.atime("foo")
    assert ctime.is_a?(Time)
    assert mtime.is_a?(Time)
    assert atime.is_a?(Time)
    assert_equal ctime, mtime
    assert_equal ctime, atime

    File.open("foo", "r") do |f|
      assert_equal ctime, f.ctime
      assert_equal mtime, f.mtime
      assert_equal atime, f.atime
    end
  end

  def test_ctime_mtime_and_atime_are_equal_for_new_directories
    FileUtils.mkdir_p("foo")
    ctime = File.ctime("foo")
    mtime = File.mtime("foo")
    atime = File.atime("foo")
    assert ctime.is_a?(Time)
    assert mtime.is_a?(Time)
    assert atime.is_a?(Time)
    assert_equal ctime, mtime
    assert_equal ctime, atime
  end

  def test_file_ctime_is_equal_to_file_stat_ctime
    File.open("foo", "w") { |f| f << "some content" }
    assert_equal File.stat("foo").ctime, File.ctime("foo")
  end

  def test_directory_ctime_is_equal_to_directory_stat_ctime
    FileUtils.mkdir_p("foo")
    assert_equal File.stat("foo").ctime, File.ctime("foo")
  end

  def test_file_mtime_is_equal_to_file_stat_mtime
    File.open("foo", "w") { |f| f << "some content" }
    assert_equal File.stat("foo").mtime, File.mtime("foo")
  end

  def test_directory_mtime_is_equal_to_directory_stat_mtime
    FileUtils.mkdir_p("foo")
    assert_equal File.stat("foo").mtime, File.mtime("foo")
  end

  def test_file_atime_is_equal_to_file_stat_atime
    File.open("foo", "w") { |f| f << "some content" }
    assert_equal File.stat("foo").atime, File.atime("foo")
  end

  def test_directory_atime_is_equal_to_directory_stat_atime
    FileUtils.mkdir_p("foo")
    assert_equal File.stat("foo").atime, File.atime("foo")
  end

  def test_utime_raises_error_if_path_does_not_exist
    assert_raise Errno::ENOENT do
      File.utime(Time.now, Time.now, '/path/to/file.txt')
    end
  end

  def test_can_call_utime_on_an_existing_file
    time = Time.now - 300 # Not now
    path = 'file.txt'
    File.open(path, 'w') do |f|
      f << ''
    end
    File.utime(time, time, path)
    assert_equal time, File.mtime('file.txt')
    assert_equal time, File.atime('file.txt')
  end

  def test_utime_returns_number_of_paths
    path1, path2 = 'file.txt', 'another_file.txt'
    [path1, path2].each do |path|
      File.open(path, 'w') do |f|
        f << ''
      end
    end
    assert_equal 2, File.utime(Time.now, Time.now, path1, path2)
  end

  def test_file_a_time_updated_when_file_is_read
    old_atime = Time.now - 300

    path = "file.txt"
    File.open(path, "w") do |f|
      f << "Hello"
    end

    File.utime(old_atime, File.mtime(path), path)

    assert_equal File.atime(path), old_atime
    File.read(path)
    assert File.atime(path) != old_atime
  end

  def test_can_read_with_File_readlines
    path = 'file.txt'
    File.open(path, 'w') do |f|
      f.puts "Yatta!", "Gatta!"
      f.puts ["woot","toot"]
    end

    assert_equal ["Yatta!\n", "Gatta!\n", "woot\n", "toot\n"], File.readlines(path)
  end

  def test_can_read_with_File_readlines_and_only_empty_lines
    path = 'file.txt'
    File.open(path, 'w') do |f|
      f.write "\n"
    end

    assert_equal ["\n"], File.readlines(path)
  end

  def test_can_read_with_File_readlines_and_new_lines
    path = 'file.txt'
    File.open(path, 'w') do |f|
      f.write "this\nis\na\ntest\n"
    end

    assert_equal ["this\n", "is\n", "a\n", "test\n"], File.readlines(path)
  end

  def test_File_close_disallows_further_access
    path = 'file.txt'
    file = File.open(path, 'w')
    file.write 'Yada'
    file.close
    assert_raise IOError do
      file.read
    end
  end

  def test_File_close_disallows_further_writes
    path = 'file.txt'
    file = File.open(path, 'w')
    file.write 'Yada'
    file.close
    assert_raise IOError do
      file << "foo"
    end
  end

  def test_can_read_from_file_objects
    path = 'file.txt'
    File.open(path, 'w') do |f|
      f.write "Yatta!"
    end

    assert_equal "Yatta!", File.new(path).read
  end

  if RUBY_VERSION >= "1.9"
    def test_file_object_has_default_external_encoding
      Encoding.default_external = "UTF-8"
      path = 'file.txt'
      File.open(path, 'w'){|f| f.write 'Yatta!' }
      assert_equal "UTF-8", File.new(path).read.encoding.name
    end
  end

  def test_file_object_initialization_with_mode_in_hash_parameter
    assert_nothing_raised do
      File.open("file.txt", {:mode => "w"}){ |f| f.write 'Yatta!' }
    end
  end

  def test_file_read_errors_appropriately
    assert_raise Errno::ENOENT do
      File.read('anything')
    end
  end

  def test_file_read_errors_on_directory
    FileUtils.mkdir_p("a_directory")

    assert_raise Errno::EISDIR do
      File.read("a_directory")
    end
  end

  def test_knows_files_are_files
    path = 'file.txt'
    File.open(path, 'w') do |f|
      f.write "Yatta!"
    end

    assert File.file?(path)
  end

  def test_File_io_returns_self
    f = File.open("foo", "w")
    assert_equal f, f.to_io
  end

  def test_File_to_i_is_alias_for_filno
    f = File.open("foo", "w")
    assert_equal f.method(:to_i), f.method(:fileno)
  end

  def test_knows_symlink_files_are_files
    path = 'file.txt'
    File.open(path, 'w') do |f|
      f.write "Yatta!"
    end
    FileUtils.ln_s path, sympath='/sympath'

    assert File.file?(sympath)
  end

  def test_knows_non_existent_files_arent_files
    assert_equal RealFile.file?('does/not/exist.txt'), File.file?('does/not/exist.txt')
  end

  def test_executable_returns_false_for_non_existent_files
    assert !File.executable?('/does/not/exist')
  end

  def test_can_chown_files
    good = 'file.txt'
    bad = 'nofile.txt'
    File.open(good,'w') { |f| f.write "foo" }
    username = Etc.getpwuid(Process.uid).name
    groupname = Etc.getgrgid(Process.gid).name

    out = FileUtils.chown(1337, 1338, good, :verbose => true)
    assert_equal [good], out
    assert_equal File.stat(good).uid, 1337
    assert_equal File.stat(good).gid, 1338
    assert_raises(Errno::ENOENT) do
      FileUtils.chown(username, groupname, bad, :verbose => true)
    end

    assert_equal [good], FileUtils.chown(username, groupname, good)
    assert_equal File.stat(good).uid, Process.uid
    assert_equal File.stat(good).gid, Process.gid
    assert_raises(Errno::ENOENT) do
      FileUtils.chown(username, groupname, bad)
    end

    assert_equal [good], FileUtils.chown(username, groupname, [good])
    assert_equal File.stat(good).uid, Process.uid
    assert_equal File.stat(good).gid, Process.gid
    assert_raises(Errno::ENOENT) do
      FileUtils.chown(username, groupname, [good, bad])
    end

    # FileUtils.chown with nil user and nil group should not change anything
    FileUtils.chown(username, groupname, good)
    assert_equal File.stat(good).uid, Process.uid
    assert_equal File.stat(good).gid, Process.gid
    assert_equal [good], FileUtils.chown(nil, nil, [good])
    assert_equal File.stat(good).uid, Process.uid
    assert_equal File.stat(good).gid, Process.gid
    assert_raises(Errno::ENOENT) do
      FileUtils.chown(nil, nil, [good, bad])
    end
  end

  def test_can_chown_R_files
    username = Etc.getpwuid(Process.uid).name
    groupname = Etc.getgrgid(Process.gid).name
    FileUtils.mkdir_p '/path/'
    File.open('/path/foo', 'w') { |f| f.write 'foo' }
    File.open('/path/foobar', 'w') { |f| f.write 'foo' }
    assert_equal ['/path'], FileUtils.chown_R(username, groupname, '/path')
    %w(/path /path/foo /path/foobar).each do |f|
      assert_equal File.stat(f).uid, Process.uid
      assert_equal File.stat(f).gid, Process.gid
    end
  end

  def test_can_chmod_files
    good = "file.txt"
    bad = "nofile.txt"
    FileUtils.touch(good)

    assert_equal [good], FileUtils.chmod(0600, good, :verbose => true)
    assert_equal File.stat(good).mode, 0100600
    assert_equal File.executable?(good), false
    assert_raises(Errno::ENOENT) do
      FileUtils.chmod(0600, bad)
    end

    assert_equal [good], FileUtils.chmod(0666, good)
    assert_equal File.stat(good).mode, 0100666
    assert_raises(Errno::ENOENT) do
      FileUtils.chmod(0666, bad)
    end

    assert_equal [good], FileUtils.chmod(0644, [good])
    assert_equal File.stat(good).mode, 0100644
    assert_raises(Errno::ENOENT) do
      FileUtils.chmod(0644, bad)
    end

    assert_equal [good], FileUtils.chmod(0744, [good])
    assert_equal File.executable?(good), true

    # This behaviour is unimplemented, the spec below is only to show that it
    # is a deliberate YAGNI omission.
    assert_equal [good], FileUtils.chmod(0477, [good])
    assert_equal File.executable?(good), false
  end

  def test_can_chmod_R_files
    FileUtils.mkdir_p "/path/sub"
    FileUtils.touch "/path/file1"
    FileUtils.touch "/path/sub/file2"

    assert_equal ["/path"], FileUtils.chmod_R(0600, "/path")
    assert_equal File.stat("/path").mode, 0100600
    assert_equal File.stat("/path/file1").mode, 0100600
    assert_equal File.stat("/path/sub").mode, 0100600
    assert_equal File.stat("/path/sub/file2").mode, 0100600

    FileUtils.mkdir_p "/path2"
    FileUtils.touch "/path2/hej"
    assert_equal ["/path2"], FileUtils.chmod_R(0600, "/path2")
  end

  def test_dir_globs_paths
    FileUtils.mkdir_p '/path'
    File.open('/path/foo', 'w') { |f| f.write 'foo' }
    File.open('/path/foobar', 'w') { |f| f.write 'foo' }

    FileUtils.mkdir_p '/path/bar'
    File.open('/path/bar/baz', 'w') { |f| f.write 'foo' }

    FileUtils.cp_r '/path/bar', '/path/bar2'

    assert_equal  ['/path'], Dir['/path']
    assert_equal %w( /path/bar /path/bar2 /path/foo /path/foobar ), Dir['/path/*']

    assert_equal ['/path/bar/baz'], Dir['/path/bar/*']
    assert_equal ['/path/foo'], Dir['/path/foo']

    assert_equal ['/path'], Dir['/path*']
    assert_equal ['/path/foo', '/path/foobar'], Dir['/p*h/foo*']
    assert_equal ['/path/foo', '/path/foobar'], Dir['/p??h/foo*']

    assert_equal ['/path/bar', '/path/bar/baz', '/path/bar2', '/path/bar2/baz', '/path/foo', '/path/foobar'], Dir['/path/**/*']
    assert_equal ['/path', '/path/bar', '/path/bar/baz', '/path/bar2', '/path/bar2/baz', '/path/foo', '/path/foobar'], Dir['/**/*']

    assert_equal ['/path/bar', '/path/bar/baz', '/path/bar2', '/path/bar2/baz', '/path/foo', '/path/foobar'], Dir['/path/**/*']
    assert_equal ['/path/bar/baz'], Dir['/path/bar/**/*']

    assert_equal ['/path/bar/baz', '/path/bar2/baz'], Dir['/path/bar/**/*', '/path/bar2/**/*']
    assert_equal ['/path/bar/baz', '/path/bar2/baz', '/path/bar/baz'], Dir['/path/ba*/**/*', '/path/bar/**/*']

    FileUtils.cp_r '/path', '/otherpath'

    assert_equal %w( /otherpath/foo /otherpath/foobar /path/foo /path/foobar ), Dir['/*/foo*']

    assert_equal ['/path/bar', '/path/foo'], Dir['/path/{foo,bar}']

    assert_equal ['/path/bar', '/path/bar2'], Dir['/path/bar{2,}']

    Dir.chdir '/path' do
      assert_equal ['foo'], Dir['foo']
    end
  end

  def test_file_utils_cp_allows_verbose_option
    File.open('foo', 'w') {|f| f << 'TEST' }
    assert_equal "cp foo bar\n", capture_stderr { FileUtils.cp 'foo', 'bar', :verbose => true }
  end

  def test_file_utils_cp_allows_noop_option
    File.open('foo', 'w') {|f| f << 'TEST' }
    FileUtils.cp 'foo', 'bar', :noop => true
    assert !File.exist?('bar'), 'does not actually copy'
  end

  def test_file_utils_cp_raises_on_invalid_option
    assert_raises ArgumentError do
      FileUtils.cp 'foo', 'bar', :whatisthis => "I don't know"
    end
  end

  def test_file_utils_cp_r_allows_verbose_option
    FileUtils.touch "/foo"
    assert_equal "cp -r /foo /bar\n", capture_stderr { FileUtils.cp_r '/foo', '/bar', :verbose => true }
  end

  def test_file_utils_cp_r_allows_noop_option
    FileUtils.touch "/foo"
    FileUtils.cp_r '/foo', '/bar', :noop => true
    assert !File.exist?('/bar'), 'does not actually copy'
  end

  def test_dir_glob_handles_root
    FileUtils.mkdir_p '/path'

    # this fails. the root dir should be named '/' but it is '.'
    assert_equal ['/'], Dir['/']
  end

  def test_dir_glob_takes_optional_flags
    FileUtils.touch "/foo"
    assert_equal Dir.glob("/*", 0), ["/foo"]
  end

  def test_dir_glob_handles_recursive_globs
    FileUtils.mkdir_p "/one/two/three"
    File.open('/one/two/three/four.rb', 'w')
    File.open('/one/five.rb', 'w')
    assert_equal ['/one/five.rb', '/one/two/three/four.rb'], Dir['/one/**/*.rb']
    assert_equal ['/one/two'], Dir['/one/**/two']
    assert_equal ['/one/two/three'], Dir['/one/**/three']
  end

  def test_dir_recursive_glob_ending_in_wildcards_returns_both_files_and_dirs
    FileUtils.mkdir_p "/one/two/three"
    File.open('/one/two/three/four.rb', 'w')
    File.open('/one/five.rb', 'w')
    assert_equal ['/one/five.rb', '/one/two', '/one/two/three', '/one/two/three/four.rb'], Dir['/one/**/*']
    assert_equal ['/one/five.rb', '/one/two'], Dir['/one/**']
  end

  def test_dir_glob_with_block
    FileUtils.touch('foo')
    FileUtils.touch('bar')

    yielded = []
    Dir.glob('*') { |file| yielded << file }

    assert_equal 2, yielded.size
  end

  def test_copy_with_subdirectory
    FileUtils.mkdir_p "/one/two/three/"
    FileUtils.mkdir_p "/onebis/two/three/"
    FileUtils.touch "/one/two/three/foo"
    Dir.glob("/one/two/three/*") do |hook|
      FileUtils.cp(hook, "/onebis/two/three/")
    end
    assert_equal ['/onebis/two/three/foo'], Dir['/onebis/two/three/*']
  end

  if RUBY_VERSION >= "1.9"
    def test_dir_home
      assert_equal RealDir.home, Dir.home
    end
  end

  def test_should_report_pos_as_0_when_opening
    File.open("foo", "w") do |f|
      f << "foobar"
      f.rewind

      assert_equal 0, f.pos
    end
  end

  def test_should_report_pos_as_1_when_seeking_one_char
    File.open("foo", "w") do |f|
      f << "foobar"

      f.rewind
      f.seek(1)

      assert_equal 1, f.pos
    end
  end

  def test_should_set_pos
    File.open("foo", "w") do |f|
      f << "foo"
    end

    fp = File.open("foo", "r")
    fp.pos = 1

    assert_equal 1, fp.pos
  end

  def test_should_set_pos_with_tell_method
    File.open("foo", "w") do |f|
      f << "foo"
    end

    fp = File.open("foo", "r")
    fp.tell = 1

    assert_equal 1, fp.pos
  end

  OMITTED_FILE_METHODS = [
    # omit methods from io/console
    :raw, :raw!, :cooked, :cooked!,
    :echo?, :echo=, :noecho,
    :winsize, :winsize=,
    :getch,
    :iflush, :ioflush, :oflush
  ]

  def test_every_method_in_file_is_in_fake_fs_file
    (RealFile.instance_methods - OMITTED_FILE_METHODS).each do |method_name|
      assert File.instance_methods.include?(method_name), "#{method_name} method is not available in File :("
    end
  end

  def test_file_should_not_respond_to_string_io_unique_methods
    uniq_string_io_methods = StringIO.instance_methods - RealFile.instance_methods
    uniq_string_io_methods.each do |method_name|
      assert !File.instance_methods.include?(method_name), "File responds to #{method_name}"
    end
  end

  def test_does_not_remove_methods_from_stringio
    stringio = StringIO.new("foo")
    assert stringio.respond_to?(:size)
  end

  def test_is_not_a_stringio
    File.open("foo", "w") do |f|
      assert !f.is_a?(StringIO), 'File is not a StringIO'
    end
  end

  def test_chdir_changes_directories_like_a_boss
    # I know memes!
    FileUtils.mkdir_p '/path'
    assert_equal '/', FileSystem.fs.name
    assert_equal [], Dir.glob('/path/*')
    Dir.chdir '/path' do
      File.open('foo', 'w') { |f| f.write 'foo'}
      File.open('foobar', 'w') { |f| f.write 'foo'}
    end

    assert_equal '/', FileSystem.fs.name
    assert_equal(['/path/foo', '/path/foobar'], Dir.glob('/path/*').sort)

    c = nil
    Dir.chdir '/path' do
      c = File.open('foo', 'r') { |f| f.read }
    end

    assert_equal 'foo', c
  end

  def test_chdir_shouldnt_keep_us_from_absolute_paths
    FileUtils.mkdir_p '/path'

    Dir.chdir '/path' do
      File.open('foo', 'w') { |f| f.write 'foo'}
      File.open('/foobar', 'w') { |f| f.write 'foo'}
    end
    assert_equal ['/path/foo'], Dir.glob('/path/*').sort
    assert_equal ['/foobar', '/path'], Dir.glob('/*').sort

    Dir.chdir '/path' do
      FileUtils.rm('foo')
      FileUtils.rm('/foobar')
    end

    assert_equal [], Dir.glob('/path/*').sort
    assert_equal ['/path'], Dir.glob('/*').sort
  end

  def test_chdir_should_be_nestable
    FileUtils.mkdir_p '/path/me'
    Dir.chdir '/path' do
      File.open('foo', 'w') { |f| f.write 'foo'}
      Dir.chdir 'me' do
        File.open('foobar', 'w') { |f| f.write 'foo'}
      end
    end

    assert_equal ['/path/foo','/path/me'], Dir.glob('/path/*').sort
    assert_equal ['/path/me/foobar'], Dir.glob('/path/me/*').sort
  end

  def test_chdir_should_be_nestable_with_absolute_paths
    FileUtils.mkdir_p '/path/me'
    Dir.chdir '/path' do
      File.open('foo', 'w') { |f| f.write 'foo'}
      Dir.chdir '/path/me' do
        File.open('foobar', 'w') { |f| f.write 'foo'}
      end
    end

    assert_equal ['/path/foo','/path/me'], Dir.glob('/path/*').sort
    assert_equal ['/path/me/foobar'], Dir.glob('/path/me/*').sort
  end

  def test_chdir_should_flop_over_and_die_if_the_dir_doesnt_exist
    assert_raise(Errno::ENOENT) do
      Dir.chdir('/nope') do
        1
      end
    end
  end

  def test_chdir_shouldnt_lose_state_because_of_errors
    FileUtils.mkdir_p '/path'

    Dir.chdir '/path' do
      File.open('foo', 'w') { |f| f.write 'foo'}
      File.open('foobar', 'w') { |f| f.write 'foo'}
    end

    begin
      Dir.chdir('/path') do
        raise Exception
      end
    rescue Exception # hardcore
    end

    Dir.chdir('/path') do
      begin
        Dir.chdir('nope'){ }
      rescue Errno::ENOENT
      end

      assert_equal ['/', '/path'], FileSystem.dir_levels
    end

    assert_equal(['/path/foo', '/path/foobar'], Dir.glob('/path/*').sort)
  end

  def test_chdir_with_no_block_is_awesome
    FileUtils.mkdir_p '/path'
    Dir.chdir('/path')
    FileUtils.mkdir_p 'subdir'
    assert_equal ['subdir'], Dir.glob('*')
    Dir.chdir('subdir')
    File.open('foo', 'w') { |f| f.write 'foo'}
    assert_equal ['foo'], Dir.glob('*')

    assert_raises(Errno::ENOENT) do
      Dir.chdir('subsubdir')
    end

    assert_equal ['foo'], Dir.glob('*')
  end

  def test_current_dir_reflected_by_pwd
    FileUtils.mkdir_p '/path'
    Dir.chdir('/path')

    assert_equal '/path', Dir.pwd
    assert_equal '/path', Dir.getwd

    FileUtils.mkdir_p 'subdir'
    Dir.chdir('subdir')

    assert_equal '/path/subdir', Dir.pwd
    assert_equal '/path/subdir', Dir.getwd
  end

  def test_current_dir_reflected_by_expand_path
    FileUtils.mkdir_p '/path'
    Dir.chdir '/path'

    assert_equal '/path', File.expand_path('.')
    assert_equal '/path/foo', File.expand_path('foo')

    FileUtils.mkdir_p 'subdir'
    Dir.chdir 'subdir'

    assert_equal '/path/subdir', File.expand_path('.')
    assert_equal '/path/subdir/foo', File.expand_path('foo')
  end

  def test_file_open_defaults_to_read
    File.open('foo','w') { |f| f.write 'bar' }
    assert_equal 'bar', File.open('foo') { |f| f.read }
  end

  def test_flush_exists_on_file
    r = File.open('foo','w') { |f| f.write 'bar';  f.flush }
    assert_equal 'foo', r.path
  end

  def test_mv_should_raise_error_on_missing_file
    assert_raise(Errno::ENOENT) do
      FileUtils.mv 'blafgag', 'foo'
    end
    exception = assert_raise(Errno::ENOENT) do
      FileUtils.mv ['foo', 'bar'], 'destdir'
    end
    assert_equal "No such file or directory - foo", exception.message
  end

  def test_mv_actually_works
    File.open('foo', 'w') { |f| f.write 'bar' }
    FileUtils.mv 'foo', 'baz'
    assert_equal 'bar', File.open('baz') { |f| f.read }
  end

  def test_mv_overwrites_existing_files
    File.open('foo', 'w') { |f| f.write 'bar' }
    File.open('baz', 'w') { |f| f.write 'qux' }
    FileUtils.mv 'foo', 'baz'
    assert_equal 'bar', File.read('baz')
  end

  def test_mv_works_with_options
    File.open('foo', 'w') {|f| f.write 'bar'}
    FileUtils.mv 'foo', 'baz', :force => true
    assert_equal('bar', File.open('baz') { |f| f.read })
  end

  def test_mv_to_directory
    File.open('foo', 'w') {|f| f.write 'bar'}
    FileUtils.mkdir_p 'destdir'
    FileUtils.mv 'foo', 'destdir'
    assert_equal('bar', File.open('destdir/foo') {|f| f.read })
    assert File.directory?('destdir')
  end

  def test_mv_array
    File.open('foo', 'w') {|f| f.write 'bar' }
    File.open('baz', 'w') {|f| f.write 'binky' }
    FileUtils.mkdir_p 'destdir'
    FileUtils.mv %w(foo baz), 'destdir'
    assert_equal('bar', File.open('destdir/foo') {|f| f.read })
    assert_equal('binky', File.open('destdir/baz') {|f| f.read })
  end

  def test_mv_accepts_verbose_option
    FileUtils.touch 'foo'
    assert_equal "mv foo bar\n", capture_stderr { FileUtils.mv 'foo', 'bar', :verbose => true }
  end

  def test_mv_accepts_noop_option
    FileUtils.touch 'foo'
    FileUtils.mv 'foo', 'bar', :noop => true
    assert File.exist?('foo'), 'does not remove src'
    assert !File.exist?('bar'), 'does not create target'
  end

  def test_mv_raises_when_moving_file_onto_directory
    FileUtils.mkdir_p 'dir/stuff'
    FileUtils.touch 'stuff'
    assert_raises Errno::EEXIST do
      FileUtils.mv 'stuff', 'dir'
    end
  end

  def test_mv_raises_when_moving_to_non_existent_directory
    FileUtils.touch 'stuff'
    assert_raises Errno::ENOENT do
      FileUtils.mv 'stuff', '/this/path/is/not/here'
    end
  end

  def test_mv_ignores_failures_when_using_force
    FileUtils.mkdir_p 'dir/stuff'
    FileUtils.touch %w[stuff other]
    FileUtils.mv %w[stuff other], 'dir', :force => true
    assert File.exist?('stuff'), 'failed move remains where it was'
    assert File.exist?('dir/other'), 'successful one is moved'
    assert !File.exist?('other'), 'successful one is moved'

    FileUtils.mv 'stuff', '/this/path/is/not/here', :force => true
    assert File.exist?('stuff'), 'failed move remains where it was'
    assert !File.exist?('/this/path/is/not/here'), 'nothing is created for a failed move'
  end

  def test_cp_actually_works
    File.open('foo', 'w') {|f| f.write 'bar' }
    FileUtils.cp('foo', 'baz')
    assert_equal 'bar', File.read('baz')
  end

  def test_cp_file_into_dir
    File.open('foo', 'w') {|f| f.write 'bar' }
    FileUtils.mkdir_p 'baz'

    FileUtils.cp('foo', 'baz')
    assert_equal 'bar', File.read('baz/foo')
  end

  def test_cp_array_of_files_into_directory
    File.open('foo', 'w') { |f| f.write 'footext' }
    File.open('bar', 'w') { |f| f.write 'bartext' }
    FileUtils.mkdir_p 'destdir'
    FileUtils.cp(%w(foo bar), 'destdir')

    assert_equal 'footext', File.read('destdir/foo')
    assert_equal 'bartext', File.read('destdir/bar')
  end

  def test_cp_fails_on_array_of_files_into_non_directory
    File.open('foo', 'w') { |f| f.write 'footext' }

    exception = assert_raise(Errno::ENOTDIR) do
      FileUtils.cp(%w(foo), 'baz')
    end
    assert_equal "Not a directory - baz", exception.to_s
  end

  def test_cp_overwrites_dest_file
    File.open('foo', 'w') {|f| f.write 'FOO' }
    File.open('bar', 'w') {|f| f.write 'BAR' }

    FileUtils.cp('foo', 'bar')
    assert_equal 'FOO', File.read('bar')
  end

  def test_cp_fails_on_no_source
    assert_raise Errno::ENOENT do
      FileUtils.cp('foo', 'baz')
    end
  end

  def test_cp_fails_on_directory_copy
    FileUtils.mkdir_p 'baz'

    assert_raise Errno::EISDIR do
      FileUtils.cp('baz', 'bar')
    end
  end

  def test_copy_file_works
    File.open('foo', 'w') {|f| f.write 'bar' }
    FileUtils.copy_file('foo', 'baz', :ignore_param_1, :ignore_param_2)
    assert_equal 'bar', File.read('baz')
  end

  def test_cp_r_doesnt_tangle_files_together
    File.open('foo', 'w') { |f| f.write 'bar' }
    FileUtils.cp_r('foo', 'baz')
    File.open('baz', 'w') { |f| f.write 'quux' }
    assert_equal 'bar', File.open('foo') { |f| f.read }
  end

  def test_cp_r_should_raise_error_on_missing_file
    # Yes, this error sucks, but it conforms to the original Ruby
    # method.
    assert_raise(RuntimeError) do
      FileUtils.cp_r 'blafgag', 'foo'
    end
  end

  def test_cp_r_handles_copying_directories
    FileUtils.mkdir_p 'subdir'
    Dir.chdir('subdir'){ File.open('foo', 'w') { |f| f.write 'footext' } }

    FileUtils.mkdir_p 'baz'

    # To a previously uncreated directory
    FileUtils.cp_r('subdir', 'quux')
    assert_equal 'footext', File.open('quux/foo') { |f| f.read }

    # To a directory that already exists
    FileUtils.cp_r('subdir', 'baz')
    assert_equal 'footext', File.open('baz/subdir/foo') { |f| f.read }

    # To a subdirectory of a directory that does not exist
    assert_raises(Errno::ENOENT) do
      FileUtils.cp_r('subdir', 'nope/something')
    end
  end

  def test_cp_r_array_of_files
    FileUtils.mkdir_p 'subdir'
    File.open('foo', 'w') { |f| f.write 'footext' }
    File.open('bar', 'w') { |f| f.write 'bartext' }
    FileUtils.cp_r(%w(foo bar), 'subdir')

    assert_equal 'footext', File.open('subdir/foo') { |f| f.read }
    assert_equal 'bartext', File.open('subdir/bar') { |f| f.read }
  end

  def test_cp_r_array_of_directories
    %w(foo bar subdir).each { |d| FileUtils.mkdir_p d }
    File.open('foo/baz', 'w') { |f| f.write 'baztext' }
    File.open('bar/quux', 'w') { |f| f.write 'quuxtext' }

    FileUtils.cp_r(%w(foo bar), 'subdir')
    assert_equal 'baztext', File.open('subdir/foo/baz') { |f| f.read }
    assert_equal 'quuxtext', File.open('subdir/bar/quux') { |f| f.read }
  end

  def test_cp_r_only_copies_into_directories
    FileUtils.mkdir_p 'subdir'
    Dir.chdir('subdir') { File.open('foo', 'w') { |f| f.write 'footext' } }

    File.open('bar', 'w') { |f| f.write 'bartext' }

    assert_raises(Errno::EEXIST) do
      FileUtils.cp_r 'subdir', 'bar'
    end

    FileUtils.mkdir_p 'otherdir'
    FileUtils.ln_s 'otherdir', 'symdir'

    FileUtils.cp_r 'subdir', 'symdir'
    assert_equal 'footext', File.open('symdir/subdir/foo') { |f| f.read }
  end

  def test_cp_r_sets_parent_correctly
    FileUtils.mkdir_p '/path/foo'
    File.open('/path/foo/bar', 'w') { |f| f.write 'foo' }
    File.open('/path/foo/baz', 'w') { |f| f.write 'foo' }

    FileUtils.cp_r '/path/foo', '/path/bar'

    assert File.exists?('/path/bar/baz')
    FileUtils.rm_rf '/path/bar/baz'
    assert_equal %w( /path/bar/bar ), Dir['/path/bar/*']
  end

  def test_clone_clones_normal_files
    RealFile.open(here('foo'), 'w') { |f| f.write 'bar' }
    assert !File.exists?(here('foo'))
    FileSystem.clone(here('foo'))
    assert_equal 'bar', File.open(here('foo')) { |f| f.read }
  ensure
    RealFile.unlink(here('foo')) if RealFile.exists?(here('foo'))
  end

  def test_clone_clones_directories
    act_on_real_fs { RealFileUtils.mkdir_p(here('subdir')) }

    FileSystem.clone(here('subdir'))

    assert File.exists?(here('subdir')), 'subdir was cloned'
    assert File.directory?(here('subdir')), 'subdir is a directory'
  ensure
    act_on_real_fs { RealFileUtils.rm_rf(here('subdir')) }
  end

  def test_clone_clones_dot_files_even_hard_to_find_ones
    act_on_real_fs { RealFileUtils.mkdir_p(here('subdir/.bar/baz/.quux/foo')) }

    assert !File.exists?(here('subdir'))

    FileSystem.clone(here('subdir'))
    assert_equal ['.', '..', '.bar'], Dir.entries(here('subdir'))
    assert_equal ['.', '..', 'foo'], Dir.entries(here('subdir/.bar/baz/.quux'))
  ensure
    act_on_real_fs { RealFileUtils.rm_rf(here('subdir')) }
  end

  def test_dir_glob_on_clone_with_absolute_path
    act_on_real_fs { RealFileUtils.mkdir_p(here('subdir/.bar/baz/.quux/foo')) }
    FileUtils.mkdir_p '/path'
    Dir.chdir('/path')
    FileSystem.clone(here('subdir'), "/foo")
    assert Dir.glob "/foo/*"
  ensure
    act_on_real_fs { RealFileUtils.rm_rf(here('subdir')) }
  end

  def test_clone_with_target_specified
    act_on_real_fs { RealFileUtils.mkdir_p(here('subdir/.bar/baz/.quux/foo')) }

    assert !File.exists?(here('subdir'))

    FileSystem.clone(here('subdir'), here('subdir2'))
    assert !File.exists?(here('subdir'))
    assert_equal ['.', '..', '.bar'], Dir.entries(here('subdir2'))
    assert_equal ['.', '..', 'foo'], Dir.entries(here('subdir2/.bar/baz/.quux'))
  ensure
    act_on_real_fs { RealFileUtils.rm_rf(here('subdir')) }
  end

  def test_clone_with_file_symlinks
    original = here('subdir/test-file')
    symlink  = here('subdir/test-file.txt')

    act_on_real_fs do
      RealDir.mkdir(RealFile.dirname(original))
      RealFile.open(original, 'w') {|f| f << 'stuff' }
      RealFileUtils.ln_s original, symlink
      assert RealFile.symlink?(symlink), 'real symlink is in place'
    end

    assert !File.exists?(original), 'file does not already exist'

    FileSystem.clone(File.dirname(original))
    assert File.symlink?(symlink), 'symlinks are cloned as symlinks'
    assert_equal 'stuff', File.read(symlink)
  ensure
    act_on_real_fs { RealFileUtils.rm_rf File.dirname(original) }
  end

  def test_clone_with_dir_symlinks
    original = here('subdir/dir')
    symlink  = here('subdir/dir.link')
    original_file = File.join(original, 'test-file')
    symlink_file  = File.join(symlink, 'test-file')

    act_on_real_fs do
      RealFileUtils.mkdir_p(original)
      RealFile.open(original_file, 'w') {|f| f << 'stuff' }
      RealFileUtils.ln_s original, symlink
      assert RealFile.symlink?(symlink), 'real symlink is in place'
    end

    assert !File.exists?(original_file), 'file does not already exist'

    FileSystem.clone(File.dirname(original))
    assert File.symlink?(symlink), 'symlinks are cloned as symlinks'
    assert_equal 'stuff', File.read(symlink_file)
  ensure
    act_on_real_fs { RealFileUtils.rm_rf File.dirname(original) }
  end

  def test_putting_a_dot_at_end_copies_the_contents
    FileUtils.mkdir_p 'subdir'
    Dir.chdir('subdir') { File.open('foo', 'w') { |f| f.write 'footext' } }

    FileUtils.mkdir_p 'newdir'
    FileUtils.cp_r 'subdir/.', 'newdir'
    assert_equal 'footext', File.open('newdir/foo') { |f| f.read }
  end

  def test_file_can_read_from_symlinks
    File.open('first', 'w') { |f| f.write '1'}
    FileUtils.ln_s 'first', 'one'
    assert_equal '1', File.open('one') { |f| f.read }

    FileUtils.mkdir_p 'subdir'
    File.open('subdir/nother','w') { |f| f.write 'works' }
    FileUtils.ln_s 'subdir', 'new'
    assert_equal 'works', File.open('new/nother') { |f| f.read }
  end

  def test_can_symlink_through_file
    FileUtils.touch("/foo")

    File.symlink("/foo", "/bar")

    assert File.symlink?("/bar")
  end

  def test_files_can_be_touched
    FileUtils.touch('touched_file')
    assert File.exists?('touched_file')
    list = ['newfile', 'another']
    FileUtils.touch(list)
    list.each { |fp| assert(File.exists?(fp)) }
  end

  def test_touch_does_not_work_if_the_dir_path_cannot_be_found
    assert_raises(Errno::ENOENT) do
      FileUtils.touch('this/path/should/not/be/here')
    end
    FileUtils.mkdir_p('subdir')
    list = ['subdir/foo', 'nosubdir/bar']

    assert_raises(Errno::ENOENT) do
      FileUtils.touch(list)
    end
  end

  def test_extname
    assert File.extname("test.doc") == ".doc"
  end

  # Directory tests
  def test_new_directory
    FileUtils.mkdir_p('/this/path/should/be/here')

    assert_nothing_raised do
      Dir.new('/this/path/should/be/here')
    end
  end

  def test_new_directory_does_not_work_if_dir_path_cannot_be_found
    assert_raises(Errno::ENOENT) do
      Dir.new('/this/path/should/not/be/here')
    end
  end

  def test_directory_close
    FileUtils.mkdir_p('/this/path/should/be/here')
    dir = Dir.new('/this/path/should/be/here')
    assert dir.close.nil?

    assert_raises(IOError) do
      dir.each { |dir| dir }
    end
  end

  def test_directory_each
    test = ['.', '..', 'file_1', 'file_2', 'file_3', 'file_4', 'file_5' ]

    FileUtils.mkdir_p('/this/path/should/be/here')

    test.each do |f|
      FileUtils.touch("/this/path/should/be/here/#{f}")
    end

    dir = Dir.new('/this/path/should/be/here')

    yielded = []
    dir.each do |dir|
      yielded << dir
    end

    assert yielded.size == test.size
    test.each { |t| assert yielded.include?(t) }
  end

  def test_directory_path
    FileUtils.mkdir_p('/this/path/should/be/here')
    good_path = '/this/path/should/be/here'
    assert_equal good_path, Dir.new('/this/path/should/be/here').path
  end

  def test_directory_pos
    test = ['.', '..', 'file_1', 'file_2', 'file_3', 'file_4', 'file_5' ]
    FileUtils.mkdir_p('/this/path/should/be/here')
    test.each do |f|
      FileUtils.touch("/this/path/should/be/here/#{f}")
    end

    dir = Dir.new('/this/path/should/be/here')

    assert dir.pos == 0
    dir.read
    assert dir.pos == 1
    dir.read
    assert dir.pos == 2
    dir.read
    assert dir.pos == 3
    dir.read
    assert dir.pos == 4
    dir.read
    assert dir.pos == 5
  end

  def test_directory_pos_assign
    test = ['.', '..', 'file_1', 'file_2', 'file_3', 'file_4', 'file_5' ]

    FileUtils.mkdir_p('/this/path/should/be/here')
    test.each do |f|
      FileUtils.touch("/this/path/should/be/here/#{f}")
    end

    dir = Dir.new('/this/path/should/be/here')

    assert dir.pos == 0
    dir.pos = 2
    assert dir.pos == 2
  end

  def test_directory_read
    test = ['.', '..', 'file_1', 'file_2', 'file_3', 'file_4', 'file_5' ]

    FileUtils.mkdir_p('/this/path/should/be/here')
    test.each do |f|
      FileUtils.touch("/this/path/should/be/here/#{f}")
    end

    dir = Dir.new('/this/path/should/be/here')

    assert dir.pos == 0
    d = dir.read
    assert dir.pos == 1
    assert d == '.'

    d = dir.read
    assert dir.pos == 2
    assert d == '..'
  end

  def test_directory_read_past_length
    test = ['.', '..', 'file_1', 'file_2', 'file_3', 'file_4', 'file_5' ]

    FileUtils.mkdir_p('/this/path/should/be/here')
    test.each do |f|
      FileUtils.touch("/this/path/should/be/here/#{f}")
    end

    dir = Dir.new('/this/path/should/be/here')

    d = dir.read
    assert_not_nil d
    d = dir.read
    assert_not_nil d
    d = dir.read
    assert_not_nil d
    d = dir.read
    assert_not_nil d
    d = dir.read
    assert_not_nil d
    d = dir.read
    assert_not_nil d
    d = dir.read
    assert_not_nil d
    d = dir.read
    assert_nil d
  end

  def test_directory_rewind
    test = ['.', '..', 'file_1', 'file_2', 'file_3', 'file_4', 'file_5' ]

    FileUtils.mkdir_p('/this/path/should/be/here')
    test.each do |f|
      FileUtils.touch("/this/path/should/be/here/#{f}")
    end

    dir = Dir.new('/this/path/should/be/here')

    d = dir.read
    d = dir.read
    assert dir.pos == 2
    dir.rewind
    assert dir.pos == 0
  end

  def test_directory_seek
    test = ['.', '..', 'file_1', 'file_2', 'file_3', 'file_4', 'file_5' ]

    FileUtils.mkdir_p('/this/path/should/be/here')
    test.each do |f|
      FileUtils.touch("/this/path/should/be/here/#{f}")
    end

    dir = Dir.new('/this/path/should/be/here')

    d = dir.seek 1
    assert d == '..'
    assert dir.pos == 1
  end

  def test_directory_class_delete
    FileUtils.mkdir_p('/this/path/should/be/here')
    Dir.delete('/this/path/should/be/here')
    assert File.exists?('/this/path/should/be/here') == false
  end

  def test_directory_class_delete_does_not_act_on_non_empty_directory
    test = ['.', '..', 'file_1', 'file_2', 'file_3', 'file_4', 'file_5' ]

    FileUtils.mkdir_p('/this/path/should/be/here')
    test.each do |f|
      FileUtils.touch("/this/path/should/be/here/#{f}")
    end

    assert_raises(Errno::ENOTEMPTY) do
      Dir.delete('/this/path/should/be/here')
    end
  end

  def test_directory_class_delete_does_not_work_if_dir_path_cannot_be_found
    assert_raises(Errno::ENOENT) do
      Dir.delete('/this/path/should/not/be/here')
    end
  end

  def test_directory_entries
    test = ['.', '..', 'file_1', 'file_2', 'file_3', 'file_4', 'file_5' ]

    FileUtils.mkdir_p('/this/path/should/be/here')

    test.each do |f|
      FileUtils.touch("/this/path/should/be/here/#{f}")
    end

    yielded = Dir.entries('/this/path/should/be/here')
    assert yielded.size == test.size
    test.each { |t| assert yielded.include?(t) }
  end

  def test_directory_entries_works_with_trailing_slash
    test = ['.', '..', 'file_1', 'file_2', 'file_3', 'file_4', 'file_5' ]

    FileUtils.mkdir_p('/this/path/should/be/here')

    test.each do |f|
      FileUtils.touch("/this/path/should/be/here/#{f}")
    end

    yielded = Dir.entries('/this/path/should/be/here/')
    assert yielded.size == test.size
    test.each { |t| assert yielded.include?(t) }
  end

  def test_directory_entries_does_not_work_if_dir_path_cannot_be_found
    assert_raises(Errno::ENOENT) do
      Dir.delete('/this/path/should/not/be/here')
    end
  end

  def test_directory_foreach
    test = ['.', '..', 'file_1', 'file_2', 'file_3', 'file_4', 'file_5' ]

    FileUtils.mkdir_p('/this/path/should/be/here')

    test.each do |f|
      FileUtils.touch("/this/path/should/be/here/#{f}")
    end

    yielded = []
    Dir.foreach('/this/path/should/be/here') do |dir|
      yielded << dir
    end

    assert yielded.size == test.size
    test.each { |t| assert yielded.include?(t) }
  end

  def test_directory_foreach_relative_paths
    test = ['.', '..', 'file_1', 'file_2', 'file_3', 'file_4', 'file_5' ]

    FileUtils.mkdir_p('/this/path/should/be/here')

    test.each do |f|
      FileUtils.touch("/this/path/should/be/here/#{f}")
    end

    yielded = []
    Dir.chdir '/this/path/should/be' do
      Dir.foreach('here') do |dir|
        yielded << dir
      end
    end

    assert yielded.size == test.size, 'wrong number of files yielded'
    test.each { |t| assert yielded.include?(t), "#{t} was not included in #{yielded.inspect}" }
  end

  def test_directory_mkdir
    Dir.mkdir('/path')
    assert File.exists?('/path')
  end

  def test_directory_mkdir_nested
    Dir.mkdir("/tmp")
    Dir.mkdir("/tmp/stream20120103-11847-xc8pb.lock")
    assert File.exists?("/tmp/stream20120103-11847-xc8pb.lock")
  end

  def test_can_create_subdirectories_with_dir_mkdir
    Dir.mkdir 'foo'
    Dir.mkdir 'foo/bar'
    assert Dir.exists?('foo/bar')
  end

  def test_can_create_absolute_subdirectories_with_dir_mkdir
    Dir.mkdir '/foo'
    Dir.mkdir '/foo/bar'
    assert Dir.exists?('/foo/bar')
  end

  def test_can_create_directories_starting_with_dot
    Dir.mkdir './path'
    assert File.exists? './path'
  end

  def test_directory_mkdir_relative
    FileUtils.mkdir_p('/new/root')
    FileSystem.chdir('/new/root')
    Dir.mkdir('path')
    assert File.exists?('/new/root/path')
  end

  def test_directory_mkdir_not_recursive
    assert_raises(Errno::ENOENT) do
      Dir.mkdir('/path/does/not/exist')
    end
  end

  def test_mkdir_raises_error_if_already_created
    Dir.mkdir "foo"

    assert_raises(Errno::EEXIST) do
      Dir.mkdir "foo"
    end
  end

  def test_directory_open
    test = ['.', '..', 'file_1', 'file_2', 'file_3', 'file_4', 'file_5' ]

    FileUtils.mkdir_p('/this/path/should/be/here')

    test.each do |f|
      FileUtils.touch("/this/path/should/be/here/#{f}")
    end

    dir = Dir.open('/this/path/should/be/here')
    assert dir.path == '/this/path/should/be/here'
  end

  def test_directory_open_block
    test = ['.', '..', 'file_1', 'file_2', 'file_3', 'file_4', 'file_5' ]

    FileUtils.mkdir_p('/this/path/should/be/here')

    test.each do |f|
      FileUtils.touch("/this/path/should/be/here/#{f}")
    end

    yielded = []
    Dir.open('/this/path/should/be/here') do |dir|
      yielded << dir
    end

    assert yielded.size == test.size
    test.each { |t| assert yielded.include?(t) }
  end

  def test_directory_exists
    assert Dir.exists?('/this/path/should/be/here') == false
    assert Dir.exist?('/this/path/should/be/here') == false
    FileUtils.mkdir_p('/this/path/should/be/here')
    assert Dir.exists?('/this/path/should/be/here') == true
    assert Dir.exist?('/this/path/should/be/here') == true
  end

  def test_tmpdir
    assert Dir.tmpdir == "/tmp"
  end

  def test_rename_renames_a_file
    FileUtils.touch("/foo")
    File.rename("/foo", "/bar")
    assert File.file?("/bar")
  end

  def test_rename_returns
    FileUtils.touch("/foo")
    assert_equal 0, File.rename("/foo", "/bar")
  end

  def test_rename_renames_two_files
    FileUtils.touch("/foo")
    FileUtils.touch("/bar")
    File.rename("/foo", "/bar")
    assert File.file?("/bar")
  end

  def test_rename_renames_a_directories
    Dir.mkdir("/foo")
    File.rename("/foo", "/bar")
    assert File.directory?("/bar")
  end

  def test_rename_renames_two_directories
    Dir.mkdir("/foo")
    Dir.mkdir("/bar")
    File.rename("/foo", "/bar")
    assert File.directory?("/bar")
  end

  def test_rename_file_to_directory_raises_error
    FileUtils.touch("/foo")
    Dir.mkdir("/bar")
    assert_raises(Errno::EISDIR) do
      File.rename("/foo", "/bar")
    end
  end

  def test_rename_directory_to_file_raises_error
    Dir.mkdir("/foo")
    FileUtils.touch("/bar")
    assert_raises(Errno::ENOTDIR) do
      File.rename("/foo", "/bar")
    end
  end


  def test_rename_with_missing_source_raises_error
    assert_raises(Errno::ENOENT) do
      File.rename("/no_such_file", "/bar")
    end
  end

  def test_hard_link_creates_file
    FileUtils.touch("/foo")

    File.link("/foo", "/bar")
    assert File.exists?("/bar")
  end

  def test_hard_link_with_missing_file_raises_error
    assert_raises(Errno::ENOENT) do
      File.link("/foo", "/bar")
    end
  end

  def test_hard_link_with_existing_destination_file
    FileUtils.touch("/foo")
    FileUtils.touch("/bar")

    assert_raises(Errno::EEXIST) do
      File.link("/foo", "/bar")
    end
  end

  def test_hard_link_returns_0_when_successful
    FileUtils.touch("/foo")

    assert_equal 0, File.link("/foo", "/bar")
  end

  def test_hard_link_returns_duplicate_file
    File.open("/foo", "w") { |x| x << "some content" }

    File.link("/foo", "/bar")
    assert_equal "some content", File.read("/bar")
  end

  def test_hard_link_with_directory_raises_error
    Dir.mkdir "/foo"

    assert_raises(Errno::EPERM) do
      File.link("/foo", "/bar")
    end
  end

  def test_file_stat_returns_file_stat_object
    FileUtils.touch("/foo")
    assert_equal File::Stat, File.stat("/foo").class
  end

  def test_can_delete_file_with_delete
    FileUtils.touch("/foo")

    File.delete("/foo")

    assert !File.exists?("/foo")
  end

  def test_can_delete_multiple_files_with_delete
    FileUtils.touch("/foo")
    FileUtils.touch("/bar")

    File.delete("/foo", "/bar")

    assert !File.exists?("/foo")
    assert !File.exists?("/bar")
  end

  def test_delete_raises_argument_error_with_no_filename_given
    assert_raises ArgumentError do
      File.delete
    end
  end

  def test_delete_returns_number_one_when_given_one_arg
    FileUtils.touch("/foo")

    assert_equal 1, File.delete("/foo")
  end

  def test_delete_returns_number_two_when_given_two_args
    FileUtils.touch("/foo")
    FileUtils.touch("/bar")

    assert_equal 2, File.delete("/foo", "/bar")
  end

  def test_delete_raises_error_when_first_file_does_not_exist
    assert_raises Errno::ENOENT do
      File.delete("/foo")
    end
  end

  def test_unlink_removes_only_one_file_content
    File.open("/foo", "w") { |f| f << "some_content" }
    File.link("/foo", "/bar")

    File.unlink("/bar")
    assert_equal "some_content", File.read("/foo")
  end

  def test_link_reports_correct_stat_info_after_unlinking
    File.open("/foo", "w") { |f| f << "some_content" }
    File.link("/foo", "/bar")

    File.unlink("/bar")
    assert_equal 1, File.stat("/foo").nlink
  end

  def test_delete_works_with_symlink
    FileUtils.touch("/foo")
    File.symlink("/foo", "/bar")

    File.unlink("/bar")

    assert File.exists?("/foo")
    assert !File.exists?("/bar")
  end

  def test_delete_works_with_symlink_source
    FileUtils.touch("/foo")
    File.symlink("/foo", "/bar")

    File.unlink("/foo")

    assert !File.exists?("/foo")
  end

  def test_file_seek_returns_0
    File.open("/foo", "w") do |f|
      f << "one\ntwo\nthree"
    end

    file = File.open("/foo", "r")

    assert_equal 0, file.seek(1)
  end

  def test_file_seek_seeks_to_location
    File.open("/foo", "w") do |f|
      f << "123"
    end

    file = File.open("/foo", "r")
    file.seek(1)
    assert_equal "23", file.read
  end

  def test_file_seek_seeks_to_correct_location
    File.open("/foo", "w") do |f|
      f << "123"
    end

    file = File.open("/foo", "r")
    file.seek(2)
    assert_equal "3", file.read
  end

  def test_file_seek_can_take_negative_offset
    File.open("/foo", "w") do |f|
      f << "123456789"
    end

    file = File.open("/foo", "r")

    file.seek(-1, IO::SEEK_END)
    assert_equal "9", file.read

    file.seek(-2, IO::SEEK_END)
    assert_equal "89", file.read

    file.seek(-3, IO::SEEK_END)
    assert_equal "789", file.read
  end

  def test_should_have_constants_inherited_from_descending_from_io
    assert_equal IO::SEEK_CUR, File::SEEK_CUR
    assert_equal IO::SEEK_END, File::SEEK_END
    assert_equal IO::SEEK_SET, File::SEEK_SET
  end

  def test_filetest_exists_return_correct_values
    FileUtils.mkdir_p("/path/to/dir")
    assert FileTest.exist?("/path/to/")

    FileUtils.rmdir("/path/to/dir")
    assert !FileTest.exist?("/path/to/dir")
  end

  def test_filetest_directory_returns_correct_values
    FileUtils.mkdir_p '/path/to/somedir'
    assert FileTest.directory?('/path/to/somedir')

    FileUtils.rm_r '/path/to/somedir'
    assert !FileTest.directory?('/path/to/somedir')
  end

  def test_filetest_file_returns_correct_values
    FileUtils.mkdir_p("/path/to")

    path = '/path/to/file.txt'
    File.open(path, 'w') { |f| f.write "Yatta!" }
    assert FileTest.file?(path)

    FileUtils.rm path
    assert !FileTest.file?(path)

    FileUtils.mkdir_p '/path/to/somedir'
    assert !FileTest.file?('/path/to/somedir')
  end

  def test_filetest_writable_returns_correct_values
    assert !FileTest.writable?('not-here.txt'), 'missing files are not writable'

    FileUtils.touch 'here.txt'
    assert FileTest.writable?('here.txt'), 'existing files are writable'

    FileUtils.mkdir 'dir'
    assert FileTest.writable?('dir'), 'directories are writable'
  end

  def test_pathname_exists_returns_correct_value
    FileUtils.touch "foo"
    assert Pathname.new("foo").exist?

    assert !Pathname.new("bar").exist?
  end

  def test_pathname_method_is_faked
    FileUtils.mkdir_p '/path'
    assert Pathname('/path').exist?, 'Pathname() method is faked'
  end

  def test_dir_mktmpdir
    FileUtils.mkdir '/tmp'

    tmpdir = Dir.mktmpdir
    assert File.directory?(tmpdir)
    FileUtils.rm_r tmpdir

    Dir.mktmpdir do |t|
      tmpdir = t
      assert File.directory?(t)
    end
    assert !File.directory?(tmpdir)
  end

  def test_activating_returns_true
    FakeFS.deactivate!
    assert_equal true, FakeFS.activate!
  end

  def test_deactivating_returns_true
    assert_equal true, FakeFS.deactivate!
  end

  def test_split
    assert File.respond_to? :split
    filename = "/this/is/what/we/expect.txt"
    path,filename = File.split(filename)
    assert_equal path, "/this/is/what/we"
    assert_equal filename, "expect.txt"
  end

  #########################
  def test_file_default_mode
    FileUtils.touch "foo"
    assert_equal File.stat("foo").mode, (0100000 + 0666 - File.umask)
  end

  def test_dir_default_mode
    Dir.mkdir "bar"
    assert_equal File.stat("bar").mode, (0100000 + 0777 - File.umask)
  end

  def test_file_default_uid_and_gid
    FileUtils.touch "foo"
    assert_equal File.stat("foo").uid, Process.uid
    assert_equal File.stat("foo").gid, Process.gid
  end

  def test_file_chmod_of_file
    FileUtils.touch "foo"
    File.chmod 0600, "foo"
    assert_equal File.stat("foo").mode, 0100600
    File.new("foo").chmod 0644
    assert_equal File.stat("foo").mode, 0100644
  end

  def test_file_chmod_of_dir
    Dir.mkdir "bar"
    File.chmod 0777, "bar"
    assert_equal File.stat("bar").mode, 0100777
    File.new("bar").chmod 01700
    assert_equal File.stat("bar").mode, 0101700
  end

  def test_file_chown_of_file
    FileUtils.touch "foo"
    File.chown 1337, 1338, "foo"
    assert_equal File.stat("foo").uid, 1337
    assert_equal File.stat("foo").gid, 1338
  end

  def test_file_chown_of_dir
    Dir.mkdir "bar"
    File.chown 1337, 1338, "bar"
    assert_equal File.stat("bar").uid, 1337
    assert_equal File.stat("bar").gid, 1338
  end

  def test_file_chown_of_file_nil_user_group
    FileUtils.touch "foo"
    File.chown 1337, 1338, "foo"
    File.chown nil, nil, "foo"
    assert_equal File.stat("foo").uid, 1337
    assert_equal File.stat("foo").gid, 1338
  end

  def test_file_chown_of_file_negative_user_group
    FileUtils.touch "foo"
    File.chown 1337, 1338, "foo"
    File.chown -1, -1, "foo"
    assert_equal File.stat("foo").uid, 1337
    assert_equal File.stat("foo").gid, 1338
  end

  def test_file_instance_chown_nil_user_group
    FileUtils.touch('foo')
    File.chown(1337, 1338, 'foo')
    assert_equal File.stat('foo').uid, 1337
    assert_equal File.stat('foo').gid, 1338
    file = File.open('foo')
    file.chown nil, nil
    assert_equal File.stat('foo').uid, 1337
    assert_equal File.stat('foo').gid, 1338
  end

  def test_file_instance_chown_negative_user_group
    FileUtils.touch('foo')
    File.chown(1337, 1338, 'foo')
    assert_equal File.stat('foo').uid, 1337
    assert_equal File.stat('foo').gid, 1338
    file = File.new('foo')
    file.chown -1, -1
    file.close
    assert_equal File.stat('foo').uid, 1337
    assert_equal File.stat('foo').gid, 1338
  end


  def test_file_umask
    assert_equal File.umask, RealFile.umask
    File.umask(0740)

    assert_equal File.umask, RealFile.umask
    assert_equal File.umask, 0740
  end

  def test_file_stat_comparable
    a_time = Time.new

    same1 = File.new("s1", "w")
    same2 = File.new("s2", "w")
    different1 = File.new("d1", "w")
    different2 = File.new("d2", "w")

    FileSystem.find("s1").mtime = a_time
    FileSystem.find("s2").mtime = a_time

    FileSystem.find("d1").mtime = a_time
    FileSystem.find("d2").mtime = a_time + 1

    assert same1.mtime == same2.mtime
    assert different1.mtime != different2.mtime

    assert same1.stat == same2.stat
    assert (same1.stat <=> same2.stat) == 0

    assert different1.stat != different2.stat
    assert (different1.stat <=> different2.stat) == -1
  end

  def test_file_binread_works
    File.open("testfile", 'w') do |f|
      f << "This is line one\nThis is line two\nThis is line three\nAnd so on...\n"
    end

    assert_equal File.binread("testfile"), "This is line one\nThis is line two\nThis is line three\nAnd so on...\n"
    assert_equal File.binread("testfile", 20), "This is line one\nThi"
    assert_equal File.binread("testfile", 20, 10), "ne one\nThis is line "
  end

  def here(fname)
    RealFile.expand_path(File.join(RealFile.dirname(__FILE__), fname))
  end

  def test_file_utils_compare_file
    file1 = 'file1.txt'
    file2 = 'file2.txt'
    file3 = 'file3.txt'
    content = "This is my \n file\content\n"
    File.open(file1, 'w') do |f|
      f.write content
    end
    File.open(file3, 'w') do |f|
      f.write "#{content} with additional content"
    end

    FileUtils.cp file1, file2

    assert_equal FileUtils.compare_file(file1, file2), true
    assert_equal FileUtils.compare_file(file1, file3), false
    assert_raises Errno::ENOENT do
      FileUtils.compare_file(file1, "file4.txt")
    end
  end

  if RUBY_VERSION >= "1.9.2"
    def test_file_size
      File.open("foo", 'w') do |f|
        f << 'Yada Yada'
        assert_equal 9, f.size
      end
    end

    def test_fdatasync
      File.open("foo", 'w') do |f|
        f << 'Yada Yada'
        assert_nothing_raised do
          f.fdatasync
        end
      end
    end

    def test_autoclose
      File.open("foo", 'w') do |f|
        assert_equal true, f.autoclose?
        f.autoclose = false
        assert_equal false, f.autoclose?
      end
    end

    def test_to_path
      File.new("foo", 'w') do |f|
        assert_equal "foo", f.to_path
      end
    end
  end

  if RUBY_VERSION >= "1.9.3"
    def test_advise
      File.open("foo", 'w') do |f|
        assert_nothing_raised do
          f.advise(:normal, 0, 0)
        end
      end
    end

    def test_file_write_can_write_a_file
      File.write("testfile", "0123456789")
      assert_equal File.read("testfile"), "0123456789"
    end

    def test_file_write_returns_the_length_written
      assert_equal File.write("testfile", "0123456789"), 10
    end

    def test_file_write_truncates_file_if_offset_not_given
      File.open("foo", 'w') do |f|
        f << "foo"
      end

      File.write('foo', 'bar')
      assert_equal File.read('foo'), 'bar'
    end

    def test_file_write_writes_at_offset_and_does_not_truncate
      File.open("foo", 'w') do |f|
        f << "foo"
      end

      File.write('foo', 'bar', 3)
      assert_equal File.read('foo'), 'foobar'
    end

    def test_can_read_binary_data_in_binary_mode
      File.open('foo', 'wb') { |f| f << "\u0000\u0000\u0000\u0003\u0000\u0003\u0000\xA3\u0000\u0000\u0000y\u0000\u0000\u0000\u0000\u0000" }
      assert_equal "\x00\x00\x00\x03\x00\x03\x00\xA3\x00\x00\x00y\x00\x00\x00\x00\x00", File.open("foo", "rb").read
    end

    def test_can_read_binary_data_in_non_binary_mode
      File.open('foo_non_bin', 'wb') { |f| f << "\u0000\u0000\u0000\u0003\u0000\u0003\u0000\xA3\u0000\u0000\u0000y\u0000\u0000\u0000\u0000\u0000" }
      assert_equal "\x00\x00\x00\x03\x00\x03\x00\xA3\x00\x00\x00y\x00\x00\x00\x00\x00".force_encoding('UTF-8'), File.open("foo_non_bin", "r").read
    end
  end
end
