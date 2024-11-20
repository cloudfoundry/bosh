require 'spec_helper'

describe 'Bosh::Director.hash_string_vals' do
  let(:h) do
    { a: 1, b: :c, c: 'd' }
  end

  it 'converts integers to strings' do
    Bosh::Director.hash_string_vals(h, :a)
    expect(h[:a]).to eq '1'
  end

  it 'convert symbols to strings' do
    Bosh::Director.hash_string_vals(h, :b)
    expect(h[:b]).to eq 'c'
  end

  it 'leaves strings as strings' do
    Bosh::Director.hash_string_vals(h, :c)
    expect(h[:c]).to eq 'd'
  end

  it 'accepts multiple keys' do
    Bosh::Director.hash_string_vals(h, :a, :b, :c)
    expect(h).to eq(a: '1', b: 'c', c: 'd')
  end

  context 'when the key is not found' do
    it 'adds the key as an empty string' do
      Bosh::Director.hash_string_vals(h, :d)
      expect(h[:d]).to eq ''
    end
  end

  context 'with a multi-level hash' do
    let(:h) do
      { a: { b: 1 } }
    end

    it 'adds the key as an empty string' do
      Bosh::Director.hash_string_vals(h[:a], :b)
      expect(h).to eq(a: { b: '1' })
    end
  end
end
