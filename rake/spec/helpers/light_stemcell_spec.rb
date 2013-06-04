require 'spec_helper'
require_relative '../../lib/helpers/ami'

module Bosh::Helpers
  describe LightStemcell do
    let(:ami) do
      Ami.new('fake-stemcell.tgz', double(AwsRegistry, region: 'fake-region'))
    end

    subject(:light_stemcell) do
      LightStemcell.new(ami)
    end

    before do
      Rake::FileUtilsExt.stub(:sh)
      stemcell_manifest = {'cloud_properties' => {'ami' => ''}}
      Psych.stub(:load_file).and_return(stemcell_manifest)
    end

    describe 'publish_light_stemcell' do
      it 'creates a new tgz' do
        Rake::FileUtilsExt.should_receive(:sh).with('tar cvzf ./light-fake-stemcell.tgz *')
        light_stemcell.publish('fake-ami-id')
      end

      it 'replaces the raw image with a blank placeholder' do
        Rake::FileUtilsExt.should_receive(:sh).with(/tar xzf fake-stemcell\.tgz --directory .* --exclude=image/)

        FileUtils.should_receive(:touch).and_return do |file|
          expect(file).to match('image')
        end
        light_stemcell.publish('fake-ami-id')
      end

      it 'adds the ami to the stemcell manifest' do
        Psych.should_receive(:dump).and_return do |stemcell_properties, out|
          expect(stemcell_properties['cloud_properties']['ami']).to eq({'fake-region' => 'fake-ami-id'})
        end
        light_stemcell.publish('fake-ami-id')
      end

      it 'names the stemcell manifest correctly' do
        File.stub(:open)
        File.should_receive(:open).with('stemcell.MF', 'w')

        light_stemcell.publish('fake-ami-id')
      end
    end
  end
end
