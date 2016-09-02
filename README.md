# Sensu Chef Repo

## Requirements

* Ruby 2.0 or later
* Bundler

## Usage

``` shell
# install required ruby gems
$ bundle install
# export required environment variables
$ export AWS_REGION=us-east-1
$ export AWS_ACCESS_KEY_ID=...
$ export AWS_SECRET_ACCESS_KEY=...
$ export AWS_DEFAULT_REGION=us-east-1
$ export NESTING_BUCKET=solodev-sensu-opsworks
# install cookbooks
$ bundle exec librarian-chef install
# create cookbooks artifact
$ bundle exec rake
# build the infrastructure stack
$ bundle exec sfn create my-sensu-infra --file sensu_infra
# update the stack (e.g. after changing template)
$ bundle exec sfn update my-sensu-infra --file sensu_infra
# destroy the stack
$ bundle exec sfn destroy my-sensu-infra
# print templates as json
$ bundle exec sfn print --file sensu
$ bundle exec sfn print --file elasticache
```
