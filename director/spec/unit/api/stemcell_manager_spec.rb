# Copyright (c) 2009-2013 GoPivotal, Inc.

require 'spec_helper'

describe Bosh::Director::Api::StemcellManager do
  let(:tmpdir) { Dir::tmpdir }
  let(:user) { Bosh::Director::Models::User.make }
  let(:task_id) { 1 }
  let(:task) { double('task', :id => task_id) }
  let(:stemcell) { 'stemcell_location' }

  describe 'create_stemcell' do
    before do
      BD::JobQueue.any_instance.stub(create_task: task)
    end

    context 'local stemcell' do
      before do
        SecureRandom.stub(:uuid).and_return('FAKE_UUID')
      end

      it 'enqueues a task to upload a local stemcell' do
        subject.stub(check_available_disk_space: true)
        subject.stub(:write_file)

        Resque.should_receive(:enqueue).with(BD::Jobs::UpdateStemcell, task_id, "#{tmpdir}/stemcell-FAKE_UUID", {})
        
        expect(subject.create_stemcell(user, stemcell)).to eql(task)
      end      
    end
    
    context 'remote stemcell' do
      it 'enqueues a task to upload a remote stemcell' do
        Resque.should_receive(:enqueue).with(BD::Jobs::UpdateStemcell, task_id, stemcell, remote: true)
        
        expect(subject.create_stemcell(user, stemcell, remote: true)).to eql(task)
      end
    end
  end  
end