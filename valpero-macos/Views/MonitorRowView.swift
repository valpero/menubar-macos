import SwiftUI

// MARK: - Monitor row

struct MonitorRowView: View {
    let monitor: Monitor
    @EnvironmentObject var state: AppState

    var body: some View {
        HStack(spacing: 8) {
            // Status dot
            Circle()
                .fill(monitor.isUp ? Color.green : Color.red)
                .frame(width: 7, height: 7)
                .shadow(color: monitor.isUp ? .green.opacity(0.5) : .red.opacity(0.5), radius: 3)

            // Name
            Text(monitor.displayName)
                .font(.system(size: 12))
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer(minLength: 4)

            // Response time
            if state.showResponseTime, let rt = monitor.lastResponseTime {
                Text(formatRT(rt))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(rtColor(rt))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(rtColor(rt).opacity(0.1), in: Capsule())
            }

            // Uptime
            if state.showUptime, let u = monitor.uptime24h {
                Text(String(format: "%.1f%%", u))
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            NSWorkspace.shared.open(monitor.dashboardURL)
        }
        .padding(.vertical, 2)
    }

    private func formatRT(_ ms: Int) -> String {
        ms >= 1000 ? String(format: "%.1fs", Double(ms) / 1000) : "\(ms)ms"
    }

    private func rtColor(_ ms: Int) -> Color {
        if ms < 300 { return .green }
        if ms < 1000 { return .orange }
        return .red
    }
}

// MARK: - Server agent row

struct AgentRowView: View {
    let agent: ServerAgent

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(agent.isOnline ? Color.green : Color.gray)
                .frame(width: 7, height: 7)

            Text(agent.displayName)
                .font(.system(size: 12))
                .lineLimit(1)

            Spacer(minLength: 4)

            if let cpu = agent.cpuPct {
                metricBadge("CPU \(Int(cpu))%", color: resourceColor(cpu))
            }
            if let ram = agent.ramPct {
                metricBadge("RAM \(Int(ram))%", color: resourceColor(ram))
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { NSWorkspace.shared.open(agent.dashboardURL) }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private func metricBadge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 10, design: .monospaced))
            .foregroundStyle(color)
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background(color.opacity(0.12), in: Capsule())
    }

    private func resourceColor(_ pct: Double) -> Color {
        if pct < 70 { return .green }
        if pct < 90 { return .orange }
        return .red
    }
}

// MARK: - Heartbeat row

struct HeartbeatRowView: View {
    let hb: Heartbeat

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(hb.isUp ? Color.green : (hb.isNew ? Color.gray : Color.red))
                .frame(width: 7, height: 7)

            Text(hb.name)
                .font(.system(size: 12))
                .lineLimit(1)

            Spacer(minLength: 4)

            Text(hb.status.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(hb.isUp ? .green : (hb.isNew ? .secondary : .red))
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Section header

struct SectionHeader: View {
    let title: String
    let icon: String
    let count: Int
    let hasIssue: Bool
    @Binding var expanded: Bool

    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) { expanded.toggle() }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)

                Text(title)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .kerning(0.5)

                Spacer()

                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(hasIssue ? .red : .secondary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(hasIssue ? Color.red.opacity(0.12) : Color.secondary.opacity(0.1), in: Capsule())
                }

                Image(systemName: expanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
