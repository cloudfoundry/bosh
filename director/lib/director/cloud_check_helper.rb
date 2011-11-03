module Bosh::Director
  module CloudCheckHelper
    COMPONENTS = {
      'disk' => Bosh::Director::DiskCheck
      'vm' => Bosh::Director::VmCheck,
      'instance' => Bosh::Director::InstanceCheck
    }
  end
end
