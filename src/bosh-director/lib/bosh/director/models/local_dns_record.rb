module Bosh::Director::Models
  class LocalDnsRecord  < Sequel::Model(Bosh::Director::Config.db)
    many_to_one :instance

    def self.insert_tombstone
      tombstone_record = create(:ip => "#{SecureRandom.uuid}-tombstone")
      where{id < tombstone_record.id}.where(Sequel.like(:ip, '%-tombstone')).delete
      tombstone_record
    end

    def links=(value)
      self.links_json = value.to_json
    end

    def links
      JSON.parse(links_json || '[]').map(&:symbolize_keys)
    end

    def to_hash
      super.tap do |h|
        h[:links] = links
        h.delete(:links_json)
      end
    end
  end
end
