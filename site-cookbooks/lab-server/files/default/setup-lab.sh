#!/bin/sh
cd /var/www/app
bundle install
cd server
bundle install
cp config/couchdb.sample.yml config/couchdb.yml
cd ..
cp config/config_sample.yml config/config.yml
make clean
make
