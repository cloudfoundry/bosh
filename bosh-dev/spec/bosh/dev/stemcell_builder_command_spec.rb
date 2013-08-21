require 'spec_helper'
require 'bosh/dev/stemcell_builder_command'

module Bosh::Dev
  describe StemcellBuilderCommand do
    let(:root_dir) { '/mnt/root' }
    let(:environment_hash) { {} }
    let(:stemcell_builder_options) do
      instance_double('Bosh::Dev::StemcellBuilderOptions',
                      spec_name: spec,
                      default: options)
    end

    let(:stemcell_environment) do
      instance_double('Bosh::Dev::StemcellEnvironment',
                      build_path: root_dir,
                      work_path: File.join(root_dir, 'work'))
    end

    subject(:stemcell_builder_command) do
      StemcellBuilderCommand.new(stemcell_environment, stemcell_builder_options)
    end

    before do
      ENV.stub(to_hash: environment_hash)
    end

    describe '#build' do
      include FakeFS::SpecHelpers

      let(:shell) { instance_double('Bosh::Core::Shell', run: nil) }
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
        Bosh::Core::Shell.stub(:new).and_return(shell)
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

      context 'when ENV contains variables besides HTTP_PROXY and NO_PROXY' do
        let(:environment_hash) do
          {
            'NOT_HTTP_PROXY' => 'nice_proxy',
            'no_proxy_just_kidding' => 'naughty_proxy'
          }
        end

        it 'nothing is passed to sudo via "env"' do
          shell.should_receive(:run) do |command|
            expect(command).not_to match(/NOT_HTTP_PROXY=nice_proxy/)
            expect(command).not_to match(/no_proxy_just_kidding=naughty_proxy/)
          end

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
          shell.should_receive(:run).with("sudo env HTTP_PROXY='nice_proxy' no_proxy='naughty_proxy' #{build_script} #{work_dir} #{spec_file} #{settings_file}")
          stemcell_builder_command.build
        end
      end
    end
  end
end
