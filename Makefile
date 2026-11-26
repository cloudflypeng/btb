SHELL := /bin/bash
DERIVED := .build
PROJECT := BTB.xcodeproj
IOS_DESTINATION ?= platform=iOS Simulator,name=iPhone 17 Pro
CORE_DIR ?= ../bbcore
CORE_FRAMEWORK := Frameworks/BTBCore.xcframework
CORE_SOURCES := $(shell find $(CORE_DIR)/cmd $(CORE_DIR)/internal $(CORE_DIR)/mobile -name '*.go' 2>/dev/null) \
	$(CORE_DIR)/go.mod $(CORE_DIR)/go.sum
ANDROID_DIR ?= Android
ANDROID_HOME ?= $(HOME)/Library/Android/sdk
ANDROID_NDK_HOME ?= $(ANDROID_HOME)/ndk/27.1.12297006
ANDROID_AAR := $(ANDROID_DIR)/app/libs/bbcore.aar

.PHONY: project build run clean core mobile core-http core-ios android android-core

project: $(CORE_FRAMEWORK)
	xcodegen generate

$(CORE_FRAMEWORK): $(CORE_SOURCES)
	mkdir -p Frameworks
	cd $(CORE_DIR) && go tool gomobile bind -target=ios,iossimulator \
		-o $(abspath $(CORE_FRAMEWORK)) ./mobile

core-ios: $(CORE_FRAMEWORK)

build: project
	xcodebuild -project $(PROJECT) -scheme BTB -configuration Debug \
		-derivedDataPath $(DERIVED) -destination 'platform=macOS' -quiet build

run: build
	open $(DERIVED)/Build/Products/Debug/BTB.app

core:
	mkdir -p $(DERIVED)
	cd ../bbcore && go build -trimpath -o ../btb/$(DERIVED)/bbcore ./cmd/bbcore

core-http: core
	$(DERIVED)/bbcore -listen 127.0.0.1:8787

$(ANDROID_AAR): $(CORE_SOURCES)
	mkdir -p $(dir $@)
	cd $(CORE_DIR) && ANDROID_HOME="$(ANDROID_HOME)" ANDROID_NDK_HOME="$(ANDROID_NDK_HOME)" \
		go tool gomobile bind -target=android -androidapi 26 \
		-ldflags=-extldflags=-Wl,-z,max-page-size=16384 \
		-javapkg=com.cloudflypeng.bbcore -o $(abspath $@) ./mobile

android-core: $(ANDROID_AAR)

android: android-core
	cd $(ANDROID_DIR) && ./gradlew :app:assembleDebug

mobile: project
	xcodebuild -project $(PROJECT) -scheme BTBMobile -configuration Debug \
		-derivedDataPath $(DERIVED)-ios -destination '$(IOS_DESTINATION)' -quiet build

clean:
	rm -rf $(DERIVED) $(DERIVED)-ios $(PROJECT)
