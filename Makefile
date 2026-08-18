.PHONY: build test bundle run clean
build:
	swift build
test:
	swift run TrackerCoreTests
bundle:
	bash Scripts/bundle.sh
run: bundle
	open build/PresenceTracker.app
clean:
	swift package clean
	rm -rf build
