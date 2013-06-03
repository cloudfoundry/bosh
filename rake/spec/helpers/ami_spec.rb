require 'spec_helper'
require_relative '../../lib/helpers/ami'

module Bosh::Helpers
  describe Ami do
    subject(:ami) do
      Ami.new('fake-stemcell.tgz', double(AwsRegistry, region: 'fake-region'))
    end

    before do
      Logger.stub(:new)
    end

    describe '#publish' do
      it 'creates a new ami' do
        Rake::FileUtilsExt.stub(:sh)
        provider = double(Bosh::Clouds::Provider, create_stemcell: 'fake-ami-id').as_null_object
        Bosh::Clouds::Provider.stub(create: provider)

        stemcell_manifest = {'cloud_properties' => {'ami' => ''}}
        Psych.stub(:load_file).and_return(stemcell_manifest)

        expect(ami.publish).to eq('fake-ami-id')
      end
    end
  end
end
