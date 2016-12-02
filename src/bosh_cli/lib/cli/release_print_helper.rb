module ReleasePrintHelper

  private
  def artifact_summary(artifact)
    [
        artifact.name,
        artifact.version,
        artifact.new_version? ? 'new version' : '',
    ]
  end

  def show_summary(builder)
    packages_table = table do |t|
      t.headings = %w(Name Version Notes)
      builder.packages.each do |package_artifact|
        t << artifact_summary(package_artifact)
      end
    end

    jobs_table = table do |t|
      t.headings = %w(Name Version Notes)
      builder.jobs.each do |job_artifact|
        t << artifact_summary(job_artifact)
      end
    end

    if builder.license
      license_table = table do |t|
        t.headings = %w(Name Version Notes)
        t << artifact_summary(builder.license)
      end

      say('License')
      say(license_table)
      nl
    end

    say('Packages')
    say(packages_table)
    nl
    say('Jobs')
    say(jobs_table)

    affected_jobs = builder.affected_jobs

    if affected_jobs.size > 0
      nl
      say('Jobs affected by changes in this release')

      affected_jobs_table = table do |t|
        t.headings = %w(Name Version)
        affected_jobs.each do |job|
          t << [job.name, job.version]
        end
      end

      say(affected_jobs_table)
    end
  end
end
