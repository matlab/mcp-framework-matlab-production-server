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

FP := ../../../bin/$(ARCH)/persist/file_persist$(EXE) 
$(FP) : main.go
	go build -o $@ $^

build: $(FP)

test: $(FP)
	go test

clean: 
	$(RM) $(FP)

install: test
