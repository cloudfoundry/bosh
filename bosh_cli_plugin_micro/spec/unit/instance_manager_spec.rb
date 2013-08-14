# Copyright (c) 2009-2012 VMware, Inc.

require 'spec_helper'

module Bosh
  module Deployer
    describe InstanceManager do
      let(:dir) { Dir.mktmpdir("bdim_spec") }
      let(:config) do
        config = Psych.load_file(spec_asset('test-bootstrap-config.yml'))
        config['dir'] = dir
        config['name'] = "spec-#{SecureRandom.uuid}"
        config['logging'] = { 'file' => "#{dir}/bmim.log" }
        config
      end
      let(:cloud) { instance_double('Bosh::Cloud') }
      let(:agent) { double('Bosh::Agent::HTTPClient') } # Uses method_missing :(
      let(:stemcell_tgz) { 'bosh-instance-1.0.tgz' }
      subject(:deployer) { InstanceManager.create(config) }

      before do
        Config.stub(cloud: cloud)
        Config.stub(agent: agent)
        Config.stub(agent_properties: {})
      end

      after do
        deployer.state.destroy
        FileUtils.remove_entry_secure dir
      end

      def load_deployment
        deployer.send(:load_deployments)["instances"].select { |d| d[:name] == deployer.state.name }.first
      end

      it 'populates disk model' do
        disk_model = deployer.disk_model
        disk_model.should == VSphereCloud::Models::Disk
        disk_model.columns.should include(:id)
        disk_model.count.should == 0
        cid = 22
        disk_model.insert(id: cid, size: 1024)
        disk_model.count.should == 1
        disk_model[cid].size.should == 1024
        disk_model[cid].destroy
        disk_model.count.should == 0
      end

      it "should create a Bosh instance" do
        spec = Psych.load_file(spec_asset("apply_spec.yml"))
        Specification.should_receive(:load_apply_spec).and_return(spec)

        deployer.stub(:run_command)
        deployer.stub(:wait_until_agent_ready)
        deployer.stub(:wait_until_director_ready)
        deployer.stub(:load_apply_spec).and_return(spec)
        deployer.stub(:load_stemcell_manifest).and_return({})

        deployer.state.uuid.should_not be_nil

        deployer.state.stemcell_cid.should be_nil
        deployer.state.vm_cid.should be_nil

        cloud.should_receive(:create_stemcell).and_return("SC-CID-CREATE")
        cloud.should_receive(:create_vm).and_return("VM-CID-CREATE")
        cloud.should_receive(:create_disk).and_return("DISK-CID-CREATE")
        cloud.should_receive(:attach_disk).with("VM-CID-CREATE", "DISK-CID-CREATE")
        agent.should_receive(:run_task).with(:mount_disk, "DISK-CID-CREATE").and_return({})
        agent.should_receive(:run_task).with(:stop)
        agent.should_receive(:run_task).with(:apply, spec)
        agent.should_receive(:run_task).with(:start)

        deployer.create(stemcell_tgz)

        deployer.state.stemcell_cid.should == "SC-CID-CREATE"
        deployer.state.vm_cid.should == "VM-CID-CREATE"
        deployer.state.disk_cid.should == "DISK-CID-CREATE"
        load_deployment.should == deployer.state.values

        deployer.renderer.total.should == deployer.renderer.index
      end

      it "should destroy a Bosh instance" do
        disk_cid = "33"
        deployer.state.disk_cid = disk_cid
        deployer.state.stemcell_name = File.basename(stemcell_tgz, ".tgz")
        deployer.state.stemcell_cid = "SC-CID-DESTROY"
        deployer.state.vm_cid = "VM-CID-DESTROY"

        agent.should_receive(:list_disk).and_return([disk_cid])
        agent.should_receive(:run_task).with(:stop)
        agent.should_receive(:run_task).with(:unmount_disk, disk_cid).and_return({})
        cloud.should_receive(:detach_disk).with("VM-CID-DESTROY", disk_cid)
        cloud.should_receive(:delete_disk).with(disk_cid)
        cloud.should_receive(:delete_vm).with("VM-CID-DESTROY")
        cloud.should_receive(:delete_stemcell).with("SC-CID-DESTROY")

        deployer.destroy

        deployer.state.stemcell_cid.should be_nil
        deployer.state.vm_cid.should be_nil
        deployer.state.disk_cid.should be_nil

        load_deployment.should == deployer.state.values

        deployer.renderer.total.should == deployer.renderer.index
      end

      it "should update a Bosh instance" do
        spec = Psych.load_file(spec_asset("apply_spec.yml"))
        Specification.should_receive(:load_apply_spec).and_return(spec)

        disk_cid = "22"
        deployer.stub(:run_command)
        deployer.stub(:wait_until_agent_ready)
        deployer.stub(:wait_until_director_ready)
        deployer.stub(:load_apply_spec).and_return(spec)
        deployer.stub(:load_stemcell_manifest).and_return({})

        deployer.state.stemcell_cid = "SC-CID-UPDATE"
        deployer.state.vm_cid = "VM-CID-UPDATE"
        deployer.state.disk_cid = disk_cid

        disk = deployer.disk_model.new
        disk.uuid = disk_cid
        disk.size = 4096
        disk.save

        agent.should_receive(:run_task).with(:stop)
        agent.should_receive(:run_task).with(:unmount_disk, disk_cid).and_return({})
        cloud.should_receive(:detach_disk).with("VM-CID-UPDATE", disk_cid)
        cloud.should_receive(:delete_vm).with("VM-CID-UPDATE")
        cloud.should_receive(:delete_stemcell).with("SC-CID-UPDATE")
        cloud.should_receive(:create_stemcell).and_return("SC-CID")
        cloud.should_receive(:create_vm).and_return("VM-CID")
        cloud.should_receive(:attach_disk).with("VM-CID", disk_cid)
        agent.should_receive(:run_task).with(:mount_disk, disk_cid).and_return({})
        agent.should_receive(:list_disk).and_return([disk_cid])
        agent.should_receive(:run_task).with(:stop)
        agent.should_receive(:run_task).with(:apply, spec)
        agent.should_receive(:run_task).with(:start)

        deployer.update(stemcell_tgz)

        deployer.state.stemcell_cid.should == "SC-CID"
        deployer.state.vm_cid.should == "VM-CID"
        deployer.state.disk_cid.should == disk_cid

        load_deployment.should == deployer.state.values
      end

      it "should fail to create a Bosh instance if stemcell CID exists" do
        deployer.state.stemcell_cid = "SC-CID"

        expect {
          deployer.create(stemcell_tgz)
        }.to raise_error(Bosh::Cli::CliError)
      end

      it "should fail to create a Bosh instance if VM CID exists" do
        deployer.state.vm_cid = "VM-CID"

        expect {
          deployer.create(stemcell_tgz)
        }.to raise_error(Bosh::Cli::CliError)
      end

      it "should fail to destroy a Bosh instance unless stemcell CID exists" do
        deployer.state.vm_cid = "VM-CID"
        agent.should_receive(:run_task).with(:stop)
        cloud.should_receive(:delete_vm).with("VM-CID")
        expect {
          deployer.destroy
        }.to raise_error(Bosh::Cli::CliError)
      end

      it "should fail to destroy a Bosh instance unless VM CID exists" do
        deployer.state.stemcell_cid = "SC-CID"
        agent.should_receive(:run_task).with(:stop)
        expect {
          deployer.destroy
        }.to raise_error(Bosh::Cli::CliError)
      end

      it "should provide a nice error if unable to connect to agent" do
        spec = Psych.load_file(spec_asset("apply_spec.yml"))
        Specification.should_receive(:load_apply_spec).and_return(spec)

        deployer.stub(:run_command)
        deployer.stub(:wait_until_agent_ready).and_raise(DirectorGatewayError)
        deployer.stub(:load_stemcell_manifest).and_return({})

        cloud.should_receive(:create_stemcell).and_return("SC-CID-CREATE")
        cloud.should_receive(:create_vm).and_return("VM-CID-CREATE")

        expect {
          deployer.create(stemcell_tgz)
        }.to raise_error(Bosh::Cli::CliError, /Unable to connect to Bosh agent/)
      end

      it "should provide a nice error if unable to connect to director" do
        spec = Psych.load_file(spec_asset("apply_spec.yml"))
        Specification.should_receive(:load_apply_spec).and_return(spec)

        deployer.stub(:run_command)
        deployer.stub(:wait_until_agent_ready)
        deployer.stub(:wait_until_director_ready).and_raise(DirectorGatewayError)
        deployer.stub(:load_apply_spec).and_return(spec)
        deployer.stub(:load_stemcell_manifest).and_return({})

        cloud.should_receive(:create_stemcell).and_return("SC-CID-CREATE")
        cloud.should_receive(:create_vm).and_return("VM-CID-CREATE")
        cloud.should_receive(:create_disk).and_return("DISK-CID-CREATE")
        cloud.should_receive(:attach_disk).with("VM-CID-CREATE", "DISK-CID-CREATE")
        agent.should_receive(:run_task).with(:mount_disk, "DISK-CID-CREATE").and_return({})
        agent.should_receive(:run_task).with(:stop)
        agent.should_receive(:run_task).with(:apply, spec)
        agent.should_receive(:run_task).with(:start)

        expect {
          deployer.create(stemcell_tgz)
        }.to raise_error(Bosh::Cli::CliError, /Unable to connect to Bosh Director/)
      end
    end
  end
end