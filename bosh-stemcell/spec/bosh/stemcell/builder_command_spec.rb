require 'spec_helper'
require 'bosh/stemcell/builder_command'

module Bosh::Stemcell
  describe BuilderCommand do
    subject(:stemcell_builder_command) do
      described_class.new(
        env,
        definition,
        version,
        release_tarball_path,
      )
    end

    let(:env) { {} }

    let(:agent) { Bosh::Stemcell::Agent.for('ruby') }
    let(:expected_agent_name) { 'ruby' }

    let(:infrastructure) do
      Bosh::Stemcell::Infrastructure.for('vsphere')
    end

    let(:operating_system) { Bosh::Stemcell::OperatingSystem.for('ubuntu') }
    let(:release_tarball_path) { "/fake/path/to/bosh-#{version}.tgz" }
    let(:version) { '007' }

    let(:definition) do
      instance_double(
        'Bosh::Stemcell::Definition',
        infrastructure: infrastructure,
        operating_system: operating_system,
        agent: agent,
      )
    end

    let(:shell) { instance_double(Bosh::Core::Shell) }

    before do
      StageCollection.stub(:new).with(definition).and_return(stage_collection)

      StageRunner.stub(:new).with(
        build_path: File.join(root_dir, 'build', 'build'),
        command_env: 'env ',
        settings_file: settings_file,
        work_path: File.join(root_dir, 'work')
      ).and_return(stage_runner)

      BuilderOptions.stub(:new).with(
        env,
        definition,
        version,
        release_tarball_path,
      ).and_return(stemcell_builder_options)

      allow(shell).to receive(:run)
      allow(Bosh::Core::Shell).to receive(:new).and_return(shell)
    end

    let(:root_dir) do
      File.join('/mnt/stemcells', infrastructure.name, infrastructure.hypervisor, operating_system.name)
    end

    let(:stemcell_builder_options) do
      instance_double('Bosh::Stemcell::BuilderOptions', default: options)
    end

    let(:stage_collection) do
      instance_double(
        'Bosh::Stemcell::StageCollection',
        operating_system_stages: %w(FAKE_OS_STAGES),
        agent_stages: %w(FAKE_AGENT_STAGES),
        infrastructure_stages: %w(FAKE_INFRASTRUCTURE_STAGES)
      )
    end

    let(:stage_runner) { instance_double('Bosh::Stemcell::StageRunner', configure_and_apply: nil) }

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
          stage_runner.should_receive(:configure_and_apply).
            with(%w(FAKE_OS_STAGES FAKE_AGENT_STAGES FAKE_INFRASTRUCTURE_STAGES)).ordered
          stemcell_builder_command.build
        end
      end

      context 'when ENV contains variables besides HTTP_PROXY and NO_PROXY' do
        let(:env) do
          {
            'NOT_HTTP_PROXY' => 'nice_proxy',
            'no_proxy_just_kidding' => 'naughty_proxy'
          }
        end

        it 'nothing is passed to sudo via "env"' do
          StageRunner.stub(:new).with(build_path: File.join(root_dir, 'build', 'build'),
                                      command_env: 'env ',
                                      settings_file: settings_file,
                                      work_path: File.join(root_dir, 'work')).and_return(stage_runner)

          stemcell_builder_command.build
        end
      end

      context 'ENV variables for HTTP_PROXY and NO_PROXY are passed to "env"' do
        let(:env) do
          {
            'HTTP_PROXY' => 'nice_proxy',
            'no_proxy' => 'naughty_proxy'
          }
        end

        it 'they are passed to sudo via "env"' do
          StageRunner.stub(:new).with(build_path: File.join(root_dir, 'build', 'build'),
                                      command_env: "env HTTP_PROXY='nice_proxy' no_proxy='naughty_proxy'",
                                      settings_file: settings_file,
                                      work_path: File.join(root_dir, 'work')).and_return(stage_runner)

          stemcell_builder_command.build
        end
      end
    end
  end
end
