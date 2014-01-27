require 'spec_helper'

require 'tmpdir'
require 'fileutils'
require 'bosh/director/core/tar_gzipper'

module Bosh::Director::Core
  describe TarGzipper do
    let(:base_dir) { Dir.mktmpdir }
    let(:sources) { %w(1 one) }
    let(:dest) { Tempfile.new('logs') } # must keep tempfile reference lest it rm
    let(:errored_retval) { ['stdout string', 'a stderr message', double('Status', success?: false, exitstatus: 5)] }
    let(:success_retval) { ['', '', double('Status', success?: true)] }

    before do
      path = File.join(base_dir, '1', '2')
      FileUtils.mkdir_p(path)
      File.write(File.join(path, 'hello.log'), 'hello')

      path = File.join(base_dir, 'one', 'two')
      FileUtils.mkdir_p(path)
      File.write(File.join(path, 'goodbye.log'), 'goodbye')
    end

    after do
      FileUtils.rm_rf(base_dir)
      FileUtils.rm_rf(dest.path)
    end

    context 'when copy first feature is enabled' do
      it 'copies the files to a temp directory before archiving' do
        Dir.stub(:mktmpdir).and_yield('/tempthing')
        FileUtils.should_receive(:cp_r).with(%w(/foo/baz /foo/bar), '/tempthing/')
        Pathname.stub(:new).and_return(instance_double('Pathname', exist?: true, absolute?: true))

        Open3.should_receive(:capture3)
        .with(*%w(tar -C /tempthing -czf /tmp/backup.tgz baz bar))
        .and_return(success_retval)

        subject.compress('/foo', %w(baz bar), '/tmp/backup.tgz', copy_first: true)
      end
    end

    it 'raises when a source has a path depth greater than 1' do # sources that contain a '/'
      expect {
        subject.compress('/var/vcap/foo', %w(foo/bar), '/tmp/backup.tgz')
      }.to raise_error("Sources must have a path depth of 1 and contain no '/'")
    end

    context 'if the source directory does not exist' do
      let(:base_dir) { '/tmp/this/is/not/here' }

      it 'raises an error' do
        FileUtils.rm_rf(base_dir)

        expect {
          subject.compress(base_dir, sources, dest.path)
        }.to raise_error("The base directory #{base_dir} could not be found.")
      end
    end

    context 'if the base_dir is not absolute' do
      let(:base_dir) { 'tmp' }

      it 'raises an error' do
        expect {
          subject.compress(base_dir, sources, dest.path)
        }.to raise_error("The base directory #{base_dir} is not an absolute path.")
      end
    end

    it 'packages the sources into the destination tarball' do
      subject.compress(base_dir, sources, dest.path)

      output = `tar tzvf #{dest.path}`
      expect(output).to include(' 1/2/hello.log')
      expect(output).to include(' one/two/goodbye.log')
    end

    it 'raises if it fails to tar' do
      Open3.stub(:capture3).and_return(errored_retval)
      expect {
        subject.compress(base_dir, sources, dest)
      }.to raise_error(RuntimeError,
                       "tar exited 5, output: 'stdout string', error: 'a stderr message'")
    end
  end
end
