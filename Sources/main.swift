import Cocoa

// MARK: - 命令行入口
// 直接运行 → 启动桌面宠物。
// 带子命令 → 当 CLI 用(可在脚本里查用量，不弹宠物)。
let args = Array(CommandLine.arguments.dropFirst())

func printUsage() {
    print("""
    UsagePet — 桌面 AI 用量宠物 / desktop AI-usage pet

    用法 / Usage:
      usagepet                启动桌面宠物 (默认)
      usagepet status         打印当前用量(纯文本)
      usagepet status --json  打印当前用量(JSON，给脚本用)
      usagepet codex          打印 Codex 速率限额
      usagepet relays         列出已配置的中转 API
      usagepet --help         显示本帮助
      usagepet --version      显示版本
    """)
}

let version = "1.0"

switch args.first {
case nil:
    // 无参数 → 启动 GUI 宠物
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.run()

case "--help", "-h", "help":
    printUsage()

case "--version", "-v", "version":
    print("usagepet \(version)")

case "status":
    CLI.status(json: args.contains("--json"))

case "codex":
    CLI.codex(json: args.contains("--json"))

case "relays":
    CLI.relays()

default:
    FileHandle.standardError.write("未知命令: \(args.first ?? "")\n\n".data(using: .utf8)!)
    printUsage()
    exit(2)
}
