require 'spec_helper'

describe Bhm::Deployment do

  describe '.create' do
    context 'from valid hash' do
      let(:deployment_data) { {'name' => 'deployment_name'} }

      it 'creates a deployment' do
        deployment = Bhm::Deployment.create(deployment_data)

        expect(deployment).to be_a(Bhm::Deployment)
      end
    end

    context 'from invalid hash' do
      let(:deployment_data) { {} }

      it 'fails to create a deployment' do
        deployment = Bhm::Deployment.create(deployment_data)

        expect(deployment).to be_nil
      end
    end

    context 'from invalid data' do
      let(:deployment_data) { 'no-hash' }

      it 'fails to create deployment' do
        deployment = Bhm::Deployment.create(deployment_data)

        expect(deployment).to be_nil
      end
    end
  end

  describe '#add_instance' do
    let(:deployment) { Bhm::Deployment.create({'name' => 'deployment-name'}) }

    it "add instance with well formed director instance data" do
      expect(deployment.add_instance(Bhm::Instance.create({'id' => 'iuuid', 'job' => 'zb', 'index' => '0', 'expects_vm' => true}))).to be(true)
      expect(deployment.instance('iuuid')).to be_a(Bhm::Instance)
      expect(deployment.instance('iuuid').id).to eq('iuuid')
      expect(deployment.instance('iuuid').deployment).to eq('deployment-name')
    end

    it "add only new instances" do
      deployment.add_instance(Bhm::Instance.create({'id' => 'iuuid', 'job' => 'zb', 'index' => '0', 'expects_vm' => true}))
      deployment.add_instance(Bhm::Instance.create({'id' => 'iuuid', 'job' => 'zb', 'index' => '0', 'expects_vm' => true}))

      expect(deployment.instances.size).to eq(1)
    end

    it "refuse to add instance with 'expects_vm=false'" do
      expect(deployment.add_instance(Bhm::Instance.create({'id' => 'iuuid', 'job' => 'zb', 'index' => '0', 'expects_vm' => false}))).to be(false)
    end

    it 'overrides existing instance' do
      deployment.add_instance(Bhm::Instance.create({'id' => 'iuuid', 'agent_id' => 'auuid', 'cid' => 'cid', 'expects_vm' => true}))
      updated_instance = Bhm::Instance.create({'id' => 'iuuid', 'agent_id' => 'another-auuid', 'cid' => 'another-cid', 'expects_vm' => true})

      deployment.add_instance(updated_instance)

      expect(deployment.instance('iuuid')).to eq(updated_instance)
    end
  end

  describe '#instance_ids' do
    let(:deployment) { Bhm::Deployment.create({'name' => 'deployment-name'}) }

    before do
      deployment.add_instance(Bhm::Instance.create({'id' => 'iuuid1', 'job' => 'zb', 'index' => '0', 'expects_vm' => true}))
      deployment.add_instance(Bhm::Instance.create({'id' => 'iuuid2', 'job' => 'zb', 'index' => '0', 'expects_vm' => true}))
    end

    it "returns all instance ids" do
      expect(deployment.instance_ids).to eq(['iuuid1', 'iuuid2'].to_set)
    end

    it "removes ids from removed instances" do
      deployment.remove_instance('iuuid1')
      expect(deployment.instance_ids).to eq(['iuuid2'].to_set)
    end
  end

  describe '#remove_instance' do
    let(:deployment) { Bhm::Deployment.create({'name' => 'deployment-name'}) }

    it "remove instance with id" do
      deployment.add_instance(Bhm::Instance.create({'id' => 'iuuid', 'job' => 'zb', 'index' => '0', 'expects_vm' => true}))

      expect(deployment.instance('iuuid')).to be_a(Bhm::Instance)
      expect(deployment.remove_instance('iuuid').id).to be_truthy
      expect(deployment.instance('iuuid')).to be_nil
    end
  end

  describe '#upsert_agent' do
    let(:deployment) { Bhm::Deployment.create({'name' => 'deployment-name'}) }
    let(:instance) { Bhm::Instance.create({'id' => 'iuuid', 'agent_id' => 'auuid', 'job' => 'zb', 'index' => '0', 'expects_vm' => true}) }

    it "adds agent" do
      expect(deployment.upsert_agent(instance)).to be(true)
      expect(deployment.agent('auuid')).to be_a(Bhm::Agent)
      expect(deployment.agent('auuid').id).to eq('auuid')
      expect(deployment.agent('auuid').deployment).to eq('deployment-name')
    end

    it "updates existing agents" do
      updated_instance = Bhm::Instance.create({'id' => 'iuuid', 'agent_id' => 'auuid', 'job' => 'new_job', 'index' => '0', 'expects_vm' => true})

      deployment.upsert_agent(instance)
      deployment.upsert_agent(updated_instance)

      expect(deployment.agents.size).to eq(1)
      expect(deployment.agent('auuid').id).to eq('auuid')
      expect(deployment.agent('auuid').job).to eq('new_job')
    end

    context 'Instance has no agent id' do
      let(:instance) { Bhm::Instance.create({'id' => 'iuuid', 'job' => 'zb', 'index' => '0', 'expects_vm' => true}) }
      it "refuses to add agent" do
        expect(deployment.upsert_agent(instance)).to be_falsey
      end
    end
  end

  describe '#remove_agent' do
    let(:deployment) { Bhm::Deployment.create({'name' => 'deployment-name'}) }
    let(:instance) { Bhm::Instance.create({'id' => 'iuuid', 'agent_id' => 'auuid', 'job' => 'zb', 'index' => '0', 'expects_vm' => true}) }

    it "remove agent with id" do
      deployment.upsert_agent(instance)

      expect(deployment.agent('auuid')).to be_a(Bhm::Agent)
      expect(deployment.remove_agent('auuid').id).to be_truthy
      expect(deployment.agent('auuid')).to be_nil
    end
  end

  describe '#agent_ids' do
    let(:deployment) { Bhm::Deployment.create({'name' => 'deployment-name'}) }

    before do
      deployment.upsert_agent(Bhm::Instance.create({'id' => 'iuuid1', 'agent_id' => 'auuid1', 'job' => 'zb', 'index' => '0', 'expects_vm' => true}))
      deployment.upsert_agent(Bhm::Instance.create({'id' => 'iuuid2', 'agent_id' => 'auuid2', 'job' => 'zb', 'index' => '0', 'expects_vm' => true}))
    end

    it "returns all agent ids" do
      expect(deployment.agent_ids).to eq(['auuid1', 'auuid2'].to_set)
    end

    it "removes ids from removed agents" do
      deployment.remove_agent('auuid1')

      expect(deployment.agent_ids).to eq(['auuid2'].to_set)
    end
  end
end
