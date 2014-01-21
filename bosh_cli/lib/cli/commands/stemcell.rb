require 'cli/public_stemcell_presenter'
require 'cli/public_stemcells'

module Bosh::Cli
  class Command::Stemcell < Command::Base
    include Bosh::Cli::VersionCalc

    usage 'verify stemcell'
    desc 'Verify stemcell'
    def verify(tarball_path)
      stemcell = Bosh::Cli::Stemcell.new(tarball_path)

      nl
      say('Verifying stemcell...')
      stemcell.validate
      nl

      if stemcell.valid?
        say("`#{tarball_path}' is a valid stemcell".make_green)
      else
        say('Validation errors:'.make_red)
        stemcell.errors.each do |error|
          say('- %s' % [error])
        end
        err("`#{tarball_path}' is not a valid stemcell")
      end
    end

    usage 'upload stemcell'
    desc 'Upload stemcell (stemcell_location can be a local file or a remote URI)'
    def upload(stemcell_location)
      auth_required

      stemcell_type = stemcell_location =~ /^#{URI::regexp}$/ ? 'remote' : 'local'
      if stemcell_type == 'local'
        stemcell = Bosh::Cli::Stemcell.new(stemcell_location)

        nl
        say('Verifying stemcell...')
        stemcell.validate
        nl

        unless stemcell.valid?
          err('Stemcell is invalid, please fix, verify and upload again')
        end

        say('Checking if stemcell already exists...')
        name = stemcell.manifest['name']
        version = stemcell.manifest['version']

        if exists?(name, version)
          err("Stemcell `#{name}/#{version}' already exists, " +
                'increment the version if it has changed')
        else
          say('No')
        end

        stemcell_location = stemcell.stemcell_file

        nl
        say('Uploading stemcell...')
        nl
      else
        nl
        say("Using remote stemcell `#{stemcell_location}'")
      end

      if stemcell_type == 'local'
        status, task_id = director.upload_stemcell(stemcell_location)
      else
        status, task_id = director.upload_remote_stemcell(stemcell_location)
      end

      task_report(status, task_id, 'Stemcell uploaded and created')
    end

    usage 'stemcells'
    desc 'Show the list of available stemcells'
    def list
      auth_required
      stemcells = director.list_stemcells.sort do |sc1, sc2|
        sc1['name'] == sc2['name'] ?
            version_cmp(sc1['version'], sc2['version']) :
            sc1['name'] <=> sc2['name']
      end

      err('No stemcells') if stemcells.empty?

      stemcells_table = table do |t|
        t.headings = 'Name', 'Version', 'CID'
        stemcells.each do |sc|
          t << get_stemcell_table_record(sc)
        end
      end

      nl
      say(stemcells_table)
      nl
      say('(*) Currently in-use')
      nl
      say('Stemcells total: %d' % stemcells.size)
    end

    usage 'public stemcells'
    desc 'Show the list of publicly available stemcells for download.'
    option '--full', 'show the full download url'
    option '--all', 'show all stemcells'
    def list_public
      public_stemcells = PublicStemcells.new
      public_stemcells_presenter = PublicStemcellPresenter.new(self, public_stemcells)
      public_stemcells_presenter.list(options)
    end

    usage 'download public stemcell'
    desc 'Downloads a stemcell from the public blobstore'
    def download_public(stemcell_filename)
      public_stemcells = PublicStemcells.new
      public_stemcells_presenter = PublicStemcellPresenter.new(self, public_stemcells)
      public_stemcells_presenter.download(stemcell_filename)
    end

    usage 'delete stemcell'
    desc 'Delete stemcell'
    option '--force', 'ignore errors while deleting the stemcell'
    def delete(name, version)
      auth_required
      force = !!options[:force]

      say('Checking if stemcell exists...')

      unless exists?(name, version)
        err("Stemcell `#{name}/#{version}' does not exist")
      end

      say("You are going to delete stemcell `#{name}/#{version}'".make_red)

      unless confirmed?
        say('Canceled deleting stemcell'.make_green)
        return
      end

      status, task_id = director.delete_stemcell(name, version, :force => force)

      task_report(status, task_id, "Deleted stemcell `#{name}/#{version}'")
    end

    private

    def exists?(name, version)
      existing = director.list_stemcells.select do |sc|
        sc['name'] == name && sc['version'] == version
      end

      !existing.empty?
    end

    def get_stemcell_table_record(sc)
      any_deployments = deployments_count(sc) > 0

      [sc['name'], "#{sc['version']}#{any_deployments ? '*' : ''}", sc['cid']]
    end

    def deployments_count(sc)
      sc.fetch('deployments_count', nil) || sc.fetch('deployments', []).size
    end
  end
end
