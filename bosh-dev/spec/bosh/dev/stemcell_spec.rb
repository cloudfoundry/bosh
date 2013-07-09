require 'spec_helper'
require 'fakefs/spec_helpers'
require 'bosh/dev/stemcell'
require 'bosh/dev/ami'
require 'bosh/dev/build'

module Bosh
  module Dev
    describe Stemcell do
      let(:stemcell_path) { spec_asset('stemcell.tgz') }

      subject { Stemcell.new(stemcell_path) }

      it 'has a manifest' do
        expect(subject.manifest).to be_a Hash
      end

      it 'has a name' do
        expect(subject.name).to eq 'micro-bosh-stemcell'
      end

      it 'has an infrastructure' do
        expect(subject.infrastructure).to eq 'aws'
      end

      it 'has a path' do
        expect(subject.path).to eq stemcell_path
      end

      it 'errors if path does not exist' do
        expect {
          Stemcell.new('/not/found/stemcell.tgz')
        }.to raise_error "Cannot find file `/not/found/stemcell.tgz'"
      end

      it 'has a version' do
        expect(subject.version).to eq '714'
      end

      it 'knows if stemcell is light' do
        expect(subject.is_light?).to be_false
      end

      it 'extracts stemcell' do
        Rake::FileUtilsExt.should_receive(:sh).with(/tar xzf .*#{stemcell_path} --directory/)
        subject.extract {}
      end

      it 'extracts stemcell and excludes files' do
        Rake::FileUtilsExt.should_receive(:sh).with(/tar xzf .*#{stemcell_path} --directory .* --exclude=image/)
        subject.extract(exclude: 'image') {}
      end

      describe 'create_light_stemcell' do
        let(:ami) do
          double(Ami, publish: 'fake-ami-id', region: 'fake-region')
        end

        before do
          Ami.stub(new: ami)
          Rake::FileUtilsExt.stub(:sh)
          File.stub(:exists?).with(/.*stemcell\.tgz/).and_return(true)
        end

        it 'creates an ami from the stemcell' do
          ami.should_receive(:publish)

          subject.create_light_stemcell
        end

        it 'creates a new tgz' do
          Rake::FileUtilsExt.stub(:sh).with(/tar xzf/).and_call_original
          Rake::FileUtilsExt.should_receive(:sh).with(/tar cvzf .*light-stemcell.tgz \*/)
          subject.create_light_stemcell
        end

        it 'replaces the raw image with a blank placeholder' do
          FileUtils.should_receive(:touch).and_return do |file|
            expect(file).to match('image')
          end
          subject.create_light_stemcell
        end

        it 'adds the ami to the stemcell manifest' do
          Psych.should_receive(:dump).and_return do |stemcell_properties, out|
            expect(stemcell_properties['cloud_properties']['ami']).to eq({'fake-region' => 'fake-ami-id'})
          end
          subject.create_light_stemcell
        end

        it 'names the stemcell manifest correctly' do
          FileUtils.stub(:touch)
          # Example fails on linux without File.stub
          File.stub(:open).and_call_original
          File.should_receive(:open).with('stemcell.MF', 'w')

          subject.create_light_stemcell
        end

        it 'returns a stemcell object' do
          expect(subject.create_light_stemcell).to be_a Stemcell
        end
      end

      describe '.from_jenkins_build' do

        it 'constructs correct jenkins path' do
          Stemcell.stub(:new)
          Dir.should_receive(:glob).with('/mnt/stemcells/aws-micro/work/work/*-stemcell-*-123.tgz').and_return([])

          Stemcell.from_jenkins_build('aws', 'micro', double(Build, number: 123))
        end
      end
    end
  end
end