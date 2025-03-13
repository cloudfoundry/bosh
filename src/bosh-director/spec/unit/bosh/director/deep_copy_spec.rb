require 'spec_helper'

module Bosh::Director
  describe DeepCopy do
    it 'does a deep copy of a deeply nested Hash' do
      deeply_nested_hash = {
        level1: {
          level2: {
            level3: 'foo'
          }
        },
        object: double('fake object')
      }

      dup = DeepCopy.copy(deeply_nested_hash)

      expect {
        dup[:level1][:level2][:level3] = 'bar'
      }.not_to(change {
        deeply_nested_hash[:level1][:level2][:level3]
      })

      expect(dup[:object]).not_to be(deeply_nested_hash[:object])
    end

    it 'does a deep copy of a nested mixed hashes and arrays' do
      leaf = { level4: 'foo' }
      deeply_nested_mixed_hash = {
        level1: {
          level2: [leaf]
        }
      }

      dup = DeepCopy.copy(deeply_nested_mixed_hash)

      expect {
        leaf[:level4] = 'bar'
      }.not_to(change {
        dup[:level1][:level2].first
      })
    end
  end
end
