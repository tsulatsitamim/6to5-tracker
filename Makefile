.PHONY: build test bundle run clean
build:
	swift build
test:
	swift test
bundle:
	bash Scripts/bundle.sh
run: bundle
	open build/PresenceTracker.app
clean:
	swift package clean
	rm -rf build
