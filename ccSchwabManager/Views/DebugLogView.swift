import SwiftUI

struct DebugLogView: View {
    @State private var logContents: String = ""
    @State private var showingLogs = false
    
    var body: some View {
        VStack {
            Button("Show Debug Logs") {
                logContents = AppLogger.shared.getLogContents()
                showingLogs = true
            }
            .buttonStyle(.borderedProminent)
            .padding()
            
            Button("Clear Logs") {
                AppLogger.shared.clearLog()
                logContents = AppLogger.shared.getLogContents()
            }
            .buttonStyle(.bordered)
            .padding()
        }
        .sheet(isPresented: $showingLogs) {
            NavigationView {
                ScrollView {
                    Text(logContents)
                        .font(.system(.caption, design: .monospaced))
                        .padding()
                        .textSelection(.enabled)
                }
                .navigationTitle("Debug Logs")
                .toolbar {
#if os(iOS)
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            showingLogs = false
                        }
                    }
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Copy") {
                            UIPasteboard.general.string = logContents
                        }
                    }
#else
                    ToolbarItem(placement: .primaryAction) {
                        Button("Done") {
                            showingLogs = false
                        }
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Button("Copy") {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(logContents, forType: .string)
                        }
                    }
#endif
                }
            }
        }
    }
} 