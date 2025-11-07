package main_test

import (
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
)

var ExeRoot = filepath.Join("..", "..", "bin",
	os.Getenv("MW_ARCH"), "yaml2json")

var TestFileFolder = filepath.Join("TestDocuments")

func TempFile(name string, t *testing.T) *os.File {

	// Create a temporary file for output
	f, err := os.CreateTemp("", name)
	if err != nil {
		t.Fatalf("Failed to create temporary output file: %v", err)
	}
	return f
}

func yaml2json(t *testing.T, filePrefix string) {
	cmd := exec.Command(filepath.Join(ExeRoot, "yaml2json"))

	// Read file with primitive values from test folder.
	inFile, err := os.Open(filepath.Join(TestFileFolder, filePrefix+".yaml"))
	if err != nil {
		t.Fatalf("Failed to open input file: %v", err)
	}
	cmd.Stdin = inFile
	defer func() {
		if err := inFile.Close(); err != nil {
			t.Errorf("Failed to close input file: %v", err)
		}
	}()

	// Create a temporary file to capture the output
	outFile := TempFile(filePrefix+"*.json", t)
	defer func() {
		if err := os.Remove(outFile.Name()); err != nil {
			t.Errorf("Failed to remove temporary file: %v", err)
		}
	}()
	cmd.Stdout = outFile

	// Produce JSON from the YAML file.
	err = cmd.Run()
	if err != nil {
		t.Fatalf("Failed to execute command: %v", err)
	}
	outFileName := outFile.Name()
	if err := outFile.Close(); err != nil {
		t.Errorf("Failed to close output file: %v", err)
	}

	// Check results -- read the JSON file
	actual, err := os.ReadFile(outFileName)
	if err != nil {
		t.Fatalf("Failed to read output file: %v", err)
	}

	// Read the file defining the expected results
	goldFile := filepath.Join(TestFileFolder, filePrefix+".json")
	expected, err := os.ReadFile(goldFile)
	if err != nil {
		t.Fatalf("Failed to read gold file: %v", err)
	}

	actualStr := strings.TrimSpace(string(actual))
	expectedStr := strings.TrimSpace(string(expected))

	// Don't trust, explicitly verify
	if actualStr != expectedStr {
		t.Errorf("Output does not match expected result:\nExpected: '%s'\nActual: '%s'", expectedStr, actualStr)
	}
}

func TestYaml2Json(t *testing.T) {
	yaml2json(t, "PrimitiveValues")
	yaml2json(t, "SimpleStruct")
	yaml2json(t, "Persistence")
}
