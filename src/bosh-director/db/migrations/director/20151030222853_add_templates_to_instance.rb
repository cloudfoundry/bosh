Sequel.migration do
  up do
    create_table(:instances_templates) do
      primary_key :id
      foreign_key :instance_id, :instances, :null => false
      foreign_key :template_id, :templates, :null => false
      unique [:instance_id, :template_id]
    end
  end
end
