require 'spec_helper'
require 'bosh/stemcell/ami'

module Bosh::Stemcell
  describe Ami do
    let(:stemcell) do
      stemcell = double('Bosh::Dev::Stemcell')
      stemcell_manifest = { 'cloud_properties' => { 'ami' => '' } }
      stemcell.stub(:extract).and_yield('/foo/bar', stemcell_manifest)
      stemcell
    end

    subject(:ami) do
      Ami.new(stemcell, instance_double('Bosh::Stemcell::AwsRegistry', region: 'fake-region'))
    end

    before do
      Logger.stub(:new)
    end

    describe 'publish' do
      it 'creates a new ami' do
        provider = instance_double('Bosh::AwsCloud::Cloud', create_stemcell: 'fake-ami-id').as_null_object
        Bosh::Clouds::Provider.stub(create: provider)

        expect(ami.publish).to eq('fake-ami-id')
      end
    end
  end
end
