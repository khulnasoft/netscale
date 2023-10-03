VERSION       := $(shell git describe --tags --always --match "[0-9][0-9][0-9][0-9].*.*")
MSI_VERSION   := $(shell git tag -l --sort=v:refname | grep "w" | tail -1 | cut -c2-)
#MSI_VERSION expects the format of the tag to be: (wX.X.X). Starts with the w character to not break cfsetup.
#e.g. w3.0.1 or w4.2.10. It trims off the w character when creating the MSI.

ifeq ($(ORIGINAL_NAME), true)
	# Used for builds that want FIPS compilation but want the artifacts generated to still have the original name.
	BINARY_NAME := netscale
else ifeq ($(FIPS), true)
	# Used for FIPS compliant builds that do not match the case above.
	BINARY_NAME := netscale-fips
else
	# Used for all other (non-FIPS) builds.
	BINARY_NAME := netscale
endif

ifeq ($(NIGHTLY), true)
	DEB_PACKAGE_NAME := $(BINARY_NAME)-nightly
	NIGHTLY_FLAGS := --conflicts netscale --replaces netscale
else
	DEB_PACKAGE_NAME := $(BINARY_NAME)
endif

DATE          := $(shell date -u '+%Y-%m-%d-%H%M UTC')
VERSION_FLAGS := -X "main.Version=$(VERSION)" -X "main.BuildTime=$(DATE)"
ifdef PACKAGE_MANAGER
	VERSION_FLAGS := $(VERSION_FLAGS) -X "github.com/khulnasoft/netscale/cmd/netscale/updater.BuiltForPackageManager=$(PACKAGE_MANAGER)"
endif

LINK_FLAGS :=
ifeq ($(FIPS), true)
	LINK_FLAGS := -linkmode=external -extldflags=-static $(LINK_FLAGS)
	# Prevent linking with libc regardless of CGO enabled or not.
	GO_BUILD_TAGS := $(GO_BUILD_TAGS) osusergo netgo fips
	VERSION_FLAGS := $(VERSION_FLAGS) -X "main.BuildType=FIPS"
endif

LDFLAGS := -ldflags='$(VERSION_FLAGS) $(LINK_FLAGS)'
ifneq ($(GO_BUILD_TAGS),)
	GO_BUILD_TAGS := -tags "$(GO_BUILD_TAGS)"
endif

ifeq ($(debug), 1)
	GO_BUILD_TAGS += -gcflags="all=-N -l"
endif

IMPORT_PATH    := github.com/khulnasoft/netscale
PACKAGE_DIR    := $(CURDIR)/packaging
PREFIX         := /usr
INSTALL_BINDIR := $(PREFIX)/bin/
INSTALL_MANDIR := $(PREFIX)/share/man/man1/

LOCAL_ARCH ?= $(shell uname -m)
ifneq ($(GOARCH),)
    TARGET_ARCH ?= $(GOARCH)
else ifeq ($(LOCAL_ARCH),x86_64)
    TARGET_ARCH ?= amd64
else ifeq ($(LOCAL_ARCH),amd64)
    TARGET_ARCH ?= amd64
else ifeq ($(LOCAL_ARCH),i686)
    TARGET_ARCH ?= amd64
else ifeq ($(shell echo $(LOCAL_ARCH) | head -c 5),armv8)
    TARGET_ARCH ?= arm64
else ifeq ($(LOCAL_ARCH),aarch64)
    TARGET_ARCH ?= arm64
else ifeq ($(LOCAL_ARCH),arm64)
    TARGET_ARCH ?= arm64
else ifeq ($(shell echo $(LOCAL_ARCH) | head -c 4),armv)
    TARGET_ARCH ?= arm
else ifeq ($(LOCAL_ARCH),s390x)
    TARGET_ARCH ?= s390x
else
    $(error This system's architecture $(LOCAL_ARCH) isn't supported)
endif

LOCAL_OS ?= $(shell go env GOOS)
ifeq ($(LOCAL_OS),linux)
    TARGET_OS ?= linux
else ifeq ($(LOCAL_OS),darwin)
    TARGET_OS ?= darwin
else ifeq ($(LOCAL_OS),windows)
    TARGET_OS ?= windows
else ifeq ($(LOCAL_OS),freebsd)
    TARGET_OS ?= freebsd
else ifeq ($(LOCAL_OS),openbsd)
    TARGET_OS ?= openbsd
else
    $(error This system's OS $(LOCAL_OS) isn't supported)
endif

ifeq ($(TARGET_OS), windows)
	EXECUTABLE_PATH=./$(BINARY_NAME).exe
else
	EXECUTABLE_PATH=./$(BINARY_NAME)
endif

ifeq ($(FLAVOR), centos-7)
	TARGET_PUBLIC_REPO ?= el7
else
	TARGET_PUBLIC_REPO ?= $(FLAVOR)
endif

ifneq ($(TARGET_ARM), )
	ARM_COMMAND := GOARM=$(TARGET_ARM)
endif

ifeq ($(TARGET_ARM), 7) 
	PACKAGE_ARCH := armhf
else
	PACKAGE_ARCH := $(TARGET_ARCH)
endif

#for FIPS compliance, FPM defaults to MD5.
RPM_DIGEST := --rpm-digest sha256

.PHONY: all
all: netscale test

.PHONY: clean
clean:
	go clean

.PHONY: netscale
netscale:
ifeq ($(FIPS), true)
	$(info Building netscale with go-fips)
	cp -f fips/fips.go.linux-amd64 cmd/netscale/fips.go
endif
	GOOS=$(TARGET_OS) GOARCH=$(TARGET_ARCH) $(ARM_COMMAND) go build -v -mod=vendor $(GO_BUILD_TAGS) $(LDFLAGS) $(IMPORT_PATH)/cmd/netscale
ifeq ($(FIPS), true)
	rm -f cmd/netscale/fips.go
	./check-fips.sh netscale
endif

.PHONY: container
container:
	docker build --build-arg=TARGET_ARCH=$(TARGET_ARCH) --build-arg=TARGET_OS=$(TARGET_OS) -t khulnasoft/netscale-$(TARGET_OS)-$(TARGET_ARCH):"$(VERSION)" .

.PHONY: generate-docker-version
generate-docker-version:
	echo latest $(VERSION) > versions


.PHONY: test
test: vet
ifndef CI
	go test -v -mod=vendor -race $(LDFLAGS) ./...
else
	@mkdir -p .cover
	go test -v -mod=vendor -race $(LDFLAGS) -coverprofile=".cover/c.out" ./...
endif

.PHONY: cover
cover:
	@echo ""
	@echo "=====> Total test coverage: <====="
	@echo ""
	# Print the overall coverage here for quick access.
	$Q go tool cover -func ".cover/c.out" | grep "total:" | awk '{print $$3}'
	# Generate the HTML report that can be viewed from the browser in CI.
	$Q go tool cover -html ".cover/c.out" -o .cover/all.html

.PHONY: test-ssh-server
test-ssh-server:
	docker-compose -f ssh_server_tests/docker-compose.yml up

netscale.1: netscale_man_template
	sed -e 's/\$${VERSION}/$(VERSION)/; s/\$${DATE}/$(DATE)/' netscale_man_template > netscale.1

install: netscale netscale.1
	mkdir -p $(DESTDIR)$(INSTALL_BINDIR) $(DESTDIR)$(INSTALL_MANDIR)
	install -m755 netscale $(DESTDIR)$(INSTALL_BINDIR)/netscale
	install -m644 netscale.1 $(DESTDIR)$(INSTALL_MANDIR)/netscale.1

# When we build packages, the package name will be FIPS-aware.
# But we keep the binary installed by it to be named "netscale" regardless.
define build_package
	mkdir -p $(PACKAGE_DIR)
	cp netscale $(PACKAGE_DIR)/netscale
	cp netscale.1 $(PACKAGE_DIR)/netscale.1
	fpm -C $(PACKAGE_DIR) -s dir -t $(1) \
		--description 'Khulnasoft Tunnel daemon' \
		--vendor 'Khulnasoft' \
		--license 'Apache License Version 2.0' \
		--url 'https://github.com/khulnasoft/netscale' \
		-m 'Khulnasoft <support@khulnasoft.com>' \
	    -a $(PACKAGE_ARCH) -v $(VERSION) -n $(DEB_PACKAGE_NAME) $(RPM_DIGEST) $(NIGHTLY_FLAGS) --after-install postinst.sh --after-remove postrm.sh \
		netscale=$(INSTALL_BINDIR) netscale.1=$(INSTALL_MANDIR)
endef

.PHONY: netscale-deb
netscale-deb: netscale netscale.1
	$(call build_package,deb)

.PHONY: netscale-rpm
netscale-rpm: netscale netscale.1
	$(call build_package,rpm)

.PHONY: netscale-pkg
netscale-pkg: netscale netscale.1
	$(call build_package,osxpkg)

.PHONY: netscale-msi
netscale-msi:
	wixl --define Version=$(VERSION) --define Path=$(EXECUTABLE_PATH) --output netscale-$(VERSION)-$(TARGET_ARCH).msi netscale.wxs

.PHONY: netscale-darwin-amd64.tgz
netscale-darwin-amd64.tgz: netscale
	tar czf netscale-darwin-amd64.tgz netscale
	rm netscale

.PHONY: homebrew-upload
homebrew-upload: netscale-darwin-amd64.tgz
	aws s3 --endpoint-url $(S3_ENDPOINT) cp --acl public-read $$^ $(S3_URI)/netscale-$$(VERSION)-$1.tgz
	aws s3 --endpoint-url $(S3_ENDPOINT) cp --acl public-read $(S3_URI)/netscale-$$(VERSION)-$1.tgz  $(S3_URI)/netscale-stable-$1.tgz

.PHONY: homebrew-release
homebrew-release: homebrew-upload
	./publish-homebrew-formula.sh netscale-darwin-amd64.tgz $(VERSION) homebrew-khulnasoft

.PHONY: github-release
github-release: netscale
	python3 github_release.py --path $(EXECUTABLE_PATH) --release-version $(VERSION)

.PHONY: github-release-built-pkgs
github-release-built-pkgs:
	python3 github_release.py --path $(PWD)/built_artifacts --release-version $(VERSION)

.PHONY: release-pkgs-linux
release-pkgs-linux:
	python3 ./release_pkgs.py

.PHONY: github-message
github-message:
	python3 github_message.py --release-version $(VERSION)

.PHONY: github-mac-upload
github-mac-upload:
	python3 github_release.py --path artifacts/netscale-darwin-amd64.tgz --release-version $(VERSION) --name netscale-darwin-amd64.tgz
	python3 github_release.py --path artifacts/netscale-amd64.pkg --release-version $(VERSION) --name netscale-amd64.pkg

.PHONY: github-windows-upload
github-windows-upload:
	python3 github_release.py --path built_artifacts/netscale-windows-amd64.exe --release-version $(VERSION) --name netscale-windows-amd64.exe
	python3 github_release.py --path built_artifacts/netscale-windows-amd64.msi --release-version $(VERSION) --name netscale-windows-amd64.msi
	python3 github_release.py --path built_artifacts/netscale-windows-386.exe --release-version $(VERSION) --name netscale-windows-386.exe
	python3 github_release.py --path built_artifacts/netscale-windows-386.msi --release-version $(VERSION) --name netscale-windows-386.msi

.PHONY: tunnelrpc-deps
tunnelrpc-deps:
	which capnp  # https://capnproto.org/install.html
	which capnpc-go  # go install zombiezen.com/go/capnproto2/capnpc-go@latest
	capnp compile -ogo tunnelrpc/tunnelrpc.capnp

.PHONY: quic-deps
quic-deps:
	which capnp
	which capnpc-go
	capnp compile -ogo quic/schema/quic_metadata_protocol.capnp

.PHONY: vet
vet:
	go vet -v -mod=vendor github.com/khulnasoft/netscale/...

.PHONY: fmt
fmt:
	goimports -l -w -local github.com/khulnasoft/netscale $$(go list -mod=vendor -f '{{.Dir}}' -a ./... | fgrep -v tunnelrpc)
