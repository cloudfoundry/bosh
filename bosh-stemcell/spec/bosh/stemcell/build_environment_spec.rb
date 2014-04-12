require 'spec_helper'
require 'bosh/stemcell/build_environment'
require 'bosh/stemcell/infrastructure'
require 'bosh/stemcell/operating_system'
require 'bosh/stemcell/definition'
require 'bosh/stemcell/agent'

module Bosh::Stemcell
  describe BuildEnvironment do
    include FakeFS::SpecHelpers

    subject { described_class.new(env, definition, version, release_tarball_path, os_image_tarball_path) }

    let(:env) { {} }

    let(:definition) do
      instance_double(
        'Bosh::Stemcell::Definition',
        infrastructure: infrastructure,
        operating_system: operating_system,
        agent: agent,
      )
    end

    let(:version) { '1234' }
    let(:release_tarball_path) { '1234.tgz' }
    let(:os_image_tarball_path) { '/some/os_image.tgz' }

    let(:stemcell_builder_source_dir) { '/fake/path/to/stemcell_builder' }
    let(:stemcell_specs_dir) { '/fake/path/to/stemcell/specs/dir' }

    let(:agent) do
      instance_double('Bosh::Stemcell::Agent::NullAgent',
                      name: 'fake-agent-name',
      )
    end

    let(:release_tarball_path) { "/fake/path/to/bosh-#{version}.tgz" }
    let(:version) { '007' }

    let(:root_dir) do
      File.join('/mnt/stemcells', infrastructure.name, infrastructure.hypervisor, operating_system.name)
    end

    let(:build_path) { File.join(root_dir, 'build', 'build') }
    let(:settings_file) { File.join(build_path, 'etc', 'settings.bash') }
    let(:work_root) { File.join(root_dir, 'work') }
    let(:work_path) { File.join(work_root, 'work') }

    let(:infrastructure) do
      instance_double('Bosh::Stemcell::Infrastructure::Base',
                      name: 'fake-infrastructure-name',
                      hypervisor: 'fake-hypervisor',
                      default_disk_size: -1,
      )
    end

    let(:stemcell_builder_options) do
      instance_double('Bosh::Stemcell::BuilderOptions', default: options)
    end

    let(:options) do
      {
        'hello' => 'world',
        'stemcell_tgz' => 'fake-stemcell.tgz',
        'stemcell_image_name' => 'fake-root-disk-image.raw'
      }
    end

    let(:operating_system) do
      instance_double('Bosh::Stemcell::OperatingSystem::Base',
                      name: 'fake-operating-system-name')
    end

    let(:shell) { instance_double(Bosh::Core::Shell) }
    let(:run_options) { { ignore_failures: true } }

    before do
      allow(Bosh::Core::Shell).to receive(:new).and_return(shell)
      allow(BuilderOptions).to receive(:new).and_return(stemcell_builder_options)
      stub_const('Bosh::Stemcell::BuildEnvironment::STEMCELL_BUILDER_SOURCE_DIR', stemcell_builder_source_dir)
      stub_const('Bosh::Stemcell::BuildEnvironment::STEMCELL_SPECS_DIR', stemcell_specs_dir)
    end

    it 'constructs stemcell builder options' do
      expect(BuilderOptions).to receive(:new).with(
        env: env,
        definition: definition,
        version: version,
        release_tarball: release_tarball_path,
        os_image_tarball: os_image_tarball_path,
      )

      subject
    end

    describe '#prepare_build' do
      before do
        allow(shell).to receive(:run)

        original_cp_r = FileUtils.method(:cp_r)
        allow(FileUtils).to receive(:cp_r) do |src, dst, options|
          original_cp_r.call(src, dst)
        end

        stemcell_builder_etc_dir = File.join(stemcell_builder_source_dir, 'etc')
        FileUtils.mkdir_p(stemcell_builder_etc_dir)
        File.open(File.join(stemcell_builder_etc_dir, 'settings.bash'), 'w') { |file| file.puts('some=var') }
      end

      it 'cleans and prepares the environment' do
        image_path = File.join(root_dir, 'work/work/mnt/tmp/grub/fake-root-disk-image.raw')
        unmount_img_command = "sudo umount #{image_path} 2> /dev/null"
        expect(shell).to receive(:run).with(unmount_img_command, run_options).ordered
        unmount_dir_command = "sudo umount #{File.join(root_dir, 'work/work/mnt')} 2> /dev/null"
        expect(shell).to receive(:run).with(unmount_dir_command, run_options).ordered
        expect(shell).to receive(:run).with("sudo rm -rf #{root_dir}", run_options).ordered

        subject.prepare_build

        expect(Dir.exists?(build_path)).to be(true)
        expect(File.read(settings_file)).to match(/some=var/)
        expect(File.read(settings_file)).to match(/hello=world/)
      end

      it 'removes any tgz files from current working directory' do
        FileUtils.touch('leftover.tgz')
        expect {
          subject.prepare_build
        }.to change { Dir.glob('*.tgz').size }.to(0)
      end

      it 'cleans the build path' do
        FileUtils.mkdir_p(build_path)
        leftover_file = File.join(build_path, 'some_file')
        FileUtils.touch(leftover_file)

        expect {
          subject.prepare_build
        }.to change { File.exist?(leftover_file) }.from(true).to(false)
      end

      it 'creates the work root' do
        expect {
          subject.prepare_build
        }.to change { Dir.exists?(work_root) }.from(false).to(true)
      end
    end

    describe '#os_image_rspec_command' do
      context 'when operating system has version' do
        before { allow(operating_system).to receive(:version).and_return('fake-version') }

        it 'returns the correct command' do
          expected_rspec_command = [
            "cd #{stemcell_specs_dir};",
            'OS_IMAGE=/some/os_image.tgz',
            'bundle exec rspec -fd',
            "spec/os_image/#{operating_system.name}_#{operating_system.version}_spec.rb",
          ].join(' ')

          expect(subject.os_image_rspec_command).to eq(expected_rspec_command)
        end
      end

      context 'when operating system does not have version' do
        before { allow(operating_system).to receive(:version).and_return(nil) }

        it 'returns the correct command' do
          expected_rspec_command = [
            "cd #{stemcell_specs_dir};",
            'OS_IMAGE=/some/os_image.tgz',
            'bundle exec rspec -fd',
            "spec/os_image/#{operating_system.name}_spec.rb",
          ].join(' ')

          expect(subject.os_image_rspec_command).to eq(expected_rspec_command)
        end
      end
    end

    describe '#stemcell_rspec_command' do
      context 'when operation system has version' do
        before { allow(operating_system).to receive(:version).and_return('fake-version') }

        it 'returns the correct command' do
          expected_rspec_command = [
            "cd #{stemcell_specs_dir};",
            "STEMCELL_IMAGE=#{File.join(work_path, 'fake-root-disk-image.raw')}",
            'bundle exec rspec -fd',
            "spec/stemcells/#{operating_system.name}_#{operating_system.version}_spec.rb",
            "spec/stemcells/#{agent.name}_agent_spec.rb",
            "spec/stemcells/#{infrastructure.name}_spec.rb",
          ].join(' ')

          expect(subject.stemcell_rspec_command).to eq(expected_rspec_command)
        end
      end

      context 'when operation system does not have version' do
        before { allow(operating_system).to receive(:version).and_return(nil) }

        it 'returns the correct command' do
          expected_rspec_command = [
            "cd #{stemcell_specs_dir};",
            "STEMCELL_IMAGE=#{File.join(work_path, 'fake-root-disk-image.raw')}",
            'bundle exec rspec -fd',
            "spec/stemcells/#{operating_system.name}_spec.rb",
            "spec/stemcells/#{agent.name}_agent_spec.rb",
            "spec/stemcells/#{infrastructure.name}_spec.rb",
          ].join(' ')

          expect(subject.stemcell_rspec_command).to eq(expected_rspec_command)
        end
      end
    end

    describe '#build_path' do
      it 'returns the build path' do
        expect(subject.build_path).to eq(build_path)
      end
    end

    describe '#chroot_dir' do
      it 'returns the right directory' do
        expect(subject.chroot_dir).to eq(File.join(work_path, 'chroot'))
      end
    end

    describe '#stemcell_file' do
      it 'returns the right file path' do
        expect(subject.stemcell_file).to eq(File.join(work_path, 'fake-stemcell.tgz'))
      end
    end

    describe '#settings_path' do
      it 'returns the settings path' do
        expect(subject.settings_path).to eq(settings_file)
      end
    end

    describe '#work_path' do
      it 'returns the work path' do
        expect(subject.work_path).to eq(work_path)
      end
    end

    describe '#command_env' do
      context 'when the environment does not have HTTP_PROXY or NO_PROXY variables' do
        it 'includes no variables' do
          expect(subject.command_env).to eq('env ')
        end
      end

      context 'when the environment has HTTP_PROXY and NO_PROXY variables' do
        let(:env) do
          {
            'HTTP_PROXY' => 'some_proxy',
            'NO_PROXY' => 'no_proxy',
            'SOME_PROXY' => 'other_proxy',
          }
        end

        it 'includes those variables' do
          expect(subject.command_env).to eq("env HTTP_PROXY='some_proxy' NO_PROXY='no_proxy'")
        end
      end

      context 'when the environment has http_proxy and no_proxy variables' do
        let(:env) do
          {
            'http_proxy' => 'some_proxy',
            'no_proxy' => 'no_proxy',
            'some_proxy' => 'other_proxy',
          }
        end

        it 'includes those variables' do
          expect(subject.command_env).to eq("env http_proxy='some_proxy' no_proxy='no_proxy'")
        end
      end
    end
  end
end
