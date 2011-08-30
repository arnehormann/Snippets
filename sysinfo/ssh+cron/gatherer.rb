#!/usr/bin/env ruby
require 'date'
require 'rubygems'
require 'json'

def as_string(arg)
  arg = arg.flatten.first if arg.class == Array
  arg
end

ips = JSON.parse(IO.read(ARGV[0] || 'servers.json'))

today = Date.today.to_s
result = {}
ips.each do |k,v|
  begin
    result[k] = `ssh root@#{v} -m command.sh`.split('######').inject({}) do |akku, elem|
      elem = (elem || '').strip
      unless elem.empty?
        entries = elem.split('####').collect do |s|
          s.strip.split(/[\r\n]+/).collect{|line| line.strip }
        end
        key, value = entries
        (akku[as_string(key)] ||= {})[as_string(value[0])] = value[1..value.length].flatten
      end
      akku
    end
  rescue Exception => e
    warn "broken (#{e}) for #{k} (#{v}) on #{today}"
  end
end
puts JSON.generate(result)