#!/usr/bin/env ruby
$KCODE = 'u'

require 'date'

def retain_by_policy(policy = {:days => 5, :weeks => 4, :months => 6, :years => 10}, ref_date = Date.today())
  defaults = {:days => 0, :weeks => 0, :months => 0, :years => 0}
  ref_week = ref_date + (7 - ref_date.wday)
  ref_month = (ref_date - (ref_date.mday - 1)) >> 1
  ref_year = (ref_date >> 12) - ref_date.yday
  [(1..(policy[:days]  || defaults[:days]  )).collect{ |d| ref_date - (d - 1) },
   (1..(policy[:weeks] || defaults[:weeks] )).collect{ |w| ref_week - (7 * w) },
   (1..(policy[:months]|| defaults[:months])).collect{ |m| (ref_month << m) - 1 },
   (1..(policy[:years] || defaults[:years] )).collect{ |y| ref_year << (12 * y) },
  ].flatten.uniq.sort.reverse
end

def dates_to_folders(files, dates)
  available = files.sort.inject({}) do |akku, val|
    (akku[Date.parse(val[/\d{4}-\d{2}-\d{2}/])] ||= []) << val
    akku
  end
  deprecated_dates = (available.keys.flatten - dates)
  results = []
  available.each do |k, v|
    results << v if deprecated_dates.include? k
  end
  results.flatten.sort
end

def quoted_join(array, quote="'")
  array.empty? ? '' : "#{quote}#{array.join("#{quote} #{quote}")}#{quote}"
end

def args_to_map(arguments, valid_keys = nil)
  arguments.inject({}) do |akku, v|
    begin
      args = v.split('=', 2)
      if valid_keys.include? args[0]
        akku[args[0].to_sym] = args[1]
      end
    rescue
    end
    akku
  end
end

if __FILE__ == $0
  if ARGV.empty? || %w(help -h --help).inject(false){ |show_help, arg| show_help || ARGV.include?(arg) }
    warn <<SHOW_USAGE
#{$0} lists all directories in '#{Dir.getwd}' that are deprecated and may be deleted.
All directories containing an ISO-formatted date (YYYY-MM-DD) are considered.
A string is returned (you have to execute the result yourself or by a script. Examine first).
The retain policy is specified by passing any of:
  days=I    retain last <I> days of backups, default 0
  weeks=I   retain last <I> weeks of backup (only sundays), default 0
  months=I  retain last <I> months of backup (only last day of month), default 0
  years=I   retain last <I> years of backup (only YYYY-12-31), default 0
other available arguments are
  dir=S     working directory, default .
  date=D    reference date for application of policy, defaults to today (#{Date.today()})
  quote=S   used to quote deprecated files and directories, default is no quote
  prefix=S  prefix (e.g. a command like "rm "), empty by default
  postfix=S postfix (e.g. additional argument for a command specified in prefix), empty by default
  show=true show resulting policy
  run=true  run output as a command
EXAMPLE:
    #{$0} days=3 weeks=2 months=2 years=1 quote="'"
  YIELDS:
    #{quoted_join(dates_to_folders(Dir['*????-??-??*'], retain_by_policy({:days => 3, :weeks => 2, :months => 2, :years => 1})), "'")}
SHOW_USAGE
    exit 0
  end
  policy = args_to_map(ARGV, %w(days weeks months years))
  policy.each{ |k, v| policy[k] = v.to_i }
  options = args_to_map(ARGV, %w(dir date quote prefix postfix show run))
  if options[:show] == "true"
    puts "policy:"
    p policy
    puts "options:"
    p options
    puts "result:"
  end
  if options[:dir]
    Dir.chdir(options[:dir])
  end
  obsolete = dates_to_folders(
    Dir['*????-??-??*'],
    retain_by_policy(policy, options[:date] || Date.today())
  )
  unless obsolete.empty?
    result = "#{options[:prefix] || ''}#{quoted_join(obsolete, options[:quote] || '')}#{options[:postfix] || ''}"
    puts result
    if options[:run] == "true"
      system result
      puts "... completed"
    end
  end
end
