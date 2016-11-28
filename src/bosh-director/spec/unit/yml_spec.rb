require 'spec_helper'

describe 'YAML parser' do
  it 'does not use Psych' do
    code_path = File.expand_path('../../..', __FILE__)
    expect(`cd #{code_path}; git grep Psych| grep -v 'spec/unit/yml.spec'`).to eq('')
  end
end
