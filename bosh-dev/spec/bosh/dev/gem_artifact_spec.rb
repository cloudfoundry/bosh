require 'spec_helper'
require 'bosh/dev/gem_artifact'
require 'bosh/dev/gem_component'

module Bosh::Dev
  describe GemArtifact do
    include FakeFS::SpecHelpers

    describe '#promote' do
      let(:component) do
        instance_double('Bosh::Dev::GemComponent', dot_gem: 'bosh-foo-1.5.0.pre.789.gem')
      end

      subject(:gem_artifact) do
        GemArtifact.new(component, 's3://bosh-ci-pipeline/1234/', '1234')
      end

      before do
        RakeFileUtils.stub(:sh)
        FileUtils.mkdir_p('~/.gem')
        FileUtils.touch('~/.gem/credentials')
        subject.stub(:puts)
        subject.stub(:warn)
      end

      it 'creates a temporary directory to place downloaded gems' do
        expect { gem_artifact.promote }.to change { File.directory?('tmp/gems-1234') }.to(true)
      end

      it 'clears out the temporary directory if it already exists to avoid promoting bad gems' do
        FileUtils.mkdir_p('tmp/gems-1234')
        FileUtils.touch("tmp/gems-1234/#{component.dot_gem}")
        expect { gem_artifact.promote }.to change { File.exist?("tmp/gems-1234/#{component.dot_gem}") }.to(false)
      end

      it 'downloads the gem from the pipeline bucket' do
        RakeFileUtils.should_receive(:sh).with('s3cmd --verbose get s3://bosh-ci-pipeline/1234/gems/gems/bosh-foo-1.5.0.pre.789.gem tmp/gems-1234')

        gem_artifact.promote
      end

      it 'pushes the downloaded gem' do
        RakeFileUtils.should_receive(:sh).with('gem push tmp/gems-1234/bosh-foo-1.5.0.pre.789.gem')

        gem_artifact.promote
      end

      it 'avoids bleeding bundler ENV stuff into the gem push' do
        stub_const('ENV', { 'BUNDLE_STUFF' => '123' })
        RakeFileUtils.stub(:sh) do |cmd|
          expect(ENV.keys.grep(/BUNDLE/)).to eq([]) if cmd =~ /gem push/
        end

        gem_artifact.promote
      end

      it 'fails with a debuggable error if the RubyGems credentials are missing' do
        FileUtils.rm('~/.gem/credentials')
        expect {
          gem_artifact.promote
        }.to raise_error("Your rubygems.org credentials aren't set. Run `gem push` to set them.")
      end

      it 'expands the path to the .gem dir since File.exists? does not like "~" in the path' do
        expect(File).to receive(:exists?) do |path|
          expect(path).not_to include('~')
          path != "tmp/gems-1234/#{component.dot_gem}"
        end.at_least(1)

        gem_artifact.promote
      end
    end
  end
end
