module Bosh::Director
  class LocalDnsRepo
    def initialize(logger, root_domain)
      @logger = logger
      @root_domain = root_domain
    end

    def update_for_instance(instance_plan)
      diff = diff(instance_plan)
      instance_model = instance_plan.instance.model
      @logger.debug("Updating local dns records for '#{instance_model}': obsolete records: #{dump(diff.obsolete)}, new records: #{dump(diff.missing)}, unmodified records: #{dump(diff.unaffected)}")

      Config.db.transaction do
        diff.obsolete.each do |record_hash|
          delete_obsolete_local_dns_records(record_hash.reject do |k, _|
            k == :links
          end)
        end

        diff.missing.each do |record_hash|
          insert_new_record(record_hash)
        end

        if diff.missing.empty? && !diff.obsolete.empty?
          Models::LocalDnsRecord.insert_tombstone
        end
      end
    end

    def diff(instance_plan)
      instance_model = instance_plan.instance.model
      existing_record_hashes = existing_record_hashes(instance_model)
      desired_record_hashes = desired_record_hashes(instance_plan)

      new_record_hashes = desired_record_hashes - existing_record_hashes
      obsolete_record_hashes = existing_record_hashes - desired_record_hashes
      unmodified_record_hashes = existing_record_hashes - obsolete_record_hashes

      Diff.new(obsolete_record_hashes, new_record_hashes, unmodified_record_hashes)
    end

    def delete_for_instance(instance_model)
      records = Models::LocalDnsRecord.where(instance_id: instance_model.id).all
      if records.size > 0
        Config.db.transaction do
          @logger.debug("Deleting local dns records for '#{instance_model}' records: #{records.map(&:to_hash)}")
          records.map(&:delete)
          Models::LocalDnsRecord.insert_tombstone
        end
      end
    end

    private

    def desired_record_hashes(instance_plan)
      desired_record_hashes = []
      networks_and_ips(instance_plan.instance.model).map do |network_to_ip|
        desired_record_hashes << instance_plan.instance_group_properties.merge(
          ip: network_to_ip[:ip],
          network: network_to_ip[:name],
          domain: @root_domain,
        )
      end
      desired_record_hashes
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

    def insert_new_record(attrs)
      Models::LocalDnsRecord.create(attrs)
    rescue Sequel::UniqueConstraintViolation
      @logger.info('Ignoring duplicate DNS record for performance reason')
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
end
