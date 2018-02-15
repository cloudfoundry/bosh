require 'spec_helper'

describe Bosh::Director::Api::ConfigManager do
  subject(:manager) { Bosh::Director::Api::ConfigManager.new }

  describe '#create' do
    let(:type) { 'my-type' }
    let(:name) { 'some-name' }
    let(:valid_yaml) { YAML.dump("---\n{key: value") }

    it 'saves the config' do
      expect do
        manager.create(type, name, valid_yaml)
      end.to change(Bosh::Director::Models::Config, :count).from(0).to(1)

      config = Bosh::Director::Models::Config.first
      expect(config.created_at).to_not be_nil
      expect(config.content).to eq(valid_yaml)
    end
  end

  describe '#find' do
    before do
      Bosh::Director::Models::Config.make(type: '4total-4names', name: 'b', content: '1')
      Bosh::Director::Models::Config.make(type: '4total-4names', name: 'e', content: '2')
      Bosh::Director::Models::Config.make(type: '3total-2names', name: 'default', content: '3')
      Bosh::Director::Models::Config.make(type: '4total-4names', name: 'default', content: '4')
      Bosh::Director::Models::Config.make(type: '4total-4names', name: 'a', content: '5')
      Bosh::Director::Models::Config.make(type: '3total-2names', name: 'a', content: '6')
      Bosh::Director::Models::Config.make(type: '3total-2names', name: 'a', content: '7')
    end

    context 'when limit is greater one' do
      before do
        Bosh::Director::Models::Config.make(type: '3total-1name', name: 'a', content: '9')
        Bosh::Director::Models::Config.make(type: '3total-1name', name: 'a', content: '10')
        Bosh::Director::Models::Config.make(type: '3total-1name', name: 'a', content: '11')
      end

      context 'when no filtering' do
        it 'returns all configs including outdated ones' do
          configs = manager.find(limit: 999)
          expect(configs.count).to eq(10)
          (0..6).each do |val|
            expect(configs).to include(Bosh::Director::Models::Config.all[val])
          end
        end

        it 'returns only `limit` amount per combination' do
          configs = manager.find(limit: 2)

          groups = configs.select { |config| config.type == '4total-4names' }
          expect(groups.count).to eq(4)
          groups = configs.select { |config| config.name == 'default' && config.type == '3total-2names' }
          expect(groups.count).to eq(1)
          groups = configs.select { |config| config.name == 'a' && config.type == '3total-2names' }
          expect(groups.count).to eq(2)
          groups = configs.select { |config| config.type == '3total-1name' }
          expect(groups.count).to eq(2)
        end

        it 'sorts type -> name `default` first -> name -> id' do
          configs = manager.find(limit: 3)

          filtered_configs = configs.map(&:values).map { |e| e.select { |k, _| k == :name || k == :type || k == :content } }
          expect(filtered_configs).to eq([
                                           { type: '3total-1name', name: 'a', content: '11' },
                                           { type: '3total-1name', name: 'a', content: '10' },
                                           { type: '3total-1name', name: 'a', content: '9' },
                                           { type: '3total-2names', name: 'default', content: '3' },
                                           { type: '3total-2names', name: 'a', content: '7' },
                                           { type: '3total-2names', name: 'a', content: '6' },
                                           { type: '4total-4names', name: 'default', content: '4' },
                                           { type: '4total-4names', name: 'a', content: '5' },
                                           { type: '4total-4names', name: 'b', content: '1' },
                                           { type: '4total-4names', name: 'e', content: '2' },
                                         ])
        end
      end

      context 'when filtering' do
        it 'returns only the elements with the given type' do
          configs = manager.find(type: '4total-4names', limit: 999)
          expect(configs.count).to eq(4)
        end

        it 'returns only the elements with the given name' do
          configs = manager.find(name: 'a', limit: 999)
          expect(configs.count).to eq(6)
        end

        it 'returns only the elements matching type and name' do
          configs = manager.find(name: 'a', type: '3total-2names', limit: 999)
          expect(configs.count).to eq(2)
        end

        it 'returns no elements with no matches' do
          configs = manager.find(type: 'foo', name: 'bar', limit: 999)
          expect(configs.count).to eq(0)
        end
      end
    end

    context 'when limit is one' do
      context 'when no filtering' do
        it 'returns the latest config for each type/name combination' do
          configs = manager.find
          expect(configs.count).to eq(6)

          [0, 1, 2, 3, 4, 6].each do |val|
            expect(configs).to include(Bosh::Director::Models::Config.all[val])
          end
        end
      end

      context 'when filtering' do
        it 'returns only the elements with the given type' do
          configs = manager.find(type: '4total-4names')
          expect(configs.count).to eq(4)
        end

        it 'returns only the elements with the given name' do
          configs = manager.find(name: 'a')
          expect(configs.count).to eq(2)
        end

        it 'returns only the elements matching type and name' do
          configs = manager.find(name: 'a', type: '3total-2names')
          expect(configs.count).to eq(1)
        end

        it 'returns no elements with no matches' do
          configs = manager.find(type: 'foo', name: 'bar')
          expect(configs.count).to eq(0)
        end
      end

      context 'when configs have been deleted' do
        it 'returns only not deleted configs' do
          Bosh::Director::Models::Config.make(type: '4total-4names', name: 'a', deleted: true)

          configs = manager.find(type: '4total-4names', name: 'a', limit: 999)

          expect(configs.count).to eq(1)
        end
      end
    end
  end

  describe '#find_by_Id' do
    let!(:config) { Bosh::Director::Models::Config.make(id: 123, type: '4total-4names', name: 'b', content: '1') }

    it 'returns config with specified id' do
      result = manager.find_by_id(123)
      expect(result).to eq(config)
    end

    context 'when config is missing' do
      it 'raises ConfigNotFound' do
        expect do
          manager.find_by_id(124)
        end.to raise_error(Bosh::Director::ConfigNotFound, 'Config 124 not found')
      end
    end
  end

  describe '#delete' do
    context 'when config entry exists' do
      it "sets deleted to 'true'" do
        Bosh::Director::Models::Config.make(type: 'my-type', name: 'my-name')

        count = manager.delete('my-type', 'my-name')

        expect(count).to eq(1)

        configs = Bosh::Director::Models::Config.where(type: 'my-type', name: 'my-name')

        expect(configs.count).to eq(1)
        expect(configs.first.deleted).to eq(true)
      end
    end

    context 'when multiple config entries exist' do
      it "sets deleted to all matching configs to 'true'" do
        Bosh::Director::Models::Config.make(type: 'my-type', name: 'my-name')
        Bosh::Director::Models::Config.make(type: 'my-type', name: 'my-name')
        Bosh::Director::Models::Config.make(type: 'other-type', name: 'other-name')

        count = manager.delete('my-type', 'my-name')

        expect(count).to eq(2)

        configs = Bosh::Director::Models::Config.where(type: 'my-type', name: 'my-name')

        expect(configs.map(:deleted)).to all(eq(true))

        configs = Bosh::Director::Models::Config.where(type: 'other-type', name: 'other-name')

        expect(configs.first.deleted).to eq(false)
      end

      it 'does not delete a deleted config again' do
        Bosh::Director::Models::Config.make(type: 'my-type', name: 'my-name', deleted: true)
        Bosh::Director::Models::Config.make(type: 'my-type', name: 'my-name')

        count = manager.delete('my-type', 'my-name')

        expect(count).to eq(1)
      end
    end

    context 'when the configs table is empty' do
      it 'does not crash' do
        count = manager.delete('my-type', 'my-name')

        expect(count).to eq(0)
      end
    end
  end

  describe '#delete_by_id' do
    context 'when config entry exists for given id' do
      it "sets deleted to 'true'" do
        id = Bosh::Director::Models::Config.make(type: 'my-type', name: 'my-name').id

        count = manager.delete_by_id(id)

        expect(Bosh::Director::Models::Config[id].deleted).to eq(true)
        expect(count).to eq(1)
      end
    end

    context 'when no config entry exists for given id' do
      it "does not update any entry" do
        count = manager.delete_by_id(5)

        expect(count).to eq(0)
      end
    end
  end


end
