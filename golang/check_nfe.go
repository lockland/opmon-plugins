package main

import (
    "crypto/x509"
    "crypto/rsa"
    "flag"
    "io/ioutil"
    "log"
    "os"
    "fmt"
    "strings"
    "net/http"
    "encoding/pem"
    "encoding/xml"

    "golang.org/x/crypto/pkcs12"
    curl "github.com/andelf/go-curl"
)

var (
    in = flag.String("certificate", "", "Certificado no formato pkcs#12 (deve conter apenas chave privada e certificado)\n")
    password = flag.String("password", "", "Senha do certificado\n")
    uf = flag.String("uf", "", "Sigla do estado: AC, AL, AM, AP, BA, CE, DF, GO, ES, MA, MG, MS, MT, PA, PB, PE, PI, PR, RJ, RN, RO, RR, RS, SC, SE, SP, TO\n")
    infoCert = flag.Bool("infocert", false, "Mostra as informações extraídas do certificado\n")
    version = flag.Bool("version", false, "Mostra a versão do plugin\n")
    verbose = flag.Int("verbose", 0, "nível de verbose [0-9]")
)

const (
    OK = 0
    WARNING = 1
    CRITICAL = 2
    UNKNOWN = 4
    OBJECT = "%v"
    OBJECT_WITH_PROPERTIES = "%#v"
    HTTP_OK = 200
    STATUS_OK = 107
    VERSION = "1.0.2"
)

//@link https://tutorialedge.net/golang/parsing-xml-with-golang/
type Message struct {
    TpAmb int `xml:"tpAmb"`
    VerAplic string `xml:"verAplic"`
    CStat int `xml:"cStat"`
    XMotivo string `xml:"xMotivo"`
    CUF int `xml:"cUF"`
    DhRecbto string `xml:"dhRecbto"`
    TMed int `xml:"tMed"`   
}

type Result struct {
    XMLName xml.Name `xml:"Envelope"`
    Msg Message `xml:"Body>nfeResultMsg>retConsStatServ"`
        
}

//@link http://speakmy.name/2014/07/29/http-request-debugging-in-go/
func debug(err error, data string, debugLevel int) {
    if err != nil {
       exitf(CRITICAL, "%s", err)
    }

    if data != "" && *verbose >= debugLevel {
        log.Printf("%s\n\n", data)
    }
}


func exit(code int, m string) {
    fmt.Println(m)
    os.Exit(code)
}

func exitf(code int, format string, vars ...interface{}) {
    fmt.Printf(format + "\n", vars...)
    os.Exit(code)
}

func showCertInfo(cert *x509.Certificate) {
    line := "+" + strings.Repeat("-", 60) + "+"
    iterate := func(label string, v []string) {
        for _, value := range v {
            fmt.Println(label + value)
        }
    }

    fmt.Println(line)
    fmt.Println(" Subject Name")
    fmt.Println(line)
    iterate(" Country              (C): ", cert.Subject.Country)
    iterate(" Organization         (O): ", cert.Subject.Organization)
    iterate(" State               (ST): ", cert.Subject.Province)
    iterate(" Organizational Unit (OU): ", cert.Subject.OrganizationalUnit)
    fmt.Println(" Common Name         (CN): " + cert.Subject.CommonName)
    iterate(" Email                   : ", cert.EmailAddresses)

    fmt.Println(line)
    fmt.Println(" Issuer Name")
    fmt.Println(line)
    fmt.Println(" Country              (C): " + cert.Issuer.Country[0])
    fmt.Println(" Organization         (O): " + cert.Issuer.Organization[0])
    fmt.Println(" Organizational Unit (OU): " + cert.Issuer.OrganizationalUnit[0])
    fmt.Println(" Common Name         (CN): " + cert.Issuer.CommonName)

    //@link https://stackoverflow.com/questions/20234104/how-to-format-current-time-using-a-yyyymmddhhmmss-format
    defaultFormat := "2006-1-2 15:04"
    fmt.Println(line)
    fmt.Println(" Issued Certificate")
    fmt.Println(line)
    fmt.Printf(" Version                 : %d\n", cert.Version)
    fmt.Printf(" Serial Number           : %d\n", cert.SerialNumber)
    fmt.Printf(" SigAlgName              : %s\n", cert.SignatureAlgorithm)
    fmt.Printf(" Not Valid Before        : %s\n", cert.NotBefore.Format(defaultFormat))
    fmt.Printf(" Not Valide After        : %s\n", cert.NotAfter.Format(defaultFormat))
    fmt.Println(line)
}

func var_dump(v interface{}) {
    //@link https://golang.org/pkg/fmt/
    format := "\nDump:\n" + OBJECT_WITH_PROPERTIES + "\n\n"
    log.Printf(format, v)
}

func getFakeResponseBody() (string) {
    return `
        <?xml version="1.0" encoding="UTF-8"?>
        <soap:Envelope xmlns:soap="http://www.w3.org/2003/05/soap-envelope" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
           <soap:Body>
              <nfeResultMsg xmlns="http://www.portalfiscal.inf.br/nfe/wsdl/NFeStatusServico4">
                 <retConsStatServ xmlns="http://www.portalfiscal.inf.br/nfe" versao="4.00">
                    <tpAmb>1</tpAmb>
                    <verAplic>RS201805211008</verAplic>
                    <cStat>107</cStat>
                    <xMotivo>Servico em Operacao</xMotivo>
                    <cUF>43</cUF>
                    <dhRecbto>2018-08-14T11:35:41-03:00</dhRecbto>
                    <tMed>-1</tMed>
                 </retConsStatServ>
              </nfeResultMsg>
           </soap:Body>
        </soap:Envelope>
    `
}

func getRequestInformation(uf string) (postData string, url string) {
    //@link https://www.oobj.com.br/bc/article/quais-os-c%C3%B3digos-de-cada-uf-no-brasil-465.html
    //@link http://www.nfe.fazenda.gov.br/portal/webServices.aspx
    UFS := map[string][]string {
        "AC": []string{"12", "https://nfe.svrs.rs.gov.br/ws/NfeStatusServico/NfeStatusServico4.asmx"},
        "AL": []string{"27", "https://nfe.svrs.rs.gov.br/ws/NfeStatusServico/NfeStatusServico4.asmx"},
        "AM": []string{"13", "https://nfe.sefaz.am.gov.br/services2/services/NfeStatusServico4"},
        "AP": []string{"16", "https://nfe.svrs.rs.gov.br/ws/NfeStatusServico/NfeStatusServico4.asmx"},
        "BA": []string{"29", "https://nfe.sefaz.ba.gov.br/webservices/NFeStatusServico4/NFeStatusServico4.asmx"},
        "CE": []string{"23", "https://nfe.sefaz.ce.gov.br/nfe4/services/NFeStatusServico4?wsdl"},
        "DF": []string{"53", "https://nfe.svrs.rs.gov.br/ws/NfeStatusServico/NfeStatusServico4.asmx"},
        "GO": []string{"52", "https://nfe.sefaz.go.gov.br/nfe/services/NFeStatusServico4?wsdl"},
        "ES": []string{"32", "https://nfe.svrs.rs.gov.br/ws/NfeStatusServico/NfeStatusServico4.asmx"},
        "MA": []string{"21", "https://www.sefazvirtual.fazenda.gov.br/NFeStatusServico4/NFeStatusServico4.asmx"},
        "MG": []string{"31", "https://nfe.fazenda.mg.gov.br/nfe2/services/NFeStatusServico4"},
        "MS": []string{"50", "https://nfe.sefaz.ms.gov.br/ws/NFeStatusServico4"},
        "MT": []string{"51", "https://nfe.sefaz.mt.gov.br/nfews/v2/services/NfeStatusServico4?wsdl"},
        "PA": []string{"15", "https://www.sefazvirtual.fazenda.gov.br/NFeStatusServico4/NFeStatusServico4.asmx"},
        "PB": []string{"25", "https://nfe.svrs.rs.gov.br/ws/NfeStatusServico/NfeStatusServico4.asmx"},
        "PE": []string{"26", "https://nfe.sefaz.pe.gov.br/nfe-service/services/NFeStatusServico4"},
        "PI": []string{"22", "https://nfe.svrs.rs.gov.br/ws/NfeStatusServico/NfeStatusServico4.asmx"},
        "PR": []string{"41", "https://nfe.sefa.pr.gov.br/nfe/NFeStatusServico4?wsdl"},
        "RJ": []string{"33", "https://nfe.svrs.rs.gov.br/ws/NfeStatusServico/NfeStatusServico4.asmx"},
        "RN": []string{"24", "https://nfe.svrs.rs.gov.br/ws/NfeStatusServico/NfeStatusServico4.asmx"},
        "RO": []string{"11", "https://nfe.svrs.rs.gov.br/ws/NfeStatusServico/NfeStatusServico4.asmx"},
        "RR": []string{"14", "https://nfe.svrs.rs.gov.br/ws/NfeStatusServico/NfeStatusServico4.asmx"},
        "RS": []string{"43", "https://nfe.sefazrs.rs.gov.br/ws/NfeStatusServico/NfeStatusServico4.asmx"},
        "SC": []string{"42", "https://nfe.svrs.rs.gov.br/ws/NfeStatusServico/NfeStatusServico4.asmx"},
        "SE": []string{"28", "https://nfe.svrs.rs.gov.br/ws/NfeStatusServico/NfeStatusServico4.asmx"},
        "SP": []string{"35", "https://nfe.fazenda.sp.gov.br/ws/nfestatusservico4.asmx"},
        "TO": []string{"17", "https://nfe.svrs.rs.gov.br/ws/NfeStatusServico/NfeStatusServico4.asmx"},
    }

    code, url := UFS[uf][0], UFS[uf][1]

    data := fmt.Sprintf(
            `<?xml version="1.0" encoding="utf-8"?>` +
            `<soap:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:soap="http://www.w3.org/2003/05/soap-envelope">` +
                `<soap:Body>` +
                    `<nfeDadosMsg xmlns="http://www.portalfiscal.inf.br/nfe/wsdl/NFeStatusServico4">` +
                        `<consStatServ versao="4.00" xmlns="http://www.portalfiscal.inf.br/nfe">` +
                            `<tpAmb>1</tpAmb>` +
                            `<cUF>%s</cUF>` +
                            `<xServ>STATUS</xServ>` +
                            `</consStatServ>` +
                    `</nfeDadosMsg>` +
                `</soap:Body>` +
            `</soap:Envelope>`,
            code,
        )

    return data, url
}

func storeCert(cert *x509.Certificate, privateKey *rsa.PrivateKey) (string, error) {
    currentPath, err := os.Getwd()
    certPath := fmt.Sprintf("%s/.%d.pem", currentPath, os.Getpid())
    pemFile, err := os.OpenFile(certPath, os.O_WRONLY|os.O_CREATE, 0600)

    if err != nil {
        return "", err    
    }

    pem.Encode(
        pemFile,
         &pem.Block{
            Type: "CERTIFICATE", Bytes: cert.Raw,
        },
    )

    pem.Encode(
        pemFile,
        &pem.Block{
            Type: "RSA PRIVATE KEY",
            Bytes: x509.MarshalPKCS1PrivateKey(privateKey),
        },
    )

    pemFile.Close()
    
    return certPath, nil
}

func doRequest(easy *curl.CURL) (string, error) {
    xmlData := ""

    recv := func (responseBody []byte, userdata interface{}) bool {
        xmlData += strings.Replace(string(responseBody), "nfeStatusServicoNFResult", "nfeResultMsg", 2)
        return xmlData != ""
    }

    easy.Setopt(curl.OPT_WRITEFUNCTION, recv)

    err := easy.Perform()

    return xmlData, err
}

func verify(cert *x509.Certificate) (error) {
    defaultOpts := x509.VerifyOptions{};
    _, err := cert.Verify(defaultOpts);
    
    if _, isCAError := err.(x509.UnknownAuthorityError); isCAError {
        return nil
    }

    return err
}

func main() {
    flag.Parse()

    if *in == "" || *password == "" || *uf == "" {
        flag.Usage()
        os.Exit(OK)
    }

    if *version {
        exit(OK, "Version: " + VERSION)
    }

    debug(nil, "CERTIFICATE: " + *in, 1)
    debug(nil, "PASSWORD: " + *password, 1)
    debug(nil, "UF: " + *uf, 1)
   
    pkcs12Data, err := ioutil.ReadFile(*in)
    debug(err, "", 0)

    /**
     *************************** WARNING ****************************************
     *
     * Patch applied from community (DecodeAll) and we need to copy that file
     * to the source package.
     *
     * @link https://github.com/ereOn/crypto/commit/05f6847ff80ca34c92a01a688c7b81e874af3009
     *
     *****************************************************************************
     */
    privateKeys, x509Certs, err := pkcs12.DecodeAll(pkcs12Data, *password)
    debug(err, "", 0)

    privateKey := privateKeys[0]
    x509Cert := x509Certs[0]

    if *infoCert {
        showCertInfo(x509Cert)
        os.Exit(OK)
    }

    err = verify(x509Cert)
    debug(err, "", 0)

    easy := curl.EasyInit()
    defer easy.Cleanup()

    postData, url := getRequestInformation(*uf)
    debug(nil, "REQUEST:\n" + postData, 2)

    /**
     * We need store the certificate and private key on disk because
     * curl doesn't support passing their content directly as a string
     */
    certPath, err := storeCert(x509Cert, privateKey.(*rsa.PrivateKey))

    easy.Setopt(curl.OPT_URL, url)
    easy.Setopt(curl.OPT_SSL_VERIFYPEER, false)
    easy.Setopt(curl.OPT_SSLCERT, certPath)
    easy.Setopt(curl.OPT_SSLKEY, certPath)
    easy.Setopt(curl.OPT_POSTFIELDS, postData)
    easy.Setopt(curl.OPT_VERBOSE, *verbose > 2)
    easy.Setopt(curl.OPT_HTTPHEADER, []string{
        `Content-Type: application/soap+xml; charset=utf-8`,
        `SOAPAction: "http://www.portalfiscal.inf.br/nfe/wsdl/NFeConsultaProtocolo4/nfeConsultaNF"`,
    })

    xmlData, err := doRequest(easy)
    os.Remove(certPath)

    result := Result {
        Msg: Message {
            TMed: -1,
        },
    }

    debug(err, "RESPONSE:\n"+ xmlData, 2)

    /* decode the xml data and map it to a declared struct*/
    err = xml.Unmarshal([]byte(xmlData), &result)
    debug(err, "XML PARSED:\n" + fmt.Sprintf(OBJECT_WITH_PROPERTIES, result), 3)

    ICode, err := easy.Getinfo(curl.INFO_RESPONSE_CODE)
    statusCode := ICode.(int)

    if result.Msg.XMotivo == "" && statusCode != HTTP_OK {
        exit(CRITICAL, fmt.Sprintf("Erro - StatusCode: %d %s", statusCode, http.StatusText(statusCode)))
    }

    if result.Msg.CStat != STATUS_OK {
        exit(CRITICAL, "Erro - Mensagem: " + result.Msg.XMotivo)
    }

    elapsed, err := easy.Getinfo(curl.INFO_TOTAL_TIME)
    messageFormat := "Tempo de Resposta %f Segundo(s) / Status %d / Mensagem: (%s) | tempo_total=%f;;;0;"

    if result.Msg.TMed == -1 {
        exitf(OK, messageFormat, elapsed, result.Msg.CStat, result.Msg.XMotivo, elapsed) 
    }

    exitf(OK, messageFormat + " tempo_medio=%d;;;0;", elapsed, result.Msg.CStat, result.Msg.XMotivo, elapsed, result.Msg.TMed)
}
