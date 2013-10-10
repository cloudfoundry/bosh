require 'spec_helper'
require 'bosh/dev/aws/micro_bosh_deployment_manifest'

module Bosh::Dev::Aws
  describe MicroBoshDeploymentManifest do
    subject { described_class.new(env) }
    let(:env) { {} }

    before { Receipts.stub(new: receipts) }
    let(:receipts) do
      instance_double(
        'Bosh::Dev::Aws::Receipts',
        vpc_outfile_path: 'fake_vpc_outfile_path',
        route53_outfile_path: 'fake_route53_outfile_path',
      )
    end

    before { Bosh::Aws::MicroboshManifest.stub(new: manifest) }
    let(:manifest) do
      instance_double(
        'Bosh::Aws::MicroboshManifest',
        name: 'fake-name',
        access_key_id: 'fake-access-key-id',
        secret_access_key: 'fake-secret-access-key',
      )
    end

    before { YAML.stub(load_file: {}) }

    its(:director_name) { should == 'micro-fake-name' }
    its(:access_key_id) { should == 'fake-access-key-id' }
    its(:secret_access_key) { should == 'fake-secret-access-key' }

    describe '#write' do
      before do
        File.stub(:write)
        manifest.stub(file_name: 'fake-file-name', to_yaml: 'manifest-yaml')
      end

      it 'loads manifest based on proper receipts' do
        YAML.should_receive(:load_file).with('fake_vpc_outfile_path').and_return('vpc-receipt' => true)
        YAML.should_receive(:load_file).with('fake_route53_outfile_path').and_return('route53-receipt' => true)
        Bosh::Aws::MicroboshManifest.should_receive(:new).with(
          { 'vpc-receipt' => true },
          { 'route53-receipt' => true },
          { hm_director_user: 'admin', hm_director_password: 'admin' },
        )
        subject.write
      end

      it 'writes generated microbosh manfifest ' do
        File.should_receive(:write).with('fake-file-name', 'manifest-yaml')
        subject.write
      end
    end
  end
end
