require 'spec_helper'

describe Bosh::WardenCloud::Helpers do
  include Bosh::WardenCloud::Helpers

  context 'uuid' do
    it 'can generate the correct uuid' do
      uuid('disk').should start_with 'disk'
    end
  end

  context 'sudo' do
    it 'run sudo cmd with sudo' do
      mock_sh('fake', true)
      sudo('fake')
    end
  end

  context 'sh' do
    it 'run sh cmd with sh' do
      mock_sh('fake')
      sh('fake')
    end
  end

end
