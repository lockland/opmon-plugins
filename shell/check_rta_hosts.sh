#!/bin/bash

####################################################
##
## Author: Sidney Souza
## E-mail: sidney.souza@opservices.com.br
##
## Date: 10/12/2012
##
####################################################
# ChangeLog
# 21/12/2012
# Ajustado os parametros de timeout do comando ping
#
####################################################

####################################################
##
## Show help
##
####################################################

function printHelp(){
	printUsage $0
    cat << EOF
    
    -l|--list,		List of hosts to use
    
    -c|--critical, 	Critical threshold (ms).
    
    -h|--help,	 	Show this help.
    
    -w|--warning, 	Warning threshold (ms).
    
    -W|--timeout, 	Timout of ping (ms), default is 1000ms.
       				- The timeout used when a destination host unreachable
           	
    -V|--version, 	Show the version of this plugin.
    
    Note: The list of hosts must be created separating each host by space
          The minimum timeout is 1000 ms. This is limitation of ping command
	
EOF

}

####################################################
##
## Show usage
##
####################################################

function printUsage(){
	echo 
	echo "Usage: $0 -l <\"list of hosts\"> -w <warning value> -c <critical value>"
	echo "Example: $0 -l \"www.google.com www.yahoo.com.br\" -w 80 -c 90"
}

####################################################
##
## Show plugin's version
##
####################################################

function version(){
	echo "Version: $version"
}

####################################################
##
## Calculates the average all of host in list
##
####################################################

function calcAvg(){
	local sumAvg=0
	local avg=0
	local qtdPackage=3
	local hosts="$list"
	local qtdHosts=$(echo $hosts | sed 's/ /\n/g' | wc -l)
	
	for i in $hosts; do
		# pick up line that contains the rtt
		stringPing=$(ping -q -l $qtdPackage -c $qtdPackage -w $timeout -W $timeout $i 2>&-)
		retPing=$?
		
		#ping was success
		if [ $retPing -eq 0 ]; then
			# pick up average ping
			avg=$(echo $stringPing | grep rtt | awk -F '/' '{ print $5 }')
		else
			# hosts unknown
			if [ $retPing -eq 2 ]; then
				echo ""
				exit 3
			# Destination Host Unreachable
		    else
				avg=$(echo $timeout*1000 | bc)
			fi
			#qtdHosts=$(($qtdHosts - 1)"
		fi
		# sum averages
		sumAvg=$(echo "scale=2; ($sumAvg + $avg)" | bc)
	done
	
	sumAvg=$(echo "scale=2; $sumAvg/ $qtdHosts" | bc)
	echo $sumAvg
}

####################################################
##
## Exit plugin and show message
##
####################################################

function exitPlugin(){
	echo $1
	exit $2 
}

####################################################
##
## Get parameters and set global variables
##
####################################################

function getOptions(){
	eval set -- "$@"

	while true ; do
		case "$1" in
	        -l|--list) 
				list=$2
				shift 2
				;;
			-w|--warning)
		    	warning=$2
				shift 2
				;;
			-W|--timout)
		    	timeout=$(echo $2/1000 | bc)
				shift 2
				;;
		    -c|--critical)
		       	critical=$2
				shift 2
		        ;;
		    -h|--help)
		       	printHelp
		       	exit 0
		        ;;
		    -V|--version)
		    	version
		       	exit 0
		        ;;
		    --) shift; break;;
		esac
	done
	
	if [ "$warning" == "" ]; then
		echo "No Warning Level Specified"
		printHelp
		exit 3;
	fi

	if [ "$critical" == "" ]; then
		echo "No Critical Level Specified"
		printHelp
		exit 3;
	fi

	if [ "$list" == "" ]; then
		echo "No Host's List Specified"
		printHelp
		exit 3;
	fi

	if [ $timeout -eq 0 ]; then
		timeout=1
	fi
	
}

# Global Variables
version=1.1
warning=""
critical=""
list=""
timeout=0

getOptions $(getopt -o l:c:w:W:hV --long "list: warning: critical: timout: help version" -n "$0" -- "$@")

avg=$(calcAvg)
timeout=$(echo $timeout*1000 | bc)

if [ -z "$avg" ]; then
	exitPlugin "ERROR - One or more host is incorrect" 3
fi

if [ `echo "scale=2; $avg < $warning" |  bc 2>&-` -eq 1 ] 2>&- ; then
	exitPlugin "OK - The rta is ${avg}ms. | Media_rta=${avg}ms;${warning}ms;${critical}ms;0ms;${timeout}ms" 0
	
elif [ `echo "scale=2; $avg < $critical" |  bc 2>&-` -eq 1 ] 2>&- ; then
	exitPlugin "WARNING - The rta is ${avg}ms. | Media_rta=${avg}ms;${warning}ms;${critical}ms;0ms;${timeout}ms" 1
	
elif [ `echo "scale=2; $avg > $critical" |  bc 2>&-` -eq 1 ] 2>&-; then
	exitPlugin "CRITICAL - The rta is ${avg}ms. | Media_rta=${avg}ms;${warning}ms;${critical}ms;0ms;${timeout}ms" 2

else
	exitPlugin "UNKNOWN - The rta is not defined." 3

fi

