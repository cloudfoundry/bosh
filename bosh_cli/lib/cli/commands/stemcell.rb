require 'cli/public_stemcell_presenter'
require 'cli/public_stemcells'

module Bosh::Cli
  class Command::Stemcell < Command::Base
    STEMCELL_EXISTS_ERROR_CODE = 50002

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
    option '--skip-if-exists', 'skips upload if stemcell already exists'
    def upload(stemcell_location)
      auth_required
      show_current_state

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
          if options[:skip_if_exists]
            say("Stemcell `#{name}/#{version}' already exists. Skipping upload.")
            return
          else
            err("Stemcell `#{name}/#{version}' already exists. Increment the version if it has changed.")
          end
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

      status, task_id = apply_upload_stemcell_strategy(stemcell_type, stemcell_location)
      success_message = 'Stemcell uploaded and created.'

      if status == :error && options[:skip_if_exists] && last_event(task_id)['error']['code'] == STEMCELL_EXISTS_ERROR_CODE
        status = :done
        success_message = skip_existing_stemcell_message(stemcell_type, stemcell_location)
      end

      task_report(status, task_id, success_message)
    end

    usage 'stemcells'
    desc 'Show the list of available stemcells'
    def list
      auth_required
      show_current_state

      stemcells = director.list_stemcells.sort do |sc1, sc2|
        if sc1['name'] == sc2['name']
          Bosh::Common::Version::StemcellVersion.parse_and_compare(sc1['version'], sc2['version'])
        else
          sc1['name'] <=> sc2['name']
        end
      end

      err('No stemcells') if stemcells.empty?

      stemcells_table = table do |t|
        t.headings = 'Name', 'OS', 'Version', 'CID'
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
      show_current_state

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

    def skip_existing_stemcell_message(stemcell_type, stemcell_location)
      if stemcell_type == 'local'
        'Stemcell already exists. Skipping upload.'
      else
        "Stemcell at #{stemcell_location} already exists."
      end
    end

    def apply_upload_stemcell_strategy(stemcell_type, stemcell_location)
      if stemcell_type == 'local'
        director.upload_stemcell(stemcell_location)
      else
        director.upload_remote_stemcell(stemcell_location)
      end
    end

    def last_event(task_id)
      event_log, _ = director.get_task_output(task_id, 0, 'event')
      JSON.parse(event_log.split("\n").last)
    end

    def exists?(name, version)
      existing = director.list_stemcells.select do |sc|
        sc['name'] == name && sc['version'] == version
      end

      !existing.empty?
    end

    def get_stemcell_table_record(sc)
      deployments = sc.fetch('deployments', [])

      [sc['name'], sc['operating_system'], "#{sc['version']}#{deployments.empty? ? '' : '*'}", sc['cid']]
    end
  end
end
