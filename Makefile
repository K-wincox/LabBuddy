.PHONY: help preflight package open clean-demo-package

help:
	@echo "LabBuddy local commands"
	@echo "  make preflight          Run local iOS checks and build if Xcode is available"
	@echo "  make package            Create dist/LabBuddy-iOS-prototype-latest.zip"
	@echo "  make open               Open LabBuddy.xcodeproj through the launcher"
	@echo "  make clean-demo-package Remove generated local prototype zip files"

preflight:
	./scripts/check-ios-local.sh

package:
	./scripts/package-ios-prototype.sh

open:
	./Open-LabBuddy.command

clean-demo-package:
	rm -rf dist
