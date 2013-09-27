require 'spec_helper'
require 'bosh/stemcell/builder_command'

module Bosh::Stemcell
  describe BuilderCommand do
    subject(:stemcell_builder_command) do
      described_class.new(
        env,
        infrastructure_name: infrastructure.name,
        operating_system_name: operating_system.name,
        release_tarball_path: release_tarball_path,
        version: version
      )
    end

    let(:env) { {} }

    let(:infrastructure) do
      instance_double(
        'Bosh::Stemcell::Infrastructure::Vsphere',
        name: 'vsphere',
        hypervisor: 'esxi'
      )
    end

    let(:operating_system) { instance_double('Bosh::Stemcell::OperatingSystem::Ubuntu', name: 'ubuntu') }
    let(:release_tarball_path) { "/fake/path/to/bosh-#{version}.tgz" }
    let(:version) { '007' }

    before do
      Infrastructure.stub(:for).with('vsphere').and_return(infrastructure)
      OperatingSystem.stub(:for).with(operating_system.name).and_return(operating_system)
      StageCollection.stub(:new).with(
        infrastructure: infrastructure,
        operating_system: operating_system
      ).and_return(stage_collection)

      StageRunner.stub(:new).with(
        build_path: File.join(root_dir, 'build', 'build'),
        command_env: 'env ',
        settings_file: settings_file,
        work_path: File.join(root_dir, 'work')
      ).and_return(stage_runner)

      BuilderOptions.stub(:new).with(
        env,
        tarball: release_tarball_path,
        stemcell_version: version,
        infrastructure: infrastructure,
        operating_system: operating_system
      ).and_return(stemcell_builder_options)
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
        operating_system_stages: ['FAKE_OS_STAGES'],
        infrastructure_stages: ['FAKE_INFRASTRUCTURE_STAGES']
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

      describe 'sanitizing the environment' do
        it 'removes any tgz files from current working directory' do
          expect {
            stemcell_builder_command.build
          }.to change { Dir.glob('*.tgz').size }.to(0)
        end

        it 'unmounts the disk image used to install Grub' do
          image_path = File.join(root_dir, 'work/work/mnt/tmp/grub/fake-root-disk-image.raw')
          unmount_img_command = "sudo umount #{image_path} 2> /dev/null"
          stemcell_builder_command.should_receive(:system).with(unmount_img_command)
          stemcell_builder_command.build
        end

        it 'unmounts work/work/mnt directory' do
          unmount_dir_command = "sudo umount #{File.join(root_dir, 'work/work/mnt')} 2> /dev/null"
          stemcell_builder_command.should_receive(:system).with(unmount_dir_command)
          stemcell_builder_command.build
        end

        it 'removes stemcell root directory' do
          stemcell_builder_command.should_receive(:system).with("sudo rm -rf #{root_dir}")
          stemcell_builder_command.build
        end
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

      describe 'running stages' do
        let(:expected_rspec_command) do
          [
            "cd #{File.expand_path('../../..', File.dirname(__FILE__))};",
            "STEMCELL_IMAGE=#{File.join(root_dir, 'work', 'work', 'fake-root-disk-image.raw')}",
            'bundle exec rspec -fd',
            "spec/stemcells/#{operating_system.name}_spec.rb",
            "spec/stemcells/#{infrastructure.name}_spec.rb",
          ].join(' ')
        end

        it 'calls #configure_and_apply' do
          stage_runner.should_receive(:configure_and_apply).
            with(['FAKE_OS_STAGES']).ordered
          stage_runner.should_receive(:configure_and_apply).
            with(['FAKE_INFRASTRUCTURE_STAGES']).ordered
          stemcell_builder_command.should_receive(:system).
            with(expected_rspec_command).ordered

          stemcell_builder_command.build
        end

        context 'with CentOS' do
          let(:operating_system) { instance_double('Bosh::Stemcell::OperatingSystem::Centos', name: 'centos') }

          it 'calls #configure_and_apply' do
            stage_runner.should_receive(:configure_and_apply).
              with(['FAKE_OS_STAGES']).ordered
            stage_runner.should_receive(:configure_and_apply).
              with(['FAKE_INFRASTRUCTURE_STAGES']).ordered
            stemcell_builder_command.should_receive(:system).
              with(expected_rspec_command).ordered

            stemcell_builder_command.build
          end
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
