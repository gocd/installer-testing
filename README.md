## Pre-Requisites

* Ruby
* Rake
* Docker

## Run test

Run this command to test latest experimental build on 4 environments - Ubuntu 14.04, Ubuntu 16.04, debian 8 and Centos7

```rake test_installers```

Run this command to test upgrade to latest experimental build from the list of older versions provided Centos7 - 

```UPGRADE_VERSIONS_LIST='X.x.x-<build_number>, ...' rake upgrade_tests``` 

## License

```plain
Copyright 2019 ThoughtWorks, Inc.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
```
