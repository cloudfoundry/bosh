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
    let(:work_path) { '/fake/path/to/work_dir/work' }

    subject(:stage_runner) do
      described_class.new(build_path: build_path,
                          command_env: command_env,
                          settings_file: settings_file,
                          work_path: work_path)
    end

    before do
      allow(Bosh::Core::Shell).to receive(:new).and_return(shell)

      allow(stage_runner).to receive(:puts)
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

        allow(File).to receive(:executable?).and_return(true) # because FakeFs does not support :executable?
      end

      it 'prints the expected messages' do
        allow(stage_runner).to receive(:puts).with("=== Configuring 'stage_0' stage ===")
        allow(stage_runner).to receive(:puts).with("== Started #{Time.now.strftime('%a %b %e %H:%M:%S %Z %Y')} ==")
        allow(stage_runner).to receive(:puts).with("=== Configuring 'stage_1' stage ===")
        allow(stage_runner).to receive(:puts).with("== Started #{Time.now.strftime('%a %b %e %H:%M:%S %Z %Y')} ==")

        stage_runner.configure(stages)
      end

      it 'runs the configure script for each stage in order' do
        expect(shell).to receive(:run).
          with('sudo env FOO=bar /fake/path/to/build_dir/stages/stage_0/config.sh /fake/path/to/settings.bash 2>&1',
               { output_command: true })
        expect(shell).to receive(:run).
          with('sudo env FOO=bar /fake/path/to/build_dir/stages/stage_1/config.sh /fake/path/to/settings.bash 2>&1',
               { output_command: true })

        stage_runner.configure(stages)
      end

      context 'when a stage does not have a config.sh file' do
        before do
          FileUtils.rm('/fake/path/to/build_dir/stages/stage_0/config.sh')
        end

        it 'does not attempt to run the configure step which is missing a config.sh' do
          expect(shell).not_to receive(:run).
            with('sudo env FOO=bar /fake/path/to/build_dir/stages/stage_0/config.sh /fake/path/to/settings.bash 2>&1',
                 { output_command: true })
          expect(shell).to receive(:run).
            with('sudo env FOO=bar /fake/path/to/build_dir/stages/stage_1/config.sh /fake/path/to/settings.bash 2>&1',
                 { output_command: true })

          stage_runner.configure(stages)
        end
      end

      context 'when a stage has config.sh file which is not executable' do
        before do
          allow(File).to receive(:executable?).
                           with('/fake/path/to/build_dir/stages/stage_1/config.sh').and_return(false)
        end

        it 'does not attempt to run the configure step which has a non-executable config.sh' do
          expect(shell).to receive(:run).
            with('sudo env FOO=bar /fake/path/to/build_dir/stages/stage_0/config.sh /fake/path/to/settings.bash 2>&1',
                 { output_command: true })
          expect(shell).not_to receive(:run).
            with('sudo env FOO=bar /fake/path/to/build_dir/stages/stage_1/config.sh /fake/path/to/settings.bash 2>&1',
                 { output_command: true })

          stage_runner.configure(stages)
        end
      end
    end

    describe '#apply' do
      it 'prints the expected messages' do
        Timecop.freeze do
          expect(stage_runner).to receive(:puts).with("=== Applying 'stage_0' stage ===")
          expect(stage_runner).to receive(:puts).with("== Started #{Time.now.strftime('%a %b %e %H:%M:%S %Z %Y')} ==")
          expect(stage_runner).to receive(:puts).with("=== Applying 'stage_1' stage ===")
          expect(stage_runner).to receive(:puts).with("== Started #{Time.now.strftime('%a %b %e %H:%M:%S %Z %Y')} ==")

          stage_runner.apply(stages)
        end
      end

      it 'runs the apply script for each stage in order' do
        expect(FileUtils).to receive(:mkdir_p).with(work_path).exactly(2).times

        expect(shell).to receive(:run).
          with('sudo env FOO=bar /fake/path/to/build_dir/stages/stage_0/apply.sh /fake/path/to/work_dir/work 2>&1',
               { output_command: true })
        expect(shell).to receive(:run).
          with('sudo env FOO=bar /fake/path/to/build_dir/stages/stage_1/apply.sh /fake/path/to/work_dir/work 2>&1',
               { output_command: true })

        stage_runner.apply(stages)
      end
    end

    describe '#configure_and_apply' do
      before do
        stages.each do |stage|
          stage_dir = File.join(File.join(build_path, 'stages'), stage.to_s)
          FileUtils.mkdir_p(stage_dir)

          config_script = File.join(stage_dir, 'config.sh')
          FileUtils.touch(config_script)
          File.chmod(0700, config_script)
        end

        allow(File).to receive(:executable?).and_return(true) # because FakeFs does not support :executable?

        # stage_runner requires that we're running as uid 1000 (usually 'ubuntu' user in the aws build env)
        allow(Process).to receive(:euid).and_return(1000)

      end

      context 'when resume_from is unset' do
        it 'runs all stages' do
          expect(stage_runner).to receive(:puts).with("=== Configuring 'stage_0' stage ===")
          expect(stage_runner).to receive(:puts).with("=== Configuring 'stage_1' stage ===")
          expect(stage_runner).to receive(:puts).with("=== Applying 'stage_0' stage ===")
          expect(stage_runner).to receive(:puts).with("=== Applying 'stage_1' stage ===")

          stage_runner.configure_and_apply(stages)
        end
      end

      context 'when resume_from is set' do
        it 'skips stages before resume_from ' do
          expect(stage_runner).to_not receive(:puts).with("=== Configuring 'stage_0' stage ===")
          expect(stage_runner).to receive(:puts).with("=== Configuring 'stage_1' stage ===")
          expect(stage_runner).to_not receive(:puts).with("=== Applying 'stage_0' stage ===")
          expect(stage_runner).to receive(:puts).with("=== Applying 'stage_1' stage ===")

          stage_runner.configure_and_apply(stages, 'stage_1')
        end
      end

      context 'when resume_from is set to an unknown stage name' do
        it 'raises an error' do
          expect {
            stage_runner.configure_and_apply(stages, 'this_stage_totally_doesnt_exist')
          }.to raise_error("Can't find stage 'this_stage_totally_doesnt_exist' to resume from. Aborting.")
        end
      end

      context 'when effective UID is not 1000' do
        it 'fails with an error message' do
          allow(Process).to receive(:euid).and_return(999)
          expect {
            stage_runner.configure_and_apply(stages)
          }.to raise_error("You must build stemcells as a user with UID 1000. Your effective UID now is 999.")
        end
      end
    end
  end
end