require 'spec_helper'
require 'bat/bosh_helper'

describe Bat::BoshHelper do
  subject(:bosh_helper) do
    Class.new { include Bat::BoshHelper }.new
  end

  before do
    stub_const('ENV', {})
    bosh_helper.stub(:puts)
  end

  describe '#bosh' do
    let(:bosh_exec) { class_double('Bosh::Exec').as_stubbed_const(transfer_nested_constants: true) }
    let(:bosh_exec_result) { instance_double('Bosh::Exec::Result', output: 'FAKE_OUTPUT') }

    it 'uses Bosh::Exec to shell out to bosh' do
      expected_command = %W(
        bundle exec bosh
        --non-interactive
        -P 1
        --config #{Bat::BoshHelper.bosh_cli_config_path}
        --user admin --password admin
        FAKE_ARGS 2>&1
      ).join(' ')
      bosh_helper.should_receive(:puts).with("--> #{expected_command}")
      bosh_exec.should_receive(:sh).with(expected_command, {}).and_return(bosh_exec_result)

      bosh_helper.bosh('FAKE_ARGS')
    end

    it 'returns the result of Bosh::Exec' do
      bosh_exec.stub(sh: bosh_exec_result)

      expect(bosh_helper.bosh('FAKE_ARGS')).to eq(bosh_exec_result)
    end

    context 'when options are passed' do
      it 'passes the options to Bosh::Exec' do
        bosh_exec.should_receive(:sh).with(anything, { foo: :bar }).and_return(bosh_exec_result)

        bosh_helper.bosh('FAKE_ARGS', { foo: :bar })
      end
    end

    context 'when bosh command raises an error' do
      it 'prints Bosh::Exec::Error messages and re-raises' do
        bosh_exec.stub(:sh).and_raise(Bosh::Exec::Error.new(1, 'fake command', 'fake output'))

        expect {
          bosh_helper.bosh('FAKE_ARG')
        }.to raise_error(Bosh::Exec::Error, /fake command/)
      end
    end

    it 'prints the output from the Bosh::Exec result' do
      bosh_exec.stub(:sh).and_return(bosh_exec_result)

      bosh_helper.should_receive(:puts).with('FAKE_OUTPUT')

      bosh_helper.bosh('fake arg')
    end

    context 'when a block is passed' do
      it 'yields the Bosh::Exec result' do
        bosh_exec.stub(sh: bosh_exec_result)

        expect { |b|
          bosh_helper.bosh('fake arg', &b)
        }.to yield_with_args(bosh_exec_result)
      end
    end
  end

  describe '#bosh_bin' do
    context 'when BAT_BOSH_BIN is set in the env' do
      its(:bosh_bin) { should eq('bundle exec bosh') }
    end

    context 'when BAT_BOSH_BIN is not set in the env' do
      before { ENV['BAT_BOSH_BIN'] = '/fake/path/to/bosh' }
      its(:bosh_bin) { should eq('/fake/path/to/bosh') }
    end
  end

  describe '#bosh_director' do
    context 'when BAT_DIRECTOR is set in the env' do
      before { ENV['BAT_DIRECTOR'] = 'fake_director.hamazon.com' }
      its(:bosh_director) { should eq('fake_director.hamazon.com') }
    end

    context 'when BAT_DIRECTOR is not set in the env' do
      it 'raises an error' do
        expect {
          bosh_helper.bosh_director
        }.to raise_error /BAT_DIRECTOR not set/
      end
    end
  end

  describe '#password' do
    context 'when BAT_VCAP_PASSWORD is set in the env' do
      before { ENV['BAT_VCAP_PASSWORD'] = 'fake_director.hamazon.com' }
      its(:password) { should eq('fake_director.hamazon.com') }
    end

    context 'when BAT_VCAP_PASSWORD is not set in the env' do
      it 'raises an error' do
        expect {
          bosh_helper.password
        }.to raise_error /BAT_VCAP_PASSWORD not set/
      end
    end
  end

  describe '#ssh_options' do
    context 'when both env vars BAT_VCAP_PASSWORD and BAT_VCAP_PRIVATE_KEY are set' do
      before do
        ENV['BAT_VCAP_PASSWORD'] = 'fake_password'
        ENV['BAT_VCAP_PRIVATE_KEY'] = 'fake_private_key'
      end
      its(:ssh_options) { should eq(private_key: 'fake_private_key', password: 'fake_password') }
    end

    context 'when BAT_VCAP_PASSWORD is not set in env' do
      it 'raises an error' do
        expect {
          bosh_helper.ssh_options
        }.to raise_error(/BAT_VCAP_PASSWORD not set/)
      end
    end

    context 'when BAT_VCAP_PRIVATE_KEY is not set in env' do
      before { ENV['BAT_VCAP_PASSWORD'] = 'fake_password' }
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
        Bosh::Exec.stub(:sh).with(/bundle exec bosh .* vms --details/, {}).and_return(fake_result)
      end

      it 'returns the vm details' do
        expect(bosh_helper.wait_for_vm('jessez/0')).to(
          eq(
            {
              job_index: 'jessez/0',
              state: 'running',
              resource_pool: 'fake_pool',
              ips: '10.20.30.1',
              cid: 'i-cid',
              agent_id: 'fake-agent-id',
              resurrection: 'active',
            }
          )
        )
      end
    end

    context 'when the named vm is not contained in the output of "bosh vms"' do
      before { Bosh::Exec.stub(:sh).with(/bosh .* vms --details/, {}).and_return(double('fake result', output: '')) }

      it 'returns nil' do
        expect(bosh_helper.wait_for_vm('jessez/0')).to be_nil
      end
    end

    context 'when the named vms was not in bosh vms output at first, but appear after 4 retries' do
      let(:bad_result) { double('fake exec result', output: bosh_vms_output_without_jesse) }
      let(:good_result) { double('fake good exec result', output: successful_bosh_vms_output) }
      before do
        Bosh::Exec.stub(:sh).with(
          /bosh .* vms --details/, {}
        ).and_return(
          bad_result,
          bad_result,
          bad_result,
          good_result,
        )
      end

      it 'returns the vm details' do
        expect(bosh_helper.wait_for_vm('jessez/0')).to(
          eq(
            {
              job_index: 'jessez/0',
              state: 'running',
              resource_pool: 'fake_pool',
              ips: '10.20.30.1',
              cid: 'i-cid',
              agent_id: 'fake-agent-id',
              resurrection: 'active',
            }
          )
        )
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
