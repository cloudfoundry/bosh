require 'spec_helper'

describe Bosh::Director::DuplicateDetector do
  let(:obj) { Object.new.tap { |o| o.extend(Bosh::Director::DuplicateDetector) } }

  it 'returns any found duplicates' do
    with_duplicates = [{ val: 1 }, { val: 1 }, { val: 2 }, { val: 3 }, { val: 3 }]
    duplicates = obj.detect_duplicates(with_duplicates) { |e| e }
    expect(duplicates).to eq(Set.new([{ val: 1 }, { val: 3 }]))
  end

  it 'returns an empty array if no duplicates are found' do
    with_duplicates = [{ val: 1 }, { val: 2 }, { val: 3 }]
    duplicates = obj.detect_duplicates(with_duplicates) { |e| e }
    expect(duplicates).to eq(Set.new([]))
  end
end
