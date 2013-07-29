require 'spec_helper'
require 'fakefs/spec_helpers'

require 'bosh/dev/bat_helper'

module Bosh::Dev
  describe BatHelper do
    include FakeFS::SpecHelpers

    let(:infrastructure_name) { 'FAKE_INFRASTRUCTURE_NAME' }
    let(:fake_infrastructure) { instance_double('Bosh::Dev::Infrastructure::Base', name: infrastructure_name) }
    let(:fake_pipeline) { instance_double('Pipeline', fetch_stemcells: nil) }

    subject { BatHelper.new(infrastructure_name) }

    before do
      Infrastructure.should_receive(:for).and_return(fake_infrastructure)

      Pipeline.stub(new: fake_pipeline)
    end

    describe '#initialize' do
      it 'sets infrastructre' do
        expect(subject.infrastructure).to eq(fake_infrastructure)
      end
    end

    describe '#run_rake' do
      before do
        ENV.delete('BAT_INFRASTRUCTURE')

        FileUtils.stub(rm_rf: nil, mkdir_p: nil)

        fake_infrastructure.stub(run_system_micro_tests: nil)
      end

      after do
        ENV.delete('BAT_INFRASTRUCTURE')
      end

      it 'removes the artifacts dir' do
        FileUtils.should_receive(:rm_rf).with(subject.artifacts_dir)

        subject.run_rake
      end

      it 'creates the microbosh depolyments dir (which is contained within artifacts dir)' do
        FileUtils.should_receive(:mkdir_p).with(subject.micro_bosh_deployment_dir)

        subject.run_rake
      end

      it 'sets ENV["BAT_INFRASTRUCTURE"]' do
        expect(ENV['BAT_INFRASTRUCTURE']).to be_nil

        subject.run_rake

        expect(ENV['BAT_INFRASTRUCTURE']).to eq(infrastructure_name)
      end

      it 'fetches stemcells for the specified infrastructure' do
        fake_pipeline.should_receive(:fetch_stemcells).with(subject.infrastructure, subject.artifacts_dir)

        subject.run_rake
      end

      it 'calls #run_system_micro_tests on the infrastructure' do
        fake_infrastructure.should_receive(:run_system_micro_tests)

        subject.run_rake
      end
    end

    describe '#artifacts_dir' do
      %w[openstack vsphere aws].each do |i|
        let(:infrastructure_name) { i }

        its(:artifacts_dir) { should eq(File.join('/tmp', 'ci-artifacts', subject.infrastructure.name, 'deployments')) }
      end
    end

    describe '#micro_bosh_deployment_dir' do
      its(:micro_bosh_deployment_dir) { should eq(File.join(subject.artifacts_dir, subject.micro_bosh_deployment_name)) }
    end

    describe '#micro_bosh_deployment_name' do
      its(:micro_bosh_deployment_name) { should == 'microbosh' }
    end

    describe '#bosh_stemcell_path' do
      before do
        fake_pipeline.stub(:bosh_stemcell_path) do |infrastructure, artifacts_dir|
          expect(infrastructure.name).to eq(infrastructure_name)
          expect(artifacts_dir).to eq(subject.artifacts_dir)
          'fake bosh stemcell path'
        end
      end

      it 'delegates to the pipeline' do
        expect(subject.bosh_stemcell_path).to eq('fake bosh stemcell path')
      end
    end

    describe '#micro_bosh_stemcell_path' do
      before do
        fake_pipeline.stub(:micro_bosh_stemcell_path) do |infrastructure, artifacts_dir|
          expect(infrastructure.name).to eq(infrastructure_name)
          expect(artifacts_dir).to eq(subject.artifacts_dir)
          'fake micro bosh stemcell path'
        end
      end

      it 'delegates to the pipeline' do
        expect(subject.micro_bosh_stemcell_path).to eq('fake micro bosh stemcell path')
      end
    end
  end
end
