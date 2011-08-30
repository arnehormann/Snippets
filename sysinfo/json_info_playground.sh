#!/bin/bash

json_test() {
  header_option="headers"
  #"system-cpu"
  comment='lists system cpus';
  #headers=</proc/cpuinfo sed -n '/^processor[\t ]*:.*$/,/^$/{/^$/{g;s/^\n*//;s/\n$//;s/\n/,/g;s/ /_/g;p;h;q};s/^\([^\t:]*\).*$/"\1"/;s/MHz/mhz/;H;}';
  headers='"processor","vendor_id","cpu_family","model","model_name","stepping","cpu_mhz","cache_size","physical_id","siblings","core_id","cpu_cores","fpu","fpu_exception","cpuid_level","wp","flags","bogomips","clflush_size","cache_alignment","address_sizes","power_management"';
  entries=</proc/cpuinfo sed -n '/^processor[\t ]*:[\t ]*[0-9]*[\t ]*$/,/^[\t ]*$/{s/^[^:]*:[\t ]*\(.*?\)[\t ]*$/"\1"/}';
  # system-cpu          /proc/cpuinfo
  # system-memory       /proc/meminfo
  # system-disks        df
  # network-activity    netstat
  # process-activity    ps ax
  if [ "${entries}" = "" ]; then
    echo "Could not retrieve information for ${1}..."
    return 1
  else
    if [ "${2}" = "${header_option}" ]; then
      echo "{\"headers\":[${headers}],\"entries\":[${entries}]}"
    else
      echo "{\"entries\":[${entries}]}"
    fi
  fi
}

ls_ssh_authorized() {
  for user in $(getent passwd|cut -d: -f1,6);do export keyfile="$(echo $user|cut -d: -f2)/.ssh/authorized_keys";[ -f "$keyfile" ]&&echo "#### USER $(echo $user|cut -d: -f1) ; FILE ${keyfile}"&&cat "$keyfile";done 2>/dev/null;
  for keyfile in /etc/ssh/auth*key*/*;do echo "#### USER $(basename $keyfile) ; FILE $keyfile"&&cat "$keyfile";done 2>/dev/null
}

ls_crons() {
  for f in /etc/crontab /etc/cron.d/*;do [ -f "$f" ]&&echo "#### FILE $f"&&sed -e '/^$/d' -e '/^#/d'<$f;done;
  for u in $(getent passwd|cut -f1 -d:);do (crontab -u $u -l>&/dev/null&&echo "#### USER $u"&&crontab -u $u -l 2>/dev/null&&echo)|sed -e '/^$/d' -e '/^#/d';done
}
