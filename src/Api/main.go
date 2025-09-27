package main

import (
	"log"
	"net/http"

	utils "github.com/PedroHenriques/golang_ms_template/Api/internal"
)

/*
main is the entry point into the application.
*/
func main() {
	http.HandleFunc("/", func (w http.ResponseWriter, r *http.Request) {
		w.Write([]byte(utils.Hello("World!")))
	})

	err := http.ListenAndServe(":10000", nil)
	if err != nil {
		log.Fatal(err)
	}
}