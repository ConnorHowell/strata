SCHEME = Strata
PROJECT = Strata.xcodeproj
DESTINATION = platform=macOS

.PHONY: build test lint clean

build:
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -destination '$(DESTINATION)' build | xcpretty || xcodebuild -project $(PROJECT) -scheme $(SCHEME) -destination '$(DESTINATION)' build

test:
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -destination '$(DESTINATION)' test | xcpretty || xcodebuild -project $(PROJECT) -scheme $(SCHEME) -destination '$(DESTINATION)' test

lint:
	swiftlint lint --config .swiftlint.yml

clean:
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) clean
	rm -rf build/
