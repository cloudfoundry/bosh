Sequel.migration do
  up do
    self[:stemcells].all do |stemcell|
      if stemcell[:operating_system].nil? || stemcell[:operating_system] == ''
        self[:stemcells].where(id: stemcell[:id]).update(operating_system: stemcell[:name])
      end
    end
  end
end
