# Copyright (c) 2009-2012 VMware, Inc.

require 'spec_helper'

module Bosh::Director
  describe Jobs::DeleteStemcell do
    describe 'perform' do
      let(:blobstore) { double('Blobstore') }

      before do
        @cloud = instance_double('Bosh::Cloud')
        Config.stub(:cloud).and_return(@cloud)
      end

      describe 'Resque job class expectations' do
        let(:job_type) { :delete_stemcell }
        it_behaves_like 'a Resque job'
      end

      it 'should fail for unknown stemcells' do
        job = Jobs::DeleteStemcell.new('test_stemcell', 'test_version', blobstore: blobstore)
        job.should_receive(:with_stemcell_lock).
          with('test_stemcell', 'test_version').and_yield

        lambda { job.perform }.should raise_exception(StemcellNotFound)
      end

      it "should fail if CPI can't delete the stemcell" do
        Models::Stemcell.make(name: 'test_stemcell', version: 'test_version', cid: 'stemcell_cid')

        @cloud.should_receive(:delete_stemcell).with('stemcell_cid').
          and_raise('error')

        job = Jobs::DeleteStemcell.new('test_stemcell', 'test_version', blobstore: blobstore)
        job.should_receive(:with_stemcell_lock).
          with('test_stemcell', 'test_version').and_yield

        lambda { job.perform }.should raise_exception('error')
      end

      it 'should not fail of the CPI raises an error and the force options is used' do
        Models::Stemcell.make(name: 'test_stemcell', version: 'test_version', cid: 'stemcell_cid')

        @cloud.should_receive(:delete_stemcell).with('stemcell_cid').
          and_raise('error')

        job = Jobs::DeleteStemcell.new('test_stemcell', 'test_version', 'force' => true, blobstore: blobstore)
        job.should_receive(:with_stemcell_lock).
          with('test_stemcell', 'test_version').and_yield
        lambda { job.perform }.should_not raise_error
      end

      it 'should fail if the deployments still reference this stemcell' do
        stemcell = Models::Stemcell.make(name: 'test_stemcell', version: 'test_version', cid: 'stemcell_cid')

        deployment = Models::Deployment.make
        deployment.add_stemcell(stemcell)

        job = Jobs::DeleteStemcell.new('test_stemcell', 'test_version', blobstore: blobstore)
        job.should_receive(:with_stemcell_lock).
          with('test_stemcell', 'test_version').and_yield
        expect { job.perform }.to raise_exception(StemcellInUse)
      end

      it 'should delete the stemcell meta if the CPI deleted the stemcell' do
        stemcell = Models::Stemcell.make(name: 'test_stemcell', version: 'test_version', cid: 'stemcell_cid')

        @cloud.should_receive(:delete_stemcell).with('stemcell_cid')

        job = Jobs::DeleteStemcell.new('test_stemcell', 'test_version', blobstore: blobstore)
        job.should_receive(:with_stemcell_lock).
          with('test_stemcell', 'test_version').and_yield
        job.perform

        Models::Stemcell[stemcell.id].should be_nil
      end

      it 'should delete the associated compiled packages' do
        stemcell = Models::Stemcell.make(name: 'test_stemcell', version: 'test_version', cid: 'stemcell_cid')

        package = Models::Package.make
        compiled_package = Models::CompiledPackage.make(package: package,
                                                        stemcell: stemcell,
                                                        blobstore_id: 'compiled-package-blb-id')

        @cloud.should_receive(:delete_stemcell).with('stemcell_cid')

        blobstore.should_receive(:delete).with('compiled-package-blb-id')

        job = Jobs::DeleteStemcell.new('test_stemcell', 'test_version', blobstore: blobstore)
        job.should_receive(:with_stemcell_lock).
          with('test_stemcell', 'test_version').and_yield
        job.perform

        Models::Stemcell[stemcell.id].should be_nil
        Models::CompiledPackage[compiled_package.id].should be_nil
      end
    end
  end
end
