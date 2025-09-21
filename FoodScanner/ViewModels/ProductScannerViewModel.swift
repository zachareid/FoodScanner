import AVFoundation
import Combine
import Foundation

@MainActor
final class ProductScannerViewModel: ObservableObject {
    enum CameraAuthorizationState: Equatable {
        case unknown
        case authorized
        case denied
        case restricted

        init(status: AVAuthorizationStatus) {
            switch status {
            case .authorized:
                self = .authorized
            case .denied:
                self = .denied
            case .restricted:
                self = .restricted
            case .notDetermined:
                self = .unknown
            @unknown default:
                self = .restricted
            }
        }
    }

    enum ScannerState: Equatable {
        case idle
        case scanning
        case fetching
        case result
        case error(message: String)
    }

    @Published var cameraAuthorizationState: CameraAuthorizationState = .unknown
    @Published var scannerState: ScannerState = .idle
    @Published var product: FoodProduct?
    @Published var scannedBarcode: String?

    private let client: OpenFoodFactsClient
    private var lastScannedCode: String?
    private var fetchTask: Task<Void, Never>?

    init(client: OpenFoodFactsClient = OpenFoodFactsClient()) {
        self.client = client
    }

    func prepareCamera() async {
        let currentStatus = AVCaptureDevice.authorizationStatus(for: .video)
        cameraAuthorizationState = CameraAuthorizationState(status: currentStatus)

        if currentStatus == .notDetermined {
            let granted = await requestCameraAccess()
            cameraAuthorizationState = granted ? .authorized : .denied
        }

        switch cameraAuthorizationState {
        case .authorized:
            if scannerState == .idle {
                beginNewScan()
            }
        case .denied, .restricted:
            scannerState = .idle
        case .unknown:
            break
        }
    }

    func beginNewScan() {
        guard cameraAuthorizationState == .authorized else { return }
        cancelInFlightFetch()
        product = nil
        scannedBarcode = nil
        lastScannedCode = nil
        scannerState = .scanning
    }

    func retry() {
        beginNewScan()
    }

    func handleScannedBarcode(_ barcode: String) {
        guard scannerState == .scanning else { return }
        let sanitized = barcode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sanitized.isEmpty else { return }
        guard sanitized != lastScannedCode else { return }

        lastScannedCode = sanitized
        scannedBarcode = sanitized
        scannerState = .fetching

        fetchTask?.cancel()
        fetchTask = Task { [weak self] in
            guard let self else { return }
            do {
                let product = try await client.fetchProduct(barcode: sanitized)
                try Task.checkCancellation()
                await MainActor.run {
                    self.product = product
                    self.scannerState = .result
                }
            } catch is CancellationError {
                return
            } catch {
                let message = self.message(for: error)
                await MainActor.run {
                    self.product = nil
                    self.scannerState = .error(message: message)
                }
            }
        }
    }

    func refreshAuthorizationStatus() {
        cameraAuthorizationState = CameraAuthorizationState(status: AVCaptureDevice.authorizationStatus(for: .video))
        if cameraAuthorizationState != .authorized {
            scannerState = .idle
        }
    }

    deinit {
        fetchTask?.cancel()
    }
}

private extension ProductScannerViewModel {
    func cancelInFlightFetch() {
        fetchTask?.cancel()
        fetchTask = nil
    }

    func requestCameraAccess() async -> Bool {
        await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .video) { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    func message(for error: Error) -> String {
        if let clientError = error as? OpenFoodFactsClient.ClientError,
           let description = clientError.errorDescription {
            return description
        }
        return error.localizedDescription
    }
}
