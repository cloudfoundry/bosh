require_relative '../spec_helper'

describe 'cli configs', type: :integration do
  with_reset_sandbox_before_each

  let(:config) { yaml_file('cloud_config.yml', Bosh::Spec::Deployments.simple_cloud_config) }

  context 'can upload a config' do
    context 'when config uses placeholders' do
      let(:config) {yaml_file('cloud_config.yml', Bosh::Spec::Deployments.cloud_config_with_placeholders)}

      it 'replaces placeholders' do
        expect(bosh_runner.run("update-config my-type #{config.path}")).to include('Succeeded')
      end
    end

    it 'updates config' do
      expect(bosh_runner.run("update-config my-type #{config.path}")).to include('Succeeded')
    end

    it 'updates named config' do
      expect(bosh_runner.run("update-config --name=my-name my-type #{config.path}")).to include('Succeeded')
    end
  end

  context 'can list configs' do
    it 'lists configs' do
      bosh_runner.run("update-config my-type --name=my-name #{config.path}")
      bosh_runner.run("update-config other-type --name=other-name #{config.path}")

      expect(bosh_runner.run("configs")).to include('my-name', 'other-name')
    end

    it 'can filter lists configs' do
      bosh_runner.run("update-config my-type --name=my-name #{config.path}")
      bosh_runner.run("update-config other-type --name=other-name #{config.path}")

      output = bosh_runner.run('configs --type=my-type --name=my-name')
      expect(output).to_not include('other-type','other-name')
      expect(output).to include('my-type', 'my-name')
    end
  end

  context 'can delete a config' do
    it 'delete a config' do
      bosh_runner.run("update-config my-type --name=my-name #{config.path}")
      bosh_runner.run("update-config other-type --name=other-name #{config.path}")

      expect(bosh_runner.run("delete-config my-type --name=my-name")).to include('Succeeded')
      output = bosh_runner.run("configs")
      expect(output).to_not include('my-type','my-name')
      expect(output).to include('other-type', 'other-name')
    end

    it 'warns if there is nothing to delete' do
      output = bosh_runner.run('delete-config my-type')
      expect(output).to include('Succeeded')
      expect(output).to include('No configs to delete')
    end
  end
end
