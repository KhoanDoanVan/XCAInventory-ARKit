//
//  InventoryFormView.swift
//  XCAInventoryTracker
//
//  Created by Đoàn Văn Khoan on 3/10/24.
//

import SwiftUI
import UniformTypeIdentifiers
import SafariServices
import USDZScanner

struct InventoryFormView: View {
    
    @StateObject var viewModel = InventoryFormViewModel()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        Form {
            List {
                inputSection
                arSection
            }
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
                .disabled(viewModel.loadingState != .none)
            }
            
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    do {
                        try viewModel.save()
                        dismiss()
                    } catch {}
                }
                .disabled(viewModel.loadingState != .none || viewModel.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .confirmationDialog("Add USDZ", isPresented: $viewModel.showUSDZSource, titleVisibility: .visible, actions: {
            Button("Select file") {
                viewModel.selectedUSDZSource = .fileImporter
            }
            
            Button("Object Capture") {
                viewModel.selectedUSDZSource = .objectCapture
            }
        })
        .sheet(isPresented: .init(get: { viewModel.selectedUSDZSource == .objectCapture }, set: { _ in
            viewModel.selectedUSDZSource = nil
        }), content: {
            USDZScanner { url in
                Task {
                    await viewModel.uploadUSDZ(fileURL:url)
                }
                viewModel.selectedUSDZSource = nil
            }
        })
        .fileImporter(isPresented: .init(get: { viewModel.selectedUSDZSource == .fileImporter }, set: { _ in
            viewModel.selectedUSDZSource = nil
        }), allowedContentTypes: [UTType.usdz], onCompletion: { result in
            switch result {
            case .success(let url):
                Task { await viewModel.uploadUSDZ(fileURL:url, isSecurityScopedResource: true) }
            case .failure(let failure):
                viewModel.error = failure.localizedDescription
            }
        })
        .alert(isPresented: .init(get: { viewModel.error != nil }, set: { _ in
            viewModel.error = nil
        }), error: "An error has occured", actions: { _ in
            
        }, message: { _ in
            Text(viewModel.error ?? "")
        })
        .navigationTitle(viewModel.navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
    }
    
    var inputSection: some View {
        Section {
            TextField("Name", text: $viewModel.name)
            Stepper("Quantity: \(viewModel.quantity)", value: $viewModel.quantity)
        }
        .disabled(viewModel.loadingState != .none)
    }
    
    var arSection: some View {
        Section("ARModel") {
            if let thumbnailURL = viewModel.thumbnailURL {
                AsyncImage(url: thumbnailURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: .infinity, maxHeight: 300)
                    case .failure(let error):
                        Text("Failed to fetch thumbnail")
                    default:
                        ProgressView()
                    }
                }
                .onTapGesture {
                    guard let usdzURL = viewModel.usdzURL else { return }
                    viewAR(url: usdzURL)
                }
            }
            
            if let usdzURL = viewModel.usdzURL {
                Button {
                    viewAR(url: usdzURL)
                } label: {
                    HStack {
                        Image(systemName: "arkit")
                            .imageScale(.large)
                        Text("View")
                    }
                }
            } else {
                Button {
                    viewModel.showUSDZSource = true
                } label: {
                    HStack {
                        Image(systemName: "arkit")
                            .imageScale(.large)
                        Text("Add USDZ")
                    }
                }
            }
            
            if let progress = viewModel.uploadProgress,
               case let .uploading(type) = viewModel.loadingState,
               progress.totalUnitCount > 0 {
                VStack {
                    ProgressView(value: progress.fractionCompleted) {
                        Text("Uploading \(type == .usdz ? "USDZ" : "Thumbnail") file \(Int(progress.fractionCompleted * 100)) %")
                    }
                    
                    Text("\(viewModel.byteCountFormatter.string(fromByteCount: progress.completedUnitCount)) / \(viewModel.byteCountFormatter.string(fromByteCount: progress.totalUnitCount))")
                }
            }
        }
        .disabled(viewModel.loadingState != .none)
    }
    
    func viewAR(url: URL) {
        let safariVC = SFSafariViewController(url: url)
        let vc = UIApplication.shared.firstKeyWindow?.rootViewController?.presentedViewController ?? UIApplication.shared.firstKeyWindow?.rootViewController
        vc?.present(safariVC, animated: true)
    }
}

extension UIApplication {
    var firstKeyWindow: UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap {
                $0 as? UIWindowScene
            }
            .filter {
                $0.activationState == .foregroundActive
            }
            .first?.keyWindow
    }
}


#Preview {
    NavigationStack {
        InventoryFormView()
    }
}
