require 'spec_helper'
require 'bosh/dev/bat_helper'
require 'bosh/dev/pipeline'

describe Bosh::Dev::BatHelper do
  let(:infrastructure) { 'aws' }

  subject { Bosh::Dev::BatHelper.new('/FAKE/WORKSPACE/DIR', infrastructure) }

  describe '#initialize' do
    its(:workspace_dir) { should eq('/FAKE/WORKSPACE/DIR') }
    its(:infrastructure) { should eq('aws') }

    context 'with an invalid infrastructure' do
      it 'raises an ArgumentError' do
        expect {
          Bosh::Dev::BatHelper.new('/FAKE/WORKSPACE/DIR', 'BAD_INFRASTRUCTURE')
        }.to raise_error(ArgumentError, /invalid infrastructure: BAD_INFRASTRUCTURE/)
      end
    end
  end

  describe '#light?' do
    context 'when infrastructure is "aws"' do
      it { should be_light }
    end

    (Bosh::Dev::BatHelper::INFRASTRUCTURE - [Bosh::Dev::BatHelper::AWS]).each do |i|
      context "when infrastructure is '#{i}'" do
        let(:infrastructure) { i }

        it { should_not be_light }
      end
    end
  end

  describe '#run_rake' do
    let(:fake_pipeline) { instance_double('Bosh::Dev::Pipeline', download_latest_stemcell: nil) }
    let(:fake_rake_task) { double('a Rake Task', invoke: nil) }

    before do
      ENV.delete('BAT_INFRASTRUCTURE')

      Bosh::Dev::Pipeline.stub(new: fake_pipeline)
      Rake::Task.stub(:[] => fake_rake_task)
      Dir.stub(:chdir).and_yield
    end

    after do
      ENV.delete('BAT_INFRASTRUCTURE')
    end

    it 'changes to the workspace directory' do
      Dir.should_receive(:chdir).with(subject.workspace_dir)

      subject.run_rake
    end

    it 'calls #cleanup' do
      subject.should_receive(:cleanup_stemcells)

      subject.run_rake
    end

    context 'when there is an exception thrown' do
      before do
        fake_rake_task.should_receive(:invoke).and_raise
      end

      it 'calls #cleanup' do
        subject.should_receive(:cleanup_stemcells)

        expect { subject.run_rake }.to raise_error
      end
    end

    Bosh::Dev::BatHelper::INFRASTRUCTURE.each do |i|
      context "when infrastructure is '#{i}'" do
        let(:infrastructure) { i }

        it 'sets ENV["BAT_INFRASTRUCTURE"]' do
          expect(ENV['BAT_INFRASTRUCTURE']).to be_nil

          subject.run_rake

          expect(ENV['BAT_INFRASTRUCTURE']).to eq(infrastructure)
        end

        it 'downloads a micro-bosh-stemcell and a bosh-stemcell' do
          fake_pipeline.should_receive(:download_latest_stemcell).
              with(infrastructure: infrastructure, name: 'micro-bosh-stemcell', light: subject.light?)
          fake_pipeline.should_receive(:download_latest_stemcell).
              with(infrastructure: infrastructure, name: 'bosh-stemcell', light: subject.light?)

          subject.run_rake
        end

        it "invokes the rake task'spec:system:#{i}:micro'" do
          fake_rake_task.should_receive(:invoke)
          Rake::Task.should_receive(:[]).with("spec:system:#{infrastructure}:micro").and_return(fake_rake_task)

          subject.run_rake
        end
      end
    end
  end

  describe '#artifacts_dir' do
    Bosh::Dev::BatHelper::INFRASTRUCTURE.each do |i|
      let(:infrastructure) { i }

      its(:artifacts_dir) { should eq(File.join('/tmp', 'ci-artifacts', subject.infrastructure, 'deployments')) }
    end
  end

  describe '#micro_bosh_deployment_dir' do
    Bosh::Dev::BatHelper::INFRASTRUCTURE.each do |i|
      let(:infrastructure) { i }

      its(:micro_bosh_deployment_dir) { should eq(File.join(subject.artifacts_dir, 'micro_bosh')) }
    end
  end

  describe '#cleanup_stemcells' do
    it 'correctly creates the glob used to delete the stemcells' do
      FileUtils.stub(:rm_f)
      Dir.should_receive(:glob).with(File.join(subject.workspace_dir, '*bosh-stemcell-*.tgz'))

      subject.cleanup_stemcells
    end

    it 'remove the stemcells with a Dir.glob' do
      Dir.stub(glob: 'FAKE_GLOB_RESULTS')
      FileUtils.should_receive(:rm_f).with('FAKE_GLOB_RESULTS')

      subject.cleanup_stemcells
    end
  end

  describe '#bosh_stemcell_path' do
    Bosh::Dev::BatHelper::INFRASTRUCTURE.each do |i|
      let(:infrastructure) { i }

      let(:expected_filename) do
        Bosh::Dev::Pipeline.new.latest_stemcell_filename(subject.infrastructure, 'bosh-stemcell', subject.light?)
      end

      its(:bosh_stemcell_path) { should eq(File.join(subject.workspace_dir, expected_filename)) }
    end
  end

  describe '#micro_bosh_stemcell_path' do
    Bosh::Dev::BatHelper::INFRASTRUCTURE.each do |i|
      let(:infrastructure) { i }

      let(:expected_filename) do
        Bosh::Dev::Pipeline.new.latest_stemcell_filename(subject.infrastructure, 'micro-bosh-stemcell', subject.light?)
      end

      its(:micro_bosh_stemcell_path) { should eq(File.join(subject.workspace_dir, expected_filename)) }
    end
  end
end
