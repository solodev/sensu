require "fileutils"

ASSET_DIR = ENV.fetch("ASSET_DIR", "tmp/assets")

FileUtils.mkdir_p(ASSET_DIR) unless File.exists?(ASSET_DIR)

def run_command(command)
  system(command) || exit(2)
end

task :create_release do
  run_command("rm -f .librarian/chef/config")
  run_command("bundle exec librarian-chef install")
  artifact = "release-#{Time.now.to_i}.zip"
  release_path = "#{ASSET_DIR}/#{artifact}"
  run_command("zip -r #{release_path} cookbooks")
  run_command("aws s3 cp #{release_path} s3://$NESTING_BUCKET/#{artifact}")
end

task :push_latest_release do
  # no-op
end

task :create_ssl do
  ssl_directory = ".ssl"
  cert_name = "sensu-rabbitmq"

  %w[ca client server certs].each do |sub_directory|
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
  }

  Dir.chdir(ssl_directory) do
    FileUtils.touch(ssl_files[:index]) unless File.exists?(ssl_files[:index])

    unless File.exists?(ssl_files[:serial])
      File.open(ssl_files[:serial], "w") do |file|
        file.write("01")
      end
    end

    # generate a new self-signed CA key & certificate
    unless File.exists?(ssl_files[:ca_key]) && File.exists?(ssl_files[:ca_cert])
      system("openssl req -x509 -config openssl.cnf -days 1825 -subj /CN=SensuCA/ -nodes -newkey rsa:2048 -keyout #{ssl_files[:ca_key]} -out #{ssl_files[:ca_cert]}")
    end

    # generate server key & certificate
    unless File.exists?(ssl_files[:server_key]) && File.exists?(ssl_files[:server_cert])
      system("openssl genrsa -out #{ssl_files[:server_key]} 2048")
      system("openssl req -new -key #{ssl_files[:server_key]} -out #{ssl_files[:server_csr]} -subj /CN=sensu/O=server/ -nodes")
      system("openssl ca -config openssl.cnf -in #{ssl_files[:server_csr]} -out #{ssl_files[:server_cert]} -notext -batch -extensions server_ca_extensions")
    end

    # generate client key & certificate
    unless File.exists?(ssl_files[:client_key]) && File.exists?(ssl_files[:client_cert])
      system("openssl genrsa -out #{ssl_files[:client_key]} 2048")
      system("openssl req -new -key #{ssl_files[:client_key]} -out #{ssl_files[:client_csr]} -subj /CN=sensu/O=client/ -nodes")
      system("openssl ca -config openssl.cnf -in #{ssl_files[:client_csr]} -out #{ssl_files[:client_cert]} -notext -batch -extensions client_ca_extensions")
    end
  end
end

task :publish => [:create_release, :push_latest_release]

task :default => :create_release
