package matomo

import (
    "net/http"
    "time"
    "net/http/httptrace"
)

type Site struct {
    Name string
    Url string
    Id string `json:"idsite"`
}


/**
 * @link https://medium.com/@cep21/go-1-7-httptrace-and-context-debug-patterns-608ae887224a
 */
func(s *Site) Open(client *http.Client) (totalTime time.Duration, ttfb time.Duration, err error) {
    req, _ := http.NewRequest("GET", s.Url, nil)
    start := time.Now()

    trace := &httptrace.ClientTrace {
        GotFirstResponseByte: func() { ttfb = time.Since(start) },
    }

    req = req.WithContext(httptrace.WithClientTrace(req.Context(), trace))
    _, err = client.Do(req);
    totalTime = time.Since(start)
    return
}

