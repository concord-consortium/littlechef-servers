# Author:: Bryan W. Berry (<bryan.berry@gmail.com>)
# Apache 2.0 license
# Cookbook Name:: maven
# Attributes:: default

# wget http://www.apache.org/dist/maven/maven-3/3.0.5/binaries/apache-maven-3.0.5-bin.tar.gz
# echo -n apache-maven-3.0.5-bin.tar.gz | sha256

default['maven']['version'] = 2
default['maven']['m2_home'] = '/usr/local/maven/default'
default['maven']['2']['url'] = "http://www.apache.org/dist/maven/binaries/apache-maven-2.2.1-bin.tar.gz"
default['maven']['2']['checksum'] = "b9a36559486a862abfc7fb2064fd1429f20333caae95ac51215d06d72c02d376"
default['maven']['3']['url'] = 'http://www.apache.org/dist/maven/maven-3/3.0.5/binaries/apache-maven-3.0.5-bin.tar.gz'
default['maven']['3']['checksum'] =  "f8cf1144584ec48758f80a60491b14f5dda26bac9f0612f0c64f725a577ec319"

