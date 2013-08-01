require 'spec_helper'
require 'bosh/dev/stemcell'

module Bosh::Dev
  describe Stemcell do
    let(:stemcell_path) { spec_asset('micro-bosh-stemcell-aws.tgz') }

    subject { Stemcell.new(stemcell_path) }

    describe '#initialize' do
      it 'errors if path does not exist' do
        expect { Stemcell.new('/not/found/stemcell.tgz') }.to raise_error "Cannot find file `/not/found/stemcell.tgz'"
      end
    end

    describe '#manifest' do
      it 'has a manifest' do
        expect(subject.manifest).to be_a Hash
      end
    end

    describe '#name' do
      it 'has a name' do
        expect(subject.name).to eq 'micro-bosh-stemcell'
      end
    end

    describe '#infrastructure' do
      it 'has an infrastructure' do
        expect(subject.infrastructure).to eq 'aws'
      end
    end

    describe '#path' do
      it 'has a path' do
        expect(subject.path).to eq(stemcell_path)
      end
    end

    describe '#version' do
      it 'has a version' do
        expect(subject.version).to eq('714')
      end
    end

    describe '#light?' do
      context 'when infrastructure is "aws"' do
        context 'when there is not an "ami" key in the "cloud_properties" section of the manifest' do
          it { should_not be_light }
        end

        context 'when there is an "ami" key in the "cloud_properties" section of the manifest' do
          let(:stemcell_path) { spec_asset('light-micro-bosh-stemcell-aws.tgz') }

          it { should be_light }
        end
      end

      context 'when infrastructure is anything but "aws"' do
        let(:stemcell_path) { spec_asset('micro-bosh-stemcell-vsphere.tgz') }

        it { should_not be_light }
      end
    end

    describe '#ami_id' do
      context 'when infrastructure is "aws"' do
        context 'when there is not an "ami" key in the "cloud_properties" section of the manifest' do
          its(:ami_id) { should be_nil }
        end

        context 'when there is an "ami" key in the "cloud_properties" section of the manifest' do
          let(:stemcell_path) { spec_asset('light-micro-bosh-stemcell-aws.tgz') }

          its(:ami_id) { should eq('ami-FAKE_AMI_KEY') }
        end
      end

      context 'when infrastructure is anything but "aws"' do
        let(:stemcell_path) { spec_asset('micro-bosh-stemcell-vsphere.tgz') }

        its(:ami_id) { should be_nil }
      end
    end

    describe '#extract' do
      it 'extracts stemcell' do
        Rake::FileUtilsExt.should_receive(:sh).with(/tar xzf .*#{stemcell_path} --directory/)
        subject.extract {}
      end

      it 'extracts stemcell and excludes files' do
        Rake::FileUtilsExt.should_receive(:sh).with(/tar xzf .*#{stemcell_path} --directory .* --exclude=image/)
        subject.extract(exclude: 'image') {}
      end
    end

    describe '#create_light_stemcell' do
      let(:ami) do
        double(Ami, publish: 'fake-ami-id', region: 'fake-region')
      end

      before do
        Ami.stub(new: ami)
        Rake::FileUtilsExt.stub(:sh)
        FileUtils.stub(:touch)
      end

      it 'creates an ami from the stemcell' do
        ami.should_receive(:publish)

        subject.create_light_stemcell
      end

      it 'creates a new tgz' do
        Rake::FileUtilsExt.should_receive(:sh) do |command|
          command.should match(/tar xzf #{subject.path} --directory .*/)
        end

        expected_tarfile = File.join(File.dirname(subject.path), 'light-micro-bosh-stemcell-aws.tgz')

        Rake::FileUtilsExt.should_receive(:sh) do |command|
          command.should match(/sudo tar cvzf #{expected_tarfile} \*/)
        end

        subject.create_light_stemcell
      end

      it 'replaces the raw image with a blank placeholder' do
        FileUtils.should_receive(:touch).and_return do |file, options|
          expect(file).to match('image')
          expect(options).to eq(verbose: true)
        end
        subject.create_light_stemcell
      end

      it 'adds the ami to the stemcell manifest' do
        Psych.should_receive(:dump).and_return do |stemcell_properties, out|
          expect(stemcell_properties['cloud_properties']['ami']).to eq({ 'fake-region' => 'fake-ami-id' })
        end

        subject.create_light_stemcell
      end

      it 'names the stemcell manifest correctly' do
        # Example fails on linux without File.stub
        File.stub(:open).and_call_original
        File.should_receive(:open).with('stemcell.MF', 'w')

        subject.create_light_stemcell
      end

      it 'returns a stemcell object' do
        expect(subject.create_light_stemcell).to be_a Stemcell
      end
    end
  end
end
