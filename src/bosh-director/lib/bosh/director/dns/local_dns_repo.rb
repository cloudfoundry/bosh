module Bosh::Director
  class LocalDnsRepo

    def initialize(logger)
      @logger = logger
    end

    def update_for_instance(instance_model)
      diff = diff(instance_model)
      @logger.debug("Updating local dns records for '#{instance_model}': obsolete records: #{dump(diff.obsolete)}, new records: #{dump(diff.missing)}, unmodified records: #{dump(diff.unaffected)}")

      if diff.missing.empty? && !diff.obsolete.empty?
        insert_tombstone
      end

      diff.missing.each do |record_hash|
        insert_new_record(record_hash)
      end

      diff.obsolete.each do |record_hash|
        delete_obsolete_local_dns_records(record_hash)
      end
    end

    def diff(instance_model)
      existing_record_hashes = existing_record_hashes(instance_model)
      desired_record_hashes = desired_record_hashes(instance_model)

      new_record_hashes = desired_record_hashes - existing_record_hashes
      obsolete_record_hashes = existing_record_hashes - desired_record_hashes
      unmodified_record_hashes = existing_record_hashes - obsolete_record_hashes

      Diff.new(obsolete_record_hashes, new_record_hashes, unmodified_record_hashes)
    end

    def delete_for_instance(instance_model)
      records = Models::LocalDnsRecord.where(instance_id: instance_model.id).all
      if records.size > 0
        insert_tombstone
        @logger.debug("Deleting local dns records for '#{instance_model}' records: #{records.map(&:to_hash)}")
        records.map(&:delete)
      end
    end

    private

    def desired_record_hashes(instance_model)
      networks_and_ips(instance_model).map do |network_to_ip|
        {
            :ip => network_to_ip[:ip],
            :instance_id => instance_model.id,
            :az => instance_model.availability_zone,
            :network => network_to_ip[:name],
            :deployment => instance_model.deployment.name,
            :instance_group => instance_model.job
        }
      end
    end

    def existing_record_hashes(instance_model)
      Models::LocalDnsRecord.where(instance_id: instance_model.id).map do |local_dns_record|
        attrs = local_dns_record.to_hash
        attrs.delete(:id)
        attrs
      end
    end

    def delete_obsolete_local_dns_records(record_hash)
      Models::LocalDnsRecord.where(record_hash).delete
    end

    def insert_tombstone
      Models::LocalDnsRecord.create(:ip => "#{SecureRandom.uuid}-tombstone")
    end

    def insert_new_record(attrs)
      begin
        Models::LocalDnsRecord.create(attrs)
      rescue Sequel::UniqueConstraintViolation
        @logger.info('Ignoring duplicate DNS record for performance reason')
      end
    end

    def networks_and_ips(instance_model)
      spec = instance_model.spec
      networks_to_ips = []
      unless spec.nil? || spec['networks'].nil?
        spec['networks'].each do |network_name, network|
          unless network['ip'].nil?
            networks_to_ips << {name: network_name, ip: network['ip']}
          end
        end
      end
      networks_to_ips
    end

    def dump(record_hashes)
      record_strings = record_hashes.map do |record_hash|
        "#{record_hash[:network]}/#{record_hash[:ip]}"
      end

      "[#{record_strings.sort.join(', ')}]"
    end
  end

  class Diff
    attr_reader :obsolete, :missing, :unaffected

    def initialize(obsolete, missing, unaffected)
      @obsolete = obsolete
      @missing = missing
      @unaffected = unaffected
    end

    def changes?
      !obsolete.empty? || !missing.empty?
    end
  end
end