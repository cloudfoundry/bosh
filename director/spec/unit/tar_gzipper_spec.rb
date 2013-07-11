require 'spec_helper'

require 'tmpdir'
require 'fileutils'

describe Bosh::Director::TarGzipper do
  let(:base_dir) { Dir.mktmpdir }
  let(:sources) { %w(1 one) }
  let(:dest) { Tempfile.new('logs') } #must keep tempfile reference lest it rm
  let(:errored_status) { double('Status', success?: false, exitstatus: 5) }

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
    Open3.stub(:capture3).and_return(['stdout string', 'a stderr message', errored_status])
    expect{subject.compress(base_dir, sources, dest)}.to raise_error(RuntimeError, "tar exited 5, output: 'stdout string', error: 'a stderr message'")
  end
end
