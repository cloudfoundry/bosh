module Bosh::Director

  class StemcellManager

    def create_stemcell(stemcell)
      stemcell_file = Tempfile.new("stemcell")
      File.open(stemcell_file.path, "w") do |f|
        buffer = ""
        f.write(buffer) until stemcell.read(16384, buffer).nil?
      end

      task = Models::Task.new(:state => :queued, :timestamp => Time.now.to_i)
      task.create

      Resque.enqueue(Jobs::UpdateStemcell, task.id, stemcell_file.path)

      task
    end

  end
end
