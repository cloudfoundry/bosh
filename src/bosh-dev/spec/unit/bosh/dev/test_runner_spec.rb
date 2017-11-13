require 'spec_helper'
require 'tmpdir'
require 'bosh/dev/test_runner'

module Bosh::Dev
  describe TestRunner do
    let(:dir) { Dir.mktmpdir }
    let(:subprojects) {
      %w(one-with-specs two-with-specs three-no-specs with-specs_cpi no-specs_cpi)
    }
    subject(:runner) { TestRunner.new }

    before do
      Dir.chdir(dir)
      subprojects.each do |sub|
        Dir.mkdir(File.join(dir, sub))
        Dir.mkdir(File.join(dir, sub, 'spec')) if sub.include?('with-specs')
      end
    end

    describe '#unit_builds' do
      it 'returns all subprojects with unit tests alphabetilcally sorted' do
        expect(runner.unit_builds.size).to eq 3
        expect(runner.unit_builds).to eq %w(one-with-specs two-with-specs with-specs_cpi)
      end
    end

    describe '#unit_cmd' do
      it 'builds an rspec command' do
        expect(runner.unit_cmd).to eq 'rspec --tty --backtrace -c -f p spec'
      end

      it 'redirects output if logfile passed' do
        expect(runner.unit_cmd('potato.log')).to eq 'rspec --tty --backtrace -c -f p spec > potato.log 2>&1'
      end
    end

    describe '#unit_exec' do
      let(:build) { runner.unit_builds.first }

      before do
        allow(Kernel).to receive(:system).and_return(true)
      end

      it 'changes directory to the build and shells out to #unit_cmd' do
        expect(Kernel).to receive(:system).with({'BOSH_BUILD_NAME' => build}, "cd #{build} && #{runner.unit_cmd}")
        runner.unit_exec(build)
      end

      it 'raises an error if the command fails' do
        allow(Kernel).to receive(:system).and_return(false)

        expect {
          runner.unit_exec(build)
        }.to raise_error /#{build} failed to build unit tests/
      end
    end

    describe '#ruby' do
      context 'when building fails' do
        before do
          allow(Kernel).to receive(:system).and_return(false)
        end

        it 'raises and error' do
          expect { runner.ruby }.to raise_error
        end
      end

      context 'when building passes' do
        before do
          allow(Kernel).to receive(:system).and_return(true)
        end

        it 'succeeds' do
          expect { runner.ruby }.not_to raise_error
        end
      end
    end
  end
end
