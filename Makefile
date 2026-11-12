.PHONY: all build dmg clean run test

all: dmg

build:
	chmod +x scripts/build.sh
	./scripts/build.sh

dmg: build
	chmod +x scripts/create_dmg.sh
	./scripts/create_dmg.sh

test:
	mkdir -p build
	clang -fobjc-arc -Isrc/Models -Isrc/Protocols -Isrc/Services -framework Foundation src/Services/LocalizationManager.m src/Models/BatteryInfo.m scripts/test_localization.m -o build/test_localization
	./build/test_localization

run: build
	open build/PrettierBattery.app

clean:
	rm -rf build PrettierBattery.dmg AppIcon.iconset
