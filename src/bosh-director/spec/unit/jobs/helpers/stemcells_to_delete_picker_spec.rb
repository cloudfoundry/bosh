require 'spec_helper'

module Bosh::Director
  describe Jobs::Helpers::StemcellsToDeletePicker do
    subject(:stemcells_to_delete_picker) { Jobs::Helpers::StemcellsToDeletePicker.new(Api::StemcellManager.new) }

    describe '#pick' do
      before do
        Models::Stemcell.make(name: 'stemcell-a', version: '1', cid: 1)
        Models::Stemcell.make(name: 'stemcell-b', version: '2', cid: 2)

        deployment_1 = Models::Deployment.make(name: 'first')
        deployment_2 = Models::Deployment.make(name: 'second')

        stemcell_with_deployment_1 = Models::Stemcell.make(name: 'stemcell-c', cid: 3)
        stemcell_with_deployment_1.add_deployment(deployment_1)

        stemcell_with_deployment_2 = Models::Stemcell.make(name: 'stemcell-d', cid: 4)
        stemcell_with_deployment_2.add_deployment(deployment_2)
      end
      context 'when removing all stemcells' do
        it 'picks unused stemcells' do
          expect(stemcells_to_delete_picker.pick(0).map { |a| a['name'] }).to match_array(['stemcell-a', 'stemcell-b'])
        end
      end

      context 'when removing all execept the latest two stemcells' do
        before do
          Models::Stemcell.make(name: 'stemcell-a', version: '10', cid: 5)
          Models::Stemcell.make(name: 'stemcell-b', version: '10', cid: 6)
          Models::Stemcell.make(name: 'stemcell-a', version: '9', cid: 7)
          Models::Stemcell.make(name: 'stemcell-b', version: '9', cid: 8)
        end

        it 'leaves out the latest two versions of each stemcell' do
          expect(stemcells_to_delete_picker.pick(2).map { |a| a['name'] }).to match_array(['stemcell-a', 'stemcell-b'])
        end
      end
    end
  end
end
