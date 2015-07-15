require 'spec_helper'

describe Bosh::Director::DeploymentPlan::Vm do
  before do
    @vm = BD::DeploymentPlan::Vm.new
  end

  describe :clean do
    it 'sets vm to nil' do
      @vm.model = 'fake-vm'
      expect{ @vm.clean }.to change(@vm, :model).to(nil)
    end
  end


end
