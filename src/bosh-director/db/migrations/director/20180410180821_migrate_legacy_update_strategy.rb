Sequel.migration do
  up do
    self[:instances].each do |instance|
      begin
        instance_spec_json = JSON.parse(instance[:spec_json])
      rescue
        next
      end

      next if instance_spec_json['update'].nil?

      if instance_spec_json['update']['strategy'] == 'legacy'
        instance_spec_json['update']['strategy'] = 'delete-create'
      elsif instance_spec_json['update']['strategy'] == 'hot-swap'
        instance_spec_json['update']['strategy'] = 'create-swap-delete'
      end

      self[:instances].where(id: instance[:id]).update(spec_json: JSON.dump(instance_spec_json))
    end
  end
end
