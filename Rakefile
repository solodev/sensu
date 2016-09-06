require "fileutils"
require "miasma"

ASSET_DIR = ENV.fetch("ASSET_DIR", "tmp/assets")
S3_BUCKET = ENV.fetch("S3_BUCKET", "solodev-sensu-opsworks")

FileUtils.mkdir_p(ASSET_DIR) unless File.exists?(ASSET_DIR)

def run_command(command)
  system(command) || exit(2)
end

task :create_release do
  run_command("rm -f .librarian/chef/config")
  run_command("bundle exec librarian-chef install")
  release_path = "#{ASSET_DIR}/release-#{Time.now.to_i}.zip"
  run_command("zip -r #{release_path} cookbooks")
end

task :push_latest_release do
  region = ENV.fetch("AWS_REGION", "us-east-1")
  bucket_region = ENV.fetch("AWS_BUCKET_REGION", region)

  remote_creds = {
    :provider => :aws,
    :credentials => {
      :aws_access_key_id => ENV["AWS_ACCESS_KEY_ID"],
      :aws_secret_access_key => ENV["AWS_SECRET_ACCESS_KEY"],
      :aws_region => region,
      :aws_bucket_region => bucket_region,
      :aws_sts_role_arn => ENV["AWS_STS_ROLE_ARN"],
      :aws_sts_external_id => ENV["AWS_STS_EXTERNAL_ID"]
    }
  }.delete_if { |key, value| value.nil? }

  begin
    remote = Miasma.api(
      :provider => remote_creds[:provider].to_s.downcase,
      :type => "storage",
      :credentials => remote_creds[:credentials]
      )

    directory = remote.buckets.get(S3_BUCKET)

    release_file = Dir.glob("#{ASSET_DIR}/release-*.zip").max_by do |file|
      File.mtime(file)
    end

    remote_file = Miasma::Models::Storage::File.new(directory)
    remote_file.name = release_file.split("/").last
    remote_file.body = File.open(release_file, "r")
    remote_file.save

    puts "Successfully pushed latest release - #{release_file}"
  end
end

task :create_ssl do
  ssl_directory = ".ssl"
  cert_name = "sensu-rabbitmq"

  %w[ca client server certs console].each do |sub_directory|
    FileUtils.mkdir_p(File.join(ssl_directory, sub_directory))
  end

  ssl_files = {
    :index => "index.txt",
    :serial => "serial",
    :ca_key => File.join("ca", "ca-key.pem"),
    :ca_cert => File.join("ca", "ca-cert.pem"),
    :ca_csr => File.join("ca", "ca.cer"),
    :client_cert => File.join("client", "#{cert_name}-cert.pem"),
    :client_key => File.join("client", "#{cert_name}-key.pem"),
    :client_csr => File.join("client", "#{cert_name}-csr.pem"),
    :server_cert => File.join("server", "#{cert_name}-cert.pem"),
    :server_key => File.join("server", "#{cert_name}-key.pem"),
    :server_csr => File.join("server", "#{cert_name}-csr.pem"),
    :console_private_key => File.join("console", "private.pem"),
    :console_public_key => File.join("console", "public.pem"),
  }

  Dir.chdir(ssl_directory) do
    FileUtils.touch(ssl_files[:index]) unless File.exists?(ssl_files[:index])

    unless File.exists?(ssl_files[:serial])
      File.open(ssl_files[:serial], "w") do |file|
        file.write("01")
      end
    end

    # generate a new self-signed CA key & certificate
    unless [:ca_key, :ca_cert].all? { |file| File.exists?(ssl_files[file]) }
      system("openssl req -x509 -config openssl.cnf -days 1825 -subj /CN=SensuCA/ -nodes -newkey rsa:2048 -keyout #{ssl_files[:ca_key]} -out #{ssl_files[:ca_cert]}")
    end

    # generate server key & certificate
    unless [:server_key, :server_cert].all? { |file| File.exists?(ssl_files[file]) }
      system("openssl genrsa -out #{ssl_files[:server_key]} 2048")
      system("openssl req -new -key #{ssl_files[:server_key]} -out #{ssl_files[:server_csr]} -subj /CN=sensu/O=server/ -nodes")
      system("openssl ca -config openssl.cnf -in #{ssl_files[:server_csr]} -out #{ssl_files[:server_cert]} -notext -batch -extensions server_ca_extensions")
    end

    # generate client key & certificate
    unless [:client_key, :client_cert].all? { |file| File.exists?(ssl_files[file]) }
      system("openssl genrsa -out #{ssl_files[:client_key]} 2048")
      system("openssl req -new -key #{ssl_files[:client_key]} -out #{ssl_files[:client_csr]} -subj /CN=sensu/O=client/ -nodes")
      system("openssl ca -config openssl.cnf -in #{ssl_files[:client_csr]} -out #{ssl_files[:client_cert]} -notext -batch -extensions client_ca_extensions")
    end

    # generate private & public keys for sensu enterprise console
    unless [:console_private_key, :console_public_key].all? { |file| File.exists?(ssl_files[file]) }
      system("openssl genrsa -out #{ssl_files[:console_private_key]} 2048")
      system("openssl rsa -in #{ssl_files[:console_private_key]} -pubout > #{ssl_files[:console_public_key]}")
    end
  end
end

task :create_secrets do
  secrets_directory = ".secrets"
  FileUtils.mkdir_p(secrets_directory)
  secrets_file = File.join(secrets_directory, "secrets.json")
  secrets = {
    :sensu => {
      :enterprise => {
        :repository => {
          :credentials => {
            :user => ENV["SE_USER"],
            :password => ENV["SE_PASS"]
          }
        }
      }
    },
    :influxdb => {
      :username => ENV["INFLUXDB_USER"],
      :password => ENV["INFLUXDB_PASS"]
    }
  }
  File.open(secrets_file, "w") do |file|
    file.write(JSON.pretty_generate(secrets))
  end
end

task :default => [:create_release, :push_latest_release]
