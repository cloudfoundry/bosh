require 'spec_helper'
require 'bosh/stemcell/archive'
require 'bosh/dev/light_stemcell_pointer'

module Bosh::Dev
  describe LightStemcellPointer do
    describe '#promote' do
      let(:upload_adapter) { instance_double('Bosh::Dev::UploadAdapter') }
      let(:light_stemcell) { instance_double('Bosh::Stemcell::Archive', ami_id: 'fake-ami_id') }

      before do
        upload_adapter_klass = class_double('Bosh::Dev::UploadAdapter').as_stubbed_const
        upload_adapter_klass.stub(:new).and_return(upload_adapter)
      end

      subject(:light_stemcell_pointer) { LightStemcellPointer.new(light_stemcell) }

      it 'uploads a pointer to the light stemcell AMI' do
        upload_adapter.should_receive(:upload).with({
                                                      bucket_name: 'bosh-jenkins-artifacts',
                                                      key: 'last_successful-bosh-stemcell-aws_ami_us-east-1',
                                                      body: light_stemcell.ami_id,
                                                      public: true
                                                    })

        light_stemcell_pointer.promote
      end
    end
  end
end
