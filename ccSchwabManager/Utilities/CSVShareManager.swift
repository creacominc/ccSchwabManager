//
//  CSVShareManager.swift
//  ccSchwabManager
//
//  Created by AI Assistant on 2025-01-27.
//

import Foundation
import SwiftUI

// CSV sharing manager that works on both platforms
class CSVShareManager: ObservableObject {
    static let shared = CSVShareManager()
    
    @Published var isShowingShareSheet = false
    @Published var csvContent = ""
    @Published var csvFileName = ""
    
    private init() {}
    
    func shareCSV(content: String, fileName: String) {
        csvContent = content
        csvFileName = fileName
        isShowingShareSheet = true
    }
}

// IOS or VisionOS
#if os(iOS) ||  os(visionOS)
import UIKit

// SwiftUI wrapper for UIActivityViewController (iOS only)
struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    let applicationActivities: [Any]?
    
    init(activityItems: [Any], applicationActivities: [Any]? = nil) {
        self.activityItems = activityItems
        self.applicationActivities = applicationActivities
    }
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities as? [UIActivity])
        controller.setValue("CSV Export", forKey: "subject")
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// SwiftUI view that handles CSV sharing on iOS
struct CSVShareView: View {
    @ObservedObject var shareManager = CSVShareManager.shared
    @State private var tempFileURL: URL?
    @State private var showError = false
    
    var body: some View {
        EmptyView()
            .sheet(isPresented: $shareManager.isShowingShareSheet) {
                Group {
                    if let fileURL = tempFileURL {
                        ShareSheet(activityItems: [fileURL])
                            .onDisappear {
                                // Clean up temporary file
                                try? FileManager.default.removeItem(at: fileURL)
                                tempFileURL = nil
                            }
                    } else {
                        // Show error alert if file creation failed
                        VStack {
                            Text("Failed to create CSV file")
                                .foregroundColor(.red)
                                .padding()
                            Button("Dismiss") {
                                shareManager.isShowingShareSheet = false
                            }
                            .padding()
                        }
                    }
                }
                .onAppear {
                    // Create temporary file when sheet appears
                    tempFileURL = createTempCSVFile()
                }
            }
    }
    
    private func createTempCSVFile() -> URL? {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let tempFileURL = documentsPath.appendingPathComponent(shareManager.csvFileName)
        
        do {
            try shareManager.csvContent.write(to: tempFileURL, atomically: true, encoding: .utf8)
            print("Successfully created temporary CSV file at: \(tempFileURL.path)")
            return tempFileURL
        } catch {
            print("Error creating temporary CSV file: \(error)")
            print("CSV content length: \(shareManager.csvContent.count)")
            print("File path: \(tempFileURL.path)")
            return nil
        }
    }
}
#else
// macOS placeholder ShareSheet - this ensures the struct exists on all platforms
struct ShareSheet: View {
    let activityItems: [Any]
    let applicationActivities: [Any]?
    
    init(activityItems: [Any], applicationActivities: [Any]? = nil) {
        self.activityItems = activityItems
        self.applicationActivities = applicationActivities
    }
    
    var body: some View {
        EmptyView()
    }
}

// macOS placeholder CSVShareView - this ensures the struct exists on all platforms
struct CSVShareView: View {
    var body: some View {
        EmptyView()
    }
}
#endif
