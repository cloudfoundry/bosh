require 'spec_helper'
require 'bosh/stemcell/builder_command_helper'
require 'bosh/stemcell/infrastructure'
require 'bosh/stemcell/operating_system'
require 'bosh/stemcell/definition'
require 'bosh/stemcell/agent'

module Bosh::Stemcell
  describe BuilderCommandHelper do
    include FakeFS::SpecHelpers

    subject { described_class.new(nil, definition, nil, nil, stemcell_builder_source_dir, stemcell_specs_dir) }

    let(:definition) do
      instance_double(
        'Bosh::Stemcell::Definition',
        infrastructure: infrastructure,
        operating_system: operating_system,
        agent: agent,
      )
    end

    let(:stemcell_builder_source_dir) { '/fake/path/to/stemcell_builder' }
    let(:stemcell_specs_dir) { '/fake/path/to/stemcell/specs/dir' }

    let(:agent) do
      instance_double('Bosh::Stemcell::Agent::NullAgent',
        name: 'fake-agent-name',
      )
    end

    let(:etc_dir) { File.join(root_dir, 'build', 'build', 'etc') }
    let(:settings_file) { File.join(etc_dir, 'settings.bash') }

    let(:release_tarball_path) { "/fake/path/to/bosh-#{version}.tgz" }
    let(:version) { '007' }

    let(:root_dir) do
      File.join('/mnt/stemcells', infrastructure.name, infrastructure.hypervisor, operating_system.name)
    end

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
        'hello'               => 'world',
        'stemcell_tgz'        => 'fake-stemcell.tgz',
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
    end

    describe '#sanitize' do
      before do
        allow(shell).to receive(:run)
      end

      it 'removes any tgz files from current working directory' do
        FileUtils.touch('leftover.tgz')
        expect {
          subject.sanitize
        }.to change { Dir.glob('*.tgz').size }.to(0)
      end

      it 'unmounts the disk image used to install Grub' do
        image_path = File.join(root_dir, 'work/work/mnt/tmp/grub/fake-root-disk-image.raw')
        unmount_img_command = "sudo umount #{image_path} 2> /dev/null"
        expect(shell).to receive(:run).with(unmount_img_command, run_options)
        subject.sanitize
      end

      it 'unmounts work/work/mnt directory' do
        unmount_dir_command = "sudo umount #{File.join(root_dir, 'work/work/mnt')} 2> /dev/null"
        expect(shell).to receive(:run).with(unmount_dir_command, run_options)
        subject.sanitize
      end

      it 'removes stemcell root directory' do
        expect(shell).to receive(:run).with("sudo rm -rf #{root_dir}", run_options)
        subject.sanitize
      end
    end

    describe '#prepare_build_root' do
      it 'creates the build root' do
        expect { subject.prepare_build_root}.to change {
          Dir.exists?(File.join(root_dir, 'build'))
        }.from(false).to(true)
      end
    end

    describe '#prepare_build_path' do
      it 'creates the build path' do
        expect { subject.prepare_build_path}.to change {
          Dir.exists?(File.join(root_dir, 'build', 'build'))
        }.from(false).to(true)
      end
    end

    describe '#copy_stemcell_builder_to_build_path' do
      let (:build_path) { File.join(root_dir, 'build', 'build') }
      before do
        FileUtils.mkdir_p(build_path)

        original_cp_r = FileUtils.method(:cp_r)
        allow(FileUtils).to receive(:cp_r) do |src, dst, options|
          original_cp_r.call(src, dst)
        end
      end

      it 'copies the stemcell builder code to the build path' do
        FileUtils.mkdir_p(stemcell_builder_source_dir)
        FileUtils.touch(File.join(stemcell_builder_source_dir, 'dummy-file'))

        expect { subject.copy_stemcell_builder_to_build_path }.to change {
          Dir.entries(File.join(root_dir, 'build', 'build')).size
        }.from(2).to(3)
      end
    end

    describe '#prepare_work_root' do
      it 'creates the work root' do
        expect { subject.prepare_work_root}.to change {
          Dir.exists?(File.join(root_dir, 'work'))
        }.from(false).to(true)
      end
    end

    describe '#persist_settings_for_bash' do
      it 'writes a settings file' do
        FileUtils.mkdir_p(File.dirname(settings_file))
        FileUtils.touch(settings_file)

        subject.persist_settings_for_bash
        expect(File.read(settings_file)).to match(/hello=world/)
      end
    end

    describe '#rspec_command' do
      it 'returns the correct command' do
        expected_rspec_command = [
          "cd #{stemcell_specs_dir};",
          "STEMCELL_IMAGE=#{File.join(root_dir, 'work', 'work', 'fake-root-disk-image.raw')}",
          "bundle exec rspec -fd",
          "spec/stemcells/#{operating_system.name}_spec.rb",
          "spec/stemcells/#{agent.name}_agent_spec.rb",
          "spec/stemcells/#{infrastructure.name}_spec.rb",
        ].join(' ')

        expect(subject.rspec_command).to eq(expected_rspec_command)
      end
    end

    describe '#chroot_dir' do
      it 'returns the right directory' do
        expect(subject.chroot_dir).to eq(File.join(root_dir, 'work', 'work', 'chroot'))
      end
    end

    describe '#stemcell_file' do
      it 'returns the right file path' do
        expect(subject.stemcell_file).to eq(File.join(root_dir, 'work', 'work', 'fake-stemcell.tgz'))
      end
    end
  end
end
