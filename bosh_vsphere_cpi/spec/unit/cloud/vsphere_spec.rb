require 'spec_helper'

describe Bosh::Clouds::VSphere do

  describe 'all the methods of the cpi' do

    # The vsphere cpi implementation is a weird delegate and the
    # list of methods must be maintained by hand. Make sure they
    # stay current.
    it 'has all methods of the cpi' do
      cpi_methods = Bosh::Cloud.instance_methods - Object.instance_methods
      vsphere_methods = Bosh::Clouds::VSphere.instance_methods - Object.instance_methods
      missing_methods = cpi_methods - vsphere_methods

      # this causes the extra elements to be printed on console
      expect(missing_methods).to match_array([])
    end
  end
end
