##########################################################################
# Copyright 2017 ThoughtWorks, Inc.
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

require 'json'
require 'timeout'
require 'fileutils'
require 'open-uri'
require 'logger'

RELEASES_JSON_URL = ENV['RELEASES_JSON_URL'] || 'https://download.go.cd/experimental/releases.json'
STABLE_RELEASES_JSON_URL = ENV['STABLE_RELEASES_JSON_URL'] || 'https://download.go.cd/releases.json'
UPGRADE_VERSIONS_LIST = ENV['UPGRADE_VERSIONS_LIST'] || "16.9.0-4001, 16.12.0-4352, 17.1.0-4511"

def partition(things)
  things               = (things || []).sort
  total_workers        = ENV['GO_JOB_RUN_COUNT'] ? ENV['GO_JOB_RUN_COUNT'].to_i : 1
  current_worker_index = ENV['GO_JOB_RUN_INDEX'] ? ENV['GO_JOB_RUN_INDEX'].to_i : 1

  return [] if things.empty?

  result = []

  until things.empty? do
    (1..total_workers).each do |worker_index|
      thing = things.pop
      if worker_index == current_worker_index
        result.push(thing)
      end
    end
  end

  result.compact
end

task :test_installers do
  distributions = ['debian-8', 'debian-9', 'ubuntu-12.04', 'ubuntu-14.04', 'ubuntu-16.04', 'centos-6', 'centos-7']
  partition(distributions).each do |box|
    begin      
      sh "GO_VERSION=#{full_version} vagrant up #{box} --provider #{ENV['PROVIDER'] || 'virtualbox'} --provision --no-parallel"
    rescue => e
      raise "Installer testing failed. Error message #{e.message}"
    ensure
      sh "vagrant destroy #{box} --force"
  end
  end
end

task :test_installers_w_postgres do
  distributions = ['ubuntu-14.04', 'centos-7']
  partition(distributions).each do |box|
    begin
      sh "GO_VERSION=#{full_version} USE_POSTGRES=yes vagrant up #{box} --provider #{ENV['PROVIDER'] || 'virtualbox'} --provision"
    rescue => e
      raise "Installer testing failed. Error message #{e.message}"
    ensure
      sh "vagrant destroy #{box} --force"
    end
  end
end


task :upgrade_tests do
  distributions = ['debian-8', 'ubuntu-12.04', 'ubuntu-14.04', 'ubuntu-16.04', 'centos-7']
  partition(distributions).each do |box|
    UPGRADE_VERSIONS_LIST.split(/\s*,\s*/).each do |from_version|
      begin
        sh "GO_VERSION=#{full_version} TEST=upgrade_test UPGRADE_VERSIONS_LIST=#{from_version} vagrant up #{box} --provider #{ENV['PROVIDER'] || 'virtualbox'} --provision --no-parallel"
      rescue => e
        raise "Installer testing failed. Error message #{e.message}"
      ensure
        sh "vagrant destroy #{box} --force"
      end
    end
  end
end

task :upgrade_tests_w_postgres do
  download_addons
  distributions = ['ubuntu-14.04', 'centos-7']
  partition(distributions).each do |box|
      UPGRADE_VERSIONS_LIST.split(/\s*,\s*/).each do |from_version|
        begin
          sh "GO_VERSION=#{full_version} TEST=upgrade_test UPGRADE_VERSIONS_LIST=#{from_version} USE_POSTGRES=yes vagrant up #{box} --provider #{ENV['PROVIDER'] || 'virtualbox'} --provision"
        rescue => e
          raise "Installer testing failed. Error message #{e.message}"
        ensure
          sh "vagrant destroy #{box} --force"
        end
      end
  end
end

def download_addons
  json = JSON.parse(open(STABLE_RELEASES_JSON_URL).read)
  myhash = json.sort {|a, b| a['go_full_version'] <=> b['go_full_version']}.reverse
  myhash.each_with_index do |key, index|
    if UPGRADE_VERSIONS_LIST.include? myhash[index]['go_full_version']
      addon = addon_for(key['go_full_version'])
      if (!File.exists?("addons/#{addon}"))
        sh "curl -L -o lib/addons/#{addon} --fail -H 'Accept: binary/octet-stream' --user '#{ENV['EXTENSIONS_USER']}:#{ENV['EXTENSIONS_PASSWORD']}'  #{ENV['ADDON_DOWNLOAD_URL']}/#{key['go_full_version']}/download?eula_accepted=true"
      end
    end
  end
end

def full_version
  json = JSON.parse(open(RELEASES_JSON_URL).read)
  json.select {|x| x['go_version'] == ENV['GO_VERSION']}.sort {|a, b| a['go_build_number'] <=> b['go_build_number']}.last['go_full_version']
end

def addon_for(core)
  versions_map = JSON.parse(File.read('./lib/addons/addon_builds.json'))
  versions_map.select{|v| v['gocd_version'] == core}.last['addons']['postgresql']
end
