require 'spec_helper'
require 'bat/env'
require 'bat/bosh_runner'
require 'bat/bosh_helper'

describe Bat::BoshHelper do
  subject(:bosh_helper) do
    Class.new { include Bat::BoshHelper }.new
  end

  before { bosh_helper.instance_variable_set('@bosh_runner', bosh_runner) }
  let(:bosh_runner) { instance_double('Bat::BoshRunner') }

  before { bosh_helper.instance_variable_set('@bosh_runner', bosh_runner) }
  let(:bosh_runner) { instance_double('Bat::BoshRunner') }

  before { stub_const('ENV', {}) }

  before { bosh_helper.instance_variable_set('@logger', Logger.new('/dev/null')) }

  describe '#ssh_options' do
    before { bosh_helper.instance_variable_set('@env', env) }
    let(:env) { instance_double('Bat::Env', vcap_password: 'fake_password') }

    context 'when both env var BAT_VCAP_PRIVATE_KEY is set' do
      before { stub_const('ENV', 'BAT_VCAP_PRIVATE_KEY' => 'fake_private_key') }
      its(:ssh_options) { should eq(private_key: 'fake_private_key', password: 'fake_password') }
    end

    context 'when BAT_VCAP_PRIVATE_KEY is not set in env' do
      before { stub_const('ENV', {}) }
      its(:ssh_options) { should eq(password: 'fake_password', private_key: nil) }
    end
  end

  describe '#wait_for_vm' do
    # rubocop:disable LineLength
    let(:successful_bosh_vms_output) { <<OUTPUT }
Deployment `jesse'

Director task 1112

Task 5402 done

+-------------------------+---------+---------------+-------------+------------+--------------------------------------+--------------+
| Job/index               | State   | Resource Pool | IPs         | CID        | Agent ID                             | Resurrection |
+-------------------------+---------+---------------+-------------+------------+--------------------------------------+--------------+
| jessez/0                | running | fake_pool     | 10.20.30.1  | i-cid      | fake-agent-id                        | active       |
| uaa_z1/0                | running | small_z1      | 10.50.91.2  | i-24cb6153 | da74e0d8-d2a6-4b2d-904a-b2f0e3dacc49 | active       |
| uaa_z2/0                | running | timid_z2      | 10.60.80.3  | i-6b19c0da | c293814f-b613-c883-1862-2dcb34c566ad | active       |
+-------------------------+---------+---------------+-------------+------------+--------------------------------------+--------------+

VMs total: 3
OUTPUT
    # rubocop:enable LineLength

    # rubocop:disable LineLength
    let(:bosh_vms_output_without_jesse) { <<OUTPUT }
Deployment `jesse'

Director task 1112

Task 5402 done

+-------------------------+---------+---------------+-------------+------------+--------------------------------------+--------------+
| Job/index               | State   | Resource Pool | IPs         | CID        | Agent ID                             | Resurrection |
+-------------------------+---------+---------------+-------------+------------+--------------------------------------+--------------+
| uaa_z2/0                | running | timid_z2      | 10.60.80.3  | i-6b19c0da | c293814f-b613-c883-1862-2dcb34c566ad | active       |
+-------------------------+---------+---------------+-------------+------------+--------------------------------------+--------------+

VMs total: 1
OUTPUT
    # rubocop:enable LineLength

    context 'when "bosh vms" contains the named vm' do
      before do
        fake_result = double('fake bosh exec result', output: successful_bosh_vms_output)
        allow(bosh_runner).to receive(:bosh).with('vms --details').and_return(fake_result)
      end

      it 'returns the vm details' do
        expect(bosh_helper.wait_for_vm('jessez/0')).to(eq(
          job_index: 'jessez/0',
          state: 'running',
          resource_pool: 'fake_pool',
          ips: '10.20.30.1',
          cid: 'i-cid',
          agent_id: 'fake-agent-id',
          resurrection: 'active',
        ))
      end
    end

    context 'when the named vm is not contained in the output of "bosh vms"' do
      before { allow(bosh_runner).to receive(:bosh).with('vms --details').and_return(double('fake result', output: '')) }

      it 'returns nil' do
        expect(bosh_helper.wait_for_vm('jessez/0')).to be_nil
      end
    end

    context 'when the named vms was not in bosh vms output at first, but appear after 4 retries' do
      let(:bad_result) { double('fake exec result', output: bosh_vms_output_without_jesse) }
      let(:good_result) { double('fake good exec result', output: successful_bosh_vms_output) }
      before do
        allow(bosh_runner).to receive(:bosh).with('vms --details').and_return(
          bad_result,
          bad_result,
          bad_result,
          good_result,
        )
      end

      it 'returns the vm details' do
        expect(bosh_helper.wait_for_vm('jessez/0')).to(eq(
          job_index: 'jessez/0',
          state: 'running',
          resource_pool: 'fake_pool',
          ips: '10.20.30.1',
          cid: 'i-cid',
          agent_id: 'fake-agent-id',
          resurrection: 'active',
        ))
      end
    end
  end

  describe '#bosh_dns_host' do
    it 'should be the value of BAT_DNS_HOST env var' do
      ENV['BAT_DNS_HOST'] = 'dns.hamazon.com'
      expect(bosh_helper.bosh_dns_host).to eq('dns.hamazon.com')
    end
  end
end
