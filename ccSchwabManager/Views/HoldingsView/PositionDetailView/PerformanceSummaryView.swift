import SwiftUI
#if os(macOS)
import AppKit
#endif

struct PerformanceSummaryView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var summaryText: String = "Loading..."
    
    var body: some View {
        #if os(macOS)
        VStack(spacing: 0) {
            // macOS header
            HStack {
                Text("Performance Benchmark")
                    .font(.headline)
                Spacer()
                Button("Export") {
                    exportPerformanceData()
                }
                Button("Close") {
                    dismiss()
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(summaryText)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                        .padding()
                }
            }
        }
        .frame(minWidth: 600, minHeight: 400)
        .onAppear {
            loadSummary()
        }
        #else
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(summaryText)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                        .padding()
                }
            }
            .navigationTitle("Performance Benchmark")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Export") {
                        exportPerformanceData()
                    }
                }
            }
            .onAppear {
                loadSummary()
            }
        }
        #endif
    }
    
    private func loadSummary() {
        summaryText = PerformanceBenchmark.shared.getSessionSummary()
    }
    
    private func exportPerformanceData() {
        guard let data = PerformanceBenchmark.shared.exportSessionData(),
              let jsonData = try? JSONSerialization.data(withJSONObject: data, options: .prettyPrinted),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            return
        }
        
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "performance_benchmark_\(Date().timeIntervalSince1970).json"
        panel.begin { response in
            if response == .OK, let url = panel.url {
                try? jsonString.write(to: url, atomically: true, encoding: .utf8)
            }
        }
    }
}
