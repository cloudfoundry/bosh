require 'spec_helper'
require 'bosh/stemcell/archive'

module Bosh::Stemcell
  describe Archive do
    subject { described_class.new(stemcell_path) }
    let(:stemcell_path) { spec_asset('fake-stemcell-aws-xen-ubuntu.tgz') }

    describe '#initialize' do
      it 'errors if path does not exist' do
        expect {
          described_class.new('/not/found/stemcell.tgz')
        }.to raise_error("Cannot find file '/not/found/stemcell.tgz'")
      end
    end

    describe '#manifest' do
      it 'has a manifest' do
        expect(subject.manifest).to be_a(Hash)
      end
    end

    describe '#name' do
      it 'has a name' do
        expect(subject.name).to eq('fake-stemcell')
      end
    end

    describe '#infrastructure' do
      it 'has an infrastructure' do
        expect(subject.infrastructure).to eq('aws')
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

    describe '#sha1' do
      context 'when sha1 is just a string (from fake-stemcell-aws-xen-ubuntu.tgz)' do
        it 'returns a sha1 as a string' do
          expect(subject.sha1).to eq('fake-stemcell-sha1')
        end
      end

      context 'when sha1 happens to be a number' do
        before { subject.manifest['sha1'] = 123 }

        it 'returns a sha1 as a string' do
          expect(subject.sha1).to eq('123')
        end
      end

      context 'when the sha1 is nil' do
        before { subject.manifest['sha1'] = nil }

        it 'raises an error' do
          expect {
            subject.sha1
          }.to raise_error(RuntimeError, 'sha1 must not be nil')
        end
      end
    end

    describe '#light?' do
      context 'when infrastructure is "aws"' do
        context 'when there is not an "ami" key in the "cloud_properties" section of the manifest' do
          it { should_not be_light }
        end

        context 'when there is an "ami" key in the "cloud_properties" section of the manifest' do
          let(:stemcell_path) { spec_asset('light-fake-stemcell-aws-xen-ubuntu.tgz') }
          it { should be_light }
        end
      end

      context 'when infrastructure is anything but "aws"' do
        let(:stemcell_path) { spec_asset('fake-stemcell-vsphere.tgz') }
        it { should_not be_light }
      end
    end

    describe '#extract' do
      it 'extracts stemcell' do
        expect(Rake::FileUtilsExt).to receive(:sh).with(/tar xzf .*#{stemcell_path} --directory/)

        subject.extract {}
      end

      it 'extracts stemcell and excludes files' do
        expect(Rake::FileUtilsExt).to receive(:sh).with(/tar xzf .*#{stemcell_path} --directory .* --exclude=image/)

        subject.extract(exclude: 'image') {}
      end
    end
  end
end
