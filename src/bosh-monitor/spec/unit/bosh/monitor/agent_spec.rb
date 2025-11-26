require 'spec_helper'

describe Bosh::Monitor::Agent do
  before :each do
    Bosh::Monitor.intervals = OpenStruct.new(agent_timeout: 344, rogue_agent_alert: 124)
  end

  def make_agent(id)
    Bosh::Monitor::Agent.new(id)
  end

  it 'knows if it is timed out' do
    now = Time.now
    agent = make_agent('007')
    expect(agent.timed_out?).to be(false)

    allow(Time).to receive(:now).and_return(now + 344)
    expect(agent.timed_out?).to be(false)

    allow(Time).to receive(:now).and_return(now + 345)
    expect(agent.timed_out?).to be(true)
  end

  it "knows if it is rogue if it isn't associated with deployment for :rogue_agent_alert seconds" do
    now = Time.now
    agent = make_agent('007')
    expect(agent.rogue?).to be(false)

    allow(Time).to receive(:now).and_return(now + 124)
    expect(agent.rogue?).to be(false)

    allow(Time).to receive(:now).and_return(now + 125)
    expect(agent.rogue?).to be(true)

    agent.deployment = 'mycloud'
    expect(agent.rogue?).to be(false)
  end

  it 'has name that depends on the currently known state' do
    agent = make_agent('zb')
    agent.cid = 'deadbeef'
    expect(agent.name).to eq('agent zb [cid=deadbeef]')
    agent.instance_id = 'iuuid'
    expect(agent.name).to eq('agent zb [instance_id=iuuid, cid=deadbeef]')
    agent.deployment = 'oleg-cloud'
    expect(agent.name).to eq('agent zb [deployment=oleg-cloud, instance_id=iuuid, cid=deadbeef]')
    agent.job = 'mysql_node'
    expect(agent.name).to eq('oleg-cloud: mysql_node(iuuid) [id=zb, cid=deadbeef]')
    agent.index = '0'
    expect(agent.name).to eq('oleg-cloud: mysql_node(iuuid) [id=zb, index=0, cid=deadbeef]')
  end

  describe '#update_instance' do
    context 'when given an instance' do
      let(:instance) do
        double('instance', job: 'job', index: 1, cid: 'cid', id: 'id')
      end

      it 'populates the corresponding attributes' do
        agent = make_agent('agent_with_instance')

        agent.update_instance(instance)

        expect(agent.job).to eq(instance.job)
        expect(agent.index).to eq(instance.index)
        expect(agent.cid).to eq(instance.cid)
        expect(agent.instance_id).to eq(instance.id)
      end

      it "does not modify job_state or process_length when updating instance" do
        agent = make_agent("agent_with_instance")
        agent.job_state = "running"
        agent.process_length = 3

        agent.update_instance(instance)

        expect(agent.job_state).to eq("running")
        expect(agent.process_length).to eq(3)
      end
    end
  end
end
