module Bosh::Director::Models::Links
  class LinkConsumerIntent < Sequel::Model(Bosh::Director::Config.db)
    many_to_one :link_consumer, :class => 'Bosh::Director::Models::Links::LinkConsumer'
    one_to_many :links, :key => :link_consumer_intent_id, :class => 'Bosh::Director::Models::Links::Link'

    def validate
      validates_presence [:link_consumer_id, :original_name, :type]
    end

    def target_link_id=(link_id)
      meta = metadata || '{}'
      meta = JSON.parse(meta)
      meta['target_link_id'] = link_id

      self.metadata = meta.to_json
    end

    def target_link_id
      meta = {}
      meta = JSON.parse(metadata) unless metadata.nil?
      meta['target_link_id'] || fallback_link_id
    end

    private

    def fallback_link_id
      return nil if links.count.zero?
      links.max_by(&:id).id
    end
  end
end