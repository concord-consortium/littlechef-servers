#!/bin/sh -e
# upstart-job
#
# Symlink target for initscripts that have been converted to Upstart.
set -e

SOLR_ROOT="<%= @solr_dir %>"

start_sunspot(){
  echo "Starting Sunspot"
  # sudo -iu deploy bash -c "cd $SOLR_ROOT && bundle exec rake sunspot:solr:start RAILS_ENV=production"
}

stop_sunspot(){
  echo "Stopping Sunspot"
  # sudo -iu deploy bash -c "cd $SOLR_ROOT && bundle exec rake sunspot:solr:stop RAILS_ENV=production"
}

restart_sunspot() {
  stop_sunspot
  sleep 1
  start_sunspot
}

sunspot_status() {
  echo "Sunspot Status is completely unknown, goodluck."
  pgrep -f solr
}

usage() {
  echo "Usage: /etc/init.d/solr.sh {start|stop|restart|status}"
}

COMMAND="$1"
case $COMMAND in
  status)
    sunspot_status
  ;;
  start)
    start_sunspot
  ;;
  stop)
    stop_sunspot
  ;;
  restart)
    restart_sunspot
  ;;
  *)
    usage
  ;;
esac