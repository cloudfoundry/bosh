function pid_exists {
  ps -p $1 &> /dev/null
  return $?
}

function kill_process {
  PID=$1
  kill -TERM $PID

  TRIES=0
  while pid_exists $PID; do
    TRIES=$(( $TRIES + 1 ))
    kill -TERM $PID
    if [ $TRIES -gt 100 ]; then
      kill -9 $PID
      break
    fi
    sleep 0.1
  done
}

function list_child_processes {
  ps -eo pid,command |
    grep bosh-director-worker |
    grep -- "-n $1" |
    awk '{print $1}' |
    grep -v ^$1$
}
