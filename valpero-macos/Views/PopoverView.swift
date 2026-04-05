import SwiftUI

struct PopoverView: View {
    @EnvironmentObject var state: AppState

    @AppStorage("sec_monitors")   private var showMonitors   = true
    @AppStorage("sec_heartbeats") private var showHeartbeats = true
    @AppStorage("sec_servers")    private var showServers    = true
    @AppStorage("sec_incidents")  private var showIncidents  = true

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    if !state.hasKey {
                        noKeyView
                    } else if state.isLoading && state.monitors.isEmpty {
                        loadingView
                    } else {
                        if !state.openIncidents.isEmpty {
                            incidentsSection
                        }
                        monitorsSection
                        if !state.heartbeats.isEmpty { heartbeatsSection }
                        if !state.agents.isEmpty     { serversSection }
                    }
                }
                .padding(.bottom, 8)
            }
            Divider()
            footer
        }
        .frame(width: 340)
        .background(.regularMaterial)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            // Logo / brand
            HStack(spacing: 6) {
                Circle()
                    .fill(
                        state.hasKey
                        ? (state.downCount > 0 ? Color.red : Color.green)
                        : Color.gray
                    )
                    .frame(width: 8, height: 8)
                    .shadow(
                        color: state.downCount > 0 ? .red.opacity(0.6) : .green.opacity(0.6),
                        radius: 4
                    )
                Text("Valpero")
                    .font(.system(size: 13, weight: .semibold))
            }

            Spacer()

            // Refresh button
            Button {
                state.refresh()
            } label: {
                Image(systemName: state.isLoading ? "arrow.triangle.2.circlepath" : "arrow.clockwise")
                    .font(.system(size: 12))
                    .rotationEffect(.degrees(state.isLoading ? 360 : 0))
                    .animation(
                        state.isLoading
                        ? .linear(duration: 1).repeatForever(autoreverses: false)
                        : .default,
                        value: state.isLoading
                    )
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("Refresh")

            // Settings button
            Button {
                state.onOpenSettings?()
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 12))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("Settings")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: - No key state

    private var noKeyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "key.slash")
                .font(.system(size: 32))
                .foregroundStyle(.tertiary)

            VStack(spacing: 6) {
                Text("No API key set")
                    .font(.system(size: 13, weight: .medium))
                Text("Open Settings to connect your Valpero account.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button("Open Settings") {
                state.onOpenSettings?()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .frame(maxWidth: .infinity)
        .padding(32)
    }

    // MARK: - Loading state

    private var loadingView: some View {
        VStack(spacing: 12) {
            ForEach(0..<4, id: \.self) { _ in
                HStack(spacing: 8) {
                    Circle().frame(width: 7, height: 7)
                    RoundedRectangle(cornerRadius: 3).frame(height: 10)
                    Spacer()
                    RoundedRectangle(cornerRadius: 3).frame(width: 40, height: 10)
                }
                .foregroundStyle(Color.secondary.opacity(0.15))
                .shimmering()
            }
        }
        .padding(16)
    }

    // MARK: - Incidents section

    private var incidentsSection: some View {
        VStack(spacing: 0) {
            sectionRow {
                SectionHeader(
                    title: "Open Incidents",
                    icon: "exclamationmark.triangle.fill",
                    count: state.openIncidents.count,
                    hasIssue: true,
                    expanded: $showIncidents
                )
            }
            if showIncidents {
                ForEach(state.openIncidents) { inc in
                    itemRow {
                        HStack(spacing: 8) {
                            Circle().fill(Color.red).frame(width: 7, height: 7)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(inc.siteName).font(.system(size: 12)).lineLimit(1)
                                if let cause = inc.cause, !cause.isEmpty {
                                    Text(cause)
                                        .font(.system(size: 10))
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                            }
                            Spacer()
                            Text(inc.formattedDuration)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.red)
                        }
                    }
                }
                Divider().padding(.vertical, 4)
            }
        }
    }

    // MARK: - Monitors section

    private var monitorsSection: some View {
        VStack(spacing: 0) {
            sectionRow {
                SectionHeader(
                    title: "Monitors",
                    icon: "antenna.radiowaves.left.and.right",
                    count: state.monitors.count,
                    hasIssue: state.downCount > 0,
                    expanded: $showMonitors
                )
            }
            if showMonitors {
                if state.monitors.isEmpty {
                    emptyRow(text: "No monitors yet")
                } else {
                    // Down first
                    ForEach(state.monitors.filter { !$0.isUp }) { mon in
                        itemRow { MonitorRowView(monitor: mon) }
                    }
                    ForEach(state.monitors.filter { $0.isUp }) { mon in
                        itemRow { MonitorRowView(monitor: mon) }
                    }
                }
            }
        }
    }

    // MARK: - Heartbeats section

    private var heartbeatsSection: some View {
        VStack(spacing: 0) {
            Divider().padding(.vertical, 4)
            sectionRow {
                SectionHeader(
                    title: "Heartbeats",
                    icon: "heart",
                    count: state.heartbeats.count,
                    hasIssue: state.heartbeats.contains { !$0.isUp && !$0.isNew },
                    expanded: $showHeartbeats
                )
            }
            if showHeartbeats {
                ForEach(state.heartbeats) { hb in
                    itemRow { HeartbeatRowView(hb: hb) }
                }
            }
        }
    }

    // MARK: - Servers section

    private var serversSection: some View {
        VStack(spacing: 0) {
            Divider().padding(.vertical, 4)
            sectionRow {
                SectionHeader(
                    title: "Servers",
                    icon: "server.rack",
                    count: state.agents.count,
                    hasIssue: state.agents.contains { !$0.isOnline },
                    expanded: $showServers
                )
            }
            if showServers {
                ForEach(state.agents) { agent in
                    itemRow { AgentRowView(agent: agent) }
                }
            }
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            if let t = state.lastRefresh {
                Text("Updated \(t, formatter: timeFormatter)")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            } else if state.error != nil {
                Label(state.error!.errorDescription ?? "Error", systemImage: "exclamationmark.circle")
                    .font(.system(size: 10))
                    .foregroundStyle(.red)
                    .lineLimit(1)
            }

            Spacer()

            Button("Dashboard →") {
                NSWorkspace.shared.open(URL(string: "https://valpero.com/dashboard")!)
            }
            .buttonStyle(.plain)
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    // MARK: - Helpers

    @ViewBuilder
    private func sectionRow<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
    }

    @ViewBuilder
    private func itemRow<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(.horizontal, 14)
            .padding(.vertical, 3)
    }

    @ViewBuilder
    private func emptyRow(text: String) -> some View {
        Text(text)
            .font(.system(size: 11))
            .foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 8)
    }
}

// MARK: - Time formatter

private let timeFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "HH:mm"
    return f
}()

// MARK: - Shimmer modifier

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    gradient: Gradient(colors: [.clear, .white.opacity(0.3), .clear]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .offset(x: phase * 300 - 150)
                .animation(.linear(duration: 1.2).repeatForever(autoreverses: false), value: phase)
            )
            .onAppear { phase = 1 }
            .clipShape(RoundedRectangle(cornerRadius: 3))
    }
}

extension View {
    func shimmering() -> some View { modifier(ShimmerModifier()) }
}
