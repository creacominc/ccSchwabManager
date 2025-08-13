//
//  CSVShareManager.swift
//  ccSchwabManager
//
//  Created by AI Assistant on 2025-01-27.
//

import Foundation
import SwiftUI

#if os(iOS)
import UIKit

// iOS-specific CSV sharing manager
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

// SwiftUI wrapper for UIActivityViewController
struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    let applicationActivities: [UIActivity]?
    
    init(activityItems: [Any], applicationActivities: [UIActivity]? = nil) {
        self.activityItems = activityItems
        self.applicationActivities = applicationActivities
    }
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
        controller.setValue("CSV Export", forKey: "subject")
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// SwiftUI view that handles CSV sharing on iOS
struct CSVShareView: View {
    @ObservedObject var shareManager = CSVShareManager.shared
    
    var body: some View {
        EmptyView()
            .sheet(isPresented: $shareManager.isShowingShareSheet) {
                // Create temporary file and share it
                let tempFileURL = createTempCSVFile()
                ShareSheet(activityItems: [tempFileURL])
                    .onDisappear {
                        // Clean up temporary file
                        try? FileManager.default.removeItem(at: tempFileURL)
                    }
            }
    }
    
    private func createTempCSVFile() -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let tempFileURL = documentsPath.appendingPathComponent(shareManager.csvFileName)
        
        do {
            try shareManager.csvContent.write(to: tempFileURL, atomically: true, encoding: .utf8)
        } catch {
            print("Error creating temporary CSV file: \(error)")
        }
        
        return tempFileURL
    }
}
#else
// macOS placeholder - this ensures the class exists on all platforms
class CSVShareManager: ObservableObject {
    static let shared = CSVShareManager()
    
    @Published var isShowingShareSheet = false
    @Published var csvContent = ""
    @Published var csvFileName = ""
    
    private init() {}
    
    func shareCSV(content: String, fileName: String) {
        // No-op on macOS since we use NSSavePanel directly
    }
}

// Placeholder ShareSheet for macOS
struct ShareSheet: View {
    let activityItems: [Any]
    let applicationActivities: [UIActivity]?
    
    init(activityItems: [Any], applicationActivities: [UIActivity]? = nil) {
        self.activityItems = activityItems
        self.applicationActivities = applicationActivities
    }
    
    var body: some View {
        EmptyView()
    }
}

// Placeholder CSVShareView for macOS
struct CSVShareView: View {
    var body: some View {
        EmptyView()
    }
}
#endif