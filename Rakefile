# frozen_string_literal: true

require "rake/testtask"
require "rubygems"
require "cucumber"
require "cucumber/rake/task"
require "mkmf"
require "fileutils"
require "google/cloud/storage"
require "encrypted/environment"
require "colorize"
require "highline"
require "tmpdir"
require "json"
require "zip"
require "macho"

desc("Builds, archives, and publishes tuist and tuistenv for release")
task :release, [:version] do |_task, options|
  decrypt_secrets
  release(options[:version])
end

desc("Publishes the installation scripts")
task :release_scripts do
  decrypt_secrets
  release_scripts
end

def release_scripts
  bucket = storage.bucket("tuist-releases")
  bucket.create_file("script/install", "scripts/install").acl.public!
  bucket.create_file("script/uninstall", "scripts/uninstall").acl.public!
end

def package
  FileUtils.mkdir_p("build")
  system("swift", "build", "--product", "tuist", "--configuration", "release")
  system(
    "swift", "build",
    "--product", "ProjectDescription",
    "--configuration", "release",
    "-Xswiftc", "-enable-library-evolution",
    "-Xswiftc", "-emit-module-interface",
    "-Xswiftc", "-emit-module-interface-path",
    "-Xswiftc", ".build/release/ProjectDescription.swiftinterface"
  )
  system(
    "swift", "build",
    "--product", "ProjectAutomation",
    "--configuration", "release",
    "-Xswiftc", "-enable-library-evolution",
    "-Xswiftc", "-emit-module-interface",
    "-Xswiftc", "-emit-module-interface-path",
    "-Xswiftc", ".build/release/ProjectAutomation.swiftinterface"
  )
  system("swift", "build", "--product", "tuistenv", "--configuration", "release")

  build_templates_path = File.join(__dir__, ".build/release/Templates")
  script_path = File.join(__dir__, ".build/release/script")
  vendor_path = File.join(__dir__, ".build/release/vendor")

  FileUtils.rm_rf(build_templates_path) if File.exist?(build_templates_path)
  FileUtils.cp_r(File.expand_path("Templates", __dir__), build_templates_path)
  FileUtils.rm_rf(script_path) if File.exist?(script_path)
  FileUtils.cp_r(File.expand_path("script", __dir__), script_path)
  FileUtils.cp_r(File.expand_path("projects/tuist/vendor", __dir__), vendor_path)

  File.delete("tuist.zip") if File.exist?("tuist.zip")
  File.delete("tuistenv.zip") if File.exist?("tuistenv.zip")

  Dir.chdir(".build/release") do
    system(
      "zip", "-q", "-r", "--symlinks",
      "tuist.zip", "tuist",
      "ProjectDescription.swiftmodule",
      "ProjectDescription.swiftdoc",
      "libProjectDescription.dylib",
      "ProjectDescription.swiftinterface",
      "ProjectAutomation.swiftmodule",
      "ProjectAutomation.swiftdoc",
      "libProjectAutomation.dylib",
      "ProjectAutomation.swiftinterface",
      "Templates",
      "vendor",
      "script"
    )
    system("zip", "-q", "-r", "--symlinks", "tuistenv.zip", "tuistenv")
  end

  FileUtils.cp(".build/release/tuist.zip", "build/tuist.zip")
  FileUtils.cp(".build/release/tuistenv.zip", "build/tuistenv.zip")
end

def release(version)
  if version.nil?
    version = cli.ask("Introduce the released version:")
  end

  puts "Releasing #{version} 🚀"

  package

  bucket = storage.bucket("tuist-releases")

  bucket.create_file("build/tuist.zip", "#{version}/tuist.zip").acl.public!
  bucket.create_file("build/tuistenv.zip", "#{version}/tuistenv.zip").acl.public!

  bucket.create_file("build/tuist.zip", "latest/tuist.zip").acl.public!
  bucket.create_file("build/tuistenv.zip", "latest/tuistenv.zip").acl.public!
  Dir.mktmpdir do |tmp_dir|
    version_path = File.join(tmp_dir, "version")
    File.write(version_path, version)
    bucket.create_file(version_path, "latest/version").acl.public!
  end
end

def system(*args)
  Kernel.system(*args) || abort
end

def cli
  @cli ||= HighLine.new
end

def storage
  @storage ||= Google::Cloud::Storage.new(
    project_id: ENV["GCS_PROJECT_ID"],
    credentials: {
      type: ENV["GCS_TYPE"],
      project_id: ENV["GCS_PROJECT_ID"],
      private_key_id: ENV["GCS_PRIVATE_KEY_ID"],
      private_key: ENV["GCS_PRIVATE_KEY"],
      client_email: ENV["GCS_CLIENT_EMAIL"],
      client_id: ENV["GCS_CLIENT_ID"],
      auth_uri: ENV["GCS_AUTH_URI"],
      token_uri: ENV["GCS_TOKEN_URI"],
      auth_provider_x509_cert_url: ENV["GCS_AUTH_PROVIDER_X509_CERT_URL"],
      client_x509_cert_url: ENV["GCS_CLIENT_X509_CERT_URL"],
    }
  )
end
