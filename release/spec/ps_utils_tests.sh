#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

source $DIR/../jobs/director/templates/ps_utils.sh

function test_pid_exists {
  echo "an existing PID should exist"
  pid_exists $$ || echo FAIL PID $$ should exist!
  echo "a non-existing PID should NOT exist"
  pid_exists -1 && echo FAIL PID -1 should NOT exist
}

function test_kill_process {
  function kill {
    NUM_KILL_ATTEMPTS=$(( $NUM_KILL_ATTEMPTS + 1 ))
  }

  function pid_exists {
    PID_EXISTS_COUNT=$(( $PID_EXISTS_COUNT - 1 ))
    if [ $PID_EXISTS_COUNT -gt 0 ]; then
      return 0
    else
      return 1
    fi
  }

  PID_EXISTS_COUNT=2
  NUM_KILL_ATTEMPTS=0

  echo "two kills should be sent to process 1"
  kill_process 1

  if [ $NUM_KILL_ATTEMPTS != 2 ]; then
    echo "FAIL expected 2 kills, got $NUM_KILL_ATTEMPTS"
  fi
}

test_pid_exists
test_kill_process
