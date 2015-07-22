#!/bin/bash
############################################################################################################################
# check_vplex-witness.sh
#
# Version    : 1.5
# Developer  : Sidney Souza
# E-mail     : sidney.souza@opservices.com.br
#
# Revision:
# 1.5	2015-22-07	Sidney Souza
#	Fixed test command because it not testing regex correctly in bash version 4.1
# Description: Used to monitoring EMC vplex's Objects
############################################################################################################################

# Constante
readonly VERSION=1.5

function _usage(){
	echo -e "Usage: $(basename $0) -H < IP VPLEX > -O < Object > -M < Mode > \n\t-U < user > -P < password > [-v][-V][-h]"
}

function _version(){
    echo "Version $VERSION"
    exit
}

function _help(){
    _usage

    echo "
$(basename $0) ${VERSION}

Developer by Opservices
Author: Sidney Souza

Description:
    Used to monitoring EMC vplex's Objects through vplex's webserver

    -H, --hostname
        IP or hostname of VPLEX Server
    -O, --object
        Object shown at mode session
    -M, --mode
        Monitoring's mode, can be cluster-status|director-status|vnx-storages-status|vplex-storages-status
    -U, --user
        User to access the vplex
    -P, --password
        User's password to access the vplex
    -s, --show-output
        Show objects can be to monitoring at mode
    -v, --verbose
        Show details for command-line debugging
    -h, --help
        Print detailed help screen
    -V, --version
        Print version information

"
    exit

}

############################################################################################################################
# @description: Retorna o dado em uma posição especifica do array.
# @params:      Integer $position, posição do array
# @return:      String $data, Dado encontrado na posição solicitada
############################################################################################################################
function _getDataAt(){
	local position=$1
	shift

	#
	# Troca o ';' por uma quebra de linha (\n) para que o grep possa obter
	# o dado na posição requerida e depois remove a numeração da linha
	# retornando apenas o dado solicitado.
	#
	local data=$(echo "$*" | tr ';' '\n' | grep -w "${position}:.*" | sed 's/[0-9]*://g')
	echo ${data}
}

############################################################################################################################
# @description: Obtêm os dados do vplex via webserver.
# @params:      String $path, Diretório onde o comando 'll' deve ser executado para receber os dados sobre o objeto passado
#               por parâmetro.
# @return:      JSON do VPLEX com os dados solicitados
############################################################################################################################
function _getCommandOutPut(){
    local path="$1"
    curl -s -X GET -d '{"args":"ll"}' -k -H "Username:${user}" -H "Password:${pass}" https://${host}/vplex/${path}/${object}

}

############################################################################################################################
# @description: Executa os comando para pegar os dados do webserver, faz o parse dos dados filtrando as informações uteis
#               para o monitoramento do objeto.
# @params:      String $path, Diretório onde o comando 'll' deve ser executado para para o receber os dados sobre o objeto
#               passado por parâmetro.
# @return:      Dados filtrados do JSON
############################################################################################################################
function _getDataObject(){
    local path="$1"

    #
    # Obtêm o json do vplex, remove as quebras de linha, adiciona as quebras
    # de linha novamente segundo o padrão necessário para realizar o parse,
    # remove o item 'info:' pois é desnecessário, adiciona a numeração de
    # linha e por fim remove dados não utilizados no monitoramento.
    #
    echo $(_getCommandOutPut "${path}" | xargs echo |
                                            sed 's/ }, { /\n/g' |
                                            grep -vi info:  |
                                            grep -n value: |
                                            sed 's/\([0-9]*\).*value: /;\1:/g;s/, name:.*//g')
}

############################################################################################################################
# @description: Valida se o parâmetro passado esta de acordo com a regexp
# @params:      String $1, item a ser validado
# @params:      String $2, regexp utilizada na validação
############################################################################################################################
function _validateParam(){
    if [[ ! "$1" =~ $2 ]]; then
    	_help
    fi
}

############################################################################################################################
# @description: Verifica se o objeto a ser monitorado é válido
# @params:      JSON $1, Dados retornados pelo webserver
############################################################################################################################
function _validateReturn(){

    if [ -z "$1" ]; then
        echo -e "Objeto não encontrado.\nVerifique se o parâmetro '-O' esta correto"
        exit 3
    fi

}

############################################################################################################################
# @description: Printa a mensagem na saída padrão e sai com o código informado.
# @params:      String $message, Mensagem que deverá ser mostrada na saída padrão
# @params:      String $status, Informa se o monitoramento esta OK ou não.
# @return:      Integer Status do monitoramento, 2 = Critical e 0 = OK
############################################################################################################################
function _quit(){
    local status=$1
    local message=$2

   	if [ "$status" != "ok" ]; then
		echo $(echo "CRITICAL: $message")
		exit 2
	else
		echo $(echo "OK: $message")
		exit 0

	fi
}

############################################################################################################################
# @description: Grava um log no /var/log. Utilizado em caso de erro.
############################################################################################################################
function _log(){
	local log=/tmp/$(basename $0).log
	touch $log
	chmod 777 $log
    echo "====================== executed at $(date +"%H:%M:%S %d/%m/%Y") ======================" >> $log
    echo "$output_webservice" >> $log
    echo "======================  log separator ======================" >> $log
}


############################################################################################################################
# @description: Retorna o dado em uma posição especifica do array.
# @params:      Array, Dados do objeto a ser monitorado
# @return:      String, Status do objeto
############################################################################################################################
function _getClusterStatus(){
	local mgmt=$( echo $1 | tr [:upper:] [:lower:] )
	local operState=$( echo $2 | tr [:upper:] [:lower:] )
	local adminState=$( echo $3  | tr [:upper:] [:lower:] )

	if [ "${mgmt}" != "ok" ] ||
	   [ "${operState}" != "in-contact" ] &&
	   [ "${operState}" != "clusters-in-contact" ] ||
	   [ "${adminState}" != "enabled" ]; then
		echo "error"
        _log
	else
		echo "ok"
	fi
}

############################################################################################################################
# @description: Trata e retorna o status do Storage
# @params:      String $1, campos Connectivity_Status ou Operational_Status
# @return:      String, status do storage
############################################################################################################################
function _getArraysStatus(){
	[ "$( echo $1 | tr [:upper:] [:lower:] )" != "ok" ] && echo "error" && _log || echo "ok"
}

############################################################################################################################
# @description: Trata e retorna o status dos Directores do vplex
# @params:      String $1, Status Operacional
# @params:      String $2, Status da Comunicação entre os Directores
# @return:      String, Status dos directores
############################################################################################################################
function _getDirectorStatus(){
	local operState=$(echo $1 | tr [:upper:] [:lower:] )
	local connState=$(echo $2 | tr [:upper:] [:lower:] )

	if [ "${connState}" != "ok" ] ||
	   [ "${operState}" != "ok" ]; then
		echo "error"
        _log
	else
		echo "ok"
	fi

}

############################################################################################################################
# @description: Função principal para monitoramento do status do cluster
# @params:      Array $data, Dados do objeto a ser monitorado.
# @return:      String $message, Mensagem de saída
# @return:      Integer $status, código de status do monitoramento
############################################################################################################################
function _cluster_status(){
    _validateParam "$object" "^(cluster-1|cluster-2|server)$"
    local data="$@"
    _validateReturn "$data"
    local name=$( _getDataAt 4 $data | tr [:lower:] [:upper:] )
    local mgmt=$( _getDataAt 3 $data )
	local operState=$(_getDataAt 5 $data )
	local adminState=$(_getDataAt 1 $data )

    _quit $(_getClusterStatus $mgmt $operState $adminState) "$name Admin_State='${adminState}'
                                                                    Operational_State='${operState}'
                                                                    Mgmt_Connectivity='${mgmt}'"

}

############################################################################################################################
# @description: Função principal para monitoramento do status do storage VNX
# @params:      Array $data, Dados do objeto a ser monitorado.
# @return:      String $message, Mensagem de saída
# @return:      Integer $status, código de status do monitoramento
############################################################################################################################
function _vnx_storages_status(){
    _validateParam "$object" "^EMC-CLARiiON-CKM[0-9]*$"
    local data="$@"
    _validateReturn "$data"
    local name=$( _getDataAt 5 $data | tr [:lower:] [:upper:] )
    local connState=$(_getDataAt 2 $data)
	_quit $(_getArraysStatus $connState) "$name Connectivity_Status='$connState'"

}

############################################################################################################################
# @description: Função principal para monitoramento do status dos directores
# @params:      Array $data, Dados do objeto a ser monitorado.
# @return:      String $message, Mensagem de saída
# @return:      Integer $status, código de status do monitoramento
############################################################################################################################
function _director_status(){
    _validateParam "$object" "^director-[0-9]-[0-9]-[[:alpha:]]$"
    local data="$@"
    _validateReturn "$data"
    local name=$( _getDataAt 20 $data | tr [:lower:] [:upper:] )
   	local operState=$( _getDataAt 21 $data | sed 's/\[ \| \]//g' | tr [:upper:] [:lower:] )
	local connState=$( _getDataAt 7 $data | tr [:upper:] [:lower:] )

    _quit $(_getDirectorStatus $operState $connState ) "$name Operational_Status='${operState}'
                                                              Communication_Status='${connState}'"
}

############################################################################################################################
# @description: Função principal para monitoramento do status do storage vplex
# @params:      Array $data, Dados do objeto a ser monitorado.
# @return:      String $message, Mensagem de saída
# @return:      Integer $status, código de status do monitoramento
############################################################################################################################
function _vplex_storages_status(){
    local data="$@"
    _validateReturn "$data"
    local name=$( _getDataAt 4 $data | tr [:lower:] [:upper:] )
    local operState=$(_getDataAt 5 $data)
	_quit $(_getArraysStatus $operState) "$name Operational_Status='${operState}'"

}

############################################################################################################################
# @description: Trata os parâmetros passados na linha de comando e seta as variáveis globais
# @params:      Array $params, Parâmetros enviados na linha de comando
############################################################################################################################
function _getOptions(){

    while [ -n "$*" ] ; do
	    case "$1" in
		    -H|--hostname) host=$2; shift 2;;
		    -O|--object) object=$2; shift 2;;
		    -M|--mode) mode=$2; shift 2;;
		    -U|--user) user=$2; shift 2;;
		    -P|--password) pass=$2; shift 2;;
		    -v|--verbose) set -x; shift;;
		    -h|--help) _help;;
		    -s|--show-output) show=1; shift;;
		    -V|--version) _version;;
		    *) _usage; exit;;
	    esac
    done

    if [ -z "$host" ] || [ -z "$mode" ] ||
       [ -z "$user" ] || [ -z "$pass" ]; then
	    _usage
	    exit
    fi

    _validateParam "$mode" "^(cluster-status|director-status|vnx-storages-status|vplex-storages-status)$"

}

############################################################################################################################
# @description: Rotina principal do plugin.
############################################################################################################################
function _main(){

    # Simula um Hash_Table associando os modos de execução as querys que serão executadas no servidor.
    local commands="_cluster_status:cluster-witness/components\n
                _vnx_storages_status:clusters/cluster-*/storage-elements/storage-arrays\n
                _director_status:engines/engine-*/directors\n
                _vplex_storages_status:clusters/cluster-*/exports/storage-views"

    # Substitui o caracter '-' pelo '_' na variável mode
    local function="_${mode//-/_}"

    # Simula a utilização de hash_tables, necessário devido a uma limitação do bash 3.X que não implementa hash por default
    local command="$(echo -e ${commands} | grep ${function} | sed 's/.*://')"

    # Utilizado para debug
    output_webservice=$(_getCommandOutPut "$command")

    if [ -n "$show" ]; then
	    echo "$output_webservice"
    else
        $function $(_getDataObject "$command")
    fi

}

############################################################################################################################
#  Inicio do fluxo principal
############################################################################################################################
_getOptions $*
_main
