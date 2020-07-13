package dashboard

import (
    "net/http"
    "time"
    "encoding/json"
    "check_publisher/apis"
    "check_publisher/apis/matomo"
)

var Verbose = 0

type Dashboard struct {
    username string
    password string
    url string
}

func New(url string, email string, password string) * Dashboard {
    return &Dashboard {
        username: email,
        password: password,
        url: url,
    }
}


func (d *Dashboard) Get(uri string) ([] byte) {
    req, _ := http.NewRequest("POST", d.url + uri, nil);
    req.SetBasicAuth(d.username, d.password);
    client := &http.Client{
        Timeout: time.Second * 30,
    }
    resp, _ := client.Do(req)
    return apis.ReadBody(resp)
}


func (d *Dashboard) GetMatomoSites() ([]matomo.Site){
    var result []matomo.Site
    json.Unmarshal(d.Get("/get_matomo_publishers"), &result)
    return result
}
