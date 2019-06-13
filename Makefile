build:
	swift build
release:
	swift build -c release
install: release
	cp .build/release/beoplay-cli /usr/local/bin/beoplay-cli
uninstall:
	rm /usr/local/bin/beoplay-cli
clean:
	swift package clean
