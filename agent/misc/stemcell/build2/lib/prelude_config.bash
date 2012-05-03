source $base_dir/lib/prelude_common.bash

# Include actual settings
source $1

mkdir -p $(dirname $settings_file)
rm -f $settings_file

# Include notice
echo "# THIS FILE IS GENERATED; DO NOT EDIT OR COMMIT" >> $settings_file

function fail() {
  printf "%s: %s\n" "$dir" "$1"
  exit 1
}

function assert_not_empty() {
  value=$(eval echo -n "\${$1:-}")

  if [ -z $value ]
  then
    fail "\$$1 is empty"
  fi

  echo $1=$value >> $settings_file
}
