#!/usr/bin/php -q
<?php

require_once("/usr/local/opmon/libexec/opservices/lib/php/Nagios/Plugin.php");

function getNagiosPlugin() {
    
    $description = "Developed by OpServices:\n\twww.opservices.com.br/suporte\n";
    $description .= "Author:\n\tSidney Souza - sidney.souza@opservices.com.br\n";
    $description .= "Description:\n\tThis plugin was created to monitoring how many e-mails ";
    $description .= "nfe account has at INBOX";
    
    $usage = "Usage:\n";
    $usage .= "\t%s -H < hostname > -U < username > -P < password > -w < warning > -c < critical >";
    
    
    $np = new Nagios_Plugin(
        array(
            'usage' => $usage,
            'version' => "version 1.0",
            'blurb' => $description
        )
    );

    $np->add_arg("hostname|H=s", "Defines which host to use.", 1);
    $np->add_arg("user|U=s", "Defines the user of email account.", 1);
    $np->add_arg("password|P=s", "Defines the password of user.", 1);
    $np->add_arg("warning|w=s", "Warning Threshold.", 1);
    $np->add_arg("critical|c=s", "Critical Threshold.", 1);
    
    $np->getopts();
    
    $np->set_thresholds( $np->opts['warning'], $np->opts['critical']);
    
    return $np;
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
    debugParameter();

    # A opção /novalidate-cert desativa a verificação do certificado ssl utilizado por padrão nos servidores imap.
    #TODO validar se um servidor que requer o certificado irá recusar a conexão.
	
    $srv = "{".$np->opts['hostname']."/novalidate-cert}Lixo Eletr&APQ-nico"; 
    $conn = imap_open($srv, $np->opts['user'], $np->opts['password']) or $np->nagios_die(imap_last_error());
   
    $countMessage = imap_num_msg($conn);

    imap_close($conn);
   
    $np->add_perfdata( "emails_junk", $countMessage, "", $np->threshold() );
    $status = $np->check_threshold($countMessage);

    $np->nagios_exit($status, "JUNK has $countMessage emails");
    
} 
    
main();

