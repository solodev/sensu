# Citadel Cookbook

[![Build Status](https://img.shields.io/travis/poise/citadel.svg)](https://travis-ci.org/poise/citadel)
[![Gem Version](https://img.shields.io/gem/v/poise-citadel.svg)](https://rubygems.org/gems/poise-citadel)
[![Cookbook Version](https://img.shields.io/cookbook/v/citadel.svg)](https://supermarket.chef.io/cookbooks/citadel)
[![Coverage](https://img.shields.io/codecov/c/github/poise/citadel.svg)](https://codecov.io/github/poise/citadel)
[![Gemnasium](https://img.shields.io/gemnasium/poise/citadel.svg)](https://gemnasium.com/poise/citadel)
[![License](https://img.shields.io/badge/license-Apache_2-blue.svg)](https://www.apache.org/licenses/LICENSE-2.0)

Using a combination of IAM roles, S3 buckets, and EC2 it is possible to use AWS
as a trusted-third-party for distributing secret or otherwise sensitive data.

## Overview

IAM roles allow specifying snippets of IAM policies in a way that can be used
from an EC2 virtual machine. Combined with a private S3 bucket, this can be
used to authorize specific hosts to specific files.

IAM Roles can be created [in the AWS Console](https://console.aws.amazon.com/iam/home#roles).
While the policies applied to a role can be changed later, the name cannot so
be careful when choosing them.

## Requirements

This cookbook requires Chef 12 or newer. It also requires the EC2 ohai plugin
to be active. If you are using a VPC, this may require setting the hint file
depending on your version of Ohai/Chef:

```bash
$ mkdir -p /etc/chef/ohai/hints
$ touch /etc/chef/ohai/hints/ec2.json
```

If you use knife-ec2 to start the instance, the hint file is already set for you.

## IAM Policy

By default, your role will not be able to access any files in your private S3
bucket. You can create IAM policies that whitelist specific keys for each role:

```json
{
  "Version": "2008-10-17",
  "Id": "<policy name>",
  "Statement": [
    {
      "Sid": "<statement name>",
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::<AWS account number>:role/<role name>"
      },
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::<bucket name>/<key pattern>"
    }
  ]
}
```

The key pattern can include `*` and `?` metacharacters, so for example
`arn:aws:s3:::myapp.citadel/deploy_keys/*` to allow access to all files in the
`deploy_keys` folder.

This policy can be attached to either the IAM role or the S3 bucket with equal
effect.

## Limitations

Each EC2 VM can only be assigned a single IAM role. This can complicate situations
where some secrets need to be shared by overlapping subsets of your servers. A
possible improvement to this would be to make a script to create all needed
composite IAM roles, possibly driven by Chef roles or other metadata.

## Attributes

* `node['citadel']['bucket']` – The default S3 bucket to use.

## Recipe Usage

You can access secret data via the `citadel` method.

```ruby
file '/etc/secret' do
  owner 'root'
  group 'root'
  mode '600'
  content citadel['keys/secret.pem']
end
```

By default the node attribute `node['citadel']['bucket']` is used to find the
S3 bucket to query, however you can override this:

```ruby
template '/etc/secret' do
  owner 'root'
  group 'root'
  mode '600'
  variables secret: citadel('mybucket')['id_rsa']
end
```

## Developing with Vagrant

While developing in a local VM, you can use the node attributes
`node['citadel']['access_key_id']` and `node['citadel']['secret_access_key']`
to provide credentials. The recommended way to do this is via environment variables
so that the Vagrantfile itself can still be kept in source control without
leaking credentials:

```ruby
config.vm.provision :chef_solo do |chef|
  chef.json = {
    citadel: {
      access_key_id: ENV['ACCESS_KEY_ID'],
      secret_access_key: ENV['SECRET_ACCESS_KEY'],
    },
  }
end
```

**WARNING:** Use of these attributes in production should be considered a likely
security risk as they will end up visible in the node data, or in the role/environment/cookbook
that sets them. This can be mitigated using Enterprise Chef ACLs, however such
configurations are generally error-prone due to the defaults being wide open.

### Testing with Test-Kitchen

Similarly you can use the same attributes with Test-Kitchen

```yaml
provisioner:
  name: chef_solo
  attributes:
    citadel:
      access_key_id: <%= ENV['AWS_ACCESS_KEY_ID'] %>
      secret_access_key: <%= ENV['AWS_SECRET_ACCESS_KEY'] %>
```

## Recommended S3 Layout

Within your S3 bucket I recommend you create one folder for each group of
secrets, and in your IAM policies have one statement per group. Each group of
secrets is a set of data with identical security requirements. Many groups will
start out only containing a single file, however having the flexibility to
change this in the future allows for things like key rotation without rewriting
all of your IAM policies.

An example of an IAM policy resource would be:

```
"Resource": "arn:aws:s3:::mybucket/myfolder/*"
```

## Creating and Updating Secrets

You can use any S3 client you prefer to manage your secrets, however make sure
that new files are set to private (accessible only to the creating user) by
default.

## Sponsors

The Poise test server infrastructure is sponsored by [Rackspace](https://rackspace.com/).

## License

Copyright 2013-2016, Balanced, Inc.
Copyright 2016, Noah Kantrowitz

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
