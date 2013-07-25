#! /usr/bin/env ruby
require 'rubygems'
require 'couchrest'
require 'cgi'
require 'json'
require 'net/http'
require 'yaml'
require 'axlsx'
require 'csv'


@db = CouchRest.database("http://ceshhar.coconutclinic.org/coconut")

data = {}

puts "Retrieving case IDs"
keys = @db.view('coconut/clients', {
    :include_docs => false
  }
)['rows'].map{|client| 
    if client["key"].match(/\p{Lower}/)
      puts "#{client["key"]} - #{client["id"]}"
      client["id"]
    end
}.compact

puts keys.length
docs = @db.bulk_load(keys)
fixed_docs = docs["rows"].map{|doc|
  puts doc
  doc["doc"]["IDLabel"].upcase!
  doc["doc"]
}
puts fixed_docs.to_yaml
puts @db.bulk_save(fixed_docs)


