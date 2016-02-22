require 'spec_helper'

module Bosh::Director
  describe ArpFlusher do
    after(:each) do
      # clear out the DB to clear state
    end

    describe "#filter_instances" do
      let(:ip_addresses) { ["10.0.0.1"] }

      it "excludes the VM being created" do
        3.times do |i|
          Bosh::Director::Models::Instance.make(uuid: SecureRandom.uuid, index: i, job: "fake-job-#{i}", vm_cid: nil)
        end
        Bosh::Director::Models::Instance.make(uuid: SecureRandom.uuid, index: 0, job: "fake-job-0", vm_cid: "fake-cid-0")
        vm_being_created_cid = "fake-cid-0"

        arp_flusher = ArpFlusher.new
        instances = arp_flusher.filter_instances(vm_being_created_cid)

        expect(instances.count).to eq 0
      end

      it "excludes VMs where the cid is nil" do
        3.times do |i|
          Bosh::Director::Models::Instance.make(uuid: SecureRandom.uuid, index: i, job: "fake-job-#{i}", vm_cid: nil)
        end
        vm_being_created_cid = "fake-cid-99"

        arp_flusher = ArpFlusher.new
        instances = arp_flusher.filter_instances(vm_being_created_cid)

        expect(instances.count).to eq 0
      end

      it "excludes compilation VMs" do
        Bosh::Director::Models::Instance.make(uuid: SecureRandom.uuid, index: 0, job: "fake-job-0", vm_cid: "fake-cid-0", compilation: true)
        vm_being_created_cid = "fake-cid-99"

        arp_flusher = ArpFlusher.new
        instances = arp_flusher.filter_instances(vm_being_created_cid)

        expect(instances.count).to eq 0
      end

      it "includes VMs that need flushing" do
        agent = Bosh::Director::Models::Instance.make(uuid: SecureRandom.uuid, index: 0, job: "fake-job-0", vm_cid: "fake-cid-0")
        vm_being_created_cid = "fake-cid-99"

        arp_flusher = ArpFlusher.new
        instances = arp_flusher.filter_instances(vm_being_created_cid)

        expect(instances).to eq [agent]
      end
    end

    describe "#delete_from_arp" do
      let(:vm_being_created_cid) { "fake-cid-99" }
      let(:ip_addresses) { ["10.0.0.1"] }
      let(:agent) { instance_double(AgentClient, wait_until_ready: nil, delete_from_arp: nil)}
      let(:instance) { Bosh::Director::Models::Instance.make(uuid: SecureRandom.uuid, index: 1, job: "fake-job-1", vm_cid: "id") }
      let(:arp_flusher) { ArpFlusher.new }

      before do
        allow(AgentClient).to receive(:with_vm_credentials_and_agent_id).
          with(instance.credentials, instance.agent_id).and_return(agent)
      end

      it "creates an AgentClient for each instance" do
        expect(AgentClient).to receive(:with_vm_credentials_and_agent_id).
          with(instance.credentials, instance.agent_id).and_return(agent)

        arp_flusher.delete_from_arp(vm_being_created_cid, ip_addresses)
      end

      it "tells the AgentClient to delete the IPs from the ARP cache" do
        arp_flusher.delete_from_arp(vm_being_created_cid, ip_addresses)

        expect(agent).to have_received(:delete_from_arp).with(ips: ip_addresses)
      end
    end
  end
end
