require 'spec_helper'

RSpec.shared_examples 'rendered postgres* bpm.yml' do
  let(:release) { Bosh::Template::Test::ReleaseDir.new(RELEASE_ROOT) }
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

RSpec.describe 'postgres job rendering' do
  describe 'postgres job' do
    it_should_behave_like 'rendered postgres* bpm.yml' do
      let(:job) { release.job('postgres') }
    end
  end

  describe 'postgres-13 job' do
    it_should_behave_like 'rendered postgres* bpm.yml' do
      let(:job) { release.job('postgres-13') }
    end
  end
end
