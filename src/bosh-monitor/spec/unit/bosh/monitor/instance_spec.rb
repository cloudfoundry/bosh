require 'spec_helper'

describe Bosh::Monitor::Instance do
  it 'refuses to create instance with malformed director instance data' do
    expect(Bosh::Monitor::Instance.create(['zb'])).to be_nil # not a Hash
  end

  it 'refuses to create instance with missing instance id' do
    expect(Bosh::Monitor::Instance.create('agent_id' => 'auuid')).to be_nil # not a Hash
  end

  it 'create instance with well formed director instance data' do
    instance = Bosh::Monitor::Instance.create(
      'id' => 'iuuid',
      'agent_id' => 'auuid',
      'job' => 'zb',
      'index' => '0',
      'cid' => 'cuuid',
      'expects_vm' => true,
      'job_state' => 'running',
      'has_processes' => true
    )

    expect(instance).to be_a(Bosh::Monitor::Instance)
    expect(instance.id).to eq('iuuid')
    expect(instance.agent_id).to eq('auuid')
    expect(instance.job).to eq('zb')
    expect(instance.index).to eq('0')
    expect(instance.cid).to eq('cuuid')
    expect(instance.expects_vm).to be_truthy
    expect(instance.job_state).to eq('running')
    expect(instance.has_processes).to be_truthy
  end

  describe '#vm?' do
    context 'instance has no vm' do
      it 'returns false' do
        instance = Bosh::Monitor::Instance.create(
          'id' => 'iuuid',
          'agent_id' => 'auuid',
          'job' => 'zb',
          'index' => '0',
          'expects_vm' => true,
          'job_state' => 'running',
          'has_processes' => false
        )

        expect(instance.vm?).to be_falsey
      end
    end

    context 'instance has vm' do
      it 'returns true' do
        instance = Bosh::Monitor::Instance.create(
          'id' => 'iuuid',
          'agent_id' => 'auuid',
          'job' => 'zb',
          'index' => '0',
          'cid' => 'cuuid',
          'expects_vm' => true,
          'job_state' => 'running',
          'has_processes' => true
        )

        expect(instance.vm?).to be_truthy
      end
    end
  end

  describe '#name' do
    let(:instance) do
      Bosh::Monitor::Instance.create(
        'id' => 'iuuid',
        'agent_id' => 'auuid',
        'job' => 'zb',
        'index' => '0',
        'cid' => 'cuuid',
        'expects_vm' => true,
        'job_state' => 'running',
        'has_processes' => true
      )
    end

    before do
      instance.deployment = 'my_deployment'
    end

    context 'instance has all attributes' do
      it 'returns full name' do
        expect(instance.name).to eq('my_deployment: zb(iuuid) [agent_id=auuid, index=0, job_state=running, has_processes=true, cid=cuuid]')
      end
    end

    context 'instance has no job, agent_id, index and cid' do
      let(:instance) { Bosh::Monitor::Instance.create('id' => 'iuuid', 'expects_vm' => true) }

      it 'returns name without missing attributes' do
        expect(instance.name).to eq('my_deployment: instance iuuid [expects_vm=true]')
      end
    end

    context 'instance has no job' do
      let(:instance) do
        Bosh::Monitor::Instance.create('id' => 'iuuid', 'agent_id' => 'auuid', 'index' => '0', 'cid' => 'cuuid', 'expects_vm' => true, 'job_state' => nil, 'has_processes' => false)
      end

      it 'returns name without job' do
        expect(instance.name).to eq('my_deployment: instance iuuid [agent_id=auuid, index=0, cid=cuuid, expects_vm=true]')
      end
    end

    context 'instance has no index' do
      let(:instance) do
        Bosh::Monitor::Instance.create('id' => 'iuuid', 'agent_id' => 'auuid', 'job' => 'zb', 'cid' => 'cuuid', 'expects_vm' => true, 'job_state' => 'failing', 'has_processes' => false)
      end

      it 'returns name without index' do
        expect(instance.name).to eq('my_deployment: zb(iuuid) [agent_id=auuid, job_state=failing, cid=cuuid]')
      end
    end

    context 'instance has no agent_id' do
      let(:instance) do
        Bosh::Monitor::Instance.create('id' => 'iuuid', 'job' => 'zb', 'index' => '0', 'cid' => 'cuuid', 'expects_vm' => true, 'job_state' => nil, 'has_processes' => false)
      end

      it 'returns name without agent_id ' do
        expect(instance.name).to eq('my_deployment: zb(iuuid) [index=0, cid=cuuid]')
      end
    end

    context 'instance has no cid' do
      let(:instance) do
        Bosh::Monitor::Instance.create('id' => 'iuuid', 'agent_id' => 'auuid', 'job' => 'zb', 'index' => '0', 'expects_vm' => true, 'job_state' => nil, 'has_processes' => false)
      end

      it 'returns name without cid' do
        expect(instance.name).to eq('my_deployment: zb(iuuid) [agent_id=auuid, index=0, cid=]')
      end
    end
  end
end
