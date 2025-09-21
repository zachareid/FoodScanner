import AVFoundation
import AudioToolbox
import SwiftUI

struct BarcodeScannerView: UIViewControllerRepresentable {
    @Binding var isScanning: Bool
    var onBarcodeScanned: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(isScanning: $isScanning, onBarcodeScanned: onBarcodeScanned)
    }

    func makeUIViewController(context: Context) -> CameraViewController {
        let controller = CameraViewController()
        controller.setMetadataDelegate(context.coordinator)
        return controller
    }

    func updateUIViewController(_ uiViewController: CameraViewController, context: Context) {
        context.coordinator.onBarcodeScanned = onBarcodeScanned
        uiViewController.setIsScanning(isScanning)
    }

    final class Coordinator: NSObject, AVCaptureMetadataOutputObjectsDelegate {
        private let isScanning: Binding<Bool>
        var onBarcodeScanned: (String) -> Void

        init(isScanning: Binding<Bool>, onBarcodeScanned: @escaping (String) -> Void) {
            self.isScanning = isScanning
            self.onBarcodeScanned = onBarcodeScanned
        }

        func metadataOutput(_ output: AVCaptureMetadataOutput,
                            didOutput metadataObjects: [AVMetadataObject],
                            from connection: AVCaptureConnection) {
            guard isScanning.wrappedValue else { return }
            guard let first = metadataObjects.compactMap({ $0 as? AVMetadataMachineReadableCodeObject }).first,
                  let value = first.stringValue else { return }

            isScanning.wrappedValue = false
            AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
            onBarcodeScanned(value)
        }
    }
}

final class CameraViewController: UIViewController {
    private let captureSession = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "BarcodeScannerSessionQueue")
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var metadataOutput: AVCaptureMetadataOutput?
    private var isConfigured = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        configureSessionIfNeeded()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.layer.bounds
    }

    func setMetadataDelegate(_ delegate: AVCaptureMetadataOutputObjectsDelegate) {
        configureSessionIfNeeded()
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.metadataOutput?.setMetadataObjectsDelegate(delegate, queue: DispatchQueue.main)
        }
    }

    func setIsScanning(_ shouldScan: Bool) {
        configureSessionIfNeeded()
        shouldScan ? startSession() : stopSession()
    }
}

private extension CameraViewController {
    func configureSessionIfNeeded() {
        sessionQueue.sync {
            guard !isConfigured else { return }

            captureSession.beginConfiguration()
            captureSession.sessionPreset = .high

            guard let videoDevice = AVCaptureDevice.default(for: .video),
                  let videoInput = try? AVCaptureDeviceInput(device: videoDevice),
                  captureSession.canAddInput(videoInput) else {
                captureSession.commitConfiguration()
                return
            }
            captureSession.addInput(videoInput)

            let metadataOutput = AVCaptureMetadataOutput()
            guard captureSession.canAddOutput(metadataOutput) else {
                captureSession.commitConfiguration()
                return
            }
            captureSession.addOutput(metadataOutput)
            metadataOutput.metadataObjectTypes = supportedCodeTypes
            metadataOutput.setMetadataObjectsDelegate(nil, queue: DispatchQueue.main)
            self.metadataOutput = metadataOutput

            captureSession.commitConfiguration()
            isConfigured = true
        }

        guard previewLayer == nil else { return }
        let layer = AVCaptureVideoPreviewLayer(session: captureSession)
        layer.videoGravity = .resizeAspectFill
        layer.frame = view.layer.bounds
        view.layer.insertSublayer(layer, at: 0)
        previewLayer = layer
    }

    func startSession() {
        sessionQueue.async {
            guard !self.captureSession.isRunning else { return }
            self.captureSession.startRunning()
        }
    }

    func stopSession() {
        sessionQueue.async {
            guard self.captureSession.isRunning else { return }
            self.captureSession.stopRunning()
        }
    }

    var supportedCodeTypes: [AVMetadataObject.ObjectType] {
        [.ean13, .ean8, .upce, .qr, .code128, .code39, .code93, .pdf417]
    }
}
