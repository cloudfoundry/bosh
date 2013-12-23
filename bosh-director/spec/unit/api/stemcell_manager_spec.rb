# Copyright (c) 2009-2013 GoPivotal, Inc.

require 'spec_helper'

module Bosh::Director
  describe Api::StemcellManager do
    let(:tmpdir) { Dir::tmpdir }
    let(:username) { 'username-1' }
    let(:task_id) { 1 }
    let(:task) { double('task', :id => task_id) }
    let(:stemcell) { 'stemcell_location' }
    let(:job_queue) { instance_double('Bosh::Director::JobQueue') }

    describe 'create_stemcell' do
      before do
        JobQueue.stub(:new).and_return(job_queue)
      end

      context 'local stemcell' do
        let(:options) { { foo: 'bar' } }

        before do
          SecureRandom.stub(:uuid).and_return('FAKE_UUID')
        end

        it 'enqueues a task to upload a local stemcell' do
          subject.stub(check_available_disk_space: true)
          subject.stub(:write_file)

          job_queue.should_receive(:enqueue).with(username,
                                                  Jobs::UpdateStemcell,
                                                  'create stemcell',
                                                  [File.join(tmpdir, 'stemcell-FAKE_UUID'), options]).and_return(task)

          expect(subject.create_stemcell(username, stemcell, options)).to eql(task)
        end
      end

      context 'remote stemcell' do
        let(:options) { { remote: true } }

        it 'enqueues a task to upload a remote stemcell' do
          job_queue.should_receive(:enqueue).with(username,
                                                  Jobs::UpdateStemcell,
                                                  'create stemcell',
                                                  [stemcell, options]).and_return(task)

          expect(subject.create_stemcell(username, stemcell, options)).to eql(task)
        end
      end
    end
  end
end
