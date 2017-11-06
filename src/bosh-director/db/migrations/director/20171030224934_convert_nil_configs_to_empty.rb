require 'yaml'

Sequel.migration do
  change do
    self[:configs].each do |config|
      parsed = nil
      old_content = config[:content]
      unless old_content.nil?
        begin
          parsed = YAML.load(config[:content])
        rescue
          next
        end
      end

      if parsed.nil?
        self[:configs].where(id: config[:id]).update(content: '--- {}')
      end
    end

    alter_table :configs do
      set_column_not_null :content
    end
  end
end
