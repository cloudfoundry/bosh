require 'spec_helper'

module Bosh::Director
  describe CloudCollection do
    subject(:collection) { CloudCollection.new([nimbus, cumulus], logger) }
    let(:logger) { double(:logger, debug: nil) }
    let(:nimbus) { { name: 'nimbus', cpi: instance_double('Bosh::Clouds::ExternalCpi') } }
    let(:cumulus) { { name: 'cumulus', cpi: instance_double('Bosh::Clouds::ExternalCpi') } }

    describe '#initialize' do
      it 'takes a list of clouds and sets a reader' do
        expect(collection.clouds).to eq([nimbus, cumulus])
      end
    end

    shared_examples_for 'a delegator' do
      it 'delegates to all elements in collection' do
        expect(nimbus[:cpi]).to receive(method_name).with(*method_args)
        expect(cumulus[:cpi]).to receive(method_name).with(*method_args)

        collection.send(method_name, *method_args)
      end

      it 'bubbles up not implemented exceptions' do
        expect(nimbus[:cpi]).to receive(method_name).with(*method_args).and_raise(Bosh::Clouds::NotImplemented)

        expect {
          collection.send(method_name, *method_args)
        }.to raise_error(Bosh::Clouds::NotImplemented)
      end
    end

    describe 'delete_stemcell' do
      let(:method_name) { :delete_stemcell }
      let(:method_args) { ['potato_id'] }

      it_behaves_like 'a delegator'
    end

    describe 'delete_vm' do
      let(:method_name) { :delete_vm }
      let(:method_args) { ['potato_id'] }

      it_behaves_like 'a delegator'
    end

    describe 'has_vm' do
      let(:method_name) { :has_vm }
      let(:method_args) { ['potato_id'] }

      it_behaves_like 'a delegator'

      it 'returns true if a cloud returns true' do
        expect(nimbus[:cpi]).to receive(method_name).with(*method_args).and_return(false)
        expect(cumulus[:cpi]).to receive(method_name).with(*method_args).and_return(true)
        expect(collection.has_vm(*method_args)).to eq(true)
      end

      it 'returns false if all clouds return false' do
        expect(nimbus[:cpi]).to receive(method_name).with(*method_args).and_return(false)
        expect(cumulus[:cpi]).to receive(method_name).with(*method_args).and_return(false)
        expect(collection.has_vm(*method_args)).to eq(false)
      end
    end

    describe 'has_disk' do
      let(:method_name) { :has_disk }
      let(:method_args) { ['flat_potato_id'] }

      it_behaves_like 'a delegator'

      it 'returns true if a cloud returns true' do
        expect(nimbus[:cpi]).to receive(method_name).with(*method_args).and_return(false)
        expect(cumulus[:cpi]).to receive(method_name).with(*method_args).and_return(true)
        expect(collection.has_disk(*method_args)).to eq(true)
      end

      it 'returns false if all clouds return false' do
        expect(nimbus[:cpi]).to receive(method_name).with(*method_args).and_return(false)
        expect(cumulus[:cpi]).to receive(method_name).with(*method_args).and_return(false)
        expect(collection.has_disk(*method_args)).to eq(false)
      end
    end

    describe 'delete_disk' do
      let(:method_name) { :delete_disk }
      let(:method_args) { ['flat_potato_id'] }

      it_behaves_like 'a delegator'
    end

    describe 'attach_disk' do
      let(:method_name) { :attach_disk }
      let(:method_args) { ['tuber_id', 'flat_potato_id'] }

      it_behaves_like 'a delegator'
    end

    describe 'set_disk_metadata' do
      let(:method_name) { :set_disk_metadata }
      let(:method_args) { ['tuber_id', 'flat_potato_id'] }

      it_behaves_like 'a delegator'
    end

    describe 'delete_snapshot' do
      let(:method_name) { :delete_snapshot }
      let(:method_args) { ['soulless_potato_id'] }

      it_behaves_like 'a delegator'
    end

    describe 'detach_disk' do
      let(:method_name) { :detach_disk }
      let(:method_args) { ['tuber_id', 'flat_potato_id'] }

      it_behaves_like 'a delegator'
    end

    describe 'resize_disk' do
      let(:method_name) { :resize_disk }
      let(:method_args) { ['tuber_id', 1024] }

      it_behaves_like 'a delegator'
    end
  end
end
