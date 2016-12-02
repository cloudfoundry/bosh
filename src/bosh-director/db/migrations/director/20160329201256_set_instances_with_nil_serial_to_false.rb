require 'json'

Sequel.migration do
  up do
    self[:instances].all do |instance|
      unless instance[:spec_json].nil?
        spec = JSON.parse(instance[:spec_json])
        if !spec['update'].nil? && spec['update'].has_key?('serial') && spec['update']['serial'].nil?
          spec['update']['serial'] = false
          self[:instances].where(id: instance[:id]).update(spec_json: JSON.generate(spec))
        end
      end
    end
  end
end
