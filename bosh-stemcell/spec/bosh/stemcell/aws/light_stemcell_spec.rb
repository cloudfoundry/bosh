require 'spec_helper'
require 'bosh/stemcell/aws/light_stemcell'
require 'bosh/stemcell/archive'

module Bosh::Stemcell
  module Aws
    describe LightStemcell do
      let(:stemcell) do
        Bosh::Stemcell::Archive.new(spec_asset('fake-stemcell-aws.tgz'))
      end

      subject(:light_stemcell) do
        LightStemcell.new(stemcell)
      end

      its(:path) { should eq(spec_asset('light-fake-stemcell-aws.tgz')) }

      describe '#write_archive' do
        let(:region) do
          instance_double('Bosh::Stemcell::Aws::Region', name: 'fake-region')
        end

        let(:ami) do
          instance_double('Bosh::Stemcell::Aws::Ami', publish: 'fake-ami-id')
        end

        let(:stemcell) do
          Bosh::Stemcell::Archive.new(spec_asset('fake-stemcell-aws.tgz'))
        end

        subject(:light_stemcell) do
          LightStemcell.new(stemcell)
        end

        before do
          allow(Region).to receive(:new).and_return(region)
          allow(Ami).to receive(:new).with(stemcell, region).and_return(ami)
          allow(Rake::FileUtilsExt).to receive(:sh)
          allow(FileUtils).to receive(:touch)
        end

        it 'creates an ami from the stemcell' do
          expect(ami).to receive(:publish)

          light_stemcell.write_archive
        end

        it 'creates a new tgz' do
          expect(Rake::FileUtilsExt).to receive(:sh) do |command|
            expect(command).to match(/tar xzf #{stemcell.path} --directory .*/)
          end

          expected_tarfile = File.join(File.dirname(stemcell.path), 'light-fake-stemcell-aws.tgz')

          expect(Rake::FileUtilsExt).to receive(:sh) do |command|
            expect(command).to match(/sudo tar cvzf #{expected_tarfile} \*/)
          end

          light_stemcell.write_archive
        end

        it 'replaces the raw image with a blank placeholder' do
          expect(FileUtils).to receive(:touch) do |file, options|
            expect(file).to match('image')
            expect(options).to eq(verbose: true)
          end
          light_stemcell.write_archive
        end

        it 'adds the ami to the stemcell manifest' do
          expect(Psych).to receive(:dump) do |stemcell_properties, out|
            expect(stemcell_properties['cloud_properties']['ami']).to eq({ 'fake-region' => 'fake-ami-id' })
          end

          light_stemcell.write_archive
        end

        it 'names the stemcell manifest correctly' do
          # Example fails on linux without File.stub
          allow(File).to receive(:open).and_call_original
          expect(File).to receive(:open).with('stemcell.MF', 'w')

          light_stemcell.write_archive
        end

        it 'does not mutate original stemcell manifest' do
          expect {
            light_stemcell.write_archive
          }.not_to change { stemcell.manifest['cloud_properties'] }
        end
      end
    end
  end
end
