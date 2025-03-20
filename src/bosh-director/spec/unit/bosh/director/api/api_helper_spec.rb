require 'spec_helper'

describe Bosh::Director::Api::ApiHelper do
  include Bosh::Director::Api::ApiHelper

  before(:each) do
    @tmpdir = Dir.mktmpdir('base_dir')
  end

  describe :check_available_disk_space do
    before :each do
      @stat = double('stat')
      allow(Sys::Filesystem).to receive(:stat).and_return(@stat)
    end

    it 'should return true if there is available disk space' do
      expect(@stat).to receive(:block_size).and_return(1024)
      expect(@stat).to receive(:blocks_available).and_return(1024)
      expect(check_available_disk_space(@tmpdir, 1048)).to be(true)
    end

    it 'should return false if there is no available disk space' do
      expect(@stat).to receive(:block_size).and_return(1024)
      expect(@stat).to receive(:blocks_available).and_return(1)
      expect(check_available_disk_space(@tmpdir, 1048)).to be(false)
    end

    it 'should return false if there is an exception when checking dir stats' do
      expect(@stat).to receive(:block_size).and_raise(Errno::EACCES)
      expect(check_available_disk_space(@tmpdir, 1048)).to be(false)
    end
  end

  describe :write_file do
    it 'should write a file' do
      file_in = StringIO.new('contents')
      file_out = File.join(@tmpdir, SecureRandom.uuid)

      write_file(file_out, file_in)
      expect(File.read(file_out)).to eq('contents')
    end

    it "should raise an exception if there's any system error call" do
      file_in = StringIO.new('contents')
      file_out = File.join(@tmpdir, SecureRandom.uuid)
      expect(File).to receive(:open).with(file_out, 'w').and_raise(Errno::ENOSPC)

      expect {
        write_file(file_out, file_in)
      }.to raise_exception(Bosh::Director::SystemError)
    end
  end

  describe :validate_manifest_yml do
    it 'should handle empty manifest' do
      expect {
        validate_manifest_yml('')
      }.to raise_exception(Bosh::Director::BadManifest, 'Manifest should not be empty')
    end

    it 'should handle YAML-nil' do
      expect {
        validate_manifest_yml("--- \n...\n")
      }.to raise_exception(Bosh::Director::BadManifest, 'Manifest should be a hash')
    end

    it 'should handle Syntax Error' do
      yml = <<-FOO
foo
  k: v
FOO
      expect {
        validate_manifest_yml(yml)
      }.to raise_exception(Bosh::Director::BadManifest, /Incorrect YAML structure of the uploaded manifest: /)
    end

    it 'should include context in error message' do
      yml = <<-FOO
foo
  k: v
FOO
      expect {
        validate_manifest_yml(yml)
      }.to raise_exception(Bosh::Director::BadManifest, /context/)
    end

    it 'should handle alias errors' do
      yml = <<-FOO
foo:
  k: *v
FOO
      expect {
        validate_manifest_yml(yml)
      }.to raise_exception(Bosh::Director::BadManifest, /Incorrect YAML structure of the uploaded manifest: /)
    end

    context 'when YAML file is valid' do
      it 'should return a ruby hash' do
        yml = <<-FOO
foo:
  k: v
FOO

        expect(validate_manifest_yml(yml)).to eq({'foo' => {'k' => 'v'}})
      end
    end
  end
end
