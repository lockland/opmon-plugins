#!/bin/bash
# VERSION: 1.4-2
# CREATED: 20/05/2014 15:00
# REVISION: ---
# AUTHOR REVISION: --- 


BASENAME=$(basename $0)
WARNING=-1
CRITICAL=-1
ERROR=-1
HELP="
Description:
    Criado para realizar o monitoramento de ramais do asterisk
    
Developed by:
    OpServices - www.opservices.com.br/suporte
    
Author:
    Sidney Souza - sidney.souza@opservices.com.br
    
Usage: 
    $BASENAME -w < warning > -c < critical > [-v] [-h]

Options:
    -h
        Mostrar esse help
    -w 
        Valor de warning
    -c
        Valor de critical
    -v
        Modo Verbose

Depends:
    GREP
    CUT
    SED
    WC
    ECHO
"


while true; do

    case "$1" in 
         -w|--warning)
              WARNING=$2
              shift 2;;
         -c|--critical)
              CRITICAL=$2
              shift 2;;
         -h|--help)
              echo -e "$HELP"
              shift
              exit 0;;
         -v|--verbose)
              set -x
              shift;;
         *)
              break;;
     esac
done

FILE=$(sudo /usr/sbin/asterisk -r -q -x 'sip show peers')
CONTENT=$(echo "$FILE" | grep -E 'UNREACHABLE|UNKNOWN' | sed -r 's/(\/|\s).*//g;s/^/<br \/>/g' )
LIST=$(echo $CONTENT)
ERROR=$([ -z "$CONTENT" ]  && echo 0 || wc -l <<< "$CONTENT")

echo "$FILE" | grep -qs "sip peers"
if [ $? -gt 0 ]; then
    echo "UNKNOWN: Dados não encontrados"
    exit 3
fi

MSG="$ERROR diferente de OK $LIST| not_ok=$ERROR;$WARNING;$CRITICAL;0;"

if [ $ERROR -ge $WARNING -a $ERROR -lt $CRITICAL ]; then
    echo "WARNING: $MSG"
    exit 1
elif [ $ERROR -ge $CRITICAL ]; then 
    echo "CRITICAL: $MSG"
    exit 2
else 
    echo "OK: $MSG"
    exit 0
fi
