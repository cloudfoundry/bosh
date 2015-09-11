require 'spec_helper'
require 'bosh/dev/gem_artifact'
require 'bosh/dev/gem_component'

module Bosh::Dev
  describe GemArtifact do
    include FakeFS::SpecHelpers

    subject(:gem_artifact) do
      GemArtifact.new(component, 's3://bosh-ci-pipeline/1234/', '1234', logger)
    end

    let(:component) { instance_double('Bosh::Dev::GemComponent') }
    before do
      allow(component).to receive(:name).and_return('bosh-foo')
      allow(component).to receive(:version).and_return('1.5.0.pre.789')
      allow(component).to receive(:dot_gem).and_return('bosh-foo-1.5.0.pre.789.gem')
    end

    let(:credentials_path) { File.expand_path('~/.gem/credentials') }

    before do
      FileUtils.mkdir_p(File.dirname(credentials_path))
      FileUtils.touch(credentials_path)
      allow(subject).to receive(:puts)
      allow(subject).to receive(:warn)
    end

    describe '#promote' do
      let(:download_cmd) do
        source = 's3://bosh-ci-pipeline/1234/gems/gems/bosh-foo-1.5.0.pre.789.gem'
        destination = 'tmp/gems-1234'
        "s3cmd --verbose get #{source} #{destination}"
      end

      let(:local_gem_path) { "tmp/gems-1234/#{component.dot_gem}" }
      let(:push_cmd) { "gem push #{local_gem_path}" }

      before do
        allow(Open3).to receive(:capture3).with(download_cmd).
          and_return([ nil, nil, instance_double('Process::Status', success?: true) ])

        allow(Open3).to receive(:capture3).with(push_cmd).
          and_return([ nil, nil, instance_double('Process::Status', success?: true) ])
      end

      it 'creates a temporary directory to place downloaded gems' do
        expect { gem_artifact.promote }.to change { File.directory?('tmp/gems-1234') }.to(true)
      end

      it 'clears out the temporary directory if it already exists to avoid promoting bad gems' do
        FileUtils.mkdir_p('tmp/gems-1234')
        FileUtils.touch(local_gem_path)
        expect { gem_artifact.promote }.to change { File.exist?(local_gem_path) }.to(false)
      end

      it 'downloads the gem from the pipeline bucket' do
        expect(Open3).to receive(:capture3).with(download_cmd).
          and_return([ nil, nil, instance_double('Process::Status', success?: true) ])

        gem_artifact.promote
      end

      it 'pushes the downloaded gem' do
        expect(Open3).to receive(:capture3).with(push_cmd).
          and_return([ nil, nil, instance_double('Process::Status', success?: true) ])

        gem_artifact.promote
      end

      it 'avoids bleeding bundler ENV stuff into the gem push' do
        stub_const('ENV', { 'BUNDLE_STUFF' => '123' })

        expect(Open3).to receive(:capture3).with(push_cmd) do
          expect(ENV.keys.grep(/BUNDLE/)).to eq([])
          [ nil, nil, instance_double('Process::Status', success?: true) ]
        end

        gem_artifact.promote
      end

      it 'fails with a debuggable error if the RubyGems credentials are missing' do
        FileUtils.rm(credentials_path)
        expect {
          gem_artifact.promote
        }.to raise_error("Your rubygems.org credentials aren't set. Run `gem push` to set them.")
      end

      it 'expands the path to the .gem dir since File.exists? does not like "~" in the path' do
        expect(File).to receive(:exists?) do |path|
          expect(path).not_to include('~')
          path != local_gem_path
        end.at_least(1)

        gem_artifact.promote
      end
    end

    describe '#promoted?' do
      let(:query_cmd) { "gem query -r -a -n bosh\\-foo" }

      it 'returns true if the gem name & version exist in the remote gem repo' do
        stdout = <<-EOS
bosh-foo (1.5.0.pre.789, 1.5.0.pre.788, 1.4.9)
not-bosh-foo (1.5.0, 1.4.9)
bosh-foo-plus-plus (1.0.0)
EOS
        expect(Open3).to receive(:capture3).with(query_cmd).
          and_return([ stdout, nil, instance_double('Process::Status', success?: true) ])

        expect(gem_artifact.promoted?).to be(true)
      end

      it 'returns false if the gem (by name) does not exist in the remote gem repo' do
        stdout = <<-EOS
not-bosh-foo (1.5.0.pre.789)
EOS
        expect(Open3).to receive(:capture3).with(query_cmd).
          and_return([ stdout, nil, instance_double('Process::Status', success?: true) ])

        expect(gem_artifact.promoted?).to be(false)
      end

      it 'returns false if the gem (by version) does not exist in the remote gem repo' do
        stdout = <<-EOS
bosh-foo (0.2.3, 0.2.2, 0.2.1, 0.2.0)
EOS
        expect(Open3).to receive(:capture3).with(query_cmd).
          and_return([ stdout, nil, instance_double('Process::Status', success?: true) ])

        expect(gem_artifact.promoted?).to be(false)
      end

      it 'avoids bleeding bundler ENV stuff into the gem query' do
        stub_const('ENV', { 'BUNDLE_STUFF' => '123' })

        expect(Open3).to receive(:capture3).with(query_cmd) do
          expect(ENV.keys.grep(/BUNDLE/)).to eq([])
          [ '', nil, instance_double('Process::Status', success?: true) ]
        end

        gem_artifact.promoted?
      end
    end
  end
end
