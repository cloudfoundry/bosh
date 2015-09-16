require 'spec_helper'
require 'logger'
require 'bosh/dev/bosh_cli_session'

module Bosh::Dev
  describe BoshCliSession do
    describe '#run_bosh' do
      subject { described_class.new(bosh_cmd) }
      let(:bosh_cmd) { instance_double('Bosh::Dev::PathBoshCmd', cmd: 'fake-bosh-bin', env: bosh_cmd_env) }
      let(:bosh_cmd_env) { { 'fake-env' => 'fake-env-value' } }

      before { allow(Bosh::Core::Shell).to receive(:new).and_return(shell) }
      let(:shell) { instance_double('Bosh::Core::Shell') }

      before { allow(subject).to receive(:puts) }

      before { allow(Tempfile).to receive(:new).with('bosh_config').and_return(tempfile) }
      let(:tempfile) { instance_double('Tempfile', path: 'fake-tmp/bosh_config') }

      it 'runs the specified bosh command' do
        expected_cmd = "fake-bosh-bin -v -n -P 10 --config 'fake-tmp/bosh_config' fake-cmd"
        output       = double('cmd-output')
        expect(shell).to receive(:run).with(expected_cmd, env: bosh_cmd_env).and_return(output)
        expect(subject.run_bosh('fake-cmd', fake: 'options')).to eq(output)
      end

      context 'when bosh fails with a RuntimeError and retrying' do
        full_cmd = "fake-bosh-bin -v -n -P 10 --config 'fake-tmp/bosh_config' fake-cmd"

        before { allow(retryable).to receive(:sleep) }
        let(:retryable) { Bosh::Retryable.new(tries: 2, on: [RuntimeError]) }
        let(:error)     { RuntimeError.new('eror-message') }

        context 'when command finally succeeds on the third time' do
          it 'retries same command given number of times' do
            expect(shell).to receive(:run).with(full_cmd, env: bosh_cmd_env).ordered.and_raise(error)
            expect(shell).to receive(:run).with(full_cmd, env: bosh_cmd_env).ordered.and_return('cmd-output')
            expect(subject.run_bosh('fake-cmd', retryable: retryable)).to eq('cmd-output')
          end
        end

        context 'when command still raises an error on the third time' do
          it 'retries and eventually raises an error' do
            expect(shell).to receive(:run).with(full_cmd, env: bosh_cmd_env).ordered.exactly(2).times.and_raise(error)
            expect {
              subject.run_bosh('fake-cmd', retryable: retryable)
            }.to raise_error(error)
          end
        end
      end

      context 'when bosh fails and debugging failures' do
        before do
          allow(shell).to receive(:run) { |cmd, _| raise 'fake-cmd broke' if cmd =~ /fake-cmd/ }
        end

        it 'debugs the last task' do
          expect_cmd = "fake-bosh-bin -v -n -P 10 --config 'fake-tmp/bosh_config' task last --debug"
          expect(shell).to receive(:run).with(expect_cmd, last_number: 100, env: bosh_cmd_env).and_return('cmd-output')

          expect {
            subject.run_bosh('fake-cmd', debug_on_fail: true)
          }.to raise_error('fake-cmd broke')
        end

        context 'and it also fails debugging the original failure' do
          before { allow(shell).to receive(:run).and_raise }

          it "doesn't debug again" do
            expect(shell).to receive(:run).twice

            expect {
              subject.run_bosh('fake-cmd', debug_on_fail: true)
            }.to raise_error
          end
        end
      end
    end

    describe '#close' do
      subject { described_class.new(bosh_cmd) }
      let(:bosh_cmd) { instance_double('Bosh::Dev::PathBoshCmd', cmd: 'fake-bosh-bin') }

      it 'tells bosh command to close' do
        expect(bosh_cmd).to receive(:close).with(no_args)
        subject.close
      end
    end
  end

  describe PathBoshCmd do
    describe '#cmd' do
      it('returns bosh') { expect(subject.cmd).to eq('bosh') }
    end

    describe '#close' do
      it('can run close') { expect { subject.close }.to_not raise_error }
    end
  end

  describe S3GemBoshCmd do
    subject { described_class.new('fake-number', logger) }

    include FakeFS::SpecHelpers

    before { allow(Bosh::Core::Shell).to receive(:new).and_return(shell) }
    let(:shell) { instance_double('Bosh::Core::Shell', run: nil) }
    before { allow(Bundler).to receive(:ruby_scope).and_return('fake-bundler-ruby-scope') }


    describe '#cmd' do
      tmp_dir = '/fake-tmp-path'
      gemfile_path = '/fake-tmp-path/Gemfile'

      before { allow(Dir).to receive(:mktmpdir).and_return(tmp_dir) }

      context 'when gems were not yet installed' do
        it 'installs gems into temporary location with bundler' do
          file = instance_double('File')
          expect(File).to receive(:open).with(gemfile_path, 'w').and_yield(file)

          expect(file).to receive(:write).with(<<-GEMFILE).ordered
source "https://bosh-ci-pipeline.s3.amazonaws.com/fake-number/gems"
source "https://rubygems.org"
gem "bosh_cli_plugin_micro", "1.fake-number.0"
GEMFILE

          expect(Bundler).to receive(:with_clean_env).ordered.and_yield

          expect(shell).to receive(:run).
            with("bundle install --no-prune --path #{tmp_dir}", env: { 'BUNDLE_GEMFILE' => gemfile_path }).
            ordered

          subject.cmd
        end

        it 'returns cmd for running bosh from temporary location' do
          expect(subject.cmd).to eq('/fake-tmp-path/fake-bundler-ruby-scope/bin/bosh')
        end
      end

      context 'when gems were installed (presence of Gemfile)' do
        before { subject.cmd }

        it 'does not install gems into temporary location again' do
          expect(shell).to_not receive(:run)
          subject.cmd
        end

        it 'returns cmd for running bosh from temporary location' do
          expect(subject.cmd).to eq('/fake-tmp-path/fake-bundler-ruby-scope/bin/bosh')
        end
      end
    end

    describe '#env' do
      tmp_dir = '/fake-tmp-path'
      gemfile_path = '/fake-tmp-path/Gemfile'

      before { allow(Dir).to receive(:mktmpdir).and_return(tmp_dir) }

      context 'when gems were not yet installed' do
        it 'installs gems into temporary location with bundler' do
          file = instance_double('File')
          expect(File).to receive(:open).with(gemfile_path, 'w').and_yield(file)

          expect(file).to receive(:write).with(<<-GEMFILE).ordered
source "https://bosh-ci-pipeline.s3.amazonaws.com/fake-number/gems"
source "https://rubygems.org"
gem "bosh_cli_plugin_micro", "1.fake-number.0"
GEMFILE

          expect(Bundler).to receive(:with_clean_env).ordered.and_yield

          expect(shell).to receive(:run).
            with("bundle install --no-prune --path #{tmp_dir}", env: { 'BUNDLE_GEMFILE' => gemfile_path }).
            ordered

          subject.env
        end

        it 'returns env for the command to use' do
          expect(subject.env).to eq('GEM_PATH' => '', 'GEM_HOME' => '/fake-tmp-path/fake-bundler-ruby-scope')
        end
      end

      context 'when gems were installed (presence of Gemfile)' do
        before { subject.env }

        it 'does not install gems into temporary location again' do
          expect(shell).to_not receive(:run)
          subject.env
        end

        it 'returns cmd for running bosh from temporary location' do
          expect(subject.env).to eq('GEM_PATH' => '', 'GEM_HOME' => '/fake-tmp-path/fake-bundler-ruby-scope')
        end
      end
    end

    describe '#close' do
      context 'when command was previously requested' do
        tmp_dir = '/fake-tmp-path'
        before { allow(Dir).to receive(:mktmpdir).and_return(tmp_dir) }

        before { subject.cmd }

        it 'removes temporary location where gems were installed' do
          expect(FileUtils).to receive(:rm_rf).with(tmp_dir)
          subject.close
        end
      end

      context 'when command was not previously requested' do
        it 'does not remove any temporary location' do
          expect(FileUtils).to_not receive(:rm_rf)
          subject.close
        end
      end
    end
  end
end
