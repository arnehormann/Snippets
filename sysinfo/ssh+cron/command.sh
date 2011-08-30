echo "###### SSH";
for user in $(getent passwd|cut -d: -f1,6);do export keyfile="$(echo $user|cut -d: -f2)/.ssh/authorized_keys";[ -f "$keyfile" ]&&echo "#### USER $(echo $user|cut -d: -f1) ; FILE ${keyfile}"&&cat "$keyfile";done 2>/dev/null;
for keyfile in /etc/ssh/auth*key*/*;do echo "#### USER $(basename $keyfile) ; FILE $keyfile"&&cat "$keyfile";done 2>/dev/null;
echo "###### CRON";
for f in /etc/crontab /etc/cron.d/*;do [ -f "$f" ]&&echo "#### FILE $f"&&sed -e '/^$/d' -e '/^#/d'<$f;done;
for u in $(getent passwd|cut -f1 -d:);do (crontab -u $u -l>&/dev/null&&echo "#### USER $u"&&crontab -u $u -l 2>/dev/null&&echo)|sed -e '/^$/d' -e '/^#/d';done
