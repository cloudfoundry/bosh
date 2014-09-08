require 'spec_helper'
require 'bosh/stemcell/archive'
require 'bosh/stemcell/aws/ami'

module Bosh::Stemcell::Aws
  describe Ami do
    subject(:ami) { Ami.new(stemcell, region, virtualization_type) }

    let(:stemcell) do
      instance_double('Bosh::Stemcell::Archive').tap do |s|
        allow(s).to receive(:extract).and_yield('/foo/bar', {
          'cloud_properties' => { 'ami' => '' }
        })
      end
    end

    let(:region) { instance_double('Bosh::Stemcell::Aws::Region', name: 'fake-region') }

    let(:virtualization_type) { "hvm" }

    describe '#publish' do
      let(:image) { instance_double('AWS::EC2::Image', :"public=" => nil) }
      let(:ec2) { instance_double('AWS::EC2', images: { 'fake-ami-id' => image }) }
      let(:cpi) { instance_double('Bosh::AwsCloud::Cloud', ec2: ec2, create_stemcell: 'fake-ami-id') }
      before { allow(Bosh::Clouds::Provider).to receive(:create).and_return(cpi) }

      let(:env) do
        {
          'BOSH_AWS_ACCESS_KEY_ID' => 'fake-access-key',
          'BOSH_AWS_SECRET_ACCESS_KEY' => 'fake-secret-access-key',
        }
      end
      before { stub_const('ENV', env) }

      before { allow(Logger).to receive(:new) }

      it 'creates a new cpi with the appropriate properties' do
        expect(Bosh::Clouds::Provider).to receive(:create).with({
          'plugin' => 'aws',
          'properties' => {
            'aws' =>       {
              'default_key_name' => 'fake',
              'region' => region.name,
              'access_key_id' => 'fake-access-key',
              'secret_access_key' => 'fake-secret-access-key'
            },
            'registry' => {
              'endpoint' => 'http://fake.registry',
              'user' => 'fake',
              'password' => 'fake'
            }
          }
        }, 'fake-director-uuid').and_return(cpi)

        ami.publish
      end

      it 'creates a new ami and makes it public' do
        expect(image).to receive(:public=).with(true)
        ami.publish
      end

      it 'returns the ami id' do
        expect(ami.publish).to eq('fake-ami-id')
      end

      context 'when virtualization type is passed' do
        let(:virtualization_type) { "hvm" }

        it 'creates the stemcell with the appropriate arguments' do
          expect(cpi).to receive(:create_stemcell) do |image_path, cloud_properties|
            expect(image_path).to eq('/foo/bar/image')
            expect(cloud_properties['virtualization_type']).to eq(virtualization_type)
            'fake-ami-id'
          end

          ami.publish
        end
      end

      context 'when no virtualization type is passed' do
        let(:virtualization_type) { nil }

        it 'creates the stemcell with the appropriate arguments' do
          expect(cpi).to receive(:create_stemcell) do |image_path, cloud_properties|
            expect(image_path).to eq('/foo/bar/image')
            expect(cloud_properties['virtualization_type']).to eq('paravirtual')
            'fake-ami-id'
          end

          ami.publish
        end
      end
    end
  end
end
