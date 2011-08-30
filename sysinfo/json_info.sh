#!/bin/bash
# Each call returns a JSON-Object in the format specified below:
# Each object may contain the following fields/keys:
#   "h"  (optional)  - HEADERS, array of strings, arrays or objects describing all elements in one "entries" element
#     JSON-string: NAME      - used when the entry-element is a value or an array of values.
#     JSON-array:  FIELDS    - used when the entry-element is an object or an array of objects.
#       The first array element is the entry-element's NAME, the following elements are available fields.
#     JSON-object: ANNOTATED - one of the above plus annotations - available annotations are:
#       "n" (mandatory) - NAME, the name (same as the string/array if it were not an object)
#       "d"  (optional) - DESCRIPTION, human-readable description of the field
#       "h"  (optional) - HEADER, the header definition if the entry-element is a dictionary/an array of dictionaries
#       "m"  (optional) - MAP, array of mappings for this column in an entry (e.g. for error states)
#         format is [["A","B"],...]   with  A = match, B = replacement
#       "u"  (optional) - UNIT, array describing the unit used, units are standardized (see below)
#   "dh" (optional)  - DYNAMIC HEADERS, boolean (false by default), must be set to true if headers are not static but generated per query
#   "e"  (mandatory) - ENTRIES, array of entries (each entry is itself an array of enty-elements)
#      each entry must contain the same number of entry-elements as specified in the header
#
## EXAMPLE
## {
##   "h": [ "key", { "n": "values", "h": [ [ { "n": "temperature", "u": "°C" }, "windspeed" ] ] } ],
##   "e": [
##     [],
##     ...
##    ]
##  }
#
# About headers:
#   Headers should be sent when the format is unknown. Headers should be stable, otherwise "dh" must be set to true!
# About entries:
#   The format described above may be nested. Each entry-element may be typed (according to http://json.org):
#     value  - as best fits the contained data (null, true, false, number, string)
#     array  - an enumeration of values
#     object - formatted as specified above (with "headers" and "entries")
#   For every entry, the entry element must be the same JSON-type (or null)
# About units:
#   Standard SI units and prefixes, no whitespace. Additional unit "b" for bit, "B" for byte
#   A list of available units and prefixes may be found at
#    http://en.wikipedia.org/wiki/SI   http://en.wikipedia.org/wiki/Binary_prefix

### as_json queries a unix system for information in JSON format
# The kind of information is specified by a COMMAND given as first argument.
# Passing "headers" (no quotes) as a second argument retrieves headers as part of the resulting JSON object.
# A loose specification of the resulting object's format is given at the top of this file.
as_json() {
  header_option="headers"
  function_name="as_json"
  case "$1" in
  # Each case has to follow the syntax given in the example below.
  # >  "command")
  # >    comment='description of command';
  # >    headers='"header1","header2",...';
  # >    entries=$(unix command to retrieve information and transform it to JSON) $>/dev/null
  # >  ;;
  # ATTENTION: comment must follow the case-specification and must fit in one line
  "active-users")
    comment='list logged-in users';
    headers='"user","terminal","login_date","login_time","address"';
    entries=$(\
        who\
        |sed -e 's/[()]/"/g'\
        |awk 'BEGIN{ORS="";}{\
            if(NR > 1){print ",\n"};\
            print "[\"" $1 "\",\"" $2 "\",\"" $3 "\",\"" $4 ":00\"," substr($0,index($0, "\"")) "]"\
            }'
        ) &>/dev/null
  ;;
  "active-disks")
    comment='list mounted devices';
    headers='"device","mountpoint","type","attributes"';
    entries=$(\
        mount\
        |sed -e 's/,/","/g;s/(/["/g' -e's/)/"]/g;s/""//g'\
        |awk 'BEGIN{FS=" ";ORS="";}{\
            if(NR > 1){print ",\n"};\
            print "[\"" $1 "\",\"" $3 "\",\"" $5 "," substr($0,index($0, "[")) "]"\
            }'
        ) &>/dev/null
  ;;
  "active-system")
    comment='list system activity';
    headers='"processes_waiting","processes_blocked","mem_used_swap","mem_free","mem_used_buffer","mem_used_cache","mem_inactive","mem_active","mem_swap_in","mem_swap_out","io_blocks_in","io_blocks_out","sys_interrupts","sys_contextswitches","cpu_user","cpu_kernel","cpu_idle","cpu_wait_for_io"';
    entries=$(\
        vmstat\
        |sed '1,2d;s/^[\t ]*/[/;s/[\t ]*$/]/;s/[\t ][\t ]*/,/g'
        ) &>/dev/null
  ;;
  "auth-users")
    comment='list available logins';
    headers='"user","password","uid","gid","info","home","shell"';
    entries=$(\
        getent passwd\
        |awk 'BEGIN{FS=":";ORS="";}{\
            if(NR > 1){print ",\n"};\
            print "[\"" $1 "\",\"" $2 "\"," $3 "," $4 ",\"" $5 "\",\"" $6 "\",\"" $7 "\"]"\
            }'
        ) &>/dev/null
  ;;
  "auth-groups")
    comment='list available groups';
    headers='"group","password","gid","users"';
    entries=$(\
        getent group\
        |sed -e's/,/","/g'\
        |awk 'BEGIN{FS=":";ORS="";}{\
            if(NR > 1){print ",\n"};\
            print "[\"" $1 "\",\"" $2 "\"," $3 ",[";\
            if ($4 != "") { print "\"" $4 "\""; }\
            print "]]"\
            }'
        ) &>/dev/null
  ;;
  "auth-shadows")
    comment='list available shadow-entries for users';
    headers='"user",{"name":"password","map":[["NP","none"],["!","none"],["LK","locked"],["*","locked"],["!!","expired"]]},"lastchange_days_since_1970","min_days_till_change","max_days_till_change","warn_days_before_expiration","days_before_inactive","expire_days_after_1970","reserved"';
    entries=$(\
        getent shadow\
        |sed -e's/::/:null:/g' -e's/::/:null:/g'\
        |awk 'BEGIN{FS=":";ORS="";}{\
            if(NR > 1){print ",\n"};\
            print "[\"" $1 "\",\"" $2 "\"," $3 ", " $4 ", " $5 ", " $6 ", " $7 ", " $8 ", \"" $9 "\"]"\
            }'
        ) &>/dev/null
  ;;
  "auth-keys")
    comment='list location (and visibility/existance) of ssh authorized_keys files';
    headers='"user","keyfile",{"n":"keys","h":["prefix","type","key","comment"]}';
    entries=exit
  ;;
  "system-disks")
    comment='list known available devices (in /etc/fstab)';
    headers='"device","mountpoint","type","attributes","dump","pass"';
    entries=$(\
        </etc/fstab sed -e'/^#/d;s/[ \t]+/ /g;s/,/","/g'\
        |awk 'BEGIN{FS=" ";ORS="";}{\
            if(NR > 1){print ",\n"};\
            print "[\"" $1 "\",\"" $2 "\",\"" $3 "\",[\"" $4 "\"]," $5 "," $6 "]"\
            }'
        ) &>/dev/null
  ;;
  "system-pci")
    comment='list connected pci devices';
    headers='"type","port","name"';
    entries=$(\
        lspci\
        |awk 'BEGIN{ORS="";}{\
            if(NR > 1){print ",\n"};\
            RL=substr($0,index($0, " ")+1);\
            print "[\"" substr(RL,0,index(RL,":")) "\",\"" substr($0,0,7) "\",\"" substr(RL,index(RL,":")+2) "\"]"\
            }'
        ) &>/dev/null
  ;;
  "system-usb")
    comment='list connected usb devices';
    headers='"bus","device","id","name"';
    entries=$(\
        lsusb\
        |awk 'BEGIN{ORS="";}{\
            if(NR > 1){print ",\n"};\
            print "[\"" substr($0,5,3) "\",\"" substr($0,16,3) "\",\"" substr($0,24,9) "\",\"" substr($0,34) "\"]"\
            }'\
        |sed -e's/" "/null/;s/""/null/'\
        ) &>/dev/null
  ;;
  # system-cpu          /proc/cpuinfo
  # system-memory       /proc/meminfo
  # system-disks        df
  # network-activity    netstat ...
  # process-activity    ps ax
  *)
    echo "  ${function_name} COMMAND [${header_option}]
retrieves system information in JSON format as specified at http://json.org/
The option '${header_option}' requests the header in the result.
available as COMMAND:"
    # the function "as_json" is defined and available via "set", extract information from case-options above from the definition
    set|sed -n '/^as_json \(\)/,/*)/{/^ *".*")/{N;s/[\t ]*\([^)]*\)) *\n *comment=.\(.*\).;/\1\t\2/;p}}'|column -t -s"$(echo -e "\t")"
    return 1
  ;;
  esac
  if [ "${entries}" = "" ]; then
    echo "Could not retrieve information for ${1}..."
    return 1
  else
    if [ "${2}" = "${header_option}" ]; then
      echo "{\"h\":[${headers}],\"e\":[${entries}]}"
    else
      echo "{\"e\":[${entries}]}"
    fi
  fi
}
