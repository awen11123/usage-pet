#!/bin/bash
# 零依赖测试：用 swiftc 编译纯逻辑 + 测试入口并运行(无需 Xcode/XCTest)
set -e
cd "$(dirname "$0")"
echo "==> 编译测试"
swiftc -o /tmp/usagepet-tests \
    Sources/Logic.swift \
    Sources/I18n.swift \
    Sources/ModelInfo.swift \
    Sources/Usage.swift \
    Sources/Codex.swift \
    Sources/Relay.swift \
    Sources/Keychain.swift \
    Tests/main.swift
echo "==> 运行"
/tmp/usagepet-tests
