build:
	swift build
release:
	swift build -c release
install: release
	cp .build/release/beoplay-cli /usr/local/bin/beoplay-cli
	defaults write beoplay-cli host 192.168.1.20     # (<-- change this to the loudspeakers ip address)
uninstall:
	rm /usr/local/bin/beoplay-cli
clean:
	swift package clean
