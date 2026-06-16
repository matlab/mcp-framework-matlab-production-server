EXE := 
ifeq ($(OS),Windows_NT)     # is Windows_NT on XP, 2000, 7, Vista, 10...
    ARCH := win64
    EXE := .exe
else
    OS := $(shell uname)  # same as "uname -s"
    ifeq ($(OS),"Linux")
	ARCH := glnxa64
    elsif ($(OS),"Darwin")
        ARCH := maca64
    endif
endif

export MW_ARCH = $(ARCH)

Y2J :=../../bin/$(ARCH)/yaml2json/yaml2json$(EXE) 
$(Y2J) : main.go
	go build -o $@ $^

build: $(Y2J)

test: $(Y2J)
	go test

clean: 
	$(RM) $(Y2J)

install: test
