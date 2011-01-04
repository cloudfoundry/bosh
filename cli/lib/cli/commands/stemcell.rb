module Bosh::Cli::Command
  class Stemcell < Base

    def verify(tarball_path)
      stemcell = Bosh::Cli::Stemcell.new(tarball_path, cache)

      say("\nVerifying stemcell...")
      stemcell.validate
      say("\n")

      if stemcell.valid?
        say("'%s' is a valid stemcell" % [ tarball_path] )
      else
        say("'%s' is not a valid stemcell:" % [ tarball_path] )
        for error in stemcell.errors
          say("- %s" % [ error ])
        end
      end      
    end

    def upload(tarball_path)
      err("Please log in first") unless logged_in?
      err("Please choose target") unless target

      stemcell = Bosh::Cli::Stemcell.new(tarball_path, cache)

      say("\nVerifying stemcell...")
      stemcell.validate
      say("\n")

      if !stemcell.valid?
        err("Stemcell is invalid, please fix, verify and upload again")
      end

      say("\nUploading stemcell...\n")

      status, message = director.upload_stemcell(stemcell.stemcell_file)

      responses = {
        :done          => "Stemcell uploaded and created",
        :non_trackable => "Uploaded stemcell but director at '#{target}' doesn't support creation tracking",
        :track_timeout => "Uploaded stemcell but timed out out while tracking status",
        :error         => "Uploaded stemcell but received an error while tracking status",
      }

      say responses[status] || "Cannot upload stemcell: #{message}"
    end

    def list
      err("Please log in first") unless logged_in?
      err("Please choose target") unless target
      stemcells = director.list_stemcells

      if stemcells.size == 0
        say("No stemcells")
        return
      end

      stemcells_table = table do |t|
        t.headings = "Name", "Version"
        stemcells.each do |sc|
          t << [ sc["name"], sc["version"] ]
        end
      end

      say("\n")
      say(stemcells_table)
      say("\n")
      say("Stemcells total: %d" % stemcells.size)
    end

    def delete(name, version)
      err("Please log in first") unless logged_in?
      err("Please choose target") unless target

      status, message = director.delete_stemcell(name, version)

      responses = {
        :done          => "Deleted stemcell %s (%s)" % [ name, version ],
        :non_trackable => "Stemcell delete in progress but director at '#{target}' doesn't support task tracking",
        :track_timeout => "Timed out out while tracking stemcell deletion progress",
        :error         => "Attemted to delete stemcell but received an error while tracking status",
      }

      say responses[status] || "Cannot delete stemcell: #{message}"
    end
  end
end
