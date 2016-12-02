require 'rspec'

describe 'ps_utils' do

  it 'checks bash utils' do
    expect(`#{File.dirname(__FILE__)}/ps_utils_tests.sh`).to eq(
        'an existing PID should exist
a non-existing PID should NOT exist
two kills should be sent to process 1
list_child_processes finds its 2 children
')
  end
end
