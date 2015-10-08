module Bosh::Director::Models
  class Vm < Sequel::Model(Bosh::Director::Config.db)
    many_to_one :deployment
    one_to_one  :instance

    def validate
      validates_presence [:deployment_id, :agent_id]
      validates_unique :agent_id
    end

    def vm_exists?
      !(cid.nil? || cid.empty?)
    end

    def apply_spec
      return nil if apply_spec_json.nil?
      result = Yajl::Parser.parse(apply_spec_json)

      unless result['resource_pool'].nil? && result['vm_type'].nil?
        if result['resource_pool'] && result['vm_type'].nil?
          result['vm_type'] = {
            'name' => result['resource_pool']['name'],
            'cloud_properties' => result['resource_pool']['cloud_properties']
          }
        end

        if result['resource_pool'] && result['resource_pool']['stemcell'] && result['stemcell'].nil?
          result['stemcell'] = result['resource_pool']['stemcell']
          result['stemcell']['alias'] = result['resource_pool']['name']
        end

        if result['resource_pool']
          result.delete('resource_pool')
        end

      end

      result
    end

    def apply_spec=(spec)
      self.apply_spec_json = Yajl::Encoder.encode(spec)
    end

    # @param [Hash] env_hash Environment hash
    def env=(env_hash)
      self.env_json = Yajl::Encoder.encode(env_hash)
    end

    # @return [Hash] VM environment hash
    def env
      return nil if env_json.nil?
      Yajl::Parser.parse(env_json)
    end

    def credentials
      return nil if credentials_json.nil?
      Yajl::Parser.parse(credentials_json)
    end

    def credentials=(spec)
      self.credentials_json = Yajl::Encoder.encode(spec)
    end
  end

  Vm.plugin :association_dependencies
  Vm.add_association_dependencies :instance => :nullify
end
