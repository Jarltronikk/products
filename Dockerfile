from ruby:2.1-onbuild
run bundler install
CMD bundle exec thin start -p  80 -e production