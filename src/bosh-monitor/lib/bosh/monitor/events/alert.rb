module Bosh::Monitor
  module Events
    class Alert < Base
      CATEGORY_VM_HEALTH = 'vm_health'.freeze
      CATEGORY_DEPLOYMENT_HEALTH = 'deployment_health'.freeze

      # Considering Bosh::Agent::Alert
      SEVERITY_MAP = {
        1 => :alert,
        2 => :critical,
        3 => :error,
        4 => :warning,
        -1 => :ignored,
      }.freeze

      attr_reader :created_at, :source, :title, :category

      def initialize(attributes = {})
        super
        @kind = :alert

        @id         = @attributes['id']
        @severity   = @attributes['severity']
        @category   = @attributes['category']
        @title      = @attributes['title']
        @summary    = @attributes['summary'] || @title
        @source     = @attributes['source']
        @deployment = @attributes['deployment']

        # This rescue is just to preserve existing test behavior. However, this
        # seems like a pretty wacky way to handle errors - wouldn't we rather
        # have a nice exception?
        @created_at = begin
                        Time.at(@attributes['created_at'])
                      rescue StandardError
                        @attributes['created_at']
                      end
      end

      def validate
        add_error('id is missing') if @id.nil?
        add_error('severity is missing') if @severity.nil?

        if @severity && (!@severity.is_a?(Integer) || @severity.negative?)
          add_error('severity is invalid (non-negative integer expected)')
        end

        add_error('title is missing') if @title.nil?
        add_error('timestamp is missing') if @created_at.nil?

        add_error('created_at is invalid UNIX timestamp') if @created_at && !@created_at.is_a?(Time)
      end

      def short_description
        "Severity #{@severity}: #{@source} #{@title}"
      end

      def severity
        SEVERITY_MAP[@severity] || @severity
      end

      def to_hash
        {
          kind: 'alert',
          id: @id,
          severity: @severity,
          category: @category,
          title: @title,
          summary: @summary,
          source: @source,
          deployment: @deployment,
          created_at: @created_at.to_i,
        }
      end

      def to_json(*_args)
        JSON.dump(to_hash)
      end

      def to_s
        "Alert @ #{@created_at.utc}, severity #{@severity}: #{@summary}"
      end

      def to_plain_text
        result = ''
        result << "#{@source}\n" unless @source.nil?
        result << (@title || 'Unknown Alert') << "\n"
        result << "Severity: #{@severity}\n"
        result << "Summary: #{@summary}\n" unless @summary.nil?
        result << "Time: #{@created_at.utc}\n"
        result
      end

      def metrics
        []
      end
    end
  end
end
