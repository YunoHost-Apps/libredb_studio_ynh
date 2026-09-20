#!/bin/bash

#=================================================
# COMMON VARIABLES AND CUSTOM HELPERS
#=================================================

# package.json declares engines.node >= 24, and the project's own .deb pins
# 24.18.0 in packaging/linux/fetch-node.sh. The standalone tarball does not
# bundle a runtime, so the package installs one through `n`.
nodejs_version="24"
