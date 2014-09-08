require 'spec_helper'
require 'bosh/dev/vm_command/build_and_publish_stemcell_command'

module Bosh::Dev
  describe VmCommand::BuildAndPublishStemcellCommand do
    subject(:command) { VmCommand::BuildAndPublishStemcellCommand.new(build_environment, env, options) }

    let(:env) do
      {
        'CANDIDATE_BUILD_NUMBER' => 'fake-CANDIDATE_BUILD_NUMBER',
        'BOSH_AWS_ACCESS_KEY_ID' => 'fake-BOSH_AWS_ACCESS_KEY_ID',
        'BOSH_AWS_SECRET_ACCESS_KEY' => 'fake-BOSH_AWS_SECRET_ACCESS_KEY',
      }
    end

    let(:build_environment) { double('Bosh::Stemcell::BuildEnvironment', stemcell_file: 'fake-stemcell.tgz') }
    let(:options) do
      {
        infrastructure_name: 'fake-infrastructure_name',
        hypervisor_name: 'fake-hypervisor_name',
        operating_system_name: 'fake-operating_system_name',
        operating_system_version: 'fake-operating_system_version',
        agent_name: 'fake-agent_name',
        os_image_s3_bucket_name: 'fake-bucket',
        os_image_s3_key: 'fake-key',
      }
    end

    describe '#to_s' do
      it 'is the command to execute on vagrant to build and publish a stemcell' do
        expected_cmd = <<-BASH
          set -eu

          cd /bosh

          export CANDIDATE_BUILD_NUMBER='fake-CANDIDATE_BUILD_NUMBER'
          export BOSH_AWS_ACCESS_KEY_ID='fake-BOSH_AWS_ACCESS_KEY_ID'
          export BOSH_AWS_SECRET_ACCESS_KEY='fake-BOSH_AWS_SECRET_ACCESS_KEY'

          bundle exec rake stemcell:build[fake-infrastructure_name,fake-hypervisor_name,fake-operating_system_name,fake-operating_system_version,fake-agent_name,fake-bucket,fake-key]
          bundle exec rake ci:publish_stemcell[fake-stemcell.tgz]
        BASH

        expect(strip_heredoc(subject.to_s)).to eq(strip_heredoc(expected_cmd))
      end

      context "when the environment contains UBUNTU_ISO" do
        before { env['UBUNTU_ISO'] = 'fake-UBUNTU_ISO' }

        it 'includes the UBUNTU_ISO export' do
          subject.to_s.should_not match(/bundle.*(?=export)/m)
          subject.to_s.should match(/export UBUNTU_ISO='fake-UBUNTU_ISO'/)
        end
      end
    end

    def strip_heredoc(str)
      str.gsub(/^\s+/, '')
    end
  end
end

