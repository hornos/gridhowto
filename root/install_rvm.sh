#!/bin/bash
\curl -L https://get.rvm.io | bash -s stable --ruby --autolibs=3
source /usr/local/rvm/scripts/rvm
gem install bundle
gem update
# rvm install ruby-1.9.3-p194
