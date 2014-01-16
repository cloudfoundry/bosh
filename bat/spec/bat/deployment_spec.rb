require 'spec_helper'
require 'bat/deployment'
require 'fileutils'

describe Bat::Deployment do
  include FakeFS::SpecHelpers

  let(:fake_template_evaluation_context) do
    class FakeTemplateEvaluationContext
      attr_reader :fake_name

      def initialize
        @fake_name = 'FAKE_DEPLOYMENT_NAME'
      end

      def get_binding
        binding
      end
    end

    FakeTemplateEvaluationContext.new
  end

  let(:template_dir) { File.expand_path(File.join(SPEC_ROOT, '..', 'templates')) }

  let(:fake_template_path) { File.join(template_dir, 'FAKE_SPEC_CPI.yml.erb') }

  let(:deployment_spec) { 'FAKE_DEPLOYMENT_SPEC' }

  subject(:deployment) { Bat::Deployment.new(deployment_spec) }

  before do
    Dir.stub(:mktmpdir) do
      FileUtils.mkdir_p('/fake/tmpdir')
      '/fake/tmpdir'
    end

    FileUtils.mkdir_p(template_dir)

    File.open(fake_template_path, 'w') do |f|
      f.write("---\nname: <%= fake_name %>")
    end

    fake_template_evaluation_context.stub_chain(:spec, cpi: 'FAKE_SPEC_CPI')
    Bosh::Common::TemplateEvaluationContext.stub(new: fake_template_evaluation_context)
  end

  describe '#initialize' do
    it 'generates a deployment manifest' do
      Bosh::Common::TemplateEvaluationContext.should_receive(:new).
        with(deployment_spec).and_return(fake_template_evaluation_context)

      Bat::Deployment.new(deployment_spec)

      expect(File.read('/fake/tmpdir/deployment')).to eq("---\nname: FAKE_DEPLOYMENT_NAME")
    end
  end

  describe '#generate_deployment_manifest' do
    let(:deployment_spec) { 'FAKE_DEPLOYMENT_SPEC' }

    it 'generates a deployment manifest' do
      Bosh::Common::TemplateEvaluationContext.should_receive(:new).with(deployment_spec).twice do
        fake_template_evaluation_context
      end

      deployment.generate_deployment_manifest(deployment_spec)

      expect(File.read('/fake/tmpdir/deployment')).to eq("---\nname: FAKE_DEPLOYMENT_NAME")
    end
  end

  describe '#name' do
    it 'returns the path of the stored manifest' do
      expect(deployment.name).to eq('FAKE_DEPLOYMENT_NAME')
    end
  end

  describe '#to_path' do
    it 'returns the path of the stored manifest' do
      expect(deployment.to_path).to eq('/fake/tmpdir/deployment')
    end
  end

  describe '#delete' do
    it 'returns the path of the stored manifest' do
      manifest_path = deployment.to_path

      expect { deployment.delete }.to change { File.exists?(manifest_path) }.to(false)
    end
  end
end
