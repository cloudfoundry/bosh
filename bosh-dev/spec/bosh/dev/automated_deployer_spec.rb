require 'spec_helper'

require 'bosh/dev/automated_deployer'

module Bosh::Dev
  describe AutomatedDeployer do
    let(:target) { 'micro.target.example.com' }
    let(:username) { 'user' }
    let(:password) { 'password' }

    let(:manifest_path) { '/tmp/manifest.yml' }
    let(:stemcell_path) { '/tmp/stemcell.tgz' }
    let(:release_path) { '/tmp/release.tgz' }

    let(:cli) { instance_double('Bosh::Dev::BoshCliSession').as_null_object }

    subject(:deployer) { AutomatedDeployer.new(target: target, username: username, password: password, cli: cli) }

    describe '#deploy' do
      def bosh_should_be_called_with(*args)
        cli.should_receive(:run_bosh).with(*args).ordered
      end

      it 'follows the normal deploy procedure' do
        bosh_should_be_called_with 'target micro.target.example.com'
        bosh_should_be_called_with 'login user password'
        bosh_should_be_called_with 'deployment /tmp/manifest.yml'
        bosh_should_be_called_with 'upload stemcell /tmp/stemcell.tgz', debug_on_fail: true
        bosh_should_be_called_with 'upload release /tmp/release.tgz', debug_on_fail: true
        bosh_should_be_called_with 'deploy', debug_on_fail: true

        deployer.deploy(manifest_path: manifest_path, release_path: release_path,
                        stemcell_path: stemcell_path, cli: cli)
      end
    end
  end
end