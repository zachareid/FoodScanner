import SwiftUI
import UIKit

struct ContentView: View {
    @StateObject private var viewModel = ProductScannerViewModel()
    @State private var isScannerActive = false
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    scannerCard
                    statusCard
                    productSection
                }
                .padding(.vertical, 24)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Food Scanner")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await viewModel.prepareCamera()
            }
            .onChange(of: scenePhase) { newPhase in
                if newPhase == .active {
                    viewModel.refreshAuthorizationStatus()
                    if viewModel.cameraAuthorizationState == .authorized,
                       viewModel.scannerState == .idle {
                        viewModel.beginNewScan()
                    }
                    isScannerActive = viewModel.scannerState == .scanning && viewModel.cameraAuthorizationState == .authorized
                }
            }
            .onChange(of: viewModel.cameraAuthorizationState) { _ in
                withAnimation(.easeInOut(duration: 0.2)) {
                    isScannerActive = viewModel.cameraAuthorizationState == .authorized && viewModel.scannerState == .scanning
                }
            }
            .onChange(of: viewModel.scannerState) { newState in
                withAnimation(.easeInOut(duration: 0.2)) {
                    isScannerActive = newState == .scanning && viewModel.cameraAuthorizationState == .authorized
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private var scannerCard: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(.secondarySystemBackground))
                .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 6)

            if viewModel.cameraAuthorizationState == .authorized {
                BarcodeScannerView(isScanning: $isScannerActive, onBarcodeScanned: viewModel.handleScannedBarcode)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .overlay(scannerOverlay)
            } else {
                permissionPrompt
                    .padding()
            }
        }
        .frame(height: 320)
    }

    private var scannerOverlay: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color.white.opacity(0.35), lineWidth: 2)

            VStack(spacing: 16) {
                Spacer()
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.white.opacity(0.7), lineWidth: 2)
                    .frame(width: 220, height: 160)
                    .overlay(
                        VStack(spacing: 8) {
                            Image(systemName: "camera.viewfinder")
                                .font(.title)
                                .foregroundStyle(Color.white)
                            Text(instructionText)
                                .font(.footnote)
                                .multilineTextAlignment(.center)
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                        }
                    )
                Spacer(minLength: 24)
            }
            .padding()
        }
        .allowsHitTesting(false)
    }

    private var instructionText: String {
        switch viewModel.scannerState {
        case .scanning:
            return "Align the barcode within the frame to scan."
        case .fetching:
            return "Fetching details…"
        case .result:
            return "Tap Scan Again for another product."
        case .error:
            return "Adjust the camera and try again."
        case .idle:
            return "Allow camera access to start scanning."
        }
    }

    @ViewBuilder
    private var permissionPrompt: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.shield")
                .font(.system(size: 44))
                .foregroundStyle(.blue)

            Text("Camera access needed")
                .font(.headline)

            Text("Grant camera permission so we can scan product barcodes.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button(action: openAppSettings) {
                Text("Open Settings")
                    .fontWeight(.semibold)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            switch viewModel.scannerState {
            case .idle:
                Text("Ready to scan")
                    .font(.headline)
                Text("Grant camera access to start scanning barcodes and seeing what’s inside your foods.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            case .scanning:
                Text("Point at a barcode")
                    .font(.headline)
                Text("The scan happens automatically when we detect a barcode.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            case .fetching:
                HStack(spacing: 12) {
                    ProgressView()
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Looking up product…")
                            .font(.headline)
                        if let code = viewModel.scannedBarcode {
                            Text(code)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            case .result:
                Text("Product found")
                    .font(.headline)
                if let code = viewModel.scannedBarcode {
                    Label(code, systemImage: "barcode")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Button(action: viewModel.beginNewScan) {
                    Label("Scan again", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
            case .error(let message):
                Text("Something went wrong")
                    .font(.headline)
                    .foregroundStyle(.red)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if let code = viewModel.scannedBarcode {
                    Text("Last barcode: \(code)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Button(action: viewModel.retry) {
                    Label("Try again", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color(.secondarySystemBackground)))
    }

    @ViewBuilder
    private var productSection: some View {
        if let product = viewModel.product, viewModel.scannerState == .result {
            VStack(alignment: .leading, spacing: 16) {
                Text("Product details")
                    .font(.title3)
                    .fontWeight(.semibold)
                ProductDetailView(product: product)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color(.secondarySystemBackground)))
        } else {
            VStack(alignment: .leading, spacing: 12) {
                Text("Scan something to begin")
                    .font(.headline)
                Text("We’ll pull nutrition facts, ingredients, and scores from Open Food Facts.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color(.secondarySystemBackground)))
        }
    }

    private func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        openURL(url)
    }
}

#Preview {
    ContentView()
}
