require 'spec_helper'
require 'bosh/dev/build_from_spec'

module Bosh::Dev
  describe BuildFromSpec do
    let(:env) { {} }

    subject(:build_from_spec) do
      BuildFromSpec.new(env, spec, options)
    end

    describe '#build' do
      include FakeFS::SpecHelpers

      let(:shell) { instance_double('Bosh::Dev::Shell', run: nil) }
      let(:pid) { 99999 }
      let(:root_dir) { "/var/tmp/bosh/bosh_agent-#{Bosh::Agent::VERSION}-#{pid}" }
      let(:build_dir) { File.join(root_dir, 'build') }
      let(:work_dir) { File.join(root_dir, 'work') }
      let(:etc_dir) { File.join(build_dir, 'etc') }
      let(:settings_file) { File.join(etc_dir, 'settings.bash') }
      let(:spec_file) { File.join(build_dir, 'spec', "#{spec}.spec") }
      let(:build_script) { File.join(build_dir, 'bin', 'build_from_spec.sh') }

      let(:spec) { 'dave' }
      let(:options) { { 'hello' => 'world' } }

      before do
        BuildFromSpec.any_instance.stub(:puts)
        Bosh::Dev::Shell.stub(:new).and_return(shell)
        Process.stub(pid: pid)
        FileUtils.stub(:cp_r).with([], build_dir, preserve: true) do
          FileUtils.mkdir_p etc_dir
          FileUtils.touch settings_file
        end
      end

      it 'creates a base directory for stemcell creation' do
        expect {
          build_from_spec.build
        }.to change { Dir.exists?(root_dir) }.from(false).to(true)
      end

      it 'creates a build directory for stemcell creation' do
        expect {
          build_from_spec.build
        }.to change { Dir.exists?(build_dir) }.from(false).to(true)
      end

      it 'copies the stemcell_builder code into the build directory' do
        FileUtils.should_receive(:cp_r).with([], build_dir, preserve: true) do
          FileUtils.mkdir_p etc_dir
          FileUtils.touch File.join(etc_dir, 'settings.bash')
        end
        build_from_spec.build
      end

      it 'creates a work directory for stemcell creation chroot' do
        expect {
          build_from_spec.build
        }.to change { Dir.exists?(work_dir) }.from(false).to(true)
      end

      context 'when the user sets their own WORK_PATH' do
        let(:env) { { 'WORK_PATH' => '/aight' } }

        it 'creates a work directory for stemcell creation chroot' do
          expect {
            build_from_spec.build
          }.to change { Dir.exists?('/aight') }.from(false).to(true)
        end
      end

      it 'writes a settings file into the build directory' do
        build_from_spec.build
        expect(File.read(settings_file)).to match(/hello=world/)
      end

      context 'when the user does not set proxy environment variables' do
        it 'runs the stemcell builder with no environment variables set' do
          shell.should_receive(:run).with("sudo env  #{build_script} #{work_dir} #{spec_file} #{settings_file}")
          build_from_spec.build
        end
      end

      context 'when the uses sets proxy environment variables' do
        let(:env) { { 'HTTP_PROXY' => 'nice_proxy', 'no_proxy' => 'naughty_proxy' } }

        it 'maintains current user proxy env vars through the shell sudo call' do
          shell.should_receive(:run).with("sudo env HTTP_PROXY='nice_proxy' no_proxy='naughty_proxy' #{build_script} #{work_dir} #{spec_file} #{settings_file}")
          build_from_spec.build
        end
      end

      context 'when the uses sets a BUILD_PATH environment variable' do
        let(:root_dir) { 'TEST_ROOT_DIR' }
        let(:env) { { 'BUILD_PATH' => root_dir } }

        it 'passes through BUILD_PATH environment variables correctly' do
          shell.should_receive(:run).with("sudo env  #{build_script} #{work_dir} #{spec_file} #{settings_file}")
          build_from_spec.build
        end
      end
    end
  end
end
