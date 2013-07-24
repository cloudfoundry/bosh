require 'spec_helper'
require 'bosh/dev/bat_helper'

module Bosh::Dev
  describe BatHelper do
    let(:infrastructure_name) { 'aws' }
    let(:fake_pipeline) { instance_double('Pipeline', fetch_stemcells: nil, cleanup_stemcells: nil) }

    subject { BatHelper.new(infrastructure_name) }

    before do
      Pipeline.stub(new: fake_pipeline)
    end

    describe '#initialize' do
      it 'sets infrastructre' do
        expect(subject.infrastructure.name).to eq('aws')
      end
    end

    describe '#run_rake' do
      let(:fake_rake_task) { double('a Rake Task', invoke: nil) }

      before do
        ENV.delete('BAT_INFRASTRUCTURE')

        Rake::Task.stub(:[] => fake_rake_task)
        Dir.stub(:chdir).and_yield
      end

      after do
        ENV.delete('BAT_INFRASTRUCTURE')
      end

      it 'cleans up stemcells' do
        fake_pipeline.should_receive(:cleanup_stemcells)

        subject.run_rake
      end

      context 'when there is an exception thrown' do
        before do
          fake_rake_task.should_receive(:invoke).and_raise
        end

        it 'cleans up stemcells' do
          fake_pipeline.should_receive(:cleanup_stemcells)

          expect { subject.run_rake }.to raise_error
        end
      end

      %w[openstack vsphere aws].each do |i|
        context "when infrastructure_name is '#{i}'" do
          let(:infrastructure_name) { i }

          it 'sets ENV["BAT_INFRASTRUCTURE"]' do
            expect(ENV['BAT_INFRASTRUCTURE']).to be_nil

            subject.run_rake

            expect(ENV['BAT_INFRASTRUCTURE']).to eq(infrastructure_name)
          end

          it 'fetches stemcells for the specified infrastructure' do
            fake_pipeline.should_receive(:fetch_stemcells).with(subject.infrastructure)

            subject.run_rake
          end

          it "invokes the rake task'spec:system:#{i}:micro'" do
            fake_rake_task.should_receive(:invoke)
            Rake::Task.should_receive(:[]).with("spec:system:#{infrastructure_name}:micro").and_return(fake_rake_task)

            subject.run_rake
          end
        end
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
        fake_pipeline.stub(:bosh_stemcell_path) do |infrastructure|
          expect(infrastructure.name).to eq(infrastructure_name)
          'fake bosh stemcell path'
        end
      end

      it 'delegates to the pipeline' do
        expect(subject.bosh_stemcell_path).to eq('fake bosh stemcell path')
      end
    end

    describe '#micro_bosh_stemcell_path' do
      before do
        fake_pipeline.stub(:micro_bosh_stemcell_path) do |infrastructure|
          expect(infrastructure.name).to eq(infrastructure_name)
          'fake micro bosh stemcell path'
        end
      end

      it 'delegates to the pipeline' do
        expect(subject.micro_bosh_stemcell_path).to eq('fake micro bosh stemcell path')
      end
    end
  end
end
