Sequel.migration do
  change do
    self[:cpi_configs].each do |cpi_config|
      self[:configs].insert({
        type: 'cpi',
        name: 'default',
        content: cpi_config[:properties],
        created_at: cpi_config[:created_at]
      })
    end
  end
end
