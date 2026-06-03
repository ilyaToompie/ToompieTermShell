import Foundation

struct AdminCommand: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let command: String
}

enum AdminCommands {
    static let groups: [(String, [AdminCommand])] = [
        ("Overview", [
            AdminCommand(title: "System info", icon: "info.circle", command: "uname -a; echo; uptime; echo; df -h; echo; free -h 2>/dev/null || vm_stat"),
            AdminCommand(title: "Uptime / load", icon: "clock", command: "uptime"),
            AdminCommand(title: "OS release", icon: "apple.logo", command: "cat /etc/os-release 2>/dev/null || sw_vers")
        ]),
        ("Resources", [
            AdminCommand(title: "Disk usage", icon: "internaldrive", command: "df -h"),
            AdminCommand(title: "Largest dirs here", icon: "chart.pie", command: "du -ahx . 2>/dev/null | sort -rh | head -20"),
            AdminCommand(title: "Memory", icon: "memorychip", command: "free -h 2>/dev/null || vm_stat"),
            AdminCommand(title: "Top by CPU", icon: "chart.bar", command: "ps aux | sort -rk3 | head -15"),
            AdminCommand(title: "Top by RAM", icon: "chart.bar.fill", command: "ps aux | sort -rk4 | head -15")
        ]),
        ("Network", [
            AdminCommand(title: "Listening ports", icon: "network", command: "ss -tulpn 2>/dev/null || netstat -tulpn 2>/dev/null || lsof -iTCP -sTCP:LISTEN -n -P"),
            AdminCommand(title: "Active connections", icon: "point.3.connected.trianglepath.dotted", command: "ss -tunp 2>/dev/null || netstat -tunp"),
            AdminCommand(title: "Public IP", icon: "globe", command: "curl -s ifconfig.me; echo")
        ]),
        ("Services & logs", [
            AdminCommand(title: "Failed services", icon: "exclamationmark.triangle", command: "systemctl --failed --no-pager 2>/dev/null"),
            AdminCommand(title: "Recent journal", icon: "doc.text.magnifyingglass", command: "journalctl -xe --no-pager 2>/dev/null | tail -50"),
            AdminCommand(title: "Docker ps", icon: "shippingbox", command: "docker ps"),
            AdminCommand(title: "Nginx test", icon: "checkmark.seal", command: "nginx -t 2>&1 || sudo nginx -t")
        ]),
        ("Sessions", [
            AdminCommand(title: "Who is online", icon: "person.2", command: "w"),
            AdminCommand(title: "Last logins", icon: "clock.arrow.circlepath", command: "last -n 20"),
            AdminCommand(title: "Auth failures", icon: "lock.trianglebadge.exclamationmark", command: "grep -i 'failed password' /var/log/auth.log 2>/dev/null | tail -20")
        ])
    ]
}
