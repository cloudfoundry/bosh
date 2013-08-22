require 'spec_helper'
require 'bosh/stemcell/archive'

module Bosh::Stemcell
  describe Archive do
    let(:stemcell_path) { spec_asset('fake-stemcell-aws.tgz') }

    subject { Archive.new(stemcell_path) }

    describe '#initialize' do
      it 'errors if path does not exist' do
        expect { Archive.new('/not/found/stemcell.tgz') }.to raise_error "Cannot find file `/not/found/stemcell.tgz'"
      end
    end

    describe '#manifest' do
      it 'has a manifest' do
        expect(subject.manifest).to be_a Hash
      end
    end

    describe '#name' do
      it 'has a name' do
        expect(subject.name).to eq 'fake-stemcell'
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
        expect(subject.version).to eq('007')
      end
    end

    describe '#light?' do
      context 'when infrastructure is "aws"' do
        context 'when there is not an "ami" key in the "cloud_properties" section of the manifest' do
          it { should_not be_light }
        end

        context 'when there is an "ami" key in the "cloud_properties" section of the manifest' do
          let(:stemcell_path) { spec_asset('light-fake-stemcell-aws.tgz') }

          it { should be_light }
        end
      end

      context 'when infrastructure is anything but "aws"' do
        let(:stemcell_path) { spec_asset('fake-stemcell-vsphere.tgz') }

        it { should_not be_light }
      end
    end

    describe '#ami_id' do
      context 'when infrastructure is "aws"' do
        context 'when there is not an "ami" key in the "cloud_properties" section of the manifest' do
          its(:ami_id) { should be_nil }
        end

        context 'when there is an "ami" key in the "cloud_properties" section of the manifest' do
          let(:stemcell_path) { spec_asset('light-fake-stemcell-aws.tgz') }

          its(:ami_id) { should eq('ami-FAKE_AMI_KEY') }
        end
      end

      context 'when infrastructure is anything but "aws"' do
        let(:stemcell_path) { spec_asset('fake-stemcell-vsphere.tgz') }

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
  end
end
