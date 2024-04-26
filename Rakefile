##########################################################################
# Copyright 2022 Thoughtworks, Inc.
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
UPGRADE_VERSIONS_LIST = ENV['UPGRADE_VERSIONS_LIST'] || '20.5.0-11820'

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
  attr_reader :name, :version, :task_name, :image_repo

  def initialize(name, version, task_name, image_repo = name)
    @name = name
    @version = version
    @task_name = task_name
    @random_string = SecureRandom.hex(3)
    @image_repo = image_repo
  end

  def image
    "#{image_repo || name}:#{version}"
  end

  def box_name
    "#{name}-#{version}-#{task_name}"
  end

  def container_name
    "#{name}-#{version}-#{task_name}-#{@random_string}"
  end

  def container_extra_run_args
    ""
  end

  def container_command
    "sleep 3600"
  end

  def <=>(other)
    box_name <=> other.box_name
  end

  def run_test(test_type = 'fresh', env = {})
    env_args = env.collect { |k, v| "'#{k}=#{v}'" }.join(' ')
    %(bash -lc "rake --trace --rakefile /configure/provision/Rakefile #{distro}:#{test_type} #{env_args}")
  end
end

class DebianLikeDistro < Distro
  def distro
    'debian'
  end

  def prepare_commands
    [
      "bash -lc 'rm -rf /etc/apt/apt.conf.d/docker-clean'",
      "bash -lc 'DEBIAN_FRONTEND=noninteractive apt-get update && apt-get install -y curl gnupg2'"
    ]
  end

  def install_build_tools
    [
      "bash -lc 'DEBIAN_FRONTEND=noninteractive apt-get install -y rake git curl'"
    ]
  end
end

class RedHatLikeDistro < Distro
  def distro
    'rhel'
  end

  def container_extra_run_args
    "--privileged"
  end

  def container_command
    "" # We'll use systemd/init system on RHEL
  end

  def prepare_commands
    [
      "bash -c 'echo fastestmirror=1 >> /etc/dnf/dnf.conf'",
      "bash -c 'echo install_weak_deps=False >> /etc/dnf/dnf.conf'",
      "bash -c 'echo metadata_timer_sync=0 >> /etc/dnf/dnf.conf'",
    ]
  end

  def install_build_tools
    [
      'dnf -y install git rubygem-rake rubygem-json',
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
    "#{pwd}/lib" => '/configure'
  }

  sh %(docker run #{mounts.collect { |k, v| "--volume #{k}:#{v}" }.join(' ')} --rm -d -it #{box.container_extra_run_args} --name #{box.container_name} #{box.image} #{box.container_command})

  box.prepare_commands.each do |each_command|
    sh "docker exec #{box.container_name} #{each_command}"
  end

  box.install_build_tools.each do |each_command|
    sh "docker exec #{box.container_name} #{each_command}"
  end
end

task :test_installers do |t|
  boxes = [
    DebianLikeDistro.new('ubuntu', '20.04', t.name),
    DebianLikeDistro.new('ubuntu', '22.04', t.name),
    DebianLikeDistro.new('ubuntu', '24.04', t.name),
    DebianLikeDistro.new('debian', '11', t.name),
    DebianLikeDistro.new('debian', '12', t.name),
    RedHatLikeDistro.new('almalinux', '8', t.name, 'almalinux/8-init'),
    RedHatLikeDistro.new('almalinux', '9', t.name, 'almalinux/9-init'),
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

task :upgrade_tests do |t|
  upgrade_boxes = [
    DebianLikeDistro.new('ubuntu', '20.04', t.name),
    DebianLikeDistro.new('ubuntu', '22.04', t.name),
    DebianLikeDistro.new('ubuntu', '24.04', t.name),
    DebianLikeDistro.new('debian', '11', t.name),
    DebianLikeDistro.new('debian', '12', t.name),
    RedHatLikeDistro.new('almalinux', '8', t.name, 'almalinux/8-init'),
    RedHatLikeDistro.new('almalinux', '9', t.name, 'almalinux/9-init'),
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

def full_version
  json = JSON.parse(URI.open(RELEASES_JSON_URL).read)
  json.select { |x| x['go_version'] == ENV['GO_VERSION'] }.sort_by { |a| a['go_build_number'].to_i }.last['go_full_version']
end
