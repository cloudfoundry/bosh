Sequel.migration do
  up do
    self[:instances].each do |instance|
      begin
        instance_spec_json = JSON.parse(instance[:spec_json])
      rescue
        next
      end

      next if instance_spec_json['update'].nil?

      instance_spec_json['update']['vm_strategy'] = instance_spec_json['update'].delete('strategy')

      self[:instances].where(id: instance[:id]).update(spec_json: JSON.dump(instance_spec_json))
    end
  end
end
