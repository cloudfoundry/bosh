
mkdir -p /var/vcap/sys/log

pid_guard() {
  echo "------------ STARTING `basename $0` at `date` --------------" | tee /dev/stderr
  pidfile=$1
  name=$2

  if [ -f "$pidfile" ]; then
    pid=$(head -1 "$pidfile")

    if [ -n "$pid" ] && [ -e /proc/$pid ]; then
      echo "$name is already running, please stop it first"
      exit 1
    fi

    echo "Removing stale pidfile..."
    rm $pidfile
  fi
}
