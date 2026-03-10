import SwiftUI
#if os(macOS)
import AppKit
import UniformTypeIdentifiers
#endif

struct PerformanceSummaryView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var summaryText: String = "Loading..."
    @State private var storageLocation: String = ""
    
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
                    if !storageLocation.isEmpty {
                        Text("Storage: \(storageLocation)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                            .padding(.top, 8)
                    }
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
                    if !storageLocation.isEmpty {
                        Text("Storage: \(storageLocation)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                            .padding(.top, 8)
                    }
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
        storageLocation = PerformanceBenchmark.shared.getStorageLocation()
    }
    
    private func exportPerformanceData() {
        guard let data = PerformanceBenchmark.shared.exportSessionData(),
              let jsonData = try? JSONSerialization.data(withJSONObject: data, options: .prettyPrinted),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            return
        }
        
        #if os(macOS)
        Task { @MainActor in
            let panel = NSSavePanel()
            panel.allowedContentTypes = [UTType.json]
            panel.nameFieldStringValue = "performance_benchmark_\(Date().timeIntervalSince1970).json"
            panel.directoryURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
            
            panel.begin { response in
                if response == .OK, let url = panel.url {
                    do {
                        try jsonString.write(to: url, atomically: true, encoding: .utf8)
                        print("JSON file saved successfully to: \(url.path)")
                    } catch {
                        print("Error saving JSON file: \(error)")
                    }
                }
            }
        }
        #else
        // iOS implementation - use share sheet
        CSVShareManager.shared.shareJSON(jsonString: jsonString, fileName: "performance_benchmark_\(Date().timeIntervalSince1970).json")
        #endif
    }
}
