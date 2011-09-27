module Bosh::Cli::Command
  class Stemcell < Base
    include Bosh::Cli::VersionCalc

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
      auth_required

      stemcell = Bosh::Cli::Stemcell.new(tarball_path, cache)

      say("\nVerifying stemcell...")
      manifest = stemcell.validate
      say("\n")

      if !stemcell.valid?
        err("Stemcell is invalid, please fix, verify and upload again")
      end

      say("Checking if stemcell already exists...")
      name = manifest["name"]
      vers = manifest["version"]

      existing = director.list_stemcells.select { |sc|
        sc["name"] == name and sc["version"] == vers
      }

      if existing.empty?
        say "No"
      else
        err "Stemcell \"#{name}\":\"#{vers}\" already exists, increment the version if it has changed"
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
      auth_required
      stemcells = director.list_stemcells.sort do |sc1, sc2|
        sc1["name"] == sc2["name"] ? version_cmp(sc1["version"], sc2["version"]) : sc1["name"] <=> sc2["name"]
      end

      err("No stemcells") if stemcells.size == 0

      stemcells_table = table do |t|
        t.headings = "Name", "Version", "CID"
        stemcells.each do |sc|
          t << [ sc["name"], sc["version"], sc["cid"] ]
        end
      end

      say("\n")
      say(stemcells_table)
      say("\n")
      say("Stemcells total: %d" % stemcells.size)
    end

    def delete(name, version)
      auth_required

      say "You are going to delete stemcell `#{name} (#{version})'".red

      unless operation_confirmed?
        say "Canceled deleting stemcell".green
        return
      end

      status, message = director.delete_stemcell(name, version)

      responses = {
        :done          => "Deleted stemcell %s (%s)" % [ name, version ],
        :non_trackable => "Stemcell delete in progress but director at '#{target}' doesn't support task tracking",
        :track_timeout => "Timed out out while tracking stemcell deletion progress",
        :error         => "Attempted to delete stemcell but received an error while tracking status",
      }

      say responses[status] || "Cannot delete stemcell: #{message}"
    end
  end
end
