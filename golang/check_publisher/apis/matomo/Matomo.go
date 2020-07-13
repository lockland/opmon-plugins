package matomo

import (
    "net/http"
    "encoding/json"
    "strings"
    "fmt"
    "strconv"
    "errors"
    "check_publisher/apis"
)

var Verbose = 0

type Matomo struct {
    url string
    token string
}

func New (url string, token string) *Matomo {
    return &Matomo{
        token: token,
        url: url,
    }
}

func (m *Matomo) Get(uri string) ([] byte) {
    return m.getContent(m.url + "?token_auth=" + m.token + "&" + uri + "&format=JSON")
}

func (m *Matomo) getContent(url string) ([] byte) {
    if Verbose >= 3 {
        fmt.Printf("GET URL: %s\n", url)
    }

    resp, _ := http.Get(url)
    return apis.ReadBody(resp)
}

func (m *Matomo) GetYesterdayVisitors() (int) {
    jsonData := m.Get("module=API&method=VisitsSummary.getVisits&idSite=all&period=day&date=yesterday")
    var result map[string]int
    json.Unmarshal(jsonData, &result)

    totalVisits := 0
    for _, visits := range result {
        totalVisits += visits
    }

    return totalVisits
}

func (m *Matomo) GetVisitsLast24h (site Site) (int) {
    jsonData := m.Get(strings.Replace("module=API&method=Live.getCounters&idSite={{idsite}}&lastMinutes=1440", "{{idsite}}", site.Id, 1));
    var result []map[string]string
    json.Unmarshal(jsonData, &result)
    i, _ := strconv.Atoi(result[0]["visits"])
    return i
}

func (m *Matomo) getSiteContainer (site Site) (map[string]string, error){
    jsonData := m.Get(strings.Replace("module=API&method=TagManager.getContainers&idSite={{idsite}}&showColumns=releases", "{{idsite}}", site.Id, 1));
    var result []map[string][]map[string]string
    json.Unmarshal(jsonData, &result)

    if Verbose >= 4 {
        fmt.Printf("%+v\n", result)
    }
    for _, release := range result[0]["releases"] {
        if release["environment"] == "live" {
            return release, nil
        }
    }
    return nil, errors.New("Could not retrieve containers from matomo")
}

func (m *Matomo) IsContainerPublished(site Site) (bool, error) {
    container, err := m.getSiteContainer(site)

    if err != nil {
        return false, err
    }

    containerUrl := "http://tagmanager.alright.network/manager/js/container_{{idcontainer}}.js";
    content := m.getContent(strings.Replace(containerUrl, "{{idcontainer}}", container["idcontainer"], 1))
    version := "versionName\":\"" + container["version_name"]
    if Verbose >= 2 {
        fmt.Printf("Search string: \"%s\"\n", version)
    }

    return strings.Contains(string(content), version), nil
}
