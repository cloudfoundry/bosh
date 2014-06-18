require 'spec_helper'
require 'bat/deployment'
require 'fileutils'

describe Bat::Deployment do
  subject(:deployment) { Bat::Deployment.new('FAKE_DEPLOYMENT_SPEC') }

  # Make sure mktmpdir is always same but unique
  let!(:tmp_dir) { Dir.mktmpdir }
  before { Dir.stub(:mktmpdir).and_return(tmp_dir) }

  before do
    template_dir = File.expand_path(File.join(SPEC_ROOT, '..', 'templates'))
    @cpi_template_path = File.join(template_dir, 'FAKE_SPEC_CPI.yml.erb')
    File.open(@cpi_template_path, 'w') { |f| f.write("---\nname: <%= fake_name %>") }
  end
  after { FileUtils.rm_f(@cpi_template_path) }

  before { Bosh::Common::TemplateEvaluationContext.stub(new: template_evaluation_context) }
  let(:template_evaluation_context) { FakeTemplateEvaluationContext.new }

  before { template_evaluation_context.stub_chain(:spec, cpi: 'FAKE_SPEC_CPI') }

  describe '#initialize' do
    it 'generates a deployment manifest' do
      Bosh::Common::TemplateEvaluationContext.should_receive(:new).with('FAKE_DEPLOYMENT_SPEC')
      Bat::Deployment.new('FAKE_DEPLOYMENT_SPEC')
      expect(File.read("#{tmp_dir}/deployment")).to eq("---\nname: FAKE_DEPLOYMENT_NAME")
    end
  end

  describe '#generate_deployment_manifest' do
    it 'generates a deployment manifest' do
      deployment # force load
      Bosh::Common::TemplateEvaluationContext.should_receive(:new).with('FAKE_DEPLOYMENT_SPEC')
      deployment.generate_deployment_manifest('FAKE_DEPLOYMENT_SPEC')
      expect(File.read("#{tmp_dir}/deployment")).to eq("---\nname: FAKE_DEPLOYMENT_NAME")
    end
  end

  describe '#name' do
    it 'returns the path of the stored manifest' do
      expect(deployment.name).to eq('FAKE_DEPLOYMENT_NAME')
    end
  end

  describe '#to_path' do
    it 'returns the path of the stored manifest' do
      expect(deployment.to_path).to eq("#{tmp_dir}/deployment")
    end
  end

  describe '#delete' do
    it 'returns the path of the stored manifest' do
      manifest_path = deployment.to_path
      expect { deployment.delete }.to change { File.exists?(manifest_path) }.to(false)
    end
  end

  class FakeTemplateEvaluationContext
    attr_reader :fake_name

    def initialize
      @fake_name = 'FAKE_DEPLOYMENT_NAME'
    end

    def get_binding
      binding
    end
  end
end
