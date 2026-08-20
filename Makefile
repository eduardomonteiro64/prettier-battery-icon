.PHONY: all build dmg clean run

all: dmg

build:
	chmod +x scripts/build.sh
	./scripts/build.sh

dmg: build
	chmod +x scripts/create_dmg.sh
	./scripts/create_dmg.sh

run: build
	open build/PrettierBattery.app

clean:
	rm -rf build PrettierBattery.dmg AppIcon.iconset
