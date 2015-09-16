require 'spec_helper'
require 'rake'
require 'bosh/dev/stemcell_vm'

module Bosh::Dev
  describe StemcellVm do
    subject(:vm) { StemcellVm.new(vm_name) }

    before { class_double('Rake::FileUtilsExt', sh: nil).as_stubbed_const }

    describe '#run' do
      subject { vm.run('echo hello') }

      def self.it_runs_the_given_command_in_the_vm(vm_name, provider)
        let(:vm_name) { vm_name }

        it 'sets up the stemcell VM' do
          expect(Rake::FileUtilsExt).to receive(:sh) do |cmd, opt, actual_cmd|
            expect(cmd).to eq('bash')
            expect(opt).to eq('-c')
            expect(strip_heredoc(actual_cmd)).to include(strip_heredoc(<<-BASH))
              pushd bosh-stemcell
              [ -e .vagrant/machines/remote/aws/id ] && vagrant destroy #{vm_name} --force
              vagrant up #{vm_name} --provider #{provider}
              [ -e .vagrant/machines/remote/aws/id ] && cat .vagrant/machines/remote/aws/id
              popd
            BASH
          end

          subject
        end

        it 'runs the given command in the VM' do
          expect(Rake::FileUtilsExt).to receive(:sh) do |cmd, opt, actual_cmd|
            expect(cmd).to eq('bash')
            expect(opt).to eq('-c')
            expect(strip_heredoc(actual_cmd)).to include(strip_heredoc(<<-BASH))
              set -e

              pushd bosh-stemcell
              vagrant ssh -c "bash -l -c 'echo hello'" #{vm_name}
              popd
            BASH
          end

          subject
        end

        it 'cleans up the VM even if something fails' do
          allow(Rake::FileUtilsExt).to receive(:sh).and_raise('BANG')
          expect(Rake::FileUtilsExt).to receive(:sh) do |cmd, opt, actual_cmd|
            expect(cmd).to eq('bash')
            expect(opt).to eq('-c')
            expect(strip_heredoc(actual_cmd)).to include(strip_heredoc(<<-BASH))
              set -e

              pushd bosh-stemcell
              vagrant destroy remote --force
              popd
            BASH
          end

          expect { subject }.to raise_error('BANG')
        end
      end

      context 'when the vm is "remote"' do
        it_runs_the_given_command_in_the_vm('remote', 'aws')
      end

      context 'when the vm is "remote"' do
        it_runs_the_given_command_in_the_vm('local', 'virtualbox')
      end

      context 'when the vm is "anything-else"' do
        let(:vm_name) { 'unrecognized-name' }

        it 'raises an error' do
          expect { subject }.to raise_error(/must be 'local' or 'remote'/)
        end
      end
    end

    def strip_heredoc(str)
      indent = str.scan(/^[ \t]*(?=\S)/).min.size
      str.gsub(/^[ \t]{#{indent}}/, '')
    end
  end
end
