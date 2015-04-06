require 'spec_helper'
require 'bosh/stemcell/aws/light_stemcell'
require 'bosh/stemcell/archive'

module Bosh::Stemcell
  module Aws
    describe LightStemcell do
      let(:regions) { ['fake-region-1', 'fake-region-2'] }
      let(:stemcell) do
        Bosh::Stemcell::Archive.new(spec_asset('fake-stemcell-aws-xen-ubuntu.tgz'))
      end

      let(:virtualization_type) { "paravirtual" }

      subject(:light_stemcell) do
        LightStemcell.new(stemcell, virtualization_type, regions)
      end

      describe "#path" do
        subject { light_stemcell.path }

        context 'when virtualization type is paravirtual' do
          let(:virtualization_type) { "paravirtual" }
          it { should eq(spec_asset('light-fake-stemcell-aws-xen-ubuntu.tgz')) }
        end

        context 'when virtualization type is hvm' do
          let(:virtualization_type) { Bosh::Stemcell::Aws::HVM_VIRTUALIZATION }
          it { should eq(spec_asset('light-fake-stemcell-aws-xen-hvm-ubuntu.tgz')) }
        end
      end

      let(:publish_response) { double }

      describe '#write_archive' do
        let(:ami) { instance_double('Bosh::Stemcell::Aws::AmiCollection', publish: publish_response) }
        let(:stemcell) { Bosh::Stemcell::Archive.new(spec_asset('fake-stemcell-aws-xen-ubuntu.tgz')) }

        before do
          allow(AmiCollection).to receive(:new).with(stemcell, regions, virtualization_type).and_return(ami)
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

          expected_tarfile = File.join(File.dirname(stemcell.path), 'light-fake-stemcell-aws-xen-ubuntu.tgz')

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

        it 'adds the original ami and all of the copied amis to the stemcell manifest' do
          expect(Psych).to receive(:dump) do |stemcell_properties, _|
            expect(stemcell_properties['cloud_properties']['ami']).to eq(publish_response)
          end

          light_stemcell.write_archive
        end

        context 'when the virtualization is hvm' do
          let(:virtualization_type) { Bosh::Stemcell::Aws::HVM_VIRTUALIZATION }
          it 'replaces the name in the manifest when it is a hvm virtualization' do
            stemcell.manifest['name'] = 'xen-fake-stemcell'
            expect(Psych).to receive(:dump) do |stemcell_properties, _|
              expect(stemcell_properties['name']).to eq('xen-hvm-fake-stemcell')
            end
            light_stemcell.write_archive
          end

          it 'replaces the cloud_properties name in the manifest when it is a hvm virtualization' do
            stemcell.manifest['cloud_properties']['name'] = 'xen-fake-stemcell'
            expect(Psych).to receive(:dump) do |stemcell_properties, _|
              expect(stemcell_properties['cloud_properties']['name']).to eq('xen-hvm-fake-stemcell')
            end
            light_stemcell.write_archive
          end
        end

        context 'when the virtualization is not hvm' do
          let(:virtualization_type) { 'non-hvm' }
          it 'does not replace the name in the manifest' do
            stemcell.manifest['name'] = 'xen-fake-stemcell'
            expect(Psych).to receive(:dump) do |stemcell_properties, _|
              expect(stemcell_properties['name']).to eq('xen-fake-stemcell')
            end
            light_stemcell.write_archive
          end
        end

        it 'names the stemcell manifest correctly' do
          # Example fails on linux without File.stub
          allow(File).to receive(:open).and_call_original
          expect(File).to receive(:write).with('stemcell.MF', anything)

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
