#!/usr/bin/perl -w

####################################################
##
## Author: Sidney Souza
## E-mail: sidney.souza@opservices.com.br
##
## Date: 25/02/2013
##
####################################################

use strict;
no strict 'refs';
use warnings;
use English;
use Switch;

use constant{
	      OK => 0,
	 WARNING => 1,
	CRITICAL => 2,
	 UNKNOWN => 3,
	    true => 1,
	   false => 0,
	 VERSION => '1.1'
};


# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Function to prepare parameter to use in plugin
#
# @return: Hash table with arguments
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
sub getOption() {
	use Getopt::Long;
	my %args;

    Getopt::Long::Configure('bundling');
    Getopt::Long::Configure('pass_through');
    GetOptions(
		'H|hostname=s'		=> \$args{ hostname },
		'o|oid=s'		=> \$args{ oid },
		'w|warning=s'		=> \$args{ warning },
		'c|critical=s'		=> \$args{ critical },
		'h|help'		=> \$args{ help },
		'C|community=s'		=> \$args{ community },
		's|string=s'		=> \$args{ stringFind },
		'r|regex=s'		=> \$args{ regex },
		'invert-search'		=> \$args{ invertRegex },
		't|timeout=i'		=> \$args{ timeout },
		'e|retries=i'		=> \$args{ retries },
		'l|label=s'		=> \$args{ label },
		'u|units=s'		=> \$args{ units },
		'p|port=i'		=> \$args{ port },
		'm|miblist=s'		=> \$args{ miblist },
		'P|protocol=s'		=> \$args{ protocol },
		'L|seclevel=s'		=> \$args{ seclevel },
		'U|secname=s'		=> \$args{ secname },
		'a|authproto=s'		=> \$args{ authproto },
		'A|authpasswd=s'	=> \$args{ authpasswd },
		'x|privproto=s'		=> \$args{ privproto },
		'X|privpasswd=s'	=> \$args{ privpasswd },
		'v|verbose=i'		=> \$args{ verbose },
		'V|Version'		=> \$args{ version },
		'O|perf-oid=s'		=> \$args{ perfOid }
	);

	if ($args{ version }){
        version();
        exit(OK);
    }

	if ($args{ help }){
        help();
        exit(OK);
    }

	if (!defined( $args{ hostname } ) || !defined( $args{ oid } ) ){
		usage();
		exit(UNKNOWN);
	}

	if ( defined($args{ protocol }) && !($args{ protocol } =~ /^(1|2c|3)$/) ){
		quit("UNKNOWN: Protocol v" . $args{ protocol } . " is invalid.", UNKNOWN);
	}

	if ( defined($args{ seclevel }) && !($args{ seclevel } =~ /^(noAuthNoPriv|authNoPriv|authPriv)$/) ){
		quit("UNKNOWN: Level " . $args{ seclevel } . " is invalid.", UNKNOWN);
	}

	if ( defined($args{ authproto }) && !($args{ authproto } =~ /^(MD5|SHA)$/) ){
		quit("UNKNOWN: Authentication Protocol " . $args{ authproto } . " is invalid.", UNKNOWN);
	}

	if ( defined($args{ privproto }) && !($args{ privproto } =~ /^(DES|AES)$/) ){
		quit("UNKNOWN: Private Protocol " . $args{ privproto } . " is invalid.", UNKNOWN);
	}

	if (
		( defined($args{ protocol }) && $args{ protocol } eq "3" ) &&
		( !defined( $args{ seclevel } ) || !defined( $args{ authpasswd } ) || !defined( $args{ secname } ) )
	){
		quit("UNKNOWN: Level, authpassword and username is required to protocol v". $args{ protocol }, UNKNOWN);
	}

	if (
		( defined($args{ warning } ) && !defined( $args{ critical } )) ||
		(!defined( $args{ warning } ) && defined( $args{ critical } ))
	){
		quit("UNKNOWN: warning and critical is necessary", UNKNOWN);
	}


	$args{ community }	= "public" if (!$args{ community });
	$args{ verbose }	= 0 if (!$args{ verbose });
	$args{ protocol }	= "1" if (!$args{ protocol });
	$args{ miblist }	= '' if (!$args{ miblist });
	$args{ privproto }	= "DES" if (!$args{ privproto });

    return %args;
}

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Function used to show message and exit plugin whith code nagios' pattern

#@params $message, $exitCode
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
sub quit($$){
	print shift()."\n";
	exit (shift());
}
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Function to show usage mode
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
sub usage(){
	use File::Basename;

	print basename($0), "\t-H <ip_address> -o <OID> [-w warn_range] [-c crit_range] [-C community] [-s string] [-r regex] [-t timeout]
\t\t\t[-e retries] [-l label] [-u units] [-m miblist] [-P snmp version] [-L seclevel] [-U secname] [-a authproto]
\t\t\t[-A authpasswd] [-x privproto] [-X privpasswd]
\t\t\n";
}

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Function to show version
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
sub version() {
    printf ("Version: %s\n", VERSION);
}

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Function to show help (Based on check_snmp's help)
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
sub help() {
       print  << 'HELP';
   	 -h, --help
		Print detailed help screen
	 -V, --version
		Print version information
	 -H, --hostname=ADDRESS
		Host name, IP Address, or unix socket (must be an absolute path)
	 -P, --protocol=[1|2c|3]
		SNMP protocol version
	 -L, --seclevel=[noAuthNoPriv|authNoPriv|authPriv]
		SNMPv3 securityLevel
	 -a, --authproto=[MD5|SHA]
		SNMPv3 auth proto
	 -x, --privproto=[DES|AES]
		SNMPv3 priv proto (default DES)
	 -C, --community=STRING
		Optional community string for SNMP communication (default is "public")
	 -U, --secname=USERNAME
		SNMPv3 username
	 -A, --authpassword=PASSWORD
		SNMPv3 authentication password
	 -X, --privpasswd=PASSWORD
		SNMPv3 privacy password
	 -o, --oid=OID
		Object identifier or SNMP variables whose value you wish to query
	 -m, --miblist=STRING
		List of MIBS to be loaded (default = none if using numeric OIDs or 'ALL'
		for symbolic OIDs.)
	 -w, --warning=THRESHOLD(s)
		Warning threshold range(s)
	 -c, --critical=THRESHOLD(s)
		Critical threshold range(s)
	 -s, --string=STRING
		Return OK state if STRING is an exact match, for case insensitive use '/[string]/i'
	 -r, --ereg=REGEX
		Return $1 to determinate Warning and Critical (perl pattern)
	 --invert-search
		Invert search result (CRITICAL if found)
	 -l, --label=STRING
		Prefix label for output from plugin
	 -u, --units=STRING
		Units label for output data (e.g., 'sec.').
	 -t, --timeout=INTEGER
		Seconds before connection times out (default: 10)
	 -e, --retries=INTEGER
		Number of retries to be used in the requests
	 -O, --perf-oid
		Label performance data with OID instead of --label
	 -v, --verbose
		Show details for command-line debugging (Nagios may truncate output)
HELP

}

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Function to determinate threshold status
#
# @params: $threshold, $valuethreshold, $verbose, $value
# @return: $status
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

sub parseThreshold($$$$){
	my ($threshold, $valuethreshold,
		$verbose,   $value) = @ARG;
	my $bool = false;

	$bool = true if (($valuethreshold =~ /^([0-9]+)$/) && ($value < 0 || $value > $1));
	$bool = true if (($valuethreshold =~ /^([0-9]+):$/) && ($value < $1));
	$bool = true if (($valuethreshold =~ /^~:([0-9]+)$/) && ($value > $1));
	$bool = true if (($valuethreshold =~ /^([0-9]+):([0-9]+)$/) && ($value < $1 || $value > $2));
	$bool = true if (($valuethreshold =~ /^@([0-9]+):([0-9]+)$/) && ($value >= $1 || $value <= $2));

	if ($verbose  == 3){
		print (">>>>>>\nDebugger parseThreshold\n------------\n");
		printf ("Is %s?: %s\n", ( ($threshold == OK)  ? "OK" : ($threshold == WARNING) ? "WARNING" : "CRITICAL"), (($bool)  ? "True:" : "False") );
		print (">>>>>>\n\n\n") ;
	}

	return $bool;
}

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Function to determinate threshold status
#
# @params: $value, $verbose, $regex
# @return: $1 (value extract with regex);
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

sub extractSentenceOnFrase($$$){
	my ($value, $verbose, $regex) = @ARG;

	$regex =~ s/\///g; # remove / string

	if ($verbose == 3){
		print (">>>>>>\nDebugger extractSentenceOnFrase\n------------\n");
		print ("Return Command: $value\n");
		print ("Regex: $regex\n");
		printf ("Value returned: %f\n", ($value =~ /$regex/ ) ? $1 :  false );
		print (">>>>>>\n\n\n") ;
	}

	if ($verbose == 2){
		print (">>>>>>\nDebugger extractSentenceOnFrase\n------------\n");
		printf ("Value returned:  %f\n", ($value =~ /$regex/ ) ? $1 : false) ;
		print (">>>>>>\n\n\n") ;
	}

	# if value satisfy regex return group ($1) else return false
	return  ($value =~ /$regex/ )  ? $1 : false;
}

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Function to find string in the Command's return
#
# @param: $value, $verbose, $stringFind, $invert
# @return: $bool
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
sub foundString($$$$){
	my ($value, $verbose, $stringFind, $invert) = @ARG;

	my $temp = $stringFind;
	$temp =~ s/\/i|\///g; # remove / and i of string, digitated when script is executed

	my $bool;
	if ( $stringFind=~ /i$/ ){ # if stringFind required case insensitive, execute this
		 $bool = ($value =~ /$temp/i ) ? true : false; # if value contains word to search, return true else return false
	} else { # else execute this
		$bool = ($value =~ /$temp/ ) ? true : false; # if value contains word to search, return true else return false
	}

	if ($verbose == 3) {
		print (">>>>>>\nDebugger Search String option\n------------\n");
		print ("Value: $value\n");
		print ("String to Find: $temp \'$stringFind\'\n");
		print ("String $temp Found\n>>>>>>\n\n\n") if ($bool);
	}

	if ($verbose == 2) {
		print (">>>>>>\nDebugger Search String option\n------------\n");
		print ("String $temp Found\n>>>>>>\n\n\n") if ($bool);
	}

	return ($invert) ? !$bool : $bool; # if --invert-search is set, return a inverse result
}
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Function used to execute command and split result (pattern snmp) to return.
#
# @params: $command, $verbose, @params
# @return: second part(1) on split array
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
sub executeComand($$$){
	my ($command, $verbose, $params) = @ARG;

	my $stdout;
	my @split;

	$command = `which $command`; # find complete path of command in the system
	chomp( $command ); # remove line \n
	$command .= " $params 2>&1"; # join command with parameter and add option to redirect stderr to stdout
	chomp( $command ); # remove line \n

	$stdout = `$command`; # execute command
	chomp( $stdout ); # remove line \n

	if (defined ( $stdout ) && "$stdout" ne "" && "$stdout" !~ /(.*No Such Object.*)|(.*Timeout: .*)/i){ # if stdout not empty and don't have error, execute this
		@split = ( split( /(STRING: |INTEGER: |Gauge32: |Counter32: |OID: |IpAddress: |Timeticks: )/,$stdout ) ); # split string following the regex pattern
		chomp( $split[$#split] ) if ( @split );
		$split[$#split] =~ s/(^\ | $)|(\/|\")//g; # remove start and end space and / and " string
		$split[$#split] =~  s/[^\w+|\d+|\-|\ |\=|\.|\:|\,]//g; # not remove all elements into list

		print (">>>>>>\nDebugger Return of Command\n------------\n") if ($verbose);
		print ("Command Executed: $command\n") if ($verbose == 3) ;
		print ("Stdout Command: $stdout\n") if ($verbose) ;
		print ("Value returned: $split[$#split]\n") if ($verbose == 3 && (@split) );
		print (">>>>>>\n\n\n") if ($verbose) ;

		return $split[$#split];
	}

	quit("CRITICAL: $stdout", CRITICAL); # Quit program if occurred errors
}

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Function to dump variables
#
# @param: Object
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
sub var_dump{
	use Data::Dumper;
	print Dumper(shift());
}

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Function to prepare arguments to use in command snmpget
#
# @param: %args
# @return: String with all parameter going to use
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

sub prepareCommand(%){
	my %args = @ARG;
	my @params;
	#comentando snmp
	if ( $args{ protocol } eq "3"){
		push (@params, ("-v " . $args{ protocol }) ) if ( $args{ protocol } );
		push (@params, ("-u " . $args{ secname }) ) if ( $args{ secname } );
		push (@params, ("-l " . $args{ seclevel }) ) if ( $args{ seclevel } );
		push (@params, ("-a " . $args{ authproto }) ) if ( $args{ authproto } );
		push (@params, ("-A " . $args{ authpasswd }) ) if ( $args{ authpasswd } );
		push (@params, ("-x " . $args{ privproto }) ) if ( $args{ privproto } );
		push (@params, ("-X " . $args{ privpasswd }) ) if ( $args{ privpasswd } );
	} else {
		push (@params, ("-v " . $args{ protocol }) ) if ( $args{ protocol } );
		push (@params, ("-c " . $args{ community }) ) if ( $args{ community } );
	}

	push (@params, $args{ hostname } );
	push (@params, $args{ oid } );
	push (@params,  "-Ovq");
	push (@params, ("-m " . $args{ miblist }) ) if ( $args{ miblist } );
	push (@params, ("-e " . $args{ retries }) ) if ( $args{ retries } );
	push (@params, ("-t " . $args{ timeout }) ) if ( $args{ timeout } );

	return join(" ", @params) # return string with parameter necessary to use
}

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Function to make a output message
#
# @params: $returnCommand, $status, %args
# @return: $output (message) and $exitCode
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

sub createOutput($$%){
	my ($returnCommand, $status, %args) = @ARG;
	my @array;

	push (@array, "SNMP - ");
	push (@array, ($status == OK)  ? "OK: " : ($status == WARNING) ? "WARNING: " : "CRITICAL: ");
	push (@array, "$args{ label } ") if ($args{ label });
	push (@array, "$returnCommand");
	push (@array, "$args{ units }") if ($args{ units });
	push (@array, " | ");
	push (@array, ( ($args{ perfOid }) ? "$args{ perfOid }=\"$returnCommand\"" : "oid:$args{ oid }=\"$returnCommand\"") );
	push (@array, defined($args{ warning } ) ? ";$args{ warning }" : ";0" );
	push (@array, defined($args{ critical } ) ? ";$args{ critical }" : ";0" );
	push (@array, ";0;0");

	my $exitCode = ($status == OK)  ? OK : ($status == WARNING) ? WARNING : CRITICAL;
	my $output = join("", @array);

	return ($output, $exitCode);
}


# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Function to validate if $returnCommand is a number or not.
# If not a number, show message error and exit plugin.
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

sub validateIsNumber($){
	my $returnCommand = shift();
	quit("CRITICAL: The result is not a number, verify your regex", CRITICAL) if ( !($returnCommand =~ m/^((\d+\.\d+)|(\d+))$/) );
}


# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Function Main, used to execute plugin
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

sub main (){

	my %args = getOption();
	my $returnCommand;
	my $result;
	my $status = OK;
	my $params;
	my @messagePlusExitCode;

	$params = prepareCommand(%args);

	$returnCommand = executeComand("snmpget", $args{ verbose }, $params);

	if ($args{ stringFind }){ # if the option is String Find, execute this
		$result = foundString($returnCommand, $args{ verbose }, $args{ stringFind }, $args{ invertRegex });
		$status = CRITICAL if (!$result);
		@messagePlusExitCode = createOutput($returnCommand, $status, %args);
		quit( $messagePlusExitCode[0], $messagePlusExitCode[1] );
	}

	if ($args{ regex }){ # if the option is regex pattern, execute this

		$result = extractSentenceOnFrase($returnCommand, $args{ verbose }, $args{ regex } );

		validateIsNumber($result);

		if ( defined($args{ warning } ) ){
			$status = WARNING if ( parseThreshold( WARNING, $args{ warning }, $args{ verbose }, $result ) );
		}

		if ( defined( $args{ critical } ) ){
			$status = CRITICAL if ( parseThreshold( CRITICAL, $args{ critical }, $args{ verbose }, $result ) );
		}

		if ($args{ verbose } == 2){
			print (">>>>>>\nDebugger regex option\n------------\n");
			print ("Return Command: $returnCommand\n>>>>>>\n\n\n");
		}

		if ($args{ verbose } == 3){
			print (">>>>>>\nDebugger regex option\n------------\n");
			print ("Return Command: $returnCommand\n");
			print ("Value: $result\n");
			print ("Status: $status\n>>>>>>\n\n\n");
		}

		@messagePlusExitCode = createOutput($result, $status, %args);
		quit( $messagePlusExitCode[0], $messagePlusExitCode[1] );
	}

	if ( defined($args{ warning } ) && defined( $args{ critical } ) ){ # if the option is Warning and Critical Only, execute this
		validateIsNumber($returnCommand);
		$status = WARNING if ( parseThreshold( WARNING, $args{ warning }, $args{ verbose }, $returnCommand ) );
		$status = CRITICAL if ( parseThreshold( CRITICAL, $args{ critical }, $args{ verbose }, $returnCommand ) );
		@messagePlusExitCode = createOutput($returnCommand, $status, %args);
		quit( $messagePlusExitCode[0], $messagePlusExitCode[1] );
	} else {
		@messagePlusExitCode = createOutput($returnCommand, $status, %args);
		quit( $messagePlusExitCode[0], $messagePlusExitCode[1] );
	}

}
&main()
