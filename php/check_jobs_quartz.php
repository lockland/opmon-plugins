#!/usr/bin/php -q
<?php

require_once("/usr/local/opmon/libexec/opservices/lib/php/Nagios/Plugin.php");

function getNagiosPlugin(){
    
    $description = "Developed by OpServices:\n\twww.opservices.com.br/suporte\n";
    $description .= "Author:\n\tSidney Souza - sidney.souza@opservices.com.br\n";
    $description .= "Description:\n\tThis plugin was created to monitoring the status of Quartz Jobs ";
    $description .= "that can be the lastJobFailed and jobStuck";
    
    $usage = "Usage:\n";
    $usage .= "\t%s -D < db-name > -U < username > -P < password > -j < job-name >\n";
    $usage .= "\t                      -g < job-group > -m < lastJobFailed | jobStuck > -M < minutes >";
    
    
    $np = new Nagios_Plugin(
        array(
            'usage' => $usage,
            'version' => "version 1.0",
            'blurb' => $description
        )
    );
    
    $np->add_arg("minutes|M=i", "Defines minimal minutes the job can be stuck.", 1);
    $np->add_arg("job-name|j=s", "Defines which job must be sought.", 1);
    $np->add_arg("db|D=s", "Defines which host to use.", 1);
    $np->add_arg("user|U=s", "Defines the user of database.", 1);
    $np->add_arg("password|P=s", "Defines the password of user.", 1);
    $np->add_arg("group|g=s", "Define which in group the job is sought.", 1);
    $np->add_arg("mode|m=s", "Define the mode this plugin work. Can be lastJobFailed or jobStuck", 1);
    
    $np->getopts();
    
    if( !preg_match('/lastJobFailed|jobStuck/',$np->opts['mode']) ){
        $np->nagios_exit(UNKNOWN, $np->print_usage());
    }

    return $np;
}

function invokeQuery($query, $np) {
    $options = $np->opts;

	if( isset($options['verbose']) ) {
		print "\n$query\n";
	}
	
	if (!$conn=oci_connect($options['user'],$options['password'],$options['db'])) {
		$err = OCIError();
		$np->nagios_die( "Erro ao conectar ao Oracle-> " .$err[message] );
	}
	
	$stid = oci_parse($conn, $query);
	oci_execute($stid);
	
	while (($row = oci_fetch_array($stid, OCI_ASSOC))) {
	    $result[] = $row;
	}
	
	oci_free_statement($stid);
	oci_close($conn);
	return $result;
}

function executeQueryAndVerbose($query, $np) {
    $options = $np->opts;    
    $result = invokeQuery( $query, $np );
    
    if( isset($options['verbose']) ) var_dump( $result ); 

    return $result;
  
}

function lastJobFailed($np) {
    $options = $np->opts;
                         
    $query = sprintf("select * from (
                           select to_char(data, 'DD/MM/YYYY HH24:MI:SS') as datalog,
                               (sysdate - data) * 1440 as diffMinutos,
                               case 
                                   when status = 'X' then 'Executando...'
                                   when status = 'F' then 'Executado com falhas'
                                   when status = 'S' then 'Sucesso!!'
                                   when status = 'E' then 'Erro' 
                                   else 'N/A' 
                               end as status
                           from logtarefasysclock logtarefa
                           join tarefasysclock systarefa 
                               on (logtarefa.tarefasysclock_id = systarefa.id)
                           where systarefa.nome = '%s'
                               and systarefa.grupo = '%s'
                               and logtarefa.status in ('F','E')
                               and (sysdate - data) * 1440 < %d
                          order by data desc ) joblogs 
                      where rownum = 1", $options['job-name'], $options['group'], $options['minutes']);

    $result = executeQueryAndVerbose($query, $np);
    
    $message = sprintf("%s-%s with STATUS: \"%s\" since %d minutes ago.", $options['group'], $options['job-name'], 
                                $result[0]['STATUS'], $result[0]['DIFFMINUTOS']);
                                
    ($result !== NULL) 
        ? $np->nagios_exit(CRITICAL, $message ) 
        : $np->nagios_exit(OK, "No Job Failed" );

}

function jobStuck($np) {
    $options = $np->opts;
    $query = sprintf("select * from (
                                select to_char(data, 'DD/MM/YYYY HH24:MI') as datalog,
                                       (sysdate - data) * 1440 as diffMinutos,
                                       ((sysdate - data) * 1440)/ 60 as diffHoras,
                                       'Executando...' as status
                                from logtarefasysclock logtarefa
                                join tarefasysclock systarefa on (logtarefa.tarefasysclock_id = systarefa.id)
                                where systarefa.nome = '%s' and 
                                      systarefa.grupo = '%s' and 
                                      logtarefa.status = 'X' and 
                                      (sysdate - data) * 1440 > %d
                               order by data desc ) joblogs 
                         where rownum = 1", $options['job-name'], $options['group'], $options['minutes']);
                         
    $result = executeQueryAndVerbose($query, $np);
    
    $message = sprintf("%s-%s stuck since %d minutes ago.", $options['group'], $options['job-name'], 
                                $result[0]['DIFFMINUTOS']);
                                
    ($result !== NULL) 
        ? $np->nagios_exit(CRITICAL, $message ) 
        : $np->nagios_exit(OK, "No Job Stuck" );

}

function debugParameter($np = NULL){

     if ( isset($np->opts['verbose'] ) ) {
          global $argv;
          $data = "Argument\n-----------------------------------\n";
          $data .= implode($argv, " ");
          $data .= "\n\n";
          file_put_contents("/tmp/" . basename($argv[0]) . ".debug", $data);
          echo $data . "\n";
          var_dump($np);
      }
}

function main(){
    $np = getNagiosPlugin();
    debugParameter($np);
        
    if($np->opts['mode'] == 'lastJobFailed')
        lastJobFailed($np);
       
    elseif ($np->opts['mode'] == 'jobStuck')
        jobStuck($np);    
    
    else 
        $np->nagios_die("UNKNOWN mode");
    
} 
    
main();

