require 'spec_helper'

describe Bosh::Director::DeploymentPlan::Vm do
  before do
    @vm = BD::DeploymentPlan::Vm.new
  end

  describe :clean_vm do
    it 'sets vm to nil' do
      @vm.model = 'fake-vm'
      expect{ @vm.clean_vm }.to change(@vm, :model).to(nil)
    end
  end


end
