build:
	swift build
test-integration: build
	cd Tests/Integration && ./TestRunner.sh
release:
	swift build -c release
install: release
	cp .build/release/beoplay-cli /usr/local/bin/beoplay-cli
uninstall:
	rm /usr/local/bin/beoplay-cli
clean:
	swift package clean
