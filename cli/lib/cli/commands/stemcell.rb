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
  end
end
