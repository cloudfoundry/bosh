# Copyright (c) 2009-2012 VMware, Inc.

require 'spec_helper'

describe Bosh::AwsCloud::Cloud do
  let(:instance_manager) { instance_double("Bosh::AwsCloud::InstanceManager") }
  let(:cloud_options) { mock_cloud_options }

  subject { Bosh::Clouds::Provider.create(:aws, cloud_options) }

  before do
    class_double("Bosh::AwsCloud::InstanceManager").as_stubbed_const
    allow(Bosh::AwsCloud::InstanceManager).to receive(:new).and_return(instance_manager)
  end

  describe 'creating via provider' do

    it 'can be created using Bosh::Cloud::Provider' do
      cloud = Bosh::Clouds::Provider.create(:aws, mock_cloud_options)
      cloud.should be_an_instance_of(Bosh::AwsCloud::Cloud)
    end

  end

  describe 'validating initialization options' do
    it 'raises an error warning the user of all the missing required configurations' do
      expect {
        described_class.new(
            {
                'aws' => {
                    'access_key_id' => 'keys to my heart',
                    'secret_access_key' => 'open sesame'
                }
            }
        )
      }.to raise_error(ArgumentError, 'missing configuration parameters > aws:region, aws:default_key_name, registry:endpoint, registry:user, registry:password')
    end

    it 'does not raise an error if all the required configuraitons are present' do
      expect {
        described_class.new(
            {
                'aws' => {
                    'access_key_id' => 'keys to my heart',
                    'secret_access_key' => 'open sesame',
                    'region' => 'fupa',
                    'default_key_name' => 'sesame'
                },
                'registry' => {
                    'user' => 'abuser',
                    'password' => 'hard2gess',
                    'endpoint' => 'http://websites.com'
                }
            }
        )
      }.to_not raise_error
    end
  end

  describe '#delete_vm' do
    let(:instance_id) { 'some-instance' }

    it "terminates the instance" do
      expect(instance_manager).to receive(:terminate).with(instance_id, false)
      subject.delete_vm(instance_id)
    end

    context "when fast_path_delete is specified" do
      let(:cloud_options) {
        mock_cloud_options.merge('aws' => mock_cloud_options['aws'].merge('fast_path_delete' => true))
      }

      it "terminates the instance with fast_path_delete" do
        expect(instance_manager).to receive(:terminate).with(instance_id, true)
        subject.delete_vm(instance_id)
      end
    end
  end
end
