require 'spec_helper'

module Bosh::Cli
  describe VmState do
    include FakeFS::SpecHelpers

    let(:director) { double(Client::Director) }
    let(:command) do
      double(Command::Base,
           interactive?: true,
           confirmed?: true,
           nl: nil,
           say: nil,
           err: nil,
           director: director)
    end
    let(:force) { false }

    let(:manifest) { Manifest.new('fake-deployment-file', director) }

    before do
      manifest_hash = { 'name' => 'fake deployment', 'inspected' => false }
      File.open('fake-deployment-file', 'w') { |f| f.write(manifest_hash.to_yaml) }
      manifest.load
    end

    subject(:vm_state) do
      VmState.new(command, manifest, force)
    end

    before do
      allow(command).to receive(:inspect_deployment_changes) do |manifest, _|
        manifest['inspected'] = true
      end
    end

    describe '#change' do
      it 'caches the manifest yaml before its mutated during inspection!' do
        expect(command.director).to receive(:change_job_state).with('fake deployment',
                                                                "---\nname: fake deployment\ninspected: true\n",
                                                                'fake job',
                                                                'fake index',
                                                                'fake new_state')

        vm_state.change('fake job', 'fake index', 'fake new_state', 'fake operation_desc')
      end
    end
  end
end
