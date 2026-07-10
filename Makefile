.PHONY: build run install release icon clean

APP_NAME    = AgentFrame
GIT_TAG    := $(shell git describe --tags --abbrev=0 2>/dev/null)
VERSION    ?= $(if $(GIT_TAG),$(patsubst v%,%,$(GIT_TAG)),0.0.0-dev)
BUILD_DIR   = .build/release
APP         = $(APP_NAME).app
CONTENTS    = $(APP)/Contents
MACOS       = $(CONTENTS)/MacOS
RESOURCES   = $(CONTENTS)/Resources
DMG         = $(APP_NAME)-$(VERSION).dmg
DMG_STAGING = .dmg_staging

icon:
	@echo "→ Generiere App-Icon…"
	swift scripts/make_icon.swift
	@echo "✓ Icon generiert"

build:
	swift build -c release
	mkdir -p $(MACOS) $(RESOURCES)
	cp $(BUILD_DIR)/$(APP_NAME) $(MACOS)/
	cp Resources/Info.plist $(CONTENTS)/
	@/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $(VERSION)" $(CONTENTS)/Info.plist
	@/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $(VERSION)" $(CONTENTS)/Info.plist
	@for lproj in Resources/*.lproj; do cp -r "$$lproj" $(RESOURCES)/; done
	@if [ -f Resources/AppIcon.icns ]; then cp Resources/AppIcon.icns $(RESOURCES)/; fi
	@echo "✓ $(APP) fertig ($(VERSION))"

run: build
	open $(APP)

install: build
	cp -r $(APP) /Applications/
	@echo "✓ In /Applications/ installiert"

release: build
	rm -rf $(DMG_STAGING) $(DMG)
	mkdir -p $(DMG_STAGING)
	cp -r $(APP) $(DMG_STAGING)/
	ln -s /Applications $(DMG_STAGING)/Applications
	hdiutil create -volname "$(APP_NAME)" -srcfolder $(DMG_STAGING) -ov -format UDZO $(DMG)
	rm -rf $(DMG_STAGING)
	@echo "✓ $(DMG) bereit für Distribution"

clean:
	rm -rf .build $(APP) $(APP_NAME)-*.dmg $(DMG_STAGING)
