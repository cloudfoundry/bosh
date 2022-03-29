require 'yaml'
require 'bosh/template/evaluation_context'
require_relative './template_example_group'

shared_examples 'rendered postgres* bpm.yml' do
  let(:release) { Bosh::Template::Test::ReleaseDir.new(File.join(File.dirname(__FILE__), '..')) }
  let(:template) { job.template('config/bpm.yml') }

  subject(:rendered_template) do
    YAML.load(template.render(properties))
  end

  context 'with standard config' do
    let(:properties) do
      {
        postgres: {
          adapter: "postgres",
          database: "bosh",
          host: "127.0.0.1",
          listen_address: "127.0.0.1",
          password: "secret",
          user: "postgres",
        },
      }
    end

    it 'should use SIGINT as shutdown signal' do
      expect(rendered_template['processes'][0]).to include('shutdown_signal' => 'INT')
    end
  end
end

describe 'postgres job' do
  it_should_behave_like 'rendered postgres* bpm.yml' do
    let(:job) { release.job('postgres') }
  end
end

describe 'postgres-10 job' do
  it_should_behave_like 'rendered postgres* bpm.yml' do
    let(:job) { release.job('postgres-10') }
  end
end
