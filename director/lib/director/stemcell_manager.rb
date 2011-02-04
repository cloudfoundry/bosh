module Bosh::Director

  class StemcellManager
    include TaskHelper

    def create_stemcell(stemcell)
      stemcell_file = File.join(Dir::tmpdir, "stemcell-#{UUIDTools::UUID.random_create}")
      File.open(stemcell_file, "w") do |f|
        buffer = ""
        f.write(buffer) until stemcell.read(16384, buffer).nil?
      end

      task = create_task("create stemcell")
      Resque.enqueue(Jobs::UpdateStemcell, task.id, stemcell_file)
      task
    end

    def delete_stemcell(stemcell)
      task = create_task("delete stemcell: #{stemcell.name}/#{stemcell.version}")
      Resque.enqueue(Jobs::DeleteStemcell, task.id, stemcell.name, stemcell.version)
      task
    end

  end
end
