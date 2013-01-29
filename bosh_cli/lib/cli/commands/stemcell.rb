# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Cli::Command
  class Stemcell < Base
    include Bosh::Cli::VersionCalc

    # The filename of the public stemcell index.
    PUBLIC_STEMCELL_INDEX = "public_stemcells_index.yml"

    # The URL of the public stemcell index.
    PUBLIC_STEMCELL_INDEX_URL =
      "https://blob.cfblob.com/rest/objects/4e4e78bca2" +
      "1e121204e4e86ee151bc04f6a19ce46b22?uid=bb6a0c89ef4048a8a0f814e2538" +
      "5d1c5/user1&expires=1893484800&signature=NJuAr9c8eOid7dKFmOEN7bmzAlI="

    DEFAULT_PUB_STEMCELL_TAG = "stable"
    ALL_STEMCELLS_TAG = "all"

    usage "verify stemcell"
    desc "Verify stemcell"
    def verify(tarball_path)
      stemcell = Bosh::Cli::Stemcell.new(tarball_path, cache)

      nl
      say("Verifying stemcell...")
      stemcell.validate
      nl

      if stemcell.valid?
        say("`#{tarball_path}' is a valid stemcell".green)
      else
        say("Validation errors:".red)
        stemcell.errors.each do |error|
          say("- %s" % [error])
        end
        err("`#{tarball_path}' is not a valid stemcell")
      end
    end

    # bosh upload stemcell
    usage "upload stemcell"
    desc "Upload stemcell"
    def upload(tarball_path)
      auth_required

      stemcell = Bosh::Cli::Stemcell.new(tarball_path, cache)

      nl
      say("Verifying stemcell...")
      stemcell.validate
      nl

      unless stemcell.valid?
        err("Stemcell is invalid, please fix, verify and upload again")
      end

      say("Checking if stemcell already exists...")
      name = stemcell.manifest["name"]
      version = stemcell.manifest["version"]

      if exists?(name, version)
        err("Stemcell `#{name}/#{version}' already exists, " +
              "increment the version if it has changed")
      else
        say("No")
      end

      nl
      say("Uploading stemcell...")
      nl

      status, task_id = director.upload_stemcell(stemcell.stemcell_file)

      task_report(status, task_id, "Stemcell uploaded and created")
    end

    # bosh stemcells
    usage "stemcells"
    desc "Show the list of available stemcells"
    def list
      auth_required
      stemcells = director.list_stemcells.sort do |sc1, sc2|
        sc1["name"] == sc2["name"] ?
            version_cmp(sc1["version"], sc2["version"]) :
            sc1["name"] <=> sc2["name"]
      end

      err("No stemcells") if stemcells.empty?

      stemcells_table = table do |t|
        t.headings = "Name", "Version", "CID"
        stemcells.each do |sc|
          t << [sc["name"], sc["version"], sc["cid"]]
        end
      end

      nl
      say(stemcells_table)
      nl
      say("Stemcells total: %d" % stemcells.size)
    end

    # Prints out the publicly available stemcells.
    usage "public stemcells"
    desc "Show the list of publicly available stemcells for download."
    option "--full", "show the full download url"
    option "--tags tag1,tag2...", Array, "filter by tag"
    option "--all", "show all stemcells"
    def list_public
      full = !!options[:full]
      tags = options[:tags] || [DEFAULT_PUB_STEMCELL_TAG]
      tags = [ALL_STEMCELLS_TAG] if options[:all]

      yaml = get_public_stemcell_list
      stemcells_table = table do |t|
        t.headings = full ? ["Name", "Url", "Tags"] : ["Name", "Tags"]
        yaml.keys.sort.each do |key|
          if key != PUBLIC_STEMCELL_INDEX
            url = yaml[key]["url"]
            yaml_tags = yaml[key]["tags"]
            next if skip_this_tag?(yaml_tags, tags)

            yaml_tags = yaml_tags ? yaml_tags.join(", ") : ""
            t << (full ? [key, url, yaml_tags] : [key, yaml_tags])
          end
        end
      end

      say(stemcells_table)

      say("To download use `bosh download public stemcell <stemcell_name>'. " +
          "For full url use --full.")
    end

    # Downloads one of the publicly available stemcells.
    usage "download public stemcell"
    desc "Downloads a stemcell from the public blobstore"
    # @param [String] stemcell_name The name of the stemcell, as seen in the
    #   public stemcell index file.
    def download_public(stemcell_name)
      yaml = get_public_stemcell_list
      yaml.delete(PUBLIC_STEMCELL_INDEX) if yaml.has_key?(PUBLIC_STEMCELL_INDEX)

      unless yaml.has_key?(stemcell_name)
        available_stemcells = yaml.map { |k| k }.join(", ")
        err("'#{stemcell_name}' not found in '#{available_stemcells}'.")
      end

      if File.exists?(stemcell_name) &&
         !confirmed?("Overwrite existing file `#{stemcell_name}'?")
        err("File `#{stemcell_name}' already exists")
      end

      url = yaml[stemcell_name]["url"]
      size = yaml[stemcell_name]["size"]
      sha1 = yaml[stemcell_name]["sha"]
      progress_bar = ProgressBar.new(stemcell_name, size)
      progress_bar.file_transfer_mode

      File.open("#{stemcell_name}", "w") do |file|
        @http_client.get(url) do |chunk|
          file.write(chunk)
          progress_bar.inc(chunk.size)
        end
      end
      progress_bar.finish

      file_sha1 = Digest::SHA1.file(stemcell_name).hexdigest
      if file_sha1 != sha1
        err("The downloaded file sha1 `#{file_sha1}' does not match the " +
            "expected sha1 `#{sha1}'")
      else
        say("Download complete".green)
      end
    end

    # bosh delete stemcell
    usage "delete stemcell"
    desc  "Delete stemcell"
    def delete(name, version)
      auth_required

      say("Checking if stemcell exists...")

      unless exists?(name, version)
        err("Stemcell `#{name}/#{version}' does not exist")
      end

      say("You are going to delete stemcell `#{name}/#{version}'".red)

      unless confirmed?
        say("Canceled deleting stemcell".green)
        return
      end

      status, task_id = director.delete_stemcell(name, version)

      task_report(status, task_id, "Deleted stemcell `#{name}/#{version}'")
    end

    private

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

    def exists?(name, version)
      existing = director.list_stemcells.select do |sc|
        sc["name"] == name && sc["version"] == version
      end

      !existing.empty?
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

  end
end
