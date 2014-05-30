require 'spec_helper'

module Bosh::Cli
  describe VmState do
    let(:director) { double(Client::Director) }
    let(:command) do
      double(Command::Base,
           interactive?: true,
           confirmed?: true,
           nl: nil,
           say: nil,
           err: nil,
           director: director,
           prepare_deployment_manifest: manifest)
    end
    let(:force) { false }
    let(:manifest) do
      { 'name' => 'fake deployment', 'inspected' => false }
    end

    subject(:vm_state) do
      VmState.new(command, force)
    end

    before do
      command.stub(:inspect_deployment_changes) do |manifest, _|
        manifest['inspected'] = true
      end
    end

    describe '#change' do
      it 'caches the manifest yaml before its mutated during inspection!' do # This is bad, but it's honest.
        command.director.should_receive(:change_job_state).with('fake deployment',
                                                                "---\nname: fake deployment\ninspected: false\n",
                                                                'fake job',
                                                                'fake index',
                                                                'fake new_state')

        vm_state.change('fake job', 'fake index', 'fake new_state', 'fake operation_desc')
      end
    end
  end
end
