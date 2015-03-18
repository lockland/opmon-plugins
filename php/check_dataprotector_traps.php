#!/usr/bin/php
<?php

#Habilita a exibição de erros (strict)
//error_reporting(E_ALL);

include "/usr/local/opmon/etc/config.php";

$mod = "EXTERNAL";

set_logged_user("opmonadmin");

// global stuff
define("_VERSION", '1.4-8');

//--------------------------------------------- Classe ---------------------------------------------
class ServiceObject {
    private $service_id;
    public $host;
    private $use_template_id;
    private $service_description;
    private $parameter;
        
    public function __construct(Host $host){
        $this->service_id(0);
        $this->host = $host;
        $this->use_template_id(0);
        $this->service_description('');
    }
    
    public function service_id($service_id = null){ 
		if ($service_id !== null)
			$this->service_id = $service_id;
		else
			return $this->service_id; 
	}

    public function use_template_id($use_template_id = null){ 
		if ($use_template_id !== null)
			$this->use_template_id = $use_template_id;
		else
			return $this->use_template_id; 
	}

    public function service_description($service_description = null){ 
		if ($service_description !== null)
			$this->service_description = $service_description;
		else
			return preg_replace('/\s/', '-', $this->service_description);
	}

    public function parameter($parameter = null){ 
		if ($parameter !== null)
			$this->parameter = $parameter;
		else 
		    return $this->parameter;
	}
	
	public function toHash(){
        $hash = array(
            "host_id" => $this->host->get_host_id(),
            "service_description" => $this->service_description(),
            "use_template_id" => $this->use_template_id(),
        );
        
        return $hash;
    }

} // End Class ServiceObject
//--------------------------------------------- Fim ------------------------------------------------

//--------------------------------------------- Classe ---------------------------------------------
class Trap {
    private $entry_time;
    private $formatline;
    private $id = 0;

    public function __construct($tuple){
        $this->id($tuple['id']);
        $this->entry_time($tuple['entry_time']);
        $this->formatline($tuple['formatline']);
    }

    public function entry_time($entry_time = null){
        if ($entry_time !== null)
            $this->entry_time = $entry_time;
        else 
            return $this->entry_time;
    }

    public function formatline($formatline = null){
        if ($formatline !== null)
            $this->formatline = $formatline;
        else 
            return $this->formatline;
    }
    
   public function id($id = null){
        if ($id !== null)
            $this->id = $id;
        else 
            return $this->id;
    }
    
} // End Class Trap
//--------------------------------------------- Fim ------------------------------------------------

//--------------------------------------------- Classe ---------------------------------------------

class DataBase {

    private static $instance = null;
    
    private function __construct (){}
    
    public static function getInstance(){
        if (!isset(self::$instance) && is_null(self::$instance)) {
            $c = __CLASS__;
            self::$instance = new $c;
        }
        
        return self::$instance;

    }

    public function setTrapRead($id){
        $sql = 'UPDATE snmptt SET trapread = 1 WHERE id = ' . $id;
        
        if (DEBUG == 1 ) {
            $message = "\n>>> Function " . __FUNCTION__ . "\n";
            $message .= "\nQuery\n------------------------------\n";
            debugger($message, $sql);
        }
        
        do_query($sql, 'snmptt');
    }
    
    public function getMountRequestTrap($host_address){
        
        $sql = "SELECT 
                    id, 
                    REPLACE(formatline, '\\\\', '') AS formatline, 
                    entry_time 
                FROM 
                    snmptt 
                WHERE 
                    formatline like '%%MountRequest%%' 
                    AND trapread = 0 
                ORDER BY id DESC
                LIMIT 1";
        
        if (DEBUG == 1 ) {
            $message = "\n>>> Function " . __FUNCTION__ . "\n";
            $message .= "\nQuery\n------------------------------\n";
            debugger($message, $sql);
        }
        
        return $this->executeQuery($sql);
    }
    
    public function getLastTrapNotRead($host_address, $backup_name){
        $config = array (
            'host_address' => $host_address,
            'backup_name' => $backup_name,
            'limit' => 1
        );

		$sql = $this->getBackupQuery($config);
		
		if (DEBUG == 1 ) {
		    $message = "\n>>> Function " . __FUNCTION__ . "\n";
            $message .= "\nQuery\n------------------------------\n";
            debugger($message, $sql);
        }
        
        return $this->executeQuery($sql); 
    }
    
    public function getLastTrapRead($host_address, $backup_name){
        $config = array (
            'host_address' => $host_address,
            'backup_name' => $backup_name,
            'limit' => 1,
            'trapread' => true
        );
        $sql = $this->getBackupQuery($config);
        
        if (DEBUG == 1 ) {
            $message = "\n>>> Function " . __FUNCTION__ . "\n";
            $message .= "\nQuery\n------------------------------\n";
            debugger($message, $sql);
        }
        
        return $this->executeQuery($sql); 
    }

    public function getAllTrapsNotRead($host_address){
        $config = array (
            'host_address' => $host_address,
        );
        
        $sql = $this->getBackupQuery($config);
        
        if (DEBUG == 1 ) {
            $message = "\n>>> Function " . __FUNCTION__ . "\n";
            $message .= "\nQuery\n------------------------------\n";
            debugger($message, $sql);
        }
        
        return $this->executeQuery($sql, true); 
    }


    private function getBackupQuery($config = array()){
    
        $sql = "SELECT 
                    id, 
                    REPLACE(formatline, '\\\\', '') AS formatline, 
                    entry_time 
                FROM 
                    snmptt 
                WHERE 
                    formatline like '%session id\=%'
                        ";
                        
        if( isset($config['backup_name']) ) {
            $sql .= "AND formatline like '%=%\"" . $config['backup_name'] . "\\\\\\%'
            " ;
        }
        
        if ( isset($config['trapread']) && $config['trapread'] == true ){
            $sql .= "AND trapread = 1
            ";
        } else {
            $sql .= "AND trapread = 0
            ";
        }

        $sql .= "ORDER BY id DESC
        ";
        
        if (isset($config['limit'])){
            $sql .= "LIMIT " . $config['limit'] . "
            ";
        }
        
        return $sql;
    }
    
    private function executeQuery($sql, $ALL = false){
        
        $query_result = do_query($sql, 'snmptt');
        
        $message = "";
        
        if ( DEBUG > 1)
            $message .= "\n>>> Function " . __FUNCTION__ . "\n";
        
        if (DEBUG >= 2 ) {
            $message .= "\nQuery\n------------------------------\n";
            debugger($message, $sql);
            
            $message = "Query Result\n------------------------------\n";
            debugger($message, $query_result);
        }
        
        if ($ALL)
            while(!$query_result->EOF){
                $result[] = $query_result->fields;
                $query_result->MoveNext();
            }
        else 
            $result = $query_result->fields;
            
        $query_result->Close();
        
        if (DEBUG == 3 ) {
            $message = "\nInterated Result\n------------------------------\n";
            debugger($message, $result);
        }

        return $result;
    }


} // End Class DataBase

//--------------------------------------------- Fim ------------------------------------------------

//--------------------------------------------- Classe ---------------------------------------------

abstract class Element {

    protected $trap;
    
    public function __construct (Trap $trap){
        $this->trap = $trap;
    }
    
    // Retorna o status segundos os thresholds
    abstract public function getStatus();
    
    protected function getFormatLineFields($pattern){
        $matches = array();
        preg_match(
            $pattern, 
            $this->trap->formatline(), 
            $matches
        );
        
       if (DEBUG == 3 ) {
            $message = "\n>>> Function " . __FUNCTION__ . "\n";
            $message .= "\nPattern\n------------------------------\n";
            debugger($message, $pattern);
            
            $message = "\nMatches\n------------------------------\n";
            debugger($message, $matches);
        }
        
        return $matches;
    }

    protected function setAttributes($fields){
    
        foreach ($fields as $method_name => $data){
            if ( !is_numeric($method_name) ) {
	            if (strlen($data) <= 0) throw new Exception("Trap com formato inválido\n");
                
                $this->{$method_name}($data);
            }
        }
    }
    
}

//--------------------------------------------- Fim ------------------------------------------------

//--------------------------------------------- Classe ---------------------------------------------
class Backup extends Element{

    private $name;
    private $period;
    private $has_error;
    private $group;
    private $session_id;


    public function __construct (Trap $trap){
        parent::__construct($trap);
        $this->name = '';
        $this->period = 'diario';
        $this->has_error = -1;
        $this->group = 'Default';
        $this->session_id = '';
        
        $fields = $this->getFormatLineFields(
            '/.*="(?P<session_id>.*)",.*="(?P<name>.*)",.*="(?P<group>.*)",.*="(?P<has_error>.*)",/'
        );
        
        $this->setAttributes($fields);
    
    }

    public function name($name = null){
        if ($name !== null)
            $this->name = $name;
        else 
            return $this->name;
    }

    public function period($period = null){
        if ($period !== null)
            $this->period = $period;
        else 
            return $this->period;
    }

    public function has_error($has_error = null){
        if ($has_error !== null)
            $this->has_error = $has_error;
        else 
            return $this->has_error;
    }

    public function group($group = null){
        if ($group !== null)
            $this->group = $group;
        else 
            return $this->group;
    }

    public function session_id($session_id = null){
        if ($session_id !== null)
            $this->session_id = $session_id;
        else 
            return $this->session_id;
    }
    
    public function getStatus(){
        if ($this->has_error < 0 ) {
            return UNKNOWN;
        } else if ($this->has_error > 0 ) {
            return CRITICAL;
        } else {
            return OK;
        }
    }

} // End Class Backup
//--------------------------------------------- Fim ------------------------------------------------

//--------------------------------------------- Classe ---------------------------------------------
class MountPoint extends Element{

    private $device_name;

    public function __construct (Trap $trap){
        parent::__construct($trap);
        $this->device_name = '';
        $fields = $this->getFormatLineFields('/.*\\"(?P<device_name>.*)"$/');        
        $this->setAttributes($fields);
    }

    public function device_name($device_name = null){
        if ($device_name !== null)
            $this->device_name = $device_name;
        else 
            return $this->device_name;
    }
    
    public function getStatus(){
        if ($this->trap->id() > 0 ) {
            return CRITICAL;
        } else {
            return OK;
        }
    }

} // End Class MountPoint
//--------------------------------------------- Fim ------------------------------------------------

//--------------------------------------------- Classe ---------------------------------------------

class API {
    
    public $configurator;
    
    public function __construct(){
        $cm = new ConfigManager();
        $this->configurator = $cm->cfg;
    }

    public function get_host_by_name( $name ){
        $id_host = get_host_id_by_name( $name );
        
        if (!is_numeric($id_host)){
            throw new InvalidArgumentException("Nome do host é invalido\n");
        }
        
        return get_host_by_id( $id_host );
    }
    
    public function get_template_by_name( $name ){
        $sql = sprintf("SELECT * FROM nagios_service_templates WHERE template_name = '%s'", $name);
        $query_result = do_query($sql, 'opcfg');
        $tuple = $query_result->fields;
        $query_result->Close();
        
        if ($tuple == false){
            throw new InvalidArgumentException("Nome do template é invalido\n");
        }
        
        $template = (object) $tuple; // Converte hash para um objeto stdClass
        return $template;
    }
    
    public function add_service(ServiceObject $service) {
            
        $service_id = $this->configurator->return_service_id_by_host_and_description(
            $service->host->get_host_id(),
            $service->service_description()
        );

        // Verifica se o AIC a ser inserido já está ou não no monitoramento. Se não estiver (id = 0)
        // ele será inserido.
        if ($service_id == 0) {
            $config = $service->toHash();

            $this->configurator->add_service($config);        

            $service_id = $this->configurator->return_service_id_by_host_and_description(
                $service->host->get_host_id(),
                $service->service_description()
            );
            
            $service->service_id( $service_id );
            
            $this->configurator->add_service_command_parameter_straight( 
                $service->service_id(), 
                $service->parameter()
            );
            
            return TRUE;
        }
        
        return FALSE;
    }
    
    public function export(){
        $running_workers = TaskRunner::getRegisteredWorkers();
        
        if ( !isset($running_workers['startExport']) || $running_workers['startExport'] != 1) {
	        throw new Exception ("Worker para export nao esta rodando\n");
        }
        
        $command = sprintf (
            "%s %s %s '%s' '%s' %s", 
            '/usr/bin/nohup',
            '/usr/bin/php -q',
            '/var/local/opmon/share/opcfg/tools/exporter/export.php 1',
            'opmonadmin',
            '127.0.0.1',
            '>/dev/null 2>/dev/null &'
        );

        $data = array(
            "command" => $command,
            "log_file" => "/var/local/opmon/share/opcfg/logs/export.log"
        );

        $ret = TaskRunner::run("startExport",json_encode($data));
        if (!$ret) {
	        throw new Exception ("Export falhou\n");
        }
    }

} // End Class API
//--------------------------------------------- Fim ------------------------------------------------

//----------------------------------------- Functions ----------------------------------------------

function debugger($message, $variable){

    echo "$message";
    ( is_object($variable) ) ? var_dump($variable) : print_r($variable);

}


//-------------------------------------------- Modules ---------------------------------------------

function getBackupStatus(Host $host, $backup_name){

    $db = DataBase::getInstance();
    
    if (DEBUG == 3 ) {
        $message = "\n>>> Function " . __FUNCTION__ . "\n";
        $message .= "\nDB instance\n------------------------------\n";
        debugger($message, $db);
    }

    $tuple = $db->getLastTrapNotRead($host->get_address(), $backup_name);
    
    $service_description = preg_replace('/\s/', '-', $backup_name );
    $service_id = get_service_id(
        $host->get_host_name(), 
        $service_description
    );
    
    //Se todas as traps já tiverem sido lidas, mantém o status
    if ($tuple == FALSE){
        $tuple = $db->getLastTrapRead($host->get_address(), $backup_name);
        
        if (DEBUG == 3 ) {
            $message = "\nTuple Read\n------------------------------\n";
            debugger($message, $tuple);
        }
        
    } else {
        $prop = array(
            "host_id" => $host->get_host_id(),
            "service_id" => $service_id,
            "time" => time(),
            "host_name" => $host->get_host_name(),
            "service_description" => $service_description
        );
        #@FIXME dando erro (255 get_contact_id) para alguns serviços na interface .
        #@DONE Após realizar um export passou a funcionar corretamente
        
        if (DEBUG == 3 ) {
            $message = "\nProperty\n------------------------------\n";
            debugger($message, $prop);
        }
        
        Cmd::serviceRemoveAcknowledgeProblem( $prop );
    }

    $trap = new Trap( $tuple );
    
    DataBase::setTrapRead( $trap->id() );
    
    try{ 
        $backup = new Backup($trap); 
    } catch (Exception $e){
        echo $e->getMessage();
        exit(CRITICAL);
    }
    
    if (DEBUG == 3 ) {
        $message = "\nBackup instance\n------------------------------\n";
        debugger($message, $backup );
    }
    
    $status = $backup->getStatus();

    #FIXME Validação para ocasiões onde não há traps para o backup
    if ($status == CRITICAL ) {
        $message = "CRITICAL: Session ID={$backup->session_id()} Specification={$backup->name()}";
    } else if ($status == OK ) {
        $message = "OK: Session ID={$backup->session_id()} Specification={$backup->name()}";
    } else {
        $message = "UNKNOWN: Não foi encontrado traps para esse backup";
        $status = UNKNOWN;
    }

    echo "$message\n";
    exit($status);
}

function addServices (API $manager, Host $host, $template){

    $db = DataBase::getInstance();
    
    if (DEBUG == 3 ) {
        $message = "\n>>> Function " . __FUNCTION__ . "\n";
        $message .= "\nDB instance\n------------------------------\n";
        debugger($message, $db);
    }
    
    $backupTuples = $db->getAllTrapsNotRead( $host->get_address() );
    
    $services_added = FALSE;

    // Serviços de backup
    foreach ( $backupTuples as $tuple ){
        $trap = new Trap($tuple);
        try{
            $backup = new Backup($trap);
        } catch (Exception $e){
            echo $e->getMessage();
            exit(CRITICAL);
        }
    
        $service = new ServiceObject($host);

        $service->service_description( $backup->name() );
        $service->use_template_id( $template->service_template_id );
        $service->parameter(sprintf (
                "-S %s -b '%s' -m getBackupStatus", 
                $host->get_host_name(),
                $backup->name()
            )
        );
        
        if (DEBUG == 3 ) {
            $message = "\nService\n------------------------------\n";
            debugger($message, $service);
        }
        
        $services_added = $manager->add_service( $service );
        
    }
    
    // Serviço de mount request
    $service = new ServiceObject( $host );
    $service->service_description( 'MountRequest' );
    $service->use_template_id(  $template->service_template_id );
    $service->parameter( sprintf (
            "-S %s -m 'MountRequest'", 
            $host->get_host_name()
        )
    );
    
    if (DEBUG == 3 ) {
        $message = "\nService MountRequest\n------------------------------\n";
        debugger($message, $service);
    }
    
    $services_added = $manager->add_service( $service );
    
    try {
    
        if ( $services_added )
            $manager->export();
            
        echo "Serviços adicionados com sucesso\n";
        exit (OK);
    } catch (Exception $e){
        echo $e->getMessage();
        exit (UNKNOWN); 
    }
}

function mountRequest(Host $host){
    $db = DataBase::getInstance();
    
    if (DEBUG == 3 ) {
        $message = "\n>>> Function " . __FUNCTION__ . "\n";
        $message .= "\nDB instance\n------------------------------\n";
        debugger($message, $db);
    }
    
    $tuple = $db->getMountRequestTrap( $host->get_address() );

    $trap = new Trap($tuple);

    DataBase::setTrapRead( $trap->id() );

    $mountPoint = new MountPoint($trap);

    if (DEBUG > 3 ) {
        $message = "\nMountPoint\n------------------------------\n";
        debugger($message, $mountPoint);
    }
    
    $status = $mountPoint->getStatus();
    
    if ($status != OK )
        $message = "CRITICAL: Mount request on device \"{$mountPoint->device_name()}\"";
    else
        $message = "OK: Has no mount request";

    echo "$message\n";
    exit($status);

}


//--------------------------------------------- Fim ------------------------------------------------

function help($only_version = FALSE){
	global $argv;
	$path = '/usr/local/opmon/libexec/custom';
	$basename = basename($argv[0]);

$help = <<<HELP

Description:
    Criado para realizar adição automática/monitoramento dos serviços de backup do Data-Protector
    na plataforma OpMon.
    
Developed by:
    OpServices - www.opservices.com.br/suporte
    
Author:
    Sidney Souza - sidney.souza@opservices.com.br
    
Usage: 
    $basename [-V] [-h] -H < host_address > -t < template_name > [-v < 1|2|3 > ] 

Options:
    -v
        Mostrar versão
    -h
        Mostrar esse help
    -S 
        Nome do IC, adicionado ao OpMon, que recebera os monitoramentos.
    -t 
        Nome do service_template que será utilizado ao adicionar novos monitoramentos.
    -v
        Modo Verbose 

Instalation:
    Para a instalação devemos seguir os seguintes passos:
    1) Copie o plugin para o diretório $path
    
    2) Permissão de execução: chmod +x $path/$basename
    
    3) Criar um IC no OpMon que recebera os monitoramentos.
      OBS: É importante que o IC cadastrado no OpMon tenha o mesmo IP que o host que gera as Traps
    
    4) Crie o comando que irá executar as checagens conforme exemplo abaixo: 
       \$USER1$/custom/$basename \$ARG1\$
      
    5) Criar um service_template que irá configurar os monitoramentos.
       PS: Necessário configurar o comando criado acima na sessão command.
    
    6) Configurar o crontab para excluir as traps com tempo igual a 2x[ maior tempo dos backups ] 
      Ex: maior_tempo = 1 mês, excluir_traps = 2 meses.
      Conf => /usr/local/opmon/utils/clean_table_by_field.php snmptt snmptt entry_time 60 >/dev/null 2>/dev/null
    
    7) Crie um serviço no IC com as seguintes configurações:
      command = [comando adicionado no passo 4]
      parameter = "-S [nome do ic criado no passo 3] -t [nome do template criado no passo 5]"
      Normal Check Interval = 60 min ou mais.      

Depends:
    Para que este plugin funcione corretamente é necessário que a mib do Data Protector esteja
    traduzida e com a mensagem no seguinte formato:
    "FORMAT Data Protector. Severity=$5;Message=$6;DataList=$7"

    *****************************************************************************
    *  Exemplo de como deve ficar a tradução da mib no arquivo de configuração  *
    *****************************************************************************
    
    EVENT dpTrap .1.3.6.1.4.1.11.2.17.1.0.59047936 "Status Events" Normal
    #FORMAT A trap with this value identifies Data Protector. $*
    FORMAT Data Protector. Severity=$5;Message=$6;DataList=$7
    SDESC
    A trap with this value identifies Data Protector.
    Variables:
      1: dpSourceId
      2: dpSourceName
      3: dpObjectName
      4: dpApplicationName
      5: dpSeverity
      6: dpMessageText
      7: dpDataList
    EDESC


HELP;

	if ($only_version) {
		printf ("%s v%s\n", $basename, _VERSION);
		exit (OK);
	}
	
	echo $help;
	exit (OK);
}
/**
 * http://stackoverflow.com/questions/2197851/function-list-of-php-file
 * http://stackoverflow.com/questions/17455043/how-to-get-functions-parameters-names-in-php
 * http://www.php.net/manual/pt_BR/function.get-class-methods.php
 * http://stackoverflow.com/questions/1869091/convert-array-to-object-php
 */

function main() {

	$opts = getopt("Vhm:b:S:t:v:");
	
	if (isset($opts['v'])) {
	    define("DEBUG", $opts['v'] );
	} else {
	    define("DEBUG", 0 );
	}

	if (isset($opts['h'])){
		help();
	}

	if (isset($opts['V'])){
		help(true);
	}
	
	if (!isset($opts['S'])){
		echo "Argumento -S < server_name > é obrigatório\n";
		return;
	}
    
	if ( !isset( $opts['m'] ) && !isset($opts['t']) ){
		echo "O Argumento -t < template_name > é obrigatório\n";
		return;
	}

    $manager = new API();

    try {
            
        if ( !isset( $opts['m'] ) )
            $template = $manager->get_template_by_name( $opts['t'] );
        $data_protector = $manager->get_host_by_name( $opts['S'] );
    
    } catch (Exception $e){
        echo $e->getMessage();
        exit(CRITICAL);
    }
    
    if ( !isset( $opts['m'] ) ) {
        addServices($manager, $data_protector, $template);
        
    } else if ( strtolower( $opts['m'] )  == 'getbackupstatus') {
        getBackupStatus($data_protector, $opts['b'] );
        
    } else if ( strtolower( $opts['m'] )  == 'mountrequest') {
        mountRequest($data_protector);
    }

}
main();
//
?>
