#!/usr/bin/env ruby
%w(mysql2 json).each{ |gem| require gem }

class Table
  attr_reader :name
  
  def initialize(name)
    @name = name
    @fields_by_index = []
    @fields_by_name = {}
  end

  def fields()
    @fields_by_index
  end
  
  def [](key)
    case key
      when Fixnum then @fields_by_index[key]
      else @fields_by_name[key]
    end
  end

  def <<(field)
    field = field.merge(:table => self, :index => @fields_by_index.length)
    @fields_by_index << field
    @fields_by_name[field[:name]] = field
  end
  
  def to_s
    (["=== #{name} ==="] + @fields_by_index.collect { |f| "  #{f.merge(:table => @name).inspect}" }).join "\n"
  end
end

def scan_field(line)
  name, sql_type, raw_options = line.split(' ', 3)
  field = {:name => name.gsub('`',''), :sql_type => sql_type, :nullable => true}
  column_options = /UNSIGNED|ZEROFILL|(?:NOT )?NULL|DEFAULT (?:'[^']*'|[^ ]*)|AUTO_INCREMENT|(?:UNIQUE|PRIMARY)(?: KEY)?|COMMENT '[^']*'|REFERENCES (?:.*)/i
  options = (raw_options || '').scan(column_options).each do |o|
    if /NOT NULL/i =~ o
      field[:nullable] = false
    elsif /NULL/i =~ o
      field[:nullable] = true
    else
      type, arg = o.split(' ', 2)
      if arg
        value = arg.gsub(/^['"]|['"]$/, '')
        value = nil if value == 'NULL'
        field[type.downcase.to_sym] = value
      else
        field[type.downcase.to_sym] = true
      end
    end
  end
  if /tinyint\(1\)/ =~ field[:sql_type]
    field[:default] = case field[:default]
      when '0' then false
      when '1' then true
      else field[:default]
    end
    field[:type] = :boolean
  else
    type, spec = sql_type.split('(', 2)
    if spec
      length, decimals = spec[0...(spec.length - 1)].split(',').collect{|d|d.strip.to_i if d}
      field[:length] = length
      field[:decimals] = decimals if decimals
    end
    field[:type] = case type.downcase
      when /bit|boolean/ then :boolean
      when /.*int(eger)?$/ then :integer
      when /real|double|float|decimal|numeric/ then :number
      when /date|time|text|char|enum|set|blob|binary/ then :string
      else raise "unknown sql type '#{sql_type}'"
    end
    if field[:default]
      if field[:type] == :integer
        field[:default] = field[:default].to_i
      elsif field[:type] == :number
        field[:default] = field[:default].to_f
      end
    end
  end
  field
end

def field2json_sql(field)
  case field[:type]
    when :string then "ifnull(concat('\"#{field[:name]}\":\"',#{field[:name]},'\"'),'')"
    when :boolean then "ifnull(concat('\"#{field[:name]}\":',if(#{field[:name]}=0,'false','true')),'')"
    else "ifnull(concat('\"#{field[:name]}\":',#{field[:name]}),'')"
  end
end

def fields2json_sql(fields, exclude_fields, append = [])
  selected_cols = fields.select{ |f| not exclude_fields.include?(f[:name]) }
  cols_sql = selected_cols.inject([]) { |cols, field| cols << field2json_sql(field) }
  "CONCAT_WS(',',#{(cols_sql + append).join(',')})"
end

def append_rows(table, join_field, external_join_field_sql, order = nil, exclude_fields = nil)
  order ||= []
  fields_sql = fields2json_sql(table.fields, (exclude_fields || []) << table[join_field][:name])
  order_sql = ''
  unless order.empty?
    ordered_fields = table.fields.select{ |f| order.include?(f[:name]) }
    unless ordered_fields.empty?
      order_sql = " ORDER BY #{ordered_fields.collect{ |f| f[:name] }.join(',')}"
    end
  end
  "(SELECT GROUP_CONCAT(CONCAT('{',#{fields_sql},'}')#{order_sql} SEPARATOR ',') x " +
  "FROM #{table.name} WHERE #{table[join_field][:name]} = #{external_join_field_sql})"
end

def append_row(table, join_field, external_join_field_sql, exclude_fields = nil)
  fields_sql = fields2json_sql(table.fields, (exclude_fields || []) << table[join_field][:name])
  "(SELECT #{fields_sql} FROM #{table.name} WHERE #{table[join_field][:name]} = #{external_join_field_sql})"
end

def row2json_sql(table, additional_fields = nil, exclude_fields = nil)
  fields_sql = fields2json_sql(table.fields, exclude_fields || [], additional_fields || [])
  "SELECT CONCAT('{',#{fields_sql},'}') FROM #{table.name}"
end


MYSQL_LOGIN = JSON.parse(IO.read(ARGV[0] || 'task.json'))
MYSQL_OPTIONS = {:as => :array, :cache_rows => false, :cast_booleans => true}
MYSQL_ORDER = MYSQL_LOGIN['order']

Mysql2::Client.default_query_options.merge!(MYSQL_OPTIONS)
db = Mysql2::Client.new(MYSQL_LOGIN)

tables = db.query("SHOW TABLES WHERE Tables_in_#{MYSQL_LOGIN[:database]} like 'p%'").inject({}) do |table_akku, tablename|
  tablename = tablename[0]
  table = Table.new(tablename)
  db.query("SHOW CREATE TABLE #{tablename}").each do |fields|
    fields[1].split("\n").each do |line|
      if /^[ \t]*\`/ =~ line
        table << scan_field(line.strip.sub(/,$/, ''))
      end
    end
  end
  table_akku[tablename] = table
  table_akku
end

documentation = <<DOCUMENTATION
  
DOCUMENTATION

missing = <<MISSING
  - aliasing of field - JSON_names (needed for multijoins)
  - sensible default format
  - data wrapping (underlying from p_... into "underlyings": [ ... ] if only one, ...)
MISSING

query = row2json_sql(product, [
        append_row(pbasket, 'product_id', 'p.id'),
        %q<'"identifiers":[',> + append_rows(pinfo, 'product_id', 'p.id', MYSQL_ORDER) + %q<,']'>,
        %q<'"underlyings":[',> + append_rows(punderlyings, 'product_id', 'p.id', MYSQL_ORDER) + %q<,']'>,
        %q<'"dates":[',> + append_rows(pdates, 'product_id', 'p.id', MYSQL_ORDER) + %q<,']'>,
        %q<'"conditions":[',> + append_rows(pconditions, 'product_id', 'p.id', MYSQL_ORDER) + %q<,']'>
]) + ' p WHERE p.product_type_id = 22'

puts "SET group_concat_max_len = 65000;"
puts query