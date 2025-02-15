package edge

import (
	"fmt"
	"github.com/fatih/color"
	"github.com/openziti/sdk-golang/ziti"
	"github.com/openziti/sdk-golang/ziti/config"
	"net"
	"net/http"
)

type zitiEchoServer struct {
	identityJson string
	listener     net.Listener
}

func (s *zitiEchoServer) ServeHTTP(rw http.ResponseWriter, r *http.Request) {
	input := r.URL.Query().Get("input")
	result := fmt.Sprintf("As you say, '%v', indeed!\n", input)
	c := color.New(color.FgGreen, color.Bold)
	c.Print("\nziti-http-echo-server: ")
	fmt.Printf("received input '%v'\n", input)
	if _, err := rw.Write([]byte(result)); err != nil {
		panic(err)
	}
}

func (s *zitiEchoServer) run() (err error) {
	config, err := config.NewFromFile(s.identityJson)
	if err != nil {
		return err
	}

	zitiContext := ziti.NewContextWithConfig(config)
	if s.listener, err = zitiContext.Listen("echo"); err != nil {
		return err
	}

	c := color.New(color.FgGreen, color.Bold)
	c.Print("\nziti-http-echo-server: ")
	fmt.Println("listening for connections from echo server")
	go func() { _ = http.Serve(s.listener, http.HandlerFunc(s.ServeHTTP)) }()
	return nil
}

func (s *zitiEchoServer) stop() error {
	return s.listener.Close()
}
