require 'spec_helper'
require 'timecop'
require 'bosh/stemcell/stage_runner'

module Bosh::Stemcell
  describe StageRunner do
    include FakeFS::SpecHelpers

    let(:shell) { instance_double('Bosh::Core::Shell', run: nil) }

    let(:stages) { [:stage_0, :stage_1] }
    let(:build_path) { '/fake/path/to/build_dir' }
    let(:command_env) { 'env FOO=bar' }
    let(:settings_file) { '/fake/path/to/settings.bash' }
    let(:work_path) { '/fake/path/to/work_dir' }

    subject(:stage_runner) do
      described_class.new(build_path: build_path,
                          command_env: command_env,
                          settings_file: settings_file,
                          work_path: work_path)
    end

    before do
      Bosh::Core::Shell.stub(:new).and_return(shell)

      stage_runner.stub(:puts)
    end

    describe '#initialize' do
      it 'requires :build_path' do
        expect {
          StageRunner.new(stages: 'FAKE', command_env: 'FAKE', settings_file: 'FAKE', work_path: 'FAKE')
        }.to raise_error('key not found: :build_path')
      end

      it 'requires :command_env' do
        expect {
          StageRunner.new(stages: 'FAKE', build_path: 'FAKE', settings_file: 'FAKE', work_path: 'FAKE')
        }.to raise_error('key not found: :command_env')
      end

      it 'requires :settings_file' do
        expect {
          StageRunner.new(stages: 'FAKE', build_path: 'FAKE', command_env: 'FAKE', work_path: 'FAKE')
        }.to raise_error('key not found: :settings_file')
      end

      it 'requires :work_path' do
        expect {
          StageRunner.new(stages: 'FAKE', build_path: 'FAKE', command_env: 'FAKE', settings_file: 'FAKE')
        }.to raise_error('key not found: :work_path')
      end
    end

    describe '#configure' do
      before do
        stages.each do |stage|
          stage_dir = File.join(File.join(build_path, 'stages'), stage.to_s)
          FileUtils.mkdir_p(stage_dir)

          config_script = File.join(stage_dir, 'config.sh')
          FileUtils.touch(config_script)
          File.chmod(0700, config_script)
        end

        File.stub(executable?: true) # because FakeFs does not support :executable?
      end

      it 'prints the expected messages' do
        stage_runner.should_receive(:puts).with("=== Configuring 'stage_0' stage ===")
        stage_runner.should_receive(:puts).with("=== Configuring 'stage_1' stage ===")

        stage_runner.configure(stages)
      end

      it 'runs the configure script for each stage in order' do
        shell.should_receive(:run).
          with('sudo env FOO=bar /fake/path/to/build_dir/stages/stage_0/config.sh /fake/path/to/settings.bash 2>&1')
        shell.should_receive(:run).
          with('sudo env FOO=bar /fake/path/to/build_dir/stages/stage_1/config.sh /fake/path/to/settings.bash 2>&1')

        stage_runner.configure(stages)
      end

      context 'when a stage does not have a config.sh file' do
        before do
          FileUtils.rm('/fake/path/to/build_dir/stages/stage_0/config.sh')
        end

        it 'does not attempt to run the configure step which is missing a config.sh' do
          shell.should_not_receive(:run).
            with('sudo env FOO=bar /fake/path/to/build_dir/stages/stage_0/config.sh /fake/path/to/settings.bash 2>&1')
          shell.should_receive(:run).
            with('sudo env FOO=bar /fake/path/to/build_dir/stages/stage_1/config.sh /fake/path/to/settings.bash 2>&1')

          stage_runner.configure(stages)
        end
      end

      context 'when a stage has config.sh file which is not executable' do
        before do
          File.stub(:executable?).with('/fake/path/to/build_dir/stages/stage_1/config.sh').and_return(false)
        end

        it 'does not attempt to run the configure step which has a non-executable config.sh' do
          shell.should_receive(:run).
            with('sudo env FOO=bar /fake/path/to/build_dir/stages/stage_0/config.sh /fake/path/to/settings.bash 2>&1')
          shell.should_not_receive(:run).
            with('sudo env FOO=bar /fake/path/to/build_dir/stages/stage_1/config.sh /fake/path/to/settings.bash 2>&1')

          stage_runner.configure(stages)
        end
      end
    end

    describe '#apply' do
      it 'prints the expected messages' do
        Timecop.freeze do
          stage_runner.should_receive(:puts).with("=== Applying 'stage_0' stage ===")
          stage_runner.should_receive(:puts).with("== Started #{Time.now.strftime('%a %b %e %H:%M:%S %Z %Y')} ==")
          stage_runner.should_receive(:puts).with("=== Applying 'stage_1' stage ===")
          stage_runner.should_receive(:puts).with("== Started #{Time.now.strftime('%a %b %e %H:%M:%S %Z %Y')} ==")

          stage_runner.apply(stages)
        end
      end

      it 'runs the apply script for each stage in order' do
        FileUtils.should_receive(:mkdir_p).with(File.join(work_path, 'work')).exactly(2).times

        shell.should_receive(:run).
          with('sudo env FOO=bar /fake/path/to/build_dir/stages/stage_0/apply.sh /fake/path/to/work_dir/work 2>&1')
        shell.should_receive(:run).
          with('sudo env FOO=bar /fake/path/to/build_dir/stages/stage_1/apply.sh /fake/path/to/work_dir/work 2>&1')

        stage_runner.apply(stages)
      end
    end
  end
end
