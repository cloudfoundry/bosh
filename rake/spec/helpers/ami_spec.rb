require 'spec_helper'
require_relative '../../lib/helpers/ami'

module Bosh::Helpers
  describe Ami do
    subject(:ami) do
      Ami.new('fake-stemcell.tgz', double(AwsRegistry, region: 'fake-region'))
    end

    before do
      Logger.stub(:new)
      Rake::FileUtilsExt.stub(:sh)
      stemcell_manifest = {'cloud_properties' => {'ami' => ''}}
      Psych.stub(:load_file).and_return(stemcell_manifest)
    end

    describe 'publish' do
      it 'creates a new ami' do
        provider = double(Bosh::Clouds::Provider, create_stemcell: 'fake-ami-id').as_null_object
        Bosh::Clouds::Provider.stub(create: provider)

        expect(ami.publish).to eq('fake-ami-id')
      end
    end

    describe 'publish_light_stemcell' do
      it 'creates a new tgz' do
        Rake::FileUtilsExt.should_receive(:sh).with('tar cvzf ./light-fake-stemcell.tgz *')
        ami.publish_light_stemcell('fake-ami-id')
      end

      it 'replaces the raw image with a blank placeholder' do
        Rake::FileUtilsExt.should_receive(:sh).with(/tar xzf fake-stemcell\.tgz --directory .* --exclude=image/)

        FileUtils.should_receive(:touch).and_return do |file|
          expect(file).to match('/image')
        end
        ami.publish_light_stemcell('fake-ami-id')
      end

      it 'adds the ami to the stemcell manifest' do
        Psych.should_receive(:dump).and_return do |stemcell_properties, out|
          expect(stemcell_properties['cloud_properties']['ami']).to eq({'fake-region' => 'fake-ami-id'})
        end
        ami.publish_light_stemcell('fake-ami-id')
      end
    end
  end
end
