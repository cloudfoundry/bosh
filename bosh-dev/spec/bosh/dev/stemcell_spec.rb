require 'spec_helper'

require 'bosh/dev/pipeline'
require 'bosh/dev/stemcell'

module Bosh
  module Dev
    describe Stemcell do
      let(:stemcell_path) { spec_asset('micro-bosh-stemcell-aws.tgz') }

      subject(:stemcell) { Stemcell.new(stemcell_path) }

      describe '#initialize' do
        it 'errors if path does not exist' do
          expect { Stemcell.new('/not/found/stemcell.tgz') }.to raise_error "Cannot find file `/not/found/stemcell.tgz'"
        end
      end

      describe '#manifest' do
        it 'has a manifest' do
          expect(stemcell.manifest).to be_a Hash
        end
      end

      describe '#name' do
        it 'has a name' do
          expect(stemcell.name).to eq 'micro-bosh-stemcell'
        end
      end

      describe '#infrastructure' do
        it 'has an infrastructure' do
          expect(stemcell.infrastructure.name).to eq 'aws'
        end
      end

      describe '#path' do
        it 'has a path' do
          expect(stemcell.path).to eq(stemcell_path)
        end
      end

      describe '#version' do
        it 'has a version' do
          expect(stemcell.version).to eq('714')
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
          stemcell.extract {}
        end

        it 'extracts stemcell and excludes files' do
          Rake::FileUtilsExt.should_receive(:sh).with(/tar xzf .*#{stemcell_path} --directory .* --exclude=image/)
          stemcell.extract(exclude: 'image') {}
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
          File.stub(exists?: true)
        end

        it 'creates an ami from the stemcell' do
          ami.should_receive(:publish)

          stemcell.create_light_stemcell
        end

        it 'creates a new tgz' do
          Rake::FileUtilsExt.should_receive(:sh) do |command|
            command.should match(/tar xzf #{subject.path} --directory .*/)
          end

          expected_tarfile = File.join(File.dirname(subject.path), 'stemcell-714-aws-ami-xen-amd64-ubuntu_lucid.tgz')

          Rake::FileUtilsExt.should_receive(:sh) do |command|
            command.should match(/sudo tar cvzf #{expected_tarfile} \*/)
          end

          stemcell.create_light_stemcell
        end

        it 'replaces the raw image with a blank placeholder' do
          FileUtils.should_receive(:touch).and_return do |file, options|
            expect(file).to match('image')
            expect(options).to eq(verbose: true)
          end
          stemcell.create_light_stemcell
        end

        it 'adds the ami to the stemcell manifest' do
          Psych.should_receive(:dump).and_return do |stemcell_properties, out|
            expect(stemcell_properties['cloud_properties']['ami']).to eq('fake-region' => 'fake-ami-id')
          end

          stemcell.create_light_stemcell
        end

        it 'names the stemcell manifest correctly' do
          # Example fails on linux without File.stub
          File.stub(:open).and_call_original
          File.should_receive(:open).with('stemcell.MF', 'w')

          stemcell.create_light_stemcell
        end

        it 'returns a stemcell object' do
          expect(stemcell.create_light_stemcell).to be_a Stemcell
        end
      end

      describe '#publish_for_pipeline' do
        let(:pipeline) { instance_double('Pipeline') }
        let(:distro) { 'ubuntu_lucid' }

        describe 'when publishing a full stemcell' do
          it 'publishes a stemcell to an S3 bucket' do
            pipeline.should_receive(:s3_upload).with(stemcell.path, 'micro-bosh-stemcell/aws/stemcell-714-aws-image-xen-amd64-ubuntu_lucid.tgz')
            pipeline.should_receive(:s3_upload).with(stemcell.path, 'micro-bosh-stemcell/aws/stemcell-latest-aws-image-xen-amd64-ubuntu_lucid.tgz')

            stemcell.publish_for_pipeline(pipeline)
          end
        end

        describe 'when publishing a light stemcell' do
          let(:stemcell_path) { spec_asset('light-micro-bosh-stemcell-aws.tgz') }

          it 'publishes a light stemcell to S3 bucket' do
            pipeline.should_receive(:s3_upload).with(stemcell.path, 'micro-bosh-stemcell/aws/stemcell-714-aws-ami-xen-amd64-ubuntu_lucid.tgz')
            pipeline.should_receive(:s3_upload).with(stemcell.path, 'micro-bosh-stemcell/aws/stemcell-latest-aws-ami-xen-amd64-ubuntu_lucid.tgz')

            stemcell.publish_for_pipeline(pipeline)
          end
        end
      end
    end
  end
end
