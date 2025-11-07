package main_test

import (
	"github.com/google/uuid"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
)

var FS = string(filepath.Separator)

var ExeRoot = filepath.Join(os.Getenv("MW_INSTALL"), "bin",
	os.Getenv("MW_ARCH"), "toolbox", "stats", "pipeline", "data",
	"persist")

func makeFake(name string, folder string, t *testing.T) {
	contents := uuid.NewString()
	file := folder + "/" + name
	err := os.WriteFile(file, []byte(contents), 0600)
	if err != nil {
		t.Errorf("Failed to create fake variable '%s'.", file)
	}
}

func smokeTest(t *testing.T) {

	// Path to the executable
	exe := filepath.Join(ExeRoot, "file_persist")

	// Create space for variables
	temp := os.TempDir()
	if strings.HasSuffix(temp, FS) == false {
		temp = temp + FS
	}
	temp = temp + uuid.NewString()
	root := "file:" + temp + FS

	// Test: create "/path/to/folder/"
	cmd := exec.Command(exe, "create", root)
	out, err := cmd.CombinedOutput()
	if err != nil {
		t.Fatalf("Failure: %v\nReason: %v\nOutput: %s\n", cmd,
			err, string(out))
	}

	_, err = os.Stat(temp)
	if os.IsNotExist(err) {
		t.Errorf("Failed to create persistence root '%s'.", temp)
	}
	t.Cleanup(func() { os.RemoveAll(temp) })

	// Insert some fake variables as different types of data files.
	makeFake("X.mat", temp, t)
	makeFake("Y.csv", temp, t)
	makeFake("Z.xml", temp, t)
	makeFake("Lorenz.html", temp, t)
	makeFake("BatteryModel.dat", temp, t)
	makeFake("BatteryData.mat", temp, t)

	// Test: exist "<variable>"
	variable := "X.mat"
	varPath := temp + FS + variable
	cmd = exec.Command(exe, "exist", root+variable)
	out, err = cmd.CombinedOutput()
	if err != nil {
		t.Fatalf("Failure: %v\nReason: %v\nOutput: %s\n", cmd,
			err, string(out))
	}
	expected := "Available: " + varPath
	actual := strings.TrimSpace(string(out))
	if expected != actual {
		t.Errorf("exist %s failed. Expecting '%s'. Got '%s'.",
			variable, expected, actual)
	}

	variable = "BatteryModel"
	varPath = temp + FS + variable
	cmd = exec.Command(exe, "exist", root+variable)
	out, err = cmd.CombinedOutput()
	if err != nil {
		t.Fatalf("Failure: %v\nReason: %v\nOutput: %s\n", cmd,
			err, string(out))
	}
	expected = "Available: " + varPath + ".dat"
	actual = strings.TrimSpace(string(out))
	if expected != actual {
		t.Errorf("exist %s failed. Expecting '%s'. Got '%s'.",
			variable, expected, actual)
	}

	// Test: match "/path/to/match"

	variable = "Battery"
	cmd = exec.Command(exe, "match", root+variable)
	out, err = cmd.CombinedOutput()
	if err != nil {
		t.Fatalf("Failure: %v\nReason: %v\nOutput: %s\n", cmd,
			err, string(out))
	}
	expectedV := []string{
		temp + FS + "BatteryData.mat",
		temp + FS + "BatteryModel.dat",
	}
	actual = strings.TrimSpace(string(out))
	// Each string in expected must appear in actual
	for e := range expectedV {
		if strings.Contains(actual, expectedV[e]) == false {
			t.Errorf("match %s failed. Could not find '%s' in '%s'",
				variable, expectedV[e], actual)
		}
	}

	// Test: copy "/path/to/source" "/path/to/destination"
	srcVar := "Lorenz.html"
	srcPath := temp + FS + srcVar
	destVar := "Attractor.html"
	destPath := temp + FS + destVar
	cmd = exec.Command(exe, "copy", root+srcVar, root+destVar)
	out, err = cmd.CombinedOutput()
	if err != nil {
		t.Fatalf("Failure: %v\nReason: %v\nOutput: %s\n", cmd,
			err, string(out))
	}
	_, err = os.Stat(destPath)
	if os.IsNotExist(err) {
		t.Errorf("Failed to copy '%s' to '%s'", srcPath, destPath)
	}
	_, err = os.Stat(srcPath)
	if os.IsNotExist(err) {
		t.Errorf("Copy destroyed '%s'", srcPath)
	}

	// Test: invalidate "<variable>"
	variable = "Z.xml"
	varPath = temp + FS + variable
	cmd = exec.Command(exe, "invalidate", root+variable)
	out, err = cmd.CombinedOutput()
	if err != nil {
		t.Fatalf("Failure: %v\nReason: %v\nOutput: %s\n", cmd,
			err, string(out))
	}
	_, err = os.Stat(varPath)
	if err != nil {
		t.Errorf("Failed to invalidate '%s'", root+variable)
	}
}

func TestFilePersist(t *testing.T) {
	smokeTest(t)
}
