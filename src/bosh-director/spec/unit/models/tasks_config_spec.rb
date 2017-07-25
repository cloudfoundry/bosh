require 'spec_helper'

module Bosh::Director::Models
  describe TasksConfig do
    let(:tasks_config_model) { TasksConfig.make(manifest: manifest) }
    let(:manifest) { {name: '((manifest_name))'} }

    describe '#manifest' do
      it 'returns result' do
        expect(tasks_config_model.manifest).to eq(manifest)
      end
    end

  end
end
