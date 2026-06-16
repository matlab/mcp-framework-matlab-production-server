// main.go
// yaml2json converts YAML to JSON, reading from STDIN, writing to STDOUT.
//
// Usage:
//    yaml2json < yaml > json

// Peter Webb, Nov. 2022
// Copyright (c) 2022, The MathWorks, Inc.

package main

import (
	"fmt"
	"github.com/ghodss/yaml"
	"io"
	"log"
	"os"
)

func main() {

	// Read stdin until EOF
	bytes, err := io.ReadAll(os.Stdin)
	if err != nil {
		log.Fatalf("Could not read bytes from input stream.\nError: %v\n", err)
	}

	// Convert the input bytes (which should be valid YAML)
	pJ, err := yaml.YAMLToJSON(bytes)
	if err != nil {
		log.Fatalf("Could not convert YAML to JSON.\nError: %v\n", err)
	}

	// Convert []byte to a string and spit it out.
	fmt.Println(string(pJ))
}
