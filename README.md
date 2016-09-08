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
# create cookbooks artifact and upload it to s3
$ bundle exec rake
# build the infrastructure stack
$ bundle exec sfn create my-sensu --file sensu
# update the stack (e.g. after changing template)
$ bundle exec sfn update my-sensu --file sensu
# destroy the stack
$ bundle exec sfn destroy my-sensu
# print template as json
$ bundle exec sfn print --file sensu
# update the cloudformation json template
$ bundle exec sfn print --file sensu > cloudformation/sensu.json
```

## Examples

Creating a new Sensu stack.

``` shell
$ bundle exec sfn create sensu-test-yellow --file sensu --defaults
[Sfn]: SparkleFormation: create
[Sfn]:   -> Name: sensu-test-yellow
[Sfn]: Stack runtime parameters: - template: sensu-test-yellow
[Sfn]: Creator: portertech
[Sfn]: Vpc Id: vpc-e7167c80
[Sfn]: Subnet Ids: subnet-3f929f15,subnet-f3c6cbab,subnet-e8dbcdd5,subnet-11bb4758
[Sfn]: Artifact Path: release-1473261173.zip
[Sfn]: Events for Stack: sensu-test-yellow
Time                      Resource Logical Id   Resource Status      Resource Status Reason
2016-09-07 19:13:50 UTC   sensu-test-yellow     CREATE_IN_PROGRESS   User Initiated
```

Updating the cookbooks artifact for an existing Sensu stack.

``` shell
$ bundle exec rake
Installing apt (2.9.2)
...
  adding: cookbooks/mingw/CONTRIBUTING.md (deflated 10%)
Successfully pushed latest release - release-1473275878.zip
$ bundle exec sfn update sensu-test-yellow --file sensu -R Sensu__ArtifactPath:release-1473275878.zip --defaults
[Sfn]: SparkleFormation: update
[Sfn]:   -> Name: sensu-test-purple Path: /home/portertech/projects/solodev/sensu/sparkleformation/sensu.rb
[Sfn]: Stack runtime parameters: - template: sensu-test-purple
[Sfn]: Pre-update resource planning report:

  Update plan for: sensu-test-purple
    No resource lifecycle changes detected!

[Sfn]: Apply this stack update? (Y/N): y
```

## Known issues

OpsWorks does not seem to guarantee unique hostnames, it sometimes
creates multiple instances within a layer with the same hostname. This
causes issues with RabbitMQ clustering and Sensu client configuration.
Provisioning another stack seems to be the easiest way to work around
the issue.
