#!/bin/bash 
#
# (c) Nelson Murilo 
# The motivation to write this tool was APT43
# Initial version: 2024/05/05 
# DKIM check added: 2026/11/26
# 

SPFMISCONF="SPF MISCONFIGURED"
DMARCNOTCONF="DMARC NOT CONFIGURED"
DKIMNOTFOUND="DKIM NOT FOUND"

usage() 
{
   echo -e "Usage: mt [-f file] [-h host]"
   exit 1
}

dkim_check() {
   common_selector_list="selector1 selector2 s1 s2 google mimecast1 mimecast2"
   line=""
   f=0
   for i in $common_selector_list; do 
      line=$(dig TXT ${i}._domainkey.$1 | grep "v=DKIM1" 2>/dev/null) 
      s=$(echo ${line}| cut -f 1 -d\-) 
      [ ! -z "$s" ] && {
         echo DKIM Selector: ${s}
         f=1
      } 
    done
    if [ ${f} -eq 0 ]; then 
         echo $DKIMNOTFOUND | grep --color "$DKIMNOTFOUND"
    fi
}

dmarc_check() {
   line=$(dig TXT _dmarc.$1 | grep DMARC 2>/dev/null) 
   if [ ! -z "$line" ]; then 
     p=$(echo "${line}" | cut -d= -f3 | cut -d\; -f 1) 
     if [ "$p" = "none" ]; then
        echo DMARC Policy not configured 
     else 
        echo DMARC Policy: $p 
     fi
   else 
      echo $DMARCNOTCONF | grep --color "$DMARCNOTCONF"
   fi
}

spf_check() {
   line=$(dig TXT $1 | grep spf 2>/dev/null) 
   if [ ! -z "$line" ]; then 
      if echo $line | grep all >/dev/null; then 
         if echo "$line" | grep -e "~all" >/dev/null; then echo "SPF softfail"; fi | grep --color softfail 
         if echo "$line" | grep -e "-all" >/dev/null; then echo "SPF hardfail"; fi
      else 
         echo $SPFMISCONF | grep --color "$SPFMISCONF"
      fi
   fi
}

mx_check()
{
   if [ $(dig MX $1  | grep MX | wc -l) -lt 2 ]; then  
      echo "No MX record for $1" | grep --color "No MX record" 
   fi
}

host=""
while getopts 'f:h:' c; do 
   case $c in 
      f) file=${OPTARG} ;;
      h) host=${OPTARG} ;;
      *) usage ;; 
   esac
done

[ -z "${file}" -a -z "${host}" ] && usage
[ ! -z "${file}" -a ! -z "${host}" ] && usage
[ ! -z "${file}" -a ! -f "${file}" ] && usage

[ ! -z "${file}" ] && hosts=$(cat $file) || hosts=$host

for host in ${hosts}; do 
   echo -e "\n$host:"
   mx_check $host
   spf_check $host
   dmarc_check $host
   dkim_check $host
done 
exit 0 

