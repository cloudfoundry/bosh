require 'spec_helper'

module Bosh::Director::Models
  describe Config do
    let(:config_model) { Config.make(content: "---\n{key : value}") }

    describe '#raw_manifest' do
      it 'returns raw content as parsed yaml' do
        expect(config_model.name).to eq('some-name')
        expect(config_model.raw_manifest.fetch('key')).to eq('value')
      end
    end

    describe '#raw_manifest=' do
      it 'returns updated content' do
        config_model.raw_manifest = {'key' => 'value2'}
        expect(config_model.raw_manifest.fetch('key')).to eq('value2')
      end
    end

    describe '#latest_set' do
      it 'returns the latest default config of the given type' do
        Bosh::Director::Models::Config.new(type: 'expected_type', content: 'fake_content', name: 'default').save
        Bosh::Director::Models::Config.new(type: 'expected_type', content: 'fake_content', name: 'default').save
        expected = Bosh::Director::Models::Config.new(type: 'expected_type', content: 'fake_content', name: 'default').save
        Bosh::Director::Models::Config.new(type: 'unexpected_type', content: 'fake_content', name: 'default').save

        latests = Bosh::Director::Models::Config.latest_set('expected_type')
        expect(latests).to contain_exactly(expected)
      end

      it 'returns the latest configs of a given type grouped by name' do
        Bosh::Director::Models::Config.new(type: 'expected_type', content: 'fake_content', name: 'fake_name_1').save
        expected1 = Bosh::Director::Models::Config.new(type: 'expected_type', content: 'fake_content', name: 'fake_name_1').save
        expected2 = Bosh::Director::Models::Config.new(type: 'expected_type', content: 'fake_content', name: 'fake_name_2').save
        Bosh::Director::Models::Config.new(type: 'unexpected_type', content: 'fake_content', name: 'fake_name_3').save

        latests = Bosh::Director::Models::Config.latest_set('expected_type')
        expect(latests).to contain_exactly(expected1, expected2)
      end

      it 'returns empty list when there are no records' do
        expect(Bosh::Director::Models::Config.latest_set('type')).to be_empty()
      end

      context 'deleted config name' do
        it 'is not enumerated in latest' do
          Bosh::Director::Models::Config.new(type: 'fake-cloud', content: 'v1', name: 'one').save
          one2 = Bosh::Director::Models::Config.new(type: 'fake-cloud', content: 'v2', name: 'one').save

          Bosh::Director::Models::Config.new(type: 'fake-cloud', content: 'v1', name: 'two').save
          Bosh::Director::Models::Config.new(type: 'fake-cloud', content: 'v2', name: 'two', deleted: true).save

          latests = Bosh::Director::Models::Config.latest_set('fake-cloud')
          expect(latests).to contain_exactly(one2)
        end

        context 'resurrected a named config' do
          it 'is enumerated in latest' do
            Bosh::Director::Models::Config.new(type: 'fake-cloud', content: 'v1', name: 'one').save
            one2 = Bosh::Director::Models::Config.new(type: 'fake-cloud', content: 'v2', name: 'one').save

            Bosh::Director::Models::Config.new(type: 'fake-cloud', content: 'v1', name: 'two').save
            Bosh::Director::Models::Config.new(type: 'fake-cloud', content: 'v2', name: 'two', deleted: true).save
            two3 = Bosh::Director::Models::Config.new(type: 'fake-cloud', content: 'v3', name: 'two').save

            latests = Bosh::Director::Models::Config.latest_set('fake-cloud')
            expect(latests).to contain_exactly(one2, two3)
          end
        end
      end
    end

    describe '#find_by_ids' do
      it 'returns all records that match ids' do
        configs = [
          Bosh::Director::Models::Config.new(type: 'expected_type', content: 'fake_content', name: 'default').save,
          Bosh::Director::Models::Config.new(type: 'expected_type', content: 'fake_content', name: 'default').save,
          Bosh::Director::Models::Config.new(type: 'expected_type', content: 'fake_content', name: 'default').save
        ]

        expect(Bosh::Director::Models::Config.find_by_ids(configs.map(&:id))).to eq(configs)
      end

      it 'returns empty array when passed nil' do
        expect(Bosh::Director::Models::Config.find_by_ids(nil)).to eq([])
      end
    end
  end
end
