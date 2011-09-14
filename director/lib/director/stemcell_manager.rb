module Bosh::Director

  class StemcellManager
    include TaskHelper

    def create_stemcell(user, stemcell)
      stemcell_file = File.join(Dir::tmpdir, "stemcell-#{UUIDTools::UUID.random_create}")
      File.open(stemcell_file, "w") do |f|
        buffer = ""
        f.write(buffer) until stemcell.read(16384, buffer).nil?
      end

      task = create_task(user, "create stemcell")
      Resque.enqueue(Jobs::UpdateStemcell, task.id, stemcell_file)
      task
    end

    def delete_stemcell(user, stemcell)
      task = create_task(user, "delete stemcell: #{stemcell.name}/#{stemcell.version}")
      Resque.enqueue(Jobs::DeleteStemcell, task.id, stemcell.name, stemcell.version)
      task
    end

    def clean_stemcells(user, name, versions_to_keep)
      task = create_task(user, "clean stemcell: #{name}")
      Resque.enqueue(Jobs::DeleteStemcell, task.id, name, nil, versions_to_keep)
      task
    end
  end
end
