#!/usr/bin/perl -w

=header
AUTOR: Sidney Souza
CRIADO EM: 03/11/2014

REVISÕES:
--------------------------------------------------------------
<versão> <Data da Revisão>, <autor da revisao>
    - <Descrição das modificações>

=cut

use strict;
use warnings;
use English;
use Switch;
use Nagios::Plugin;
use File::Basename;
use vars qw ($np);

use POSIX;
use LWP::UserAgent;
use HTTP::Request;

use constant{
       TRUE => 1,
      FALSE => 0,
    VERSION => '2.1',
};

################################################################################
# Exibi o manual do software
################################################################################

sub getGuideLine() {

    my $name = basename($PROGRAM_NAME);
    my $path = "/usr/local/opmon/libexec/opservices";

    print <<EOF;

--------------------------------------------------------------------------------
Manual.
--------------------------------------------------------------------------------

Descrição do plugin:
    Este plugin realiza o envio de sms via webservices.

Instalação:
    Copiar este plugin para o diretório $path

    Adicionar permissão de execução:
    chmod +x $path/$name

    Configurar o comando no OpMon.

    Adicionar o comando aos contatos que irão receber as notificações.

    OBS: O contato deve ter o numero do celular no seguinte padrão: 5100000000.

Dependências:
    perl module English
    Instalação: yum install "perl(English)" -y

    perl module Switch
    Instalação: yum install "perl(Switch)" -y

    perl module File::Basename
    Instalação: yum install "perl(File::Basename)" -y

    perl module LWP::UserAgent
    Instalação: yum install "perl(LWP::UserAgent)" -y

    perl module HTTP::Request;
    Instalação: yum install "perl(HTTP::Request)" -y

    perl module Nagios::Plugin;
    Instalação: yum install "perl(Nagios::Plugin)" -y

Funcionamento:
    O plugin será executado pelo OpMon e irá gerar a notificação baseado nos
    dados armazenados em variáveis de ambiente. Esses dados são coletados e
    enviados ao webservices via GET onde são definidos 3 parâmetros:
    DDD = composto por dois digitos
    tel = numero que recebera a mensagem
    msg = mensagem propriamente dita

    Após receber os dados o webservices realiza o envio da mensagem e retorna
    uma página com o conteúdo OK (caso a mensagem tenha sido enviada) ou com o
    erro gerado na execução.

    Para fins de teste é possível utilizar o parâmetro "-e test" que o plugin
    irá gerar uma mensagem com dados fictícios e enviará para o contato informa-
    do no parâmetro "-n" ou ainda executar um wget conforme exemplo a seguir:

    \$ wget -O - "http://<ip>:<porta>/sms?ddd=51&tel=00000000&msg=sender_message"

Exemplos de execução e retorno do comando:

    # Parametro type não foi definido ou é inválido.
    ./$name
    UNKNOWN - Invalid type value (host|service|test).

    # Numero de telefone do contato não foi definido ou é inválido.
    ./$name -H <address> -p <port> -e test -n 0519999999999999999
    UNKNOWN - The number informed has the wrong formatting. 0519999999999999999 Please use 5100000000

    # Mensagem enviada com sucesso para o contato
    ./$name -H <address> -p <port> -e test -n 51999999999
    OK - The message has been sent

    # Falha ao enviar sms para o contato
    ./$name -H <address> -p <port> -e test -n 51999999999
    CRITICAL - Internal Server Error: << server error>>


EOF
    exit (OK);

}

sub setNagios() {

    # Constructor
    $np = Nagios::Plugin->new(
        url => "www.opservices.com.br/suporte",
        shortname => "\r", # Elimina o shortname
        version => VERSION,
        license => "Developed by:\n\tOpServices\n"
            . "Author: \n\tSidney Souza - sidney.souza\@opservices.com.br\n",
        usage => "Usage:\n\t%s -H <hostaddress> -p <port> -e <type> -n <number>"
    );

    $np->add_arg(
        spec => "man",
        help => ["Show guideline"]
    );

    $np->add_arg(
        spec => "to|n=i",
        required => TRUE,
        default => "",
        help => ["Contact phone number to send the"
        . " messagem. Must be like \"5100000000\""]
    );

    $np->add_arg(
        spec => "type|e=s",
        required => TRUE,
        default => "",
        help => ["Type of message to send: service,host or test."]
    );

       $np->add_arg(
        spec => "host|H=s",
        required => TRUE,
        default => "",
        help => ["WebServices address."]
    );

    $np->add_arg(
        spec => "port|p=i",
        required => TRUE,
        default => "",
        help => ["WebServices port."]
    );

    $np->getopts;

}

sub validateParameter(){

    $np->nagios_die(
        "Invalid type value (host|service|test)."
    ) if ($np->opts->type !~ /^(host|service|test)$/);

    $np->nagios_die(
        "Invalid debug value (1|2)\n"
    ) if ( $np->opts->verbose !~ /^(0|1|2)$/ );

}

sub getMessage($) {
    my ($type) = @ARG;
    my $msg = "";
    my %test = (
                'Type' => 'DOWNTIMECANCELLED',
                'Date' => '00-00-0000 00:00:00',
            'HostName' => 'HOSTNAME',
         'ServiceName' => 'SERVICEDESC',
        'ServiceState' => 'SERVICESTATE',
    );

    my %opmon = (
        'NotificationType' => $ENV{'NAGIOS_NOTIFICATIONTYPE'},
                    'Date' => $ENV{'NAGIOS_SHORTDATETIME'},
                'HostName' => $ENV{'NAGIOS_HOSTNAME'},
             'HostAddress' => $ENV{'NAGIOS_HOSTADDRESS'},
               'HostState' => $ENV{'NAGIOS_HOSTSTATE'},
             'ServiceName' => $ENV{'NAGIOS_SERVICEDESC'},
            'ServiceState' => $ENV{'NAGIOS_SERVICESTATE'},
                  'Detail' => $ENV{'NAGIOS_SERVICEOUTPUT'}
    );

    if ($type eq "host"){

        $msg = sprintf(
            "%s\nHost: %s\nState: %s\nAddress: %s\nDate/Time: %s",
            $opmon{'NotificationType'},
            $opmon{'HostName'},
            $opmon{'HostState'},
            $opmon{'HostAddress'},
            $opmon{'Date'}
        );

    } elsif ($type eq "service") {

        $msg = sprintf(
            "%s\nHost: %s\nService: %s\nState: %s\nDate/Time: %s",
            $opmon{'NotificationType'},
            $opmon{'HostName'},
            $opmon{'ServiceName'},
            $opmon{'ServiceState'},
            $opmon{'Date'}
        );

    } elsif ($type eq "test") {

        $msg = sprintf(
            "%s\nHost: %s\nService: %s\nState: %s\nDate/Time: %s",
            $test{'Type'},
            $test{'HostName'},
            $test{'ServiceName'},
            $test{'ServiceState'},
            $test{'Date'}
        );

    }
    return $msg;
}

sub getDddAndPhoneNumber($) {

    my ($contactNumber) = @ARG;

    # Se o contato não for definido ou se o tamanho for menor que
    # 10 (dd + numero)
    $np->nagios_die(
        "The number informed has the wrong formatting. $contactNumber"
        . " Please use 5100000000.\n"
    ) if (length($contactNumber) ne 10 );


    my $ddd = substr($contactNumber, 0, 2);
    my $tel = substr($contactNumber, 2, 10);

    return ($ddd, $tel);
}

sub logger($) {
    my ($msg) = @ARG;
    my $name = basename($PROGRAM_NAME);
    $name =~ s/.pl//;
    my $path = `pwd`;
    chomp($path);
    my $log = "$path/$name.log";
    my $date = strftime("%d/%m/%Y - %H:%M:%S",localtime);

    if ($np->opts->verbose == 1) {
        print "$msg\n";
    } elsif ($np->opts->verbose == 2) {
        open(LOG, ">>$log");
        print LOG "$date => $msg\n";
        close(LOG);
    }
}

sub sendMessage($){

    my ($url) = @ARG;

    my $userAgent = LWP::UserAgent->new;

    my $agent = "Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.9)"
    . " Gecko/2008052912 Firefox/3.0";

    $userAgent->agent("$agent");

    my $request = new HTTP::Request GET => "$url";
    my $response = $userAgent->request($request);

    logger("----- Resposta -----");
    logger($response->as_string());

    return $response;

}

sub main() {

    setNagios();

    getGuideLine() if ($np->opts->man);

    validateParameter();

    #Phone Number Data
    my ($DDD,$phoneNumber) = getDddAndPhoneNumber($np->opts->to);
    logger("----- DDD e Numero -----");
    logger("$DDD $phoneNumber");

    #Get enviroment info
    my $message = getMessage($np->opts->type);

    logger("----- Mensagem -----");
    logger("$message");

    my $url = sprintf (
        "http://%s:%s/sms?ddd=%s&tel=%s&msg=%s",
        $np->opts->host,
        $np->opts->port,
        $DDD,
        $phoneNumber,
        $message
    );

    logger("----- URL -----");
    logger($url);

    my $response = sendMessage($url);

    $np->nagios_exit(
        return_code => $np->OK,
        message => "The message has been sent"
    ) if ( $response->content eq "OK" );

    $np->nagios_exit(
        return_code => $np->CRITICAL,
        message => "Internal Server Error: " . $response->content
    );

}
&main;
