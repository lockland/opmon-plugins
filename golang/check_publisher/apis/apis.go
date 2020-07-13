package apis

import (
    "net/http"
    "io/ioutil"
) 

func ReadBody(resp *http.Response) ([] byte) {
    content, _ := ioutil.ReadAll(resp.Body)
    resp.Body.Close()
    return content
}

