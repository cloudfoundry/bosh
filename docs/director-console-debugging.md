# Director Console debugging

## SSH to the Director VM

For director version <= 265.x

```bash
sudo su
/var/vcap/jobs/director/bin/director_ctl console 
```

For director version >= 266.x

```bash
sudo su
/var/vcap/jobs/director/bin/console
```

## Potentially useful snippets:

### List foreign keys for a table

```ruby
Bosh::Director::Config.db.foreign_key_list(:instances)
```

### Typical select

```ruby
Bosh::Director::Config.db[:instances].where(variable_set_id: nil).first
```

### Find first item in a table

```ruby
Bosh::Director::Config.db[:schema_migrations].where(filename: "xxx").first
```

### Consistent sort of applied migrations

```ruby
Bosh::Director::Config.db[:schema_migrations].order(:filename).last
```

### Manually record applied migration -- super dangerous.

```ruby
Bosh::Director::Config.db[:schema_migrations] << {filename: "xxx"}
```

### update first item in a table

```ruby
Bosh::Director::Models::Instance.first.update(boostrap: false)
```

### verify and delete disk reference

```ruby
Bosh::Director::Models::PersistentDisk.where(disk_cid: "...").all
Bosh::Director::Models::PersistentDisk.where(disk_cid: "...").delete
```

### download specific blob from blobstore with an ID

```ruby
File.open("/tmp/my-temp-blob-file", 'wb') { |file| Bosh::Director::App.instance.blobstores.blobstore.get("some-blobstore-id", file) }
```
