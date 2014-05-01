require 'spec_helper'
require 'bosh/dev/stemcell_vm'
require 'bosh/stemcell/build_environment'

module Bosh::Dev
  describe StemcellVm do
    describe '#publish' do
      let(:options) do
        {
          vm_name: 'remote',
          infrastructure_name: 'fake-infrastructure_name',
          operating_system_name: 'fake-operating_system_name',
          operating_system_version: 'fake-operating_system_version',
          agent_name: 'fake-agent_name',
          os_image_s3_bucket_name: 'fake-bucket',
          os_image_s3_key: 'fake-key',
        }
      end

      let(:env) do
        {
          'CANDIDATE_BUILD_NUMBER' => 'fake-CANDIDATE_BUILD_NUMBER',
          'BOSH_AWS_ACCESS_KEY_ID' => 'fake-BOSH_AWS_ACCESS_KEY_ID',
          'BOSH_AWS_SECRET_ACCESS_KEY' => 'fake-BOSH_AWS_SECRET_ACCESS_KEY',
        }
      end

      let(:build_environment) { instance_double('Bosh::Stemcell::BuildEnvironment', stemcell_file: 'fake-stemcell.tgz') }

      subject(:vm) { StemcellVm.new(options, env, build_environment) }

      before { allow(Rake::FileUtilsExt).to receive(:sh) }

      it 'changes to the bosh-stemcell dir so its Vagrantfile is visible' do
        expect(Rake::FileUtilsExt).to receive(:sh).with(/cd bosh-stemcell/)

        vm.publish
      end

      it 'avoids loading the virtualbox driver by checking for a running ami' do
        expect(Rake::FileUtilsExt).to receive(:sh).with(include('[ -e .vagrant/machines/remote/aws/id ] && vagrant destroy remote --force'))

        vm.publish
      end

      it 'recreates the VM to ensure a clean environment' do
        expect(Rake::FileUtilsExt).to receive(:sh) do |cmd|
          expect(cmd).to match /vagrant destroy remote --force/
          expect(cmd).to match /vagrant up remote/
        end

        vm.publish
      end

      describe 'publishing the stemcell inside the VM' do
        def expected_cmd(rake_task_args, stemcell_path)
          strip_heredoc(<<-BASH)
            vagrant ssh -c "
              bash -l -c '
                set -eu
                cd /bosh

                export CANDIDATE_BUILD_NUMBER='fake-CANDIDATE_BUILD_NUMBER'
                export BOSH_AWS_ACCESS_KEY_ID='fake-BOSH_AWS_ACCESS_KEY_ID'
                export BOSH_AWS_SECRET_ACCESS_KEY='fake-BOSH_AWS_SECRET_ACCESS_KEY'

                bundle exec rake stemcell:build[#{rake_task_args}]
                bundle exec rake ci:publish_stemcell[#{stemcell_path}]
              '
            " remote
          BASH
        end

        it 'publishes a stemcell inside the VM' do
          expect(Rake::FileUtilsExt).to receive(:sh) do |cmd|
            actual = strip_heredoc(cmd)
            expected = expected_cmd(
              'fake-infrastructure_name,fake-operating_system_name,fake-operating_system_version,fake-agent_name,fake-bucket,fake-key',
              'fake-stemcell.tgz'
            )

            expect(actual).to include(expected)
          end

          vm.publish
        end
      end

      it 'cleans up the VM even if something fails' do
        expect(Rake::FileUtilsExt).to receive(:sh) do |cmd|
          raise 'BANG' if cmd =~ /rake ci:publish_stemcell/

          actual = strip_heredoc(cmd)
          expected = strip_heredoc(<<-BASH)
            set -eu
            cd bosh-stemcell
            vagrant destroy remote --force
          BASH

          expect(actual).to include(expected)
        end.twice

        expect { vm.publish }.to raise_error('BANG')
      end

      context 'when the UBUNTU_ISO is (optionally) specified' do
        before { env['UBUNTU_ISO'] = 'fake-UBUNTU_ISO' }

        it 'exports UBUNTU_ISO for vagrant ssh -c' do
          expect(Rake::FileUtilsExt).to receive(:sh).with(/export UBUNTU_ISO='fake-UBUNTU_ISO'/)

          vm.publish
        end
      end

      it 'fails early' do
        expect(Rake::FileUtilsExt).to receive(:sh).with(/set -eu/)

        vm.publish
      end

      context 'when the vm is "remote"' do
        before { options[:vm_name] = 'remote' }

        it 'uses the "aws" provider' do
          expect(Rake::FileUtilsExt).to receive(:sh).with(/vagrant up remote --provider aws/)

          vm.publish
        end
      end

      context 'when the vm is "local"' do
        before { options[:vm_name] = 'local' }

        it 'uses the "virtualbox" provider' do
          expect(Rake::FileUtilsExt).to receive(:sh).with(/vagrant up local --provider virtualbox/)

          vm.publish
        end
      end

      context 'when the vm is "anything-else"' do
        before { options[:vm_name] = 'unrecognized-name' }

        it 'raises an error' do
          expect { vm.publish }.to raise_error(/must be 'local' or 'remote'/)
        end
      end
    end

    def strip_heredoc(str)
      indent = str.scan(/^[ \t]*(?=\S)/).min.size
      str.gsub(/^[ \t]{#{indent}}/, '')
    end
  end
end
