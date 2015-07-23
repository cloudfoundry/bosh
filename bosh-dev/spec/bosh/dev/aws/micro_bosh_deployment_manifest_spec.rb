require 'spec_helper'
require 'bosh/dev/aws/micro_bosh_deployment_manifest'

module Bosh::Dev::Aws
  describe MicroBoshDeploymentManifest do
    subject { described_class.new(env, 'manual') }
    let(:env) { {} }

    before { allow(Receipts).to receive_messages(new: receipts) }
    let(:receipts) do
      instance_double(
        'Bosh::Dev::Aws::Receipts',
        vpc_outfile_path: 'fake_vpc_outfile_path',
        route53_outfile_path: 'fake_route53_outfile_path',
      )
    end

    before { allow(Bosh::AwsCliPlugin::MicroboshManifest).to receive_messages(new: manifest) }
    let(:manifest) do
      instance_double(
        'Bosh::AwsCliPlugin::MicroboshManifest',
        name: 'fake-name',
        access_key_id: 'fake-access-key-id',
        secret_access_key: 'fake-secret-access-key',
        network_type: 'manual',
      )
    end

    before { allow(YAML).to receive_messages(load_file: {}) }

    its(:director_name) { should eq('micro-fake-name') }
    its(:access_key_id) { should eq('fake-access-key-id') }
    its(:secret_access_key) { should eq('fake-secret-access-key') }

    it 'requires the net type to match the manifest' do
      allow(manifest).to receive(:network_type).and_return('dynamic')
      expect { described_class.new(env, 'manual').send(:manifest) }.to raise_error
      expect { described_class.new(env, 'dynamic').send(:manifest) }.not_to raise_error
    end

    describe '#write' do
      before do
        allow(File).to receive(:write)
        allow(manifest).to receive_messages(file_name: 'fake-file-name', to_yaml: 'manifest-yaml')
      end

      it 'loads manifest based on proper receipts' do
        expect(YAML).to receive(:load_file).with('fake_vpc_outfile_path').and_return('vpc-receipt' => true)
        expect(YAML).to receive(:load_file).with('fake_route53_outfile_path').and_return('route53-receipt' => true)
        expect(Bosh::AwsCliPlugin::MicroboshManifest).to receive(:new).with(
          { 'vpc-receipt' => true },
          { 'route53-receipt' => true },
          { hm_director_user: 'admin', hm_director_password: 'admin' },
        )
        subject.write
      end

      it 'writes generated microbosh manfifest ' do
        expect(File).to receive(:write).with('fake-file-name', 'manifest-yaml')
        subject.write
      end
    end
  end
end
