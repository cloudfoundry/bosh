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

    DEFAULT_PUB_STEMCELL_TAG = "stable"

    ALL_STEMCELLS_TAG = "all"

    # usage "verify stemcell <path>"
    # desc  "Verify stemcell"
    # route :stemcell, :verify
    def verify(tarball_path)
      stemcell = Bosh::Cli::Stemcell.new(tarball_path, cache)

      say("\nVerifying stemcell...")
      stemcell.validate
      say("\n")

      if stemcell.valid?
        say("'%s' is a valid stemcell" % [tarball_path])
      else
        say("Validation errors:".red)
        for error in stemcell.errors
          say("- %s" % [error])
        end
        err("'%s' is not a valid stemcell" % [tarball_path])
      end
    end

    # usage "upload stemcell <path>"
    # desc  "Upload the stemcell"
    # route :stemcell, :upload
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

      unless exists?(name, version)
        say("No")
      else
        err("Stemcell `#{name}/#{version}' already exists, " +
            "increment the version if it has changed")
      end

      say("\nUploading stemcell...\n")

      status, _ = director.upload_stemcell(stemcell.stemcell_file)

      task_report(status, "Stemcell uploaded and created")
    end

    # usage "stemcells"
    # desc  "Show the list of available stemcells"
    # route :stemcell, :list
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
        err("Received HTTP #{status_code} from #{PUBLIC_STEMCELL_INDEX_URL}.")
      end
      YAML.load(response.body)
    end

    def skip_this_tag?(yaml_tags, requested_tags)
      if requested_tags == [ALL_STEMCELLS_TAG]
        return false
      end
      unless yaml_tags
        return true
      end
      requested_tags.each do |tag|
        unless yaml_tags.include?(tag)
          return true
        end
      end
      return false
    end

    # Prints out the publicly available stemcells.
    #
    # usage "public stemcells"
    # desc  "Show the list of publicly available stemcells for download."
    # option "--full", "show the full download url"
    # route :stemcell, :list_public
    def list_public(*args)
      full = args.include?("--full")
      tags_index = args.index("--tags")
      tags = [DEFAULT_PUB_STEMCELL_TAG]
      if tags_index
        tags_index += 1
        raise "Must include tags." if args.length - 1 < tags_index
        tags = args[tags_index].sub(" ", "").split(",")
      end
      yaml = get_public_stemcell_list
      stemcells_table = table do |t|
        if full
          t.headings = "Name", "Url", "Tags"
        else
          t.headings = "Name", "Tags"
        end
        yaml.keys.sort.each do |key|
          if key != PUBLIC_STEMCELL_INDEX
            url = yaml[key]["url"]
            yaml_tags = yaml[key]["tags"]
            next if skip_this_tag?(yaml_tags, tags)

            yaml_tags = yaml_tags ? yaml_tags.join(", ") : ""
            if full
              t << [key, url, yaml_tags]
            else
              t << [key, yaml_tags]
            end
          end
        end
      end
      puts(stemcells_table)
      if full
        puts("To download use 'bosh download public stemcell <stemcell_name>'.")
      else
        puts("To download use 'bosh download public stemcell <stemcell_name>'." +
            "  To show download urls use --full.")
      end
    end

    # Downloads one of the publicly available stemcells.
    # @param [String] stemcell_name The name of the stemcell, as seen in the
    #     public stemcell index file.
    #
    # usage "download public stemcell <stemcell_name>"
    # desc  "Downloads a stemcell from the public blobstore."
    # route :stemcell, :download_public
    def download_public(stemcell_name)
      yaml = get_public_stemcell_list
      yaml.delete(PUBLIC_STEMCELL_INDEX) if yaml.has_key?(PUBLIC_STEMCELL_INDEX)

      unless yaml.has_key?(stemcell_name)
        available_stemcells = yaml.map { |k| k }.join(", ")
        err("'#{stemcell_name}' not found in '#{available_stemcells}'.")
      end

      if File.exists?(stemcell_name) &&
          !agree("#{stemcell_name} exists locally. Overwrite it? [yn]")
        return
      end

      url = yaml[stemcell_name]["url"]
      size = yaml[stemcell_name]["size"]
      sha1 = yaml[stemcell_name]["sha"]
      progress_bar = ProgressBar.new(stemcell_name, size)
      progress_bar.file_transfer_mode
      File.open("#{stemcell_name}", "w") { |file|
        @http_client.get(url) do |chunk|
          file.write(chunk)
          progress_bar.inc(chunk.size)
        end
      }
      progress_bar.finish
      file_sha1 = Digest::SHA1.file(stemcell_name).hexdigest
      if file_sha1 != sha1
        err("The downloaded file sha1 '#{file_sha1}' does not match the " +
            "expected sha1 '#{sha1}'.")
      else
        puts("Download complete.")
      end
    end

    # usage "delete stemcell <name> <version>"
    # desc  "Delete the stemcell"
    # route :stemcell, :delete
    def delete(name, version)
      auth_required

      say("Checking if stemcell exists...")

      if exists?(name, version)
        say("Yes")
      else
        err("Stemcell `#{name}/#{version}' does not exist")
      end

      say("You are going to delete stemcell `#{name}/#{version}'".red)

      unless confirmed?
        say("Canceled deleting stemcell".green)
        return
      end

      status, _ = director.delete_stemcell(name, version)

      task_report(status, "Deleted stemcell `#{name}/#{version}'")
    end

    def exists?(name, version)
      existing = director.list_stemcells.select do |sc|
        sc["name"] == name && sc["version"] == version
      end

      !existing.empty?
    end
  end
end
