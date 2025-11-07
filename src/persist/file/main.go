// main.go
// Entry point for file variable manager.
//
// Usage:
//   file copy "/path/to/source" "/path/to/destination"
//   file create "/path/to/folder/"
//   file match "/path/to/match"
//   file exist "<variable>"
//   file invalidate "<variable>"

// Peter Webb, Nov. 2022
// Copyright (c) 2022, The MathWorks, Inc.

package main

import (
	"errors"
	"flag"
	"fmt"
	"io"
	"log"
	"net/url"
	"os"
	"path"
	"path/filepath"
	"runtime"
	"strings"
	"syscall"
)

func exist(u *url.URL) (bool, string) {

	avail := false

	foundFile := u.Path
	if _, err := os.Stat(u.Path); err == nil {
		avail = true
	} else {
		// If there's no extension, look for any extension
		ext := path.Ext(u.Path)
		if len(ext) == 0 {
			// Get all files matching the given path
			varName := path.Base(u.Path)
			files, err := filepath.Glob(u.Path + ".*")
			if err != nil {
				log.Fatalf("Bad file name pattern: '%s'\n", u.Path+".*")
			}

			// Find any (the first) file that completely contains
			// the prefix.
			for f := range files {
				// Chop off extension
				ext = filepath.Ext(files[f])
				file := strings.ReplaceAll(files[f], ext, "")
				// The variable name is now the base part of the file name
				variable := filepath.Base(file)
				if variable == varName {
					avail = true
					foundFile = files[f]
					break
				}
			}
		}
	}
	return avail, foundFile
}

func platformPath(drive string, pth string) string {
	// Add drive letter back
	if len(drive) > 0 {
		pth = drive + ":" + pth
	}
	// Platform-specific path separator
	pth = strings.ReplaceAll(pth, "/", string(filepath.Separator))
	return pth
}

func sanitizeURI(uri string) (string, string) {
	var drive = ""
	if runtime.GOOS == "windows" {
		// Clean URIs on Windows to deal with drive letter
		// Starts with file:
		var prefix = "file:"
		var pth = string(uri[5:])
		var driveOffset = len(prefix)
		if pth[0] == '/' {
			driveOffset = driveOffset + 1
		}
		c := uri[driveOffset]
		if uri[driveOffset+1] == ':' &&
			('0' <= c && c <= '9' || 'a' <= c && c <= 'z' ||
				'A' <= c && c <= 'Z') {
			drive = string(c)
			pth = string(uri[driveOffset+2:])
		}
		// Foward-slash everywhere. Remove colon. URI will
		// start with file:...
		uri = strings.Replace(prefix+pth, "\\", "/", -1) //nolint:staticcheck
	}
	return uri, drive
}

func main() {

	// Command line arguments -- expect two or three
	flag.Parse()
	if len(flag.Args()) != 2 && len(flag.Args()) != 3 {
		log.Fatalf("Expecting two or three arguments. Got %d.\n"+
			"Usage: file copy|create|exist|invalidate|match <variable URI> [<URI>].",
			len(flag.Args()))
	}

	// On Windows, look for drive letter-prefixed URIs, and remove and
	// remember the drive letter. Need to CD to the root of that drive
	// before attempting file operations.

	uri, drive := sanitizeURI(string(flag.Arg(1)))
	if len(drive) > 0 {
		cwd, err := syscall.Getwd()
		if err != nil {
			log.Fatalf("Could not determine current working directory.")
		}
		err = syscall.Chdir(drive + ":/")
		if err != nil {
			log.Fatalf("URL starts with drive letter '%s' but "+
				"cannot change directory to '%s:\\'", drive, drive)
		}

		defer func() {
			err := syscall.Chdir(cwd)
			if err != nil {
				log.Fatalf("Cannot change directory to '%s:\\'", cwd)
			}
		}()
	}

	// err is a better name than e, but declaring err here causes all shorts
	// of "shadowing" warnings when the linter examines the switch blocks
	// below. (Since each block is a separate lexical context, the in-block
	// declarations don't interfere with each other.)
	u, e := url.Parse(uri)
	if e != nil {
		log.Fatalf("Invalid URI: %s. Error: %s\n", uri, e)
	}
	if len(u.Path) == 0 {
		log.Fatalf("Failed to extract path from '%s'.", uri)
	}

	switch flag.Arg(0) {

	case "copy":
		// copy source destination
		uri, destDrive := sanitizeURI(flag.Arg(2))
		dest, err := url.Parse(uri)
		if err != nil {
			log.Fatalf("Invalid destination URI: %s. Error: %s\n",
				flag.Arg(2), err)
		}

		// Source must exist
		avail, _ := exist(u)
		// I disagree with the linter here -- avail == false IS more readable
		// than !avail, but I argue with robots in vain.
		if !avail {
			log.Fatalf("Source URI %s does not exist.", uri)
		}
		srcF, err := os.Open(u.Path)
		if err != nil {
			log.Fatalf("Unable to open source file %s for reading: %s\n",
				u.Path, err)
		}
		defer srcF.Close()

		// Create destination
		if len(drive) > 0 && len(destDrive) > 0 && destDrive != drive {
			err = syscall.Chdir(destDrive + ":/")
			if err != nil {
				log.Fatalf("Destination URL starts with drive letter '%s' "+
					"but cannot change directory to '%s:\\'", destDrive,
					destDrive)
			}
		}

		destF, err := os.Create(dest.Path)
		if err != nil {
			log.Fatalf("Unable to create destination file %s for writing: %s\n",
				dest.Path, err)
		}
		defer destF.Close()

		bytes, err := io.Copy(destF, srcF)
		if err != nil {
			log.Fatalf("Unable to copy data from %s to %s: %s\n",
				u.Path, dest.Path, err)
		}
		if bytes == 0 {
			log.Printf("Copied zero bytes from %s to %s.",
				u.Path, dest.Path)
		}

	case "create":
		// If URI path ends with /, it's a folder. If the folder doesn't exist,
		// create it.
		pth := platformPath(drive, u.Path)
		if u.Path[len(u.Path)-1:] == "/" {
			if _, err := os.Stat(u.Path); errors.Is(err, os.ErrNotExist) {
				err = os.MkdirAll(u.Path, os.ModePerm)
				if err != nil {
					log.Fatal(err)
				} else {
					fmt.Printf("Created: %s\n", pth)
				}
			} else if err == nil {
				fmt.Printf("Exists: %s\n", pth)
			}
		} else {
			log.Fatalf("create requires path to end with '/'. '%s' does not.",
				pth)
		}
	case "match":
		// Get all files matching the given path
		files, err := filepath.Glob(u.Path + "*")
		pth := platformPath(drive, u.Path)
		if err != nil {
			log.Fatalf("Bad file name pattern: '%s'\n", pth+"*")
		}
		for f := range files {
			fmt.Println(platformPath(drive, files[f]))
		}

	case "exist":
		avail, foundFile := exist(u)
		foundFile = platformPath(drive, foundFile)

		if avail {
			fmt.Printf("Available: %s\n", foundFile)

		} else {
			fmt.Printf("Nonexistent: %s\n", platformPath(drive, u.Path))
		}

	case "invalidate":
		pth := platformPath(drive, u.Path)
		if _, err := os.Stat(u.Path); err == nil {
			fmt.Printf("Invalid: %s\n", pth)
		} else {
			err = os.Remove(u.Path)
			if err != nil {
				log.Fatalf("Could not invalidate %s: %s.\n", pth, err)
			}
			if _, err = os.Stat(u.Path); err != nil {
				fmt.Printf("Invalidated: %s\n", pth)
			}
		}

	}
}
