# Copyright (c) 2009-2013 GoPivotal, Inc.

require File.expand_path("../../../spec_helper", __FILE__)

describe Bosh::Director::Api::StemcellManager do

  let(:tmpdir) { Dir::tmpdir }
  let(:user) { Bosh::Director::Models::User.make }
  let(:task_id) { 1 }
  let(:task) { double('task', :id => task_id) }
  let(:stemcell) { 'stemcell_location' }
  let(:stemcell_manager) { described_class.new }

  describe 'create_stemcell' do
    before do
      stemcell_manager.stub(:create_task).and_return(task)
      SecureRandom.stub(:uuid).and_return('uuid')
    end   

    context 'local stemcell' do
      it 'enqueues a task to upload a local stemcell' do                
        stemcell_manager.should_receive(:check_available_disk_space).and_return(true)
        stemcell_manager.should_receive(:write_file)
        Resque.should_receive(:enqueue).with(BD::Jobs::UpdateStemcell, task_id, "#{tmpdir}/stemcell-uuid", {})
        
        expect(stemcell_manager.create_stemcell(user, stemcell)).to eql(task)
      end      
    end
    
    context 'remote stemcell' do
      it 'enqueues a task to upload a remote stemcell' do
        Resque.should_receive(:enqueue).with(BD::Jobs::UpdateStemcell, task_id, stemcell, {:remote => true})
        
        expect(stemcell_manager.create_stemcell(user, stemcell, :remote => true)).to eql(task)
      end
    end
  end  
end