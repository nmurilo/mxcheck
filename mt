#!/bin/bash 
#
# (c) Nelson Murilo 
# The motivation to write this tool was APT43
# Initial version: 2024/05/05 
# 

SPFMISCONF="SPF MISCONFIGURED"
DMARCNOTCONF="DMARC NOT CONFIGURED"

usage() 
{
   echo -e "Usage: mt [-f file] [-h host]"
   exit 1
}

dmark_check() {
   line=$(dig _dmarc.$1 txt | grep DMARC 2>/dev/null) 
   if [ ! -z "$line" ]; then 
     p=$(echo $line | cut -d= -f3 | cut -d\; -f 1) 
     if [ "$p" = "nome" ]; then
        echo DMARC Policy not configured 
     else 
        echo DMARC Policy: $p 
     fi
   else 
      echo $DMARCNOTCONF | grep --color "$DMARCNOTCONF"
   fi
}

spf_check() {
   line=$(dig $1 txt | grep spf 2>/dev/null) 
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
   if [ $(dig mx $1  | grep MX | wc -l) -lt 2 ]; then  
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


if [ ! -z "${host}" ]; then 
   echo $host: 
   mx_check $host
   spf_check $host
   dmark_check $host
else 
   for host in $(cat $file); do 
      echo -e "\n$host:"
      mx_check $host
      spf_check $host
      dmark_check $host
   done 
fi 
exit 0 

