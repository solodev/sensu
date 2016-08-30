require "fileutils"

ASSET_DIR = ENV.fetch("ASSET_DIR", "tmp/assets")

FileUtils.mkdir_p(ASSET_DIR) unless File.exists?(ASSET_DIR)

def run_command(command)
  system(command) || exit(2)
end

task :create_release do
  run_command("zip -r #{ASSET_DIR}/release-#{Time.now.to_i}.zip cookbooks")
end

task :push_latest_release do
  # no-op
end

task :publish => [:create_release, :push_latest_release]

task :default => :create_release
