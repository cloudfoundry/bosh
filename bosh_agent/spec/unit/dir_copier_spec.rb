require 'spec_helper'
require 'bosh_agent/dir_copier'
require 'tmpdir'
require 'fileutils'

describe Bosh::Agent::DirCopier do
  describe '#migrate' do
    before do
      @source = Dir.mktmpdir
      @destination = Dir.mktmpdir
    end

    after do
      FileUtils.remove_entry_secure(@source)
      FileUtils.remove_entry_secure(@destination)
    end

    it 'copies files in source directory into destination, preserving metadata' do
      copier = Bosh::Agent::DirCopier.new(@source, @destination)

      source_file_path = File.join(@source, 'foo')
      File.write(source_file_path, 'fake file content')
      source_stat = File.lstat(source_file_path)

      copier.copy
      destination_file_path = File.join(@destination, 'foo')
      destination_stat = File.lstat(destination_file_path)

      source_stat.should eq(destination_stat)
    end
  end
end
