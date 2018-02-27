## Director Console debugging

```
$ bosh -d dep1 ssh name/id
$ sudo su
# /var/vcap/jobs/director/bin/director_ctl console
```

Potentially useful snippets:

```ruby
# list foreign keys for a table
Bosh::Director::Config.db.foreign_key_list(:instances)

# typical select
Bosh::Director::Config.db[:instances].where(variable_set_id: nil).first

# find first item in a table
Bosh::Director::Config.db[:schema_migrations].where(filename: "xxx").first

# consistent sort of applied migrations
Bosh::Director::Config.db[:schema_migrations].order(:filename).last

# manually record applied migration -- super dangerous.
Bosh::Director::Config.db[:schema_migrations] << {filename: "xxx"}

# update first item in a table
Bosh::Director::Models::Instance.first.update(boostrap: false)
```
