source $base_dir/lib/prelude_common.bash

# Include actual settings
source $1

mkdir -p $(dirname $settings_file)
rm -f $settings_file

# Include notice
echo "# THIS FILE IS GENERATED; DO NOT EDIT OR COMMIT" >> $settings_file

function assert_available() {
  if ! which $1 >/dev/null
  then
    echo "$1 is not available"
    exit 1
  fi
}

function fail() {
  printf "%s: %s\n" "$dir" "$1"
  exit 1
}

function persist() {
  value=$(eval echo -n "\${$1:-}")
  echo "$1=$value" >> $settings_file
}

function assert_value() {
  value=$(eval echo -n "\${$1:-}")

  if [ -z $value ]
  then
    fail "\$$1 is empty"
  fi
}

function persist_value() {
  assert_value $1
  persist $1
}

function assert_dir() {
  assert_value $1

  value=$(eval echo -n "\${$1:-}")

  if [ ! -d $value ]
  then
    fail "\$$1 is not a directory"
  fi
}

function persist_dir() {
  assert_dir $1
  persist $1
}

function assert_file() {
  assert_value $1

  value=$(eval echo -n "\${$1:-}")

  if [ ! -f $value ]
  then
    fail "\$$1 is not a file"
  fi
}

function persist_file() {
  assert_file $1
  persist $1
}
