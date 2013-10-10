require 'spec_helper'
require 'bosh/dev/gem_artifact'
require 'bosh/dev/gem_component'

module Bosh::Dev
  describe GemArtifact do
    describe '#promote' do
      include FakeFS::SpecHelpers

      let(:component) do
        instance_double('Bosh::Dev::GemComponent', dot_gem: 'bosh-foo-1.5.0.pre.789.gem')
      end

      subject(:gem_artifact) do
        GemArtifact.new(component, 's3://bosh-ci-pipeline/1234', '1234')
      end

      before do
        RakeFileUtils.stub(:sh)
        FileUtils.mkdir_p('~/.gem')
        FileUtils.touch('~/.gem/credentials')
      end

      it 'creates a temporary directory to place downloaded gems' do
        expect { gem_artifact.promote }.to change { File.directory?('tmp/gems-1234') }.to(true)
      end

      it 'downloads the gem from the pipeline bucket' do
        RakeFileUtils.should_receive(:sh).with('s3cmd --verbose get s3://bosh-ci-pipeline/1234/gems/gems/bosh-foo-1.5.0.pre.789.gem tmp/gems-1234')

        gem_artifact.promote
      end

      it 'pushes the downloaded gem' do
        RakeFileUtils.should_receive(:sh).with('gem push tmp/gems-1234/bosh-foo-1.5.0.pre.789.gem')

        gem_artifact.promote
      end

      it 'fails with a debuggable error if the RubyGems credentials are missing' do
        FileUtils.rm('~/.gem/credentials')
        expect { gem_artifact.promote }.to raise_error("Your rubygems.org credentials aren't set. Run `gem push` to set them.")
      end
    end
  end
end
