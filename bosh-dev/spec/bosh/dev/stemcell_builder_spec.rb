require 'spec_helper'
require 'fakefs/spec_helpers'
require 'bosh/dev/stemcell_builder'

module Bosh::Dev
  describe StemcellBuilder do
    include FakeFS::SpecHelpers

    describe '.for_candidate_build' do
      before { Build.stub(candidate: build) }
      let(:build) { instance_double('Bosh::Dev::Build::Candidate') }
      let(:definition) { instance_double('Bosh::Stemcell::Definition') }

      it 'returns an instance of stemcell builder' do
        builder = instance_double('Bosh::Dev::StemcellBuilder')
        described_class.should_receive(:new).with(
          ENV,
          build,
          definition
        ).and_return(builder)

        allow(Bosh::Stemcell::Definition).to receive(:for).and_return(definition)

        expect(described_class.for_candidate_build(
          'infrastructure-name',
          'operating-system-name',
          'ruby-agent',
        )).to eq builder

        expect(Bosh::Stemcell::Definition).to have_received(:for)
                                              .with('infrastructure-name', 'operating-system-name', 'ruby-agent')
      end
    end

    describe '#build_stemcell' do
      subject(:builder) do
        StemcellBuilder.new(
          env,
          build,
          definition,
        )
      end

      let(:env) { {} }
      let(:build) do
        instance_double(
          'Bosh::Dev::Build::Candidate',
          release_tarball_path: 'release-tarball-path',
          number: build_number,
        )
      end
      let(:infrastructure_name) { 'vsphere' }
      let(:operating_system_name) { 'ubuntu' }
      let(:agent_name) { 'ruby' }
      let(:definition) { instance_double('Bosh::Stemcell::Definition') }

      let(:build_number) { '869' }

      before { GemComponents.stub(new: gem_components) }
      let(:gem_components) { instance_double('Bosh::Dev::GemComponents', build_release_gems: nil) }

      let(:stemcell_builder_command) do
        instance_double('Bosh::Stemcell::BuilderCommand', build: nil, chroot_dir: '/fake/chroot/dir')
      end

      let(:fake_work_path) { '/fake/work/path' }
      let(:stemcell_file_path) { File.join(fake_work_path, 'FAKE-stemcell.tgz') }

      before do
        Bosh::Stemcell::BuilderCommand.stub(:new).with(
          env,
          definition,
          build_number,
          build.release_tarball_path
        ).and_return(stemcell_builder_command)
      end

      its(:stemcell_chroot_dir) { should eq('/fake/chroot/dir') }

      before do
        stemcell_builder_command.stub(:build) do
          FileUtils.mkdir_p(fake_work_path)
          FileUtils.touch(stemcell_file_path)
          stemcell_file_path
        end
      end

      it 'generates the bosh gems' do
        gem_components.should_receive(:build_release_gems)

        builder.build_stemcell
      end

      it 'creates a basic stemcell and returns its absolute path' do
        expect(builder.build_stemcell).to eq('/fake/work/path/FAKE-stemcell.tgz')
      end

      it 'creates a basic stemcell' do
        expect {
          builder.build_stemcell
        }.to change { File.exist?('/fake/work/path/FAKE-stemcell.tgz') }.to(true)
      end

      context 'when the stemcell is not created' do
        before do
          stemcell_builder_command.stub(build: stemcell_file_path)
        end

        it 'fails early and loud' do
          expect {
            builder.build_stemcell
          }.to raise_error("#{stemcell_file_path} does not exist")
        end
      end
    end
  end
end
