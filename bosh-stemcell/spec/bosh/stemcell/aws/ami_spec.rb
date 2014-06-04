require 'spec_helper'
require 'bosh/stemcell/archive'
require 'bosh/stemcell/aws/ami'

module Bosh::Stemcell::Aws
  describe Ami do
    subject(:ami) { Ami.new(stemcell, region) }

    let(:stemcell) do
      instance_double('Bosh::Stemcell::Archive').tap do |s|
        allow(s).to receive(:extract).and_yield('/foo/bar', {
          'cloud_properties' => { 'ami' => '' }
        })
      end
    end

    let(:region) { instance_double('Bosh::Stemcell::Aws::Region', name: 'fake-region') }

    before { allow(Logger).to receive(:new) }

    describe '#publish' do
      let(:env) do
        {
          'BOSH_AWS_ACCESS_KEY_ID' => 'fake-access-key',
          'BOSH_AWS_SECRET_ACCESS_KEY' => 'fake-secret-access-key',
        }
      end
      before { stub_const('ENV', env) }

      it 'creates a new ami and makes it public' do
        image = instance_double('AWS::EC2::Image')
        expect(image).to receive(:public=).with(true)

        ec2 = instance_double('AWS::EC2', images: { 'fake-ami-id' => image })

        cpi = instance_double(
          'Bosh::AwsCloud::Cloud',
          create_stemcell: 'fake-ami-id',
          ec2: ec2,
        )

        expect(Bosh::Clouds::Provider).to receive(:create) do |cloud_config|
          expect(cloud_config['plugin']).to eq('aws')
          expect(cloud_config['properties']['aws']['access_key_id']).to eq('fake-access-key')
          expect(cloud_config['properties']['aws']['secret_access_key']).to eq('fake-secret-access-key')
          cpi
        end

        expect(ami.publish).to eq('fake-ami-id')
      end
    end
  end
end
