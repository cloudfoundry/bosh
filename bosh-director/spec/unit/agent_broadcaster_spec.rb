require 'spec_helper'

module Bosh::Director
  describe AgentBroadcaster do
    after(:each) do
      # clear out the DB to clear state
    end

    let(:ip_addresses) { ["10.0.0.1"] }
    let(:instance) { Bosh::Director::Models::Instance.make(uuid: SecureRandom.uuid, index: 1, job: "fake-job-1", vm_cid: "id-1") }
    let(:instance2) { Bosh::Director::Models::Instance.make(uuid: SecureRandom.uuid, index: 2, job: "fake-job-1", vm_cid: "id-2") }
    let(:agent) { double(AgentClient, wait_until_ready: nil, fake_method: nil, delete_arp_entries: nil)}
    let(:agent_broadcast) { AgentBroadcaster.new }

    describe "#filter_instances" do
      it "excludes the VM being created" do
        3.times do |i|
          Bosh::Director::Models::Instance.make(uuid: SecureRandom.uuid, index: i, job: "fake-job-#{i}", vm_cid: nil)
        end
        Bosh::Director::Models::Instance.make(uuid: SecureRandom.uuid, index: 0, job: "fake-job-0", vm_cid: "fake-cid-0")
        vm_being_created_cid = "fake-cid-0"

        agent_broadcast = AgentBroadcaster.new
        instances = agent_broadcast.filter_instances(vm_being_created_cid)

        expect(instances.count).to eq 0
      end

      it "excludes VMs where the cid is nil" do
        3.times do |i|
          Bosh::Director::Models::Instance.make(uuid: SecureRandom.uuid, index: i, job: "fake-job-#{i}", vm_cid: nil)
        end
        vm_being_created_cid = "fake-cid-99"

        agent_broadcast = AgentBroadcaster.new
        instances = agent_broadcast.filter_instances(vm_being_created_cid)

        expect(instances.count).to eq 0
      end

      it "excludes compilation VMs" do
        Bosh::Director::Models::Instance.make(uuid: SecureRandom.uuid, index: 0, job: "fake-job-0", vm_cid: "fake-cid-0", compilation: true)
        vm_being_created_cid = "fake-cid-99"

        agent_broadcast = AgentBroadcaster.new
        instances = agent_broadcast.filter_instances(vm_being_created_cid)

        expect(instances.count).to eq 0
      end

      it "includes VMs that need flushing" do
        agent = Bosh::Director::Models::Instance.make(uuid: SecureRandom.uuid, index: 0, job: "fake-job-0", vm_cid: "fake-cid-0")
        vm_being_created_cid = "fake-cid-99"

        agent_broadcast = AgentBroadcaster.new
        instances = agent_broadcast.filter_instances(vm_being_created_cid)

        expect(instances).to eq [agent]
      end
    end

    describe "#broadcast" do
      let(:vm_being_created_cid) { "fake-cid-99" }
      let(:agent2) { double(AgentClient, wait_until_ready: nil, fake_method: nil, delete_arp_entries: nil)}
      let(:instances) { [instance, instance2 ]}

      before do
        Config.max_threads = 5

        allow(AgentClient).to receive(:with_vm_credentials_and_agent_id).
          with(instance.credentials, instance.agent_id).and_return(agent)
      end

      it "broadcast fake_method with fake_arg to agents" do
        expect(AgentClient).to receive(:with_vm_credentials_and_agent_id).
          with(instance.credentials, instance.agent_id).and_return(agent)

        expect(AgentClient).to receive(:with_vm_credentials_and_agent_id).
            with(instance.credentials, instance2.agent_id).and_return(agent)

        agent_broadcast.broadcast(instances, :fake_method, 'fake-arg')
      end

      context 'when broadcast method is :delete_arp_entries' do
        it "creates an AgentClient for each instance" do
          expect(AgentClient).to receive(:with_vm_credentials_and_agent_id).
              with(instance.credentials, instance.agent_id).and_return(agent)

          agent_broadcast.broadcast([instance], :delete_arp_entries, ips: ip_addresses)
        end

        it "tells the AgentClient to delete the IPs from the ARP cache" do
          expect(agent).to receive(:delete_arp_entries).with(ips: ip_addresses)

          agent_broadcast.broadcast([instance], :delete_arp_entries, ips: ip_addresses)
        end
      end
    end

    describe "#delete_arp_entries" do
      it 'successfully broadcast :delete_arp_entries call' do
        expect(AgentClient).to receive(:with_vm_credentials_and_agent_id).
            with(instance.credentials, instance.agent_id).and_return(agent)
        expect(agent).to receive(:send).with(:delete_arp_entries, ips: ip_addresses)

        agent_broadcast.delete_arp_entries('fake-vm-cid-to-exclude', ip_addresses)
      end

      it 'successfully filers out id-1 and broadcast :delete_arp_entries call' do
        expect(AgentClient).to receive(:with_vm_credentials_and_agent_id).
            with(instance.credentials, instance.agent_id).and_return(agent)
        expect(AgentClient).to_not receive(:with_vm_credentials_and_agent_id).
            with(instance2.credentials, instance2.agent_id)

        agent_broadcast.delete_arp_entries('id-2', ip_addresses)
      end
    end

    describe "#sync_dns" do
      it 'successfully broadcast :sync_dns call' do
        expect(AgentClient).to receive(:with_vm_credentials_and_agent_id).
            with(instance.credentials, instance.agent_id).and_return(agent)
        expect(agent).to receive(:send).with(:sync_dns, 'fake-blob-id', 'fake-sha1')

        agent_broadcast.sync_dns('fake-blob-id', 'fake-sha1')
      end
    end
  end
end
