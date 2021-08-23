require 'spec_helper'
require 'bosh/core/shell'

module Bosh::Core
  describe Shell do
    subject { Shell.new(stdout) }
    let(:stdout) { StringIO.new }

    describe '#run' do
      it 'shells out, prints and returns the output of the command' do
        expect(subject.run('echo hello; echo world')).to eq("hello\nworld")
        expect(stdout.string).to eq("hello\nworld\n")
      end

      it 'shells out with specified additional env variables' do
        stub_const('ENV', 'SHELL' => '/bin/bash')
        expect(subject.run('env env', env: { 'VAR' => '123' })).to include('VAR=123')
        expect(stdout.string).to include('VAR=123')
      end

      it 'shells out with specified additional env variables even when SHELL env variable is not available' do
        stub_const('ENV', 'PATH' => ENV['PATH'])
        expect(subject.run('env env', env: { 'VAR' => '123' })).to include('VAR=123')
        expect(stdout.string).to include('VAR=123')
      end

      context 'when "output_command" is specified' do
        it 'outputs the command' do
          subject.run('echo 1;echo 2;echo 3;echo 4;echo 5', output_command: true)
          expect(stdout.string).to include('echo 1;echo 2;echo 3;echo 4;echo 5')
        end
      end

      context 'when "last_number" is specified' do
        it 'tails "last_number" lines of output' do
          cmd = 'echo 1;echo 2;echo 3;echo 4;echo 5'
          expect(subject.run(cmd, last_number: 3)).to eq("3\n4\n5")
          expect(stdout.string).to eq("1\n2\n3\n4\n5\n")
        end

        it 'outputs the entire output if more lines are requested than generated' do
          cmd = 'echo 1;echo 2;echo 3;echo 4;echo 5'
          expect(subject.run(cmd, last_number: 6)).to eq("1\n2\n3\n4\n5")
          expect(stdout.string).to eq("1\n2\n3\n4\n5\n")
        end
      end

      context 'when the command fails' do
        it 'raises an error' do
          expect {
            subject.run('false')
          }.to raise_error /Failed: 'false' from /
        end

        it 'redacts strings' do
          expect {
            subject.run('false && i am a secret command: butterflies and unicorns', redact: ['butterflies', 'unicorns'])
          }.to raise_error /Failed: 'false && i am a secret command: \[REDACTED\] and \[REDACTED\]' from /
        end

        context 'because the working directory has gone missing' do
          it 'fails gracefully with a slightly helpful error message' do
            allow(Dir).to receive(:pwd).and_raise(Errno::ENOENT, 'No such file or directory - getcwd')
            expect {
              subject.run('false')
            }.to raise_error /from a deleted directory/
          end
        end

        context 'and ignoring failures' do
          it 'raises an error' do
            subject.run('false', ignore_failures: true)
            expect(stdout.string).to match(/continuing anyway/)
          end
        end
      end
    end
  end
end
