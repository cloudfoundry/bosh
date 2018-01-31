Sequel.migration do
  up do
    rename_table :stemcell_matches, :stemcell_uploads
  end
end
