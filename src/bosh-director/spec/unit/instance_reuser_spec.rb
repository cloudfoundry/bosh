require 'spec_helper'

module Bosh::Director
  describe InstanceReuser do
    let(:reuser) { described_class.new }
    let(:reservation) { instance_double('Bosh::Director::NetworkReservation') }
    let(:network_settings) do
      {}
    end
    let(:instance) { instance_double(DeploymentPlan::Instance) }

    let!(:stemcell_model) { Models::Stemcell.make(name: 'stemcell-name', version: '1') }

    let(:stemcell) do
      stemcell = FactoryBot.build(:deployment_plan_stemcell, name: stemcell_model.name, version: stemcell_model.version)
      stemcell.bind_model(Models::Deployment.make)
      stemcell
    end

    let(:different_stemcell) do
      model = Models::Stemcell.make(name: 'different-stemcell-name', version: '1')
      stemcell = FactoryBot.build(:deployment_plan_stemcell, name: model.name, version: model.version)
      stemcell.bind_model(Models::Deployment.make)
      stemcell
    end

    let(:stemcell_of_same_name_and_version) do
      stemcell = FactoryBot.build(:deployment_plan_stemcell, name: stemcell_model.name, version: stemcell_model.version)
      stemcell.bind_model(Models::Deployment.make)
      stemcell
    end

    let(:second_stemcell) { Models::Stemcell.make }
    let(:second_instance) { Object.new }

    describe '#add_in_use_instance' do
      it 'should add a instance to the InstanceReuser' do
        expect(reuser.get_num_instances(stemcell)).to eq(0)
        reuser.add_in_use_instance(instance, stemcell)
        expect(reuser.get_num_instances(stemcell)).to eq(1)
      end

      it 'should not offer an added in use instance until it is released' do
        expect(reuser.get_instance(stemcell)).to be_nil
        reuser.add_in_use_instance(instance, stemcell)
        expect(reuser.get_instance(stemcell)).to be_nil
        reuser.release_instance(instance)
        expect(reuser.get_instance(stemcell)).to eq(instance)
        expect(reuser.get_instance(stemcell)).to be_nil
      end
    end

    describe '#get_instance' do
      it 'should make the instance unavailable' do
        reuser.add_in_use_instance(instance, stemcell)
        reuser.release_instance(instance)
        reuser.get_instance(stemcell)
        expect(reuser.get_instance(stemcell)).to be_nil
      end

      it 'should return instances based on the stemcell name and version' do
        reuser.add_in_use_instance(instance, stemcell)
        reuser.release_instance(instance)
        expect(reuser.get_num_instances(stemcell_of_same_name_and_version)).to eq(1)
        expect(reuser.get_num_instances(second_stemcell)).to eq(0)
        expect(reuser.get_instance(stemcell_of_same_name_and_version)).to eq(instance)
      end
    end

    describe '#get_num_total_instances' do
      it 'should return the total count of instances across all stemcells' do
        expect(reuser.total_instance_count).to eq(0)
        reuser.add_in_use_instance(instance, stemcell)
        expect(reuser.total_instance_count).to eq(1)
        reuser.add_in_use_instance(instance, stemcell)
        expect(reuser.total_instance_count).to eq(2)
        reuser.add_in_use_instance(instance, different_stemcell)
        expect(reuser.total_instance_count).to eq(3)
      end
    end

    describe '#get_num_instances' do
      it 'should return the total count of in use instances and idle instances from the given stemcell' do
        expect(reuser.get_num_instances(stemcell)).to eq(0)

        reuser.add_in_use_instance(instance, stemcell)
        expect(reuser.get_num_instances(stemcell)).to eq(1)
        reuser.release_instance(instance)
        expect(reuser.get_num_instances(stemcell)).to eq(1)

        reuser.add_in_use_instance(second_instance, second_stemcell)
        expect(reuser.get_num_instances(stemcell)).to eq(1)
        expect(reuser.get_num_instances(second_stemcell)).to eq(1)
      end
    end

    describe '#each' do
      it 'should iterate in use instances and idle instances' do
        reuser.add_in_use_instance(instance, stemcell)
        reuser.release_instance(instance)
        reuser.add_in_use_instance(second_instance, second_stemcell)

        iterated = []
        reuser.each do |instance|
          iterated << instance
        end

        expect(iterated).to match_array([instance, second_instance])
      end
    end

    describe '#release_instance' do
      context 'when the instance is in use' do
        it 'makes it available again' do
          reuser.add_in_use_instance(instance, stemcell)
          reuser.get_instance(stemcell)
          reuser.release_instance(instance)
          expect(reuser.get_instance(stemcell)).to eq(instance)
        end
      end
    end

    describe '#remove_instance' do
      it 'should remove an instance' do
        reuser.add_in_use_instance(instance, stemcell)
        expect(reuser.get_num_instances(stemcell)).to eq(1)
        reuser.remove_instance(instance)
        expect(reuser.get_num_instances(stemcell)).to eq(0)
      end
    end

    describe '#remove_idle_instance_not_matching_stemcell' do
      it 'should remove an instance belonging to any stemcell not matching the given stemcell' do
        reuser.add_in_use_instance(instance, stemcell)
        reuser.release_instance(instance)
        reuser.add_in_use_instance(second_instance, second_stemcell)
        reuser.release_instance(second_instance)

        expect(reuser.remove_idle_instance_not_matching_stemcell(stemcell)).to eq(second_instance)
        expect(reuser.get_instance(second_stemcell)).to eq(nil)
        expect(reuser.get_instance(stemcell)).to eq(instance)
      end
    end
  end
end
