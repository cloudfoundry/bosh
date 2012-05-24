# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Cli::Command
  class Stemcell < Base
    include Bosh::Cli::VersionCalc

    # The filename of the public stemcell index.
    PUBLIC_STEMCELL_INDEX = "public_stemcells_index.yml"

    # The URL of the public stemcell index.
    PUBLIC_STEMCELL_INDEX_URL = "https://blob.cfblob.com/rest/objects/4e4e78bca2" +
        "1e121204e4e86ee151bc04f6a19ce46b22?uid=bb6a0c89ef4048a8a0f814e2538" +
        "5d1c5/user1&expires=1893484800&signature=NJuAr9c8eOid7dKFmOEN7bmzAlI="

    def verify(tarball_path)
      stemcell = Bosh::Cli::Stemcell.new(tarball_path, cache)

      say("\nVerifying stemcell...")
      stemcell.validate
      say("\n")

      if stemcell.valid?
        say("'%s' is a valid stemcell" % [tarball_path])
      else
        say("'%s' is not a valid stemcell:" % [tarball_path])
        for error in stemcell.errors
          say("- %s" % [error])
        end
      end
    end

    def upload(tarball_path)
      auth_required

      stemcell = Bosh::Cli::Stemcell.new(tarball_path, cache)

      say("\nVerifying stemcell...")
      stemcell.validate
      say("\n")

      unless stemcell.valid?
        err("Stemcell is invalid, please fix, verify and upload again")
      end

      say("Checking if stemcell already exists...")
      name = stemcell.manifest["name"]
      version = stemcell.manifest["version"]

      existing = director.list_stemcells.select do |sc|
        sc["name"] == name and sc["version"] == version
      end

      if existing.empty?
        say("No")
      else
        err("Stemcell \"#{name}\":\"#{version}\" already exists, " +
            "increment the version if it has changed")
      end

      say("\nUploading stemcell...\n")

      status, message = director.upload_stemcell(stemcell.stemcell_file)

      responses = {
        :done => "Stemcell uploaded and created",
        :non_trackable => "Uploaded stemcell but director at '#{target}' " +
                          "doesn't support creation tracking",
        :track_timeout => "Uploaded stemcell but timed out out " +
                          "while tracking status",
        :error => "Uploaded stemcell but received an error " +
                  "while tracking status",
      }

      say(responses[status] || "Cannot upload stemcell: #{message}")
    end

    def list
      auth_required
      stemcells = director.list_stemcells.sort do |sc1, sc2|
        sc1["name"] == sc2["name"] ?
            version_cmp(sc1["version"], sc2["version"]) :
            sc1["name"] <=> sc2["name"]
      end

      err("No stemcells") if stemcells.size == 0

      stemcells_table = table do |t|
        t.headings = "Name", "Version", "CID"
        stemcells.each do |sc|
          t << [sc["name"], sc["version"], sc["cid"]]
        end
      end

      say("\n")
      say(stemcells_table)
      say("\n")
      say("Stemcells total: %d" % stemcells.size)
    end

    # Grabs the index file for the publicly available stemcells.
    # @return [Hash] The index file YAML as a hash.
    def get_public_stemcell_list
      @http_client = HTTPClient.new
      response = @http_client.get(PUBLIC_STEMCELL_INDEX_URL)
      status_code = response.http_header.status_code
      if status_code != HTTP::Status::OK
        raise "Received HTTP #{status_code} from #{index_url}."
      end
      YAML.load(response.body)
    end

    # Prints out the publicly available stemcells.
    def list_public
      yaml = get_public_stemcell_list
      stemcells_table = table do |t|
        t.headings = "Name", "Url"
        yaml.keys.sort.each do |key|
          if key != PUBLIC_STEMCELL_INDEX
            t << [key, yaml[key]["url"]]
          end
        end
      end
      puts(stemcells_table)
      puts("To download use 'bosh download public stemcell <stemcell_name>'.")
    end

    # Downloads one of the publicly available stemcells.
    # @param [String] stemcell_name The name of the stemcell, as seen in the
    #     public stemcell index file.
    def download_public(stemcell_name)
      yaml = get_public_stemcell_list
      yaml.delete(PUBLIC_STEMCELL_INDEX) if yaml.has_key?(PUBLIC_STEMCELL_INDEX)

      unless yaml.has_key?(stemcell_name)
        available_stemcells = yaml.map { |k| k }.join(", ")
        puts("'#{stemcell_name}' not found in '#{available_stemcells}'.".red)
        return
      end

      if File.exists?(stemcell_name) &&
          !agree("#{stemcell_name} exists locally. Overwrite it? [yn]")
        return
      end

      url = yaml[stemcell_name]["url"]
      size = yaml[stemcell_name]["size"]
      pBar = ProgressBar.new(stemcell_name, size)
      pBar.file_transfer_mode
      File.open("#{stemcell_name}", "w") { |file|
        @http_client.get(url) do |chunk|
          file.write(chunk)
          pBar.inc(chunk.size)
        end
      }
      pBar.finish
      puts("Download complete.")
    end

    def delete(name, version)
      auth_required

      say("You are going to delete stemcell `#{name} (#{version})'".red)

      unless confirmed?
        say("Canceled deleting stemcell".green)
        return
      end

      status, message = director.delete_stemcell(name, version)

      responses = {
        :done => "Deleted stemcell #{name} (#{version})",
        :non_trackable => "Stemcell delete in progress but director " +
                          "at '#{target}' doesn't support task tracking",
        :track_timeout => "Timed out out while tracking " +
                          "stemcell deletion progress",
        :error => "Attempted to delete stemcell but received an error " +
                  "while tracking status",
      }

      say(responses[status] || "Cannot delete stemcell: #{message}")
    end
  end
end
