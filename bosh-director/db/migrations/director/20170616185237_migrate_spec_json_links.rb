Sequel.migration do
  up do
    self[:instances].each do |instance|
      begin
        instance_spec_json = JSON.parse(instance[:spec_json])
      rescue
        next
      end

      if !instance_spec_json['job']
        next
      end

      links_hash = instance_spec_json['links']
      jobs_hash = instance_spec_json['job']['templates']

      if links_hash == nil
        next
      end

      if jobs_hash == nil || jobs_hash.empty?
        next
      end

      instance_spec_json['links'] = {}

      jobs_hash.each do |job|
        job_name = job['name']
        instance_spec_json['links'][job_name] = links_hash
      end

      self[:instances].where(id: instance[:id]).update(spec_json: JSON.dump(instance_spec_json))

    end
  end
end
