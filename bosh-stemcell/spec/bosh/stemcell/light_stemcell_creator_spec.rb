require 'spec_helper'
require 'bosh/stemcell/light_stemcell_creator'

module Bosh::Stemcell
  describe LightStemcellCreator do
    describe '.create' do

      let(:ami) do
        instance_double('Bosh::Stemcell::Ami', publish: 'fake-ami-id', region: 'fake-region')
      end

      let(:stemcell) do
        Stemcell.new(spec_asset('micro-bosh-stemcell-aws.tgz'))
      end

      before do
        Bosh::Stemcell::Ami.stub(new: ami)
        Rake::FileUtilsExt.stub(:sh)
        FileUtils.stub(:touch)
      end

      it 'creates an ami from the stemcell' do
        ami.should_receive(:publish)

        LightStemcellCreator.create(stemcell)
      end

      it 'creates a new tgz' do
        Rake::FileUtilsExt.should_receive(:sh) do |command|
          command.should match(/tar xzf #{stemcell.path} --directory .*/)
        end

        expected_tarfile = File.join(File.dirname(stemcell.path), 'light-micro-bosh-stemcell-aws.tgz')

        Rake::FileUtilsExt.should_receive(:sh) do |command|
          command.should match(/sudo tar cvzf #{expected_tarfile} \*/)
        end

        LightStemcellCreator.create(stemcell)
      end

      it 'replaces the raw image with a blank placeholder' do
        FileUtils.should_receive(:touch).and_return do |file, options|
          expect(file).to match('image')
          expect(options).to eq(verbose: true)
        end
        LightStemcellCreator.create(stemcell)
      end

      it 'adds the ami to the stemcell manifest' do
        Psych.should_receive(:dump).and_return do |stemcell_properties, out|
          expect(stemcell_properties['cloud_properties']['ami']).to eq({ 'fake-region' => 'fake-ami-id' })
        end

        LightStemcellCreator.create(stemcell)
      end

      it 'names the stemcell manifest correctly' do
        # Example fails on linux without File.stub
        File.stub(:open).and_call_original
        File.should_receive(:open).with('stemcell.MF', 'w')

        LightStemcellCreator.create(stemcell)
      end

      it 'returns a stemcell object' do
        expect(LightStemcellCreator.create(stemcell)).to be_a Stemcell
      end
    end
  end
end
