require 'spec_helper'
require 'bosh/stemcell/archive'
require 'bosh/stemcell/aws/ami'

module Bosh::Stemcell::Aws
  describe Ami do
    subject(:ami) { Ami.new(stemcell, region) }

    let(:stemcell) do
      instance_double('Bosh::Stemcell::Archive').tap do |s|
        s.stub(:extract).and_yield('/foo/bar', {
          'cloud_properties' => { 'ami' => '' }
        })
      end
    end

    let(:region) { instance_double('Bosh::Stemcell::Aws::Region', name: 'fake-region') }

    before { Logger.stub(:new) }

    describe '#publish' do
      it 'creates a new ami and makes it public' do
        image = instance_double('AWS::EC2::Image')
        expect(image).to receive(:public=).with(true)

        ec2 = instance_double('AWS::EC2', images: { 'fake-ami-id' => image })

        cpi = instance_double(
          'Bosh::AwsCloud::Cloud',
          create_stemcell: 'fake-ami-id',
          ec2: ec2,
        )

        Bosh::Clouds::Provider.stub(create: cpi)

        expect(ami.publish).to eq('fake-ami-id')
      end
    end
  end
end
