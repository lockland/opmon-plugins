package opmon

import (
    "fmt"
    "os"
    "time"
)

const (
    OK = 0
    WARNING = 1
    CRITICAL = 2
    UNKNOWN = 4
)

var Verbose = 0

func Exit(code int, format string, vars ...interface{}) {
    fmt.Printf(format + "\n", vars...)
    os.Exit(code)
}

func openPipe(test bool) (*os.File, error) {
    if test {
        return os.OpenFile("/dev/null", os.O_WRONLY, 0640);
    }

    return os.OpenFile("/usr/local/opmon/var/rw/opmon.cmd", os.O_WRONLY, os.ModeNamedPipe);
}

func SendServiceResult(hostname string, serviceName string, output string, status int) (bool) {
    timestamp := time.Now().Unix();
    pipe, err := openPipe("TEST" == hostname)
    defer pipe.Close();

    if err != nil {
        Exit(CRITICAL, "CRITICAL - Could not open opmon pipe: " + err.Error())
    }

    command := fmt.Sprintf(
        "[%d] PROCESS_SERVICE_CHECK_RESULT;%s;%s;%d;%s",
        timestamp,
        hostname,
        serviceName,
        status,
        output,
    );

    fmt.Fprintln(pipe, command);

    if (Verbose >= 1) {
        fmt.Fprintln(os.Stdout, command);
    }

    return true
}
