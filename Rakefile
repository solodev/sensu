require "fileutils"
require "miasma"

ASSET_DIR = ENV.fetch("ASSET_DIR", "tmp/assets")
S3_BUCKET = ENV.fetch("S3_BUCKET", "solodev-sensu-opsworks")
SENSU_DIRECTORY = File.join(ASSET_DIR, "sensu")

FileUtils.mkdir_p(ASSET_DIR) unless File.exists?(ASSET_DIR)

def run_command(command)
  system(command) || exit(2)
end

def push_file_to_s3(file)
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

    remote_file = Miasma::Models::Storage::File.new(directory)
    remote_file.name = file
    remote_file.body = File.open(file, "r")
    remote_file.save
  end
end

desc "creates a release (zip) of the cookbooks directory"
task :create_release do
  run_command("rm -f .librarian/chef/config")
  run_command("bundle exec librarian-chef install")
  release_path = "#{ASSET_DIR}/release-#{Time.now.to_i}.zip"
  run_command("zip -r #{release_path} cookbooks")
end

desc "pushes the latest release to S3"
task :push_latest_release do
  Dir.chdir(ASSET_DIR) do
    release_file = Dir.glob("release-*.zip").max_by do |file|
      File.mtime(file)
    end

    push_file_to_s3(release_file)
    puts "Successfully pushed latest release - #{release_file}"
  end
end

desc "creates ssl keys & certs for rabbitmq/sensu"
task :create_ssl do
  ssl_directory = File.join(SENSU_DIRECTORY, "ssl")

  %w[ca client server certs console].each do |sub_directory|
    FileUtils.mkdir_p(File.join(ssl_directory, sub_directory))
  end

  ssl_files = {
    :index => "index.txt",
    :serial => "serial",
    :ca_key => File.join("ca", "ca-key.pem"),
    :ca_cert => File.join("ca", "ca-cert.pem"),
    :ca_csr => File.join("ca", "ca.cer"),
    :client_cert => File.join("client", "cert.pem"),
    :client_key => File.join("client", "key.pem"),
    :client_csr => File.join("client", "csr.pem"),
    :server_cert => File.join("server", "cert.pem"),
    :server_key => File.join("server", "key.pem"),
    :server_csr => File.join("server", "csr.pem"),
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
    else
      puts "[skipping] ca key and certificate already exist"
    end

    # generate server key & certificate
    unless [:server_key, :server_cert].all? { |file| File.exists?(ssl_files[file]) }
      system("openssl genrsa -out #{ssl_files[:server_key]} 2048")
      system("openssl req -new -key #{ssl_files[:server_key]} -out #{ssl_files[:server_csr]} -subj /CN=sensu/O=server/ -nodes")
      system("openssl ca -config openssl.cnf -in #{ssl_files[:server_csr]} -out #{ssl_files[:server_cert]} -notext -batch -extensions server_ca_extensions")
    else
      puts "[skipping] server key and certificate already exist"
    end

    # generate client key & certificate
    unless [:client_key, :client_cert].all? { |file| File.exists?(ssl_files[file]) }
      system("openssl genrsa -out #{ssl_files[:client_key]} 2048")
      system("openssl req -new -key #{ssl_files[:client_key]} -out #{ssl_files[:client_csr]} -subj /CN=sensu/O=client/ -nodes")
      system("openssl ca -config openssl.cnf -in #{ssl_files[:client_csr]} -out #{ssl_files[:client_cert]} -notext -batch -extensions client_ca_extensions")
    else
      puts "[skipping] client key and certificate already exist"
    end
  end
end

desc "pushes ssl keys & certs to S3"
task :push_ssl do
  Dir.chdir(ASSET_DIR) do
    Dir.glob("sensu/ssl/**/*").each do |file|
      unless File.directory?(file)
        push_file_to_s3(file)
        puts "Successfully pushed #{file} to S3"
      end
    end
  end
end

desc "creates the dashboard private/public keypair"
task :create_dashboard_keypair do
  dashboard_directory = File.join(SENSU_DIRECTORY, "dashboard")

  FileUtils.mkdir_p(dashboard_directory)

  Dir.chdir(dashboard_directory) do
    unless [:private, :public].all? { |file| File.exists?("#{file}.pem") }
      system("openssl genrsa -out private.pem 2048")
      system("openssl rsa -in private.pem -pubout > public.pem")
    else
      puts "[skipping] keypair files for dashboard already exist"
    end
  end
end

desc "pushes the dashboard private/public keys to S3"
task :push_dashboard_keypair do
  Dir.chdir(ASSET_DIR) do
    Dir.glob("sensu/dashboard/*").each do |file|
      push_file_to_s3(file)
      puts "Successfully pushed #{file} to S3"
    end
  end
end

desc "creates the secrets file for use with chef"
task :create_secrets do
  secrets_file = File.join(ASSET_DIR, "secrets.json")
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

desc "pushes the secrets file to S3"
task :push_secrets do
  Dir.chdir(ASSET_DIR) do
    push_file_to_s3("secrets.json")
    puts "Successfully pushed secrets.json to S3"
  end
end

desc "creates and pushes a new release"
task :default => [:create_release, :push_latest_release]
