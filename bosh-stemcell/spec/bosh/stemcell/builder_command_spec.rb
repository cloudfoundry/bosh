require 'spec_helper'
require 'bosh/stemcell/builder_command'
require 'bosh/stemcell/build_environment'
require 'bosh/stemcell/stage_collection'
require 'bosh/stemcell/stage_runner'

module Bosh::Stemcell
  describe BuilderCommand do
    subject(:stemcell_builder_command) do
      described_class.new(
        helper,
        collection,
        runner
      )
    end

    let(:env) { {} }

    let(:agent) { Bosh::Stemcell::Agent.for('ruby') }
    let(:expected_agent_name) { 'ruby' }

    let(:release_tarball_path) { "/fake/path/to/bosh-#{version}.tgz" }
    let(:version) { '007' }

    let(:definition) do
      instance_double(
        'Bosh::Stemcell::Definition',
        agent: agent,
      )
    end

    let(:shell) { instance_double(Bosh::Core::Shell) }

    let(:helper) { instance_double('Bosh::Stemcell::BuildEnvironment',
                                   prepare_build: nil, chroot_dir: File.join(root_dir, 'work', 'work', 'chroot'),
                                   rspec_command: nil, stemcell_file: nil,
    ) }

    let(:collection) do
      instance_double(
        'Bosh::Stemcell::StageCollection',
        operating_system_stages: os_stages,
        agent_stages: %w(FAKE_AGENT_STAGES),
        infrastructure_stages: %w(FAKE_INFRASTRUCTURE_STAGES)
      )
    end

    let(:runner) { instance_double('Bosh::Stemcell::StageRunner', configure_and_apply: nil) }

    let(:download_adapter) { instance_double('Bosh::Dev::DownloadAdapter', download: nil) }
    let(:work_root) { File.join(root_dir, 'work') }

    before do
      allow(shell).to receive(:run)
      allow(Bosh::Core::Shell).to receive(:new).and_return(shell)
      #allow(Bosh::Dev::DownloadAdapter).to receive(:new).and_return(download_adapter)
    end

    let(:root_dir) { '/mnt/stemcells/dummy/dummy/dummy' }

    let(:stemcell_builder_options) do
      instance_double('Bosh::Stemcell::BuilderOptions', default: options)
    end

    let(:os_stages) do
      %w(FAKE_OS_STAGES)
    end

    let(:etc_dir) { File.join(root_dir, 'build', 'build', 'etc') }
    let(:settings_file) { File.join(etc_dir, 'settings.bash') }

    let(:options) do
      {
        'hello'               => 'world',
        'stemcell_tgz'        => 'fake-stemcell.tgz',
        'stemcell_image_name' => 'fake-root-disk-image.raw'
      }
    end

    its(:chroot_dir) { should eq(File.join(root_dir, 'work', 'work', 'chroot')) }

    describe '#build' do
      include FakeFS::SpecHelpers

      before do
        Process.stub(pid: 99999)

        stemcell_builder_command.stub(system: true)
        FileUtils.touch('leftover.tgz')

        FileUtils.stub(:cp_r).with([], File.join(root_dir, 'build', 'build'), preserve: true, verbose: true) do
          FileUtils.mkdir_p(etc_dir)
          FileUtils.touch(settings_file)
        end
      end

      describe 'running stages' do
        it 'calls #configure_and_apply' do
          runner.should_receive(:configure_and_apply).
            with(%w(FAKE_AGENT_STAGES FAKE_INFRASTRUCTURE_STAGES)).ordered

          stemcell_builder_command.build
        end
      end
    end

    describe '#build_base_image_for_stemcell' do
      it 'builds correct stages' do
        expect(runner).to receive(:configure_and_apply).with(os_stages)

        stemcell_builder_command.build_base_image_for_stemcell
      end
    end

    describe '#download_and_extract_base_os_image' do
      #before { allow(File).to receive(:open) }

      xit 'utilizes download adapter to download and extracts the file to the work dir' do
        expect(download_adapter).to receive(:download).with('fake://uri', '/tmp/base_os_image.tgz')
        expect(shell).to receive(:run).with("tar -xzf -C #{File.join(work_root, 'work')} /tmp/base_os_image.tgz")

        stemcell_builder_command.download_and_extract_base_os_image('fake://uri')
      end
    end
  end
end
