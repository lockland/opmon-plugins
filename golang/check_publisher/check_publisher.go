/**
* https://stackoverflow.com/questions/28081486/how-can-i-go-run-a-project-with-multiple-files-in-the-main-package
*/

package main

import (
    "check_publisher/opmon"
    "check_publisher/apis/matomo"
    "check_publisher/apis/dashboard"
    "flag"
    "fmt"
    "net/http"
    "os"
    "strings"
    "sync"
    "time"
    Url "net/url"
)

var (
    hostname = flag.String("H", "", "OpMon host name. Use TEST for dry-run")
    verbose  = flag.Int("v", 0, "verbose level [0-4]")
)

func parseUrl(url string) string {
    u, _ := Url.Parse(url)
    return strings.Replace(u.Hostname(), "www.", "", 1)
}

func processSite(site matomo.Site, matomoClient *matomo.Matomo, wg *sync.WaitGroup) bool {
    defer wg.Done()

    serviceName := parseUrl(site.Url)
    client := &http.Client{
        Timeout: time.Second * 10,
    }

    if *verbose >= 4 {
        fmt.Printf("%#v\n", site)
    }

    totalTime, TTFB, err := site.Open(client)
    if err != nil {
        return opmon.SendServiceResult(*hostname, serviceName, err.Error(), opmon.UNKNOWN)
    }

    if matomoClient.GetVisitsLast24h(site) == 0 {
        return opmon.SendServiceResult(
            *hostname,
            serviceName,
            "CRITICAL - TagManager was not installed properly or removed",
            opmon.CRITICAL,
        )
    }

    isContainerPublished, err := matomoClient.IsContainerPublished(site)

    if err != nil {
        return opmon.SendServiceResult(*hostname, serviceName, "CRITICAL - " + err.Error(), opmon.CRITICAL)
    }

    if !isContainerPublished {
        return opmon.SendServiceResult(
            *hostname,
            serviceName,
            "WARNING - Published container and cloudfront container have different version",
            opmon.WARNING,
        )
    }

    return opmon.SendServiceResult(
        *hostname,
        serviceName,
        fmt.Sprintf("OK - Site working properly|total_time=%.2fs ttfb=%.2fs", totalTime.Seconds(), TTFB.Seconds()),
        opmon.OK,
    )
}

func main() {

    flag.Parse()

    if *hostname == "" {
        flag.Usage()
        os.Exit(opmon.OK)
    }

    opmon.Verbose = *verbose
    matomo.Verbose = *verbose
    dashboard.Verbose = *verbose

    matomoClient := matomo.New(MATOMO_URL, MATOMO_TOKEN)
    visitsYesterday := matomoClient.GetYesterdayVisitors()
    if MINIMUM_EXPECTED_VISITORS > visitsYesterday {
        opmon.Exit(opmon.CRITICAL, "CRITICAL - Analytics may not be working properly")
    }

    var wg sync.WaitGroup
    dashboardClient := dashboard.New(DASHBOARD_URL, DASHBOARD_USER, DASHBOARD_PASS)
    sites := dashboardClient.GetMatomoSites()
    for _, site := range sites {
        wg.Add(1)
        go processSite(site, matomoClient, &wg)
    }

    wg.Wait()
    opmon.Exit(opmon.OK, "OK - Processed All Sites | visitsYesterday=%d", visitsYesterday)
}
