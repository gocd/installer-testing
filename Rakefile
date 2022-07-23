##########################################################################
# Copyright 2018 ThoughtWorks, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
##########################################################################

$stdout.sync = true
$stderr.sync = true

require 'json'
require 'timeout'
require 'fileutils'
require 'open-uri'
require 'logger'
require 'securerandom'

RELEASES_JSON_URL = ENV['RELEASES_JSON_URL'] || 'https://download.go.cd/experimental/releases.json'
STABLE_RELEASES_JSON_URL = ENV['STABLE_RELEASES_JSON_URL'] || 'https://download.go.cd/releases.json'
UPGRADE_VERSIONS_LIST = ENV['UPGRADE_VERSIONS_LIST'] || '16.9.0-4001, 16.12.0-4352, 17.1.0-4511'

def partition(things)
  things = (things || []).sort
  total_workers = ENV['GO_JOB_RUN_COUNT'] ? ENV['GO_JOB_RUN_COUNT'].to_i : 1
  current_worker_index = ENV['GO_JOB_RUN_INDEX'] ? ENV['GO_JOB_RUN_INDEX'].to_i : 1

  return [] if things.empty?

  result = []

  until things.empty?
    (1..total_workers).each do |worker_index|
      thing = things.pop
      result.push(thing) if worker_index == current_worker_index
    end
  end

  result.compact
end

class Distro
  attr_reader :name, :version, :task_name

  def initialize(name, version, task_name)
    @name = name
    @version = version
    @task_name = task_name
    @random_string = SecureRandom.hex(3)
  end

  def image
    "#{name}:#{version}"
  end

  def box_name
    "#{name}-#{version}-#{task_name}"
  end

  def container_name
    "#{name}-#{version}-#{task_name}-#{@random_string}"
  end

  def <=>(other)
    box_name <=> other.box_name
  end

  def run_test(test_type = 'fresh', env = {})
    env_args = env.collect { |k, v| "'#{k}=#{v}'" }.join(' ')
    %(bash -lc "rake --trace --rakefile /vagrant/provision/Rakefile #{distro}:#{test_type} #{env_args}")
  end
end

class DebianDistro < Distro
  def distro
    'debian'
  end

  def cache_dirs
    ['/var/cache/apt/archives', '/var/lib/apt/lists']
  end

  def prepare_commands
    [
      "bash -lc 'rm -rf /etc/apt/apt.conf.d/docker-clean'",
      'apt-get update',
      'apt-get install -y apt-transport-https curl gnupg2'
    ]
  end

  def install_jdk
    [
      'apt-get install -y openjdk-11-jre-headless'
    ]
  end

  def install_build_tools
    [
      'apt-get install -y rake ruby-json unzip git curl'
    ]
  end
end

class UbuntuDistro < DebianDistro

end

class CentosDistro < Distro
  def distro
    'centos'
  end

  def cache_dirs
    ['/var/cache/yum']
  end

  def prepare_commands
    [
      'yum makecache'
    ]
  end

  def install_jdk
    [
      'yum -y install java-11-openjdk'
    ]
  end

  def install_build_tools
    [
      "yum -y install initscripts sysvinit-tools",
      "yum -y install unzip git rubygem-rake",
    ]
  end
end

def boot_container(box)
  pwd = File.dirname(__FILE__)

  sh "docker stop #{box.container_name}" do |_ok, _res|
    puts "box #{box.container_name} does not exist, ignoring!"
  end

  sh "docker rm #{box.container_name}" do |_ok, _res|
    puts "box #{box.container_name} does not exist, ignoring!"
  end

  sh "docker pull #{box.image}"

  mounts = {
    "#{pwd}/lib" => '/vagrant'
  }

  box.cache_dirs.each do |cache_dir|
    host_dir = File.expand_path("~/.gocd-installer-testing/cache/#{box.box_name}/#{cache_dir}")
    mkdir_p host_dir
    mounts[host_dir] = cache_dir
  end

  sh %(docker run #{mounts.collect { |k, v| "--volume #{k}:#{v}" }.join(' ')} --rm -d -it --name #{box.container_name} #{box.image} sleep 3600)

  box.prepare_commands.each do |each_command|
    sh "docker exec #{box.container_name} #{each_command}"
  end

  box.install_jdk.each do |each_command|
    sh "docker exec #{box.container_name} #{each_command}"
  end

  box.install_build_tools.each do |each_command|
    sh "docker exec #{box.container_name} #{each_command}"
  end
end

task :test_installers do |t|
  boxes = [
      UbuntuDistro.new('ubuntu', '20.04', t.name),
      UbuntuDistro.new('ubuntu', '22.04', t.name),
      DebianDistro.new('debian', '11', t.name),
      CentosDistro.new('centos', '7', t.name),
  ]

  partition(boxes).each do |box|
    boot_container(box)
    begin
      env = { GO_VERSION: full_version }
      sh "docker exec #{box.container_name} #{box.run_test('fresh', env)}"
    rescue StandardError => e
      raise "Installer testing failed. Error message #{e.message} #{e.backtrace.join("\n")}"
    ensure
      sh "docker stop #{box.container_name}"
    end
  end
end

task :test_installers_w_postgres do |t|
  postgres_boxes = [
      #UbuntuDistro.new('ubuntu', '16.04', t.name),
      CentosDistro.new('centos', '7', t.name),
  ]

  partition(postgres_boxes).each do |box|
    boot_container(box)
    begin
      env = { GO_VERSION: full_version, USE_POSTGRES: true }
      sh "docker exec #{box.container_name} #{box.run_test('fresh', env)}"
    rescue StandardError => e
      raise "Installer testing failed. Error message #{e.message} #{e.backtrace.join("\n")}"
    ensure
      sh "docker stop #{box.container_name}"
    end
  end
end

task :upgrade_tests do |t|
  upgrade_boxes = [
    UbuntuDistro.new('ubuntu', '20.04', t.name),
    UbuntuDistro.new('ubuntu', '22.04', t.name),
    DebianDistro.new('debian', '11', t.name),
    CentosDistro.new('centos', '7', t.name)
  ]

  partition(upgrade_boxes).each do |box|
    UPGRADE_VERSIONS_LIST.split(/\s*,\s*/).each do |from_version|
      boot_container(box)
      begin
        env = { GO_VERSION: full_version, UPGRADE_VERSIONS_LIST: from_version }
        sh "docker exec #{box.container_name} #{box.run_test('upgrade_test', env)}"
      rescue StandardError => e
        raise "Installer testing failed. Error message #{e.message} #{e.backtrace.join("\n")}"
      ensure
        sh "docker rm -f #{box.container_name}"
      end
    end
  end
end

task :upgrade_tests_w_postgres do |t|
  download_addons
  postgres_upgrade_boxes = [
      #UbuntuDistro.new('ubuntu', '14.04', t.name),
      CentosDistro.new('centos', '7', t.name),
  ]
  partition(postgres_upgrade_boxes).each do |box|
    UPGRADE_VERSIONS_LIST.split(/\s*,\s*/).each do |from_version|
      boot_container(box)
      begin
        env = { GO_VERSION: full_version, UPGRADE_VERSIONS_LIST: from_version, USE_POSTGRES: true }
        sh "docker exec #{box.container_name} #{box.run_test('upgrade_test', env)}"
      rescue StandardError => e
        raise "Installer testing failed. Error message #{e.message} #{e.backtrace.join("\n")}"
      ensure
        sh "docker rm -f #{box.container_name}"
      end
    end
  end
end

task :verify_osx_signer do
  sh "curl -L -o go-server-#{full_version}-osx.zip --fail  https://download.gocd.org/experimental/binaries/#{full_version}/osx/go-server-#{full_version}-osx.zip"
  sh "unzip go-server-#{full_version}-osx.zip"
  sh 'codesign --verify --verbose Go\\ Server.app'
end

def download_addons
  json = JSON.parse(URI.open(STABLE_RELEASES_JSON_URL).read)
  myhash = json.sort_by { |a| a['go_full_version'] }.reverse
  myhash.each_with_index do |key, index|
    next unless UPGRADE_VERSIONS_LIST.include? myhash[index]['go_full_version']
    addon = addon_for(key['go_full_version'])
    unless File.exist?("addons/#{addon}")
      sh "curl -L -o lib/addons/#{addon} --fail -H 'Accept: binary/octet-stream' --user '#{ENV['EXTENSIONS_USER']}:#{ENV['EXTENSIONS_PASSWORD']}'  #{ENV['ADDON_DOWNLOAD_URL']}/#{key['go_full_version']}/download?eula_accepted=true"
    end
  end
end

def full_version
  json = JSON.parse(URI.open(RELEASES_JSON_URL).read)
  json.select { |x| x['go_version'] == ENV['GO_VERSION'] }.sort_by { |a| a['go_build_number'].to_i }.last['go_full_version']
end

def addon_for(core)
  versions_map = JSON.parse(File.read('./lib/addons/addon_builds.json'))
  versions_map.select { |v| v['gocd_version'] == core }.last['addons']['postgresql']
end
