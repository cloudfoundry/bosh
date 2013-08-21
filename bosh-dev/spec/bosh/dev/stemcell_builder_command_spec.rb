require 'spec_helper'
require 'bosh/dev/stemcell_builder_command'

module Bosh::Dev
  describe StemcellBuilderCommand do
    let(:root_dir) { '/mnt/root' }
    let(:env) { {} }

    subject(:stemcell_builder_command) do
      StemcellBuilderCommand.new(env, spec, root_dir, File.join(root_dir, 'work'), options)
    end

    describe '#build' do
      include FakeFS::SpecHelpers

      let(:shell) { instance_double('Bosh::Dev::Shell', run: nil) }
      let(:pid) { 99999 }
      let(:build_dir) { File.join(root_dir, 'build') }
      let(:work_dir) { File.join(root_dir, 'work') }
      let(:etc_dir) { File.join(build_dir, 'etc') }
      let(:settings_file) { File.join(etc_dir, 'settings.bash') }
      let(:spec_file) { File.join(build_dir, 'spec', "#{spec}.spec") }
      let(:build_script) { File.join(build_dir, 'bin', 'build_from_spec.sh') }

      let(:spec) { 'dave' }
      let(:options) { { 'hello' => 'world' } }

      before do
        StemcellBuilderCommand.any_instance.stub(:puts)
        Bosh::Dev::Shell.stub(:new).and_return(shell)
        Process.stub(pid: pid)
        FileUtils.stub(:cp_r).with([], build_dir, preserve: true) do
          FileUtils.mkdir_p etc_dir
          FileUtils.touch settings_file
        end
      end

      it 'creates a base directory for stemcell creation' do
        expect {
          stemcell_builder_command.build
        }.to change { Dir.exists?(root_dir) }.from(false).to(true)
      end

      it 'creates a build directory for stemcell creation' do
        expect {
          stemcell_builder_command.build
        }.to change { Dir.exists?(build_dir) }.from(false).to(true)
      end

      it 'copies the stemcell_builder code into the build directory' do
        FileUtils.should_receive(:cp_r).with([], build_dir, preserve: true) do
          FileUtils.mkdir_p etc_dir
          FileUtils.touch File.join(etc_dir, 'settings.bash')
        end
        stemcell_builder_command.build
      end

      it 'creates a work directory for stemcell creation chroot' do
        expect {
          stemcell_builder_command.build
        }.to change { Dir.exists?(work_dir) }.from(false).to(true)
      end

      it 'writes a settings file into the build directory' do
        stemcell_builder_command.build
        expect(File.read(settings_file)).to match(/hello=world/)
      end

      context 'when the user does not set proxy environment variables' do
        it 'runs the stemcell builder with no environment variables set' do
          shell.should_receive(:run).with("sudo env  #{build_script} #{work_dir} #{spec_file} #{settings_file}")
          stemcell_builder_command.build
        end
      end

      context 'when the uses sets proxy environment variables' do
        let(:env) do
          {
            'HTTP_PROXY' => 'nice_proxy',
            'no_proxy' => 'naughty_proxy'
          }
        end

        it 'maintains current user proxy env vars through the shell sudo call' do
          shell.should_receive(:run).with("sudo env HTTP_PROXY='nice_proxy' no_proxy='naughty_proxy' #{build_script} #{work_dir} #{spec_file} #{settings_file}")
          stemcell_builder_command.build
        end
      end

      context 'when the uses sets a BUILD_PATH environment variable' do
        let(:root_dir) { 'TEST_ROOT_DIR' }

        it 'passes through BUILD_PATH environment variables correctly' do
          shell.should_receive(:run).with("sudo env  #{build_script} #{work_dir} #{spec_file} #{settings_file}")
          stemcell_builder_command.build
        end
      end
    end
  end
end
