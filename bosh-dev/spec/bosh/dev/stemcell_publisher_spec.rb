require 'spec_helper'
require 'bosh/dev/stemcell_publisher'

module Bosh::Dev
  describe StemcellPublisher do
    include FakeFS::SpecHelpers

    let(:environment) do
      instance_double('Bosh::Dev::StemcellEnvironment',
                      infrastructure: 'aws',
                      directory: '/stemcell_environment',
                      work_path: '/stemcell_environment/work')
    end

    subject(:publisher) do
      StemcellPublisher.new(environment)
    end

    describe '#publish' do
      let(:stemcell) { instance_double('Bosh::Stemcell::Stemcell') }
      let(:light_stemcell) { instance_double('Bosh::Stemcell::Aws::LightStemcell', write_archive: nil, path: 'fake light stemcell path') }
      let(:pipeline) { instance_double('Bosh::Dev::Pipeline', publish_stemcell: nil) }

      before do
        Bosh::Stemcell::Stemcell.stub(:new).and_return(stemcell)
        Bosh::Stemcell::Aws::LightStemcell.stub(:new).with(stemcell).and_return(light_stemcell)
        Pipeline.stub(:new).and_return(pipeline)

        stemcell_output_dir = File.join(environment.work_path, 'work')
        stemcell_path = File.join(stemcell_output_dir, 'fake-stemcell.tgz')

        FileUtils.mkdir_p(stemcell_output_dir)
        FileUtils.touch(stemcell_path)
      end

      it 'publishes the generated stemcell' do
        pipeline.should_receive(:publish_stemcell).with(stemcell)

        publisher.publish
      end

      context 'when infrastructure is aws' do
        let(:light_stemcell_stemcell) { instance_double('Bosh::Stemcell::Stemcell') }

        it 'publishes an aws light stemcell' do
          Bosh::Stemcell::Stemcell.should_receive(:new).with(light_stemcell.path).and_return(light_stemcell_stemcell)
          light_stemcell.should_receive(:write_archive)
          pipeline.should_receive(:publish_stemcell).with(light_stemcell_stemcell)

          publisher.publish
        end
      end

      context 'when infrastructure is not aws' do
        before do
          environment.stub(:infrastructure).and_return('vsphere')
        end

        it 'does nothing since other infrastructures do not have light stemcells' do
          light_stemcell.should_not_receive(:write_archive)

          publisher.publish
        end
      end
    end
  end
end
