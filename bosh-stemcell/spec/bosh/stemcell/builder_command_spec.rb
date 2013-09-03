require 'spec_helper'

require 'bosh/stemcell/builder_command'

module Bosh::Stemcell
  describe BuilderCommand do
    let(:root_dir) { '/mnt/root' }
    let(:environment_hash) { {} }

    let(:stemcell_builder_options) do
      instance_double('Bosh::Stemcell::BuilderOptions',
                      default: options,
                      spec_name: 'FAKE_SPEC_NAME')
    end
    let(:stemcell_environment) do
      instance_double('Bosh::Stemcell::Environment',
                      sanitize: nil,
                      build_path: File.join(root_dir, 'build'),
                      work_path: File.join(root_dir, 'work'))
    end

    let(:version) { '007' }
    let(:release_tarball_path) { "/fake/path/to/bosh-#{version}.tgz" }
    let(:infrastructure) { instance_double('Bosh::Stemcell::Infrastructure::Vsphere', name: 'vsphere') }
    let(:operating_system) { instance_double('Bosh::Stemcell::OperatingSystem::Ubuntu', name: 'ubuntu') }
    let(:stage_collection) { instance_double('Bosh::Stemcell::StageCollection::Base', stages: 'FAKE_STAGES') }
    let(:stage_runner) { instance_double('Bosh::Stemcell::StageRunner', configure_and_apply: nil) }

    subject(:stemcell_builder_command) do
      BuilderCommand.new(infrastructure_name: infrastructure.name,
                         operating_system_name: operating_system.name,
                         release_tarball_path: release_tarball_path,
                         version: version)
    end

    before do
      ENV.stub(to_hash: environment_hash)

      Infrastructure.stub(:for).with('vsphere').and_return(infrastructure)
      OperatingSystem.stub(:for).with('ubuntu').and_return(operating_system)
      StageCollection.stub(:for).with('FAKE_SPEC_NAME').and_return(stage_collection)

      StageRunner.stub(:new).with(stages: 'FAKE_STAGES',
                                  build_path: File.join(root_dir, 'build', 'build'),
                                  command_env: 'env ',
                                  settings_file: settings_file,
                                  work_path: File.join(root_dir, 'work')).and_return(stage_runner)

      Environment.stub(:new).with(infrastructure_name: infrastructure.name).and_return(stemcell_environment)
      BuilderOptions.stub(:new).with(tarball: release_tarball_path,
                                     stemcell_version: version,
                                     infrastructure: infrastructure,
                                     operating_system: operating_system).and_return(stemcell_builder_options)
    end

    let(:etc_dir) { File.join(File.join(root_dir, 'build', 'build'), 'etc') }
    let(:settings_file) { File.join(etc_dir, 'settings.bash') }

    let(:options) { { 'hello' => 'world', 'stemcell_tgz' => 'fake-stemcell.tgz' } }

    its(:chroot_dir) { should eq(File.join(root_dir, 'work', 'work', 'chroot')) }

    describe '#build' do
      include FakeFS::SpecHelpers

      before do
        Process.stub(pid: 99999)

        FileUtils.stub(:cp_r).with([], File.join(root_dir, 'build', 'build'), preserve: true, verbose: true) do
          FileUtils.mkdir_p(etc_dir)
          FileUtils.touch(settings_file)
        end
      end

      it 'sanitizes the stemcell environment' do
        stemcell_environment.should_receive(:sanitize)

        stemcell_builder_command.build
      end

      it 'returns the full path of the generated stemcell archive' do
        expect(stemcell_builder_command.build).to eq(File.join(root_dir, 'work', 'work', 'fake-stemcell.tgz'))
      end

      it 'creates a base directory for stemcell creation' do
        expect {
          stemcell_builder_command.build
        }.to change { Dir.exists?(root_dir) }.from(false).to(true)
      end

      it 'creates a build directory for stemcell creation' do
        expect {
          stemcell_builder_command.build
        }.to change { Dir.exists?(File.join(root_dir, 'build')) }.from(false).to(true)
      end

      it 'copies the stemcell_builder code into the build directory' do
        FileUtils.should_receive(:cp_r).with([],
                                             File.join(root_dir, 'build', 'build'),
                                             preserve: true,
                                             verbose: true) do
          FileUtils.mkdir_p(etc_dir)
          FileUtils.touch(settings_file)
        end

        stemcell_builder_command.build
      end

      it 'creates a work directory for stemcell creation chroot' do
        expect {
          stemcell_builder_command.build
        }.to change { Dir.exists?(File.join(root_dir, 'work')) }.from(false).to(true)
      end

      it 'writes a settings file into the build directory' do
        stemcell_builder_command.build

        expect(File.read(settings_file)).to match(/hello=world/)
      end

      context 'when ENV contains variables besides HTTP_PROXY and NO_PROXY' do
        let(:environment_hash) do
          {
            'NOT_HTTP_PROXY' => 'nice_proxy',
            'no_proxy_just_kidding' => 'naughty_proxy'
          }
        end

        it 'nothing is passed to sudo via "env"' do
          StageRunner.stub(:new).with(stages: 'FAKE_STAGES',
                                      build_path: File.join(root_dir, 'build', 'build'),
                                      command_env: 'env ',
                                      settings_file: settings_file,
                                      work_path: File.join(root_dir, 'work')).and_return(stage_runner)

          stemcell_builder_command.build
        end
      end

      context 'ENV variables for HTTP_PROXY and NO_PROXY are passed to "env"' do
        let(:environment_hash) do
          {
            'HTTP_PROXY' => 'nice_proxy',
            'no_proxy' => 'naughty_proxy'
          }
        end

        it 'they are passed to sudo via "env"' do
          StageRunner.stub(:new).with(stages: 'FAKE_STAGES',
                                      build_path: File.join(root_dir, 'build', 'build'),
                                      command_env: "env HTTP_PROXY='nice_proxy' no_proxy='naughty_proxy'",
                                      settings_file: settings_file,
                                      work_path: File.join(root_dir, 'work')).and_return(stage_runner)

          stemcell_builder_command.build
        end
      end
    end
  end
end
