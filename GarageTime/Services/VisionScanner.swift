import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
#if canImport(VisionKit)
import VisionKit
#endif

/// SwiftUI wrapper around `DataScannerViewController`. Returns recognized text on stop.
struct VisionScannerView: UIViewControllerRepresentable {

    enum Mode {
        case vin            // 17 alphanumeric (excluding I, O, Q)
        case freeform       // for receipts
    }

    let mode: Mode
    let onResult: (String) -> Void
    let onCancel: () -> Void

    func makeUIViewController(context: Context) -> UIViewController {
        #if canImport(VisionKit)
        guard DataScannerViewController.isSupported, DataScannerViewController.isAvailable else {
            return UnsupportedScannerViewController(message: "VisionKit scanning isn't available on this device.", onCancel: onCancel)
        }
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.text(textContentType: nil)],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: false,
            isPinchToZoomEnabled: true,
            isGuidanceEnabled: true,
            isHighlightingEnabled: true
        )
        scanner.delegate = context.coordinator
        try? scanner.startScanning()
        context.coordinator.scanner = scanner
        return wrapped(scanner: scanner, coord: context.coordinator)
        #else
        return UnsupportedScannerViewController(message: "VisionKit not available in this build.", onCancel: onCancel)
        #endif
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    // MARK: - Wrapper to add a Cancel + Use Result toolbar over the scanner.

    private func wrapped(scanner: UIViewController, coord: Coordinator) -> UIViewController {
        let host = ScannerHostController()
        host.embed(scanner)
        host.onCancel = { onCancel() }
        host.onConfirm = { coord.confirm() }
        return host
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject {
        let parent: VisionScannerView
        weak var scanner: UIViewController?
        var lastText: String = ""

        init(parent: VisionScannerView) {
            self.parent = parent
        }

        func confirm() {
            switch parent.mode {
            case .vin:
                if let vin = extractVIN(from: lastText) {
                    parent.onResult(vin)
                } else {
                    parent.onResult("")
                }
            case .freeform:
                parent.onResult(lastText)
            }
        }

        private func extractVIN(from text: String) -> String? {
            let candidate = text.replacingOccurrences(of: " ", with: "").uppercased()
            // 17 characters, A-Z + 0-9 minus I, O, Q
            let allowed = CharacterSet(charactersIn: "ABCDEFGHJKLMNPRSTUVWXYZ0123456789")
            let scanner = Scanner(string: candidate)
            scanner.charactersToBeSkipped = nil
            while !scanner.isAtEnd {
                if let chunk = scanner.scanCharacters(from: allowed), chunk.count >= 17 {
                    return String(chunk.prefix(17))
                }
                _ = scanner.scanUpToCharacters(from: allowed)
            }
            return nil
        }
    }
}

#if canImport(VisionKit)
extension VisionScannerView.Coordinator: DataScannerViewControllerDelegate {
    func dataScanner(_ dataScanner: DataScannerViewController, didTapOn item: RecognizedItem) {
        if case .text(let text) = item {
            lastText = text.transcript
        }
    }
    func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
        // Capture continuously — the most recent recognized text becomes the candidate.
        let texts = allItems.compactMap { item -> String? in
            if case .text(let t) = item { return t.transcript }
            return nil
        }
        lastText = texts.joined(separator: "\n")
    }
}
#endif

// MARK: - Host controller (Cancel / Use buttons)

final class ScannerHostController: UIViewController {
    var onCancel: (() -> Void)?
    var onConfirm: (() -> Void)?

    func embed(_ child: UIViewController) {
        addChild(child)
        view.addSubview(child.view)
        child.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            child.view.topAnchor.constraint(equalTo: view.topAnchor),
            child.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            child.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            child.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
        child.didMove(toParent: self)

        // Toolbar overlay
        let toolbar = UIView()
        toolbar.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        toolbar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(toolbar)
        NSLayoutConstraint.activate([
            toolbar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            toolbar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            toolbar.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            toolbar.heightAnchor.constraint(equalToConstant: 100),
        ])

        let cancel = UIButton(type: .system)
        cancel.setTitle("Cancel", for: .normal)
        cancel.setTitleColor(.white, for: .normal)
        cancel.addAction(UIAction { [weak self] _ in self?.onCancel?() }, for: .touchUpInside)

        let use = UIButton(type: .system)
        use.setTitle("Use Result", for: .normal)
        use.setTitleColor(UIColor(red: 1.0, green: 0.42, blue: 0.21, alpha: 1), for: .normal)
        use.titleLabel?.font = .systemFont(ofSize: 17, weight: .bold)
        use.addAction(UIAction { [weak self] _ in self?.onConfirm?() }, for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [cancel, UIView(), use])
        stack.axis = .horizontal
        stack.distribution = .equalCentering
        stack.translatesAutoresizingMaskIntoConstraints = false
        toolbar.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: toolbar.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: toolbar.trailingAnchor, constant: -24),
            stack.topAnchor.constraint(equalTo: toolbar.topAnchor, constant: 12),
        ])
    }
}

/// Shown when the device can't run DataScannerViewController.
final class UnsupportedScannerViewController: UIViewController {
    let message: String
    let onCancel: () -> Void

    init(message: String, onCancel: @escaping () -> Void) {
        self.message = message
        self.onCancel = onCancel
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        let label = UILabel()
        label.text = message
        label.textColor = .white
        label.numberOfLines = 0
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            label.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            label.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
        ])
        let cancel = UIButton(type: .system)
        cancel.setTitle("Close", for: .normal)
        cancel.addAction(UIAction { [weak self] _ in self?.onCancel() }, for: .touchUpInside)
        cancel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(cancel)
        NSLayoutConstraint.activate([
            cancel.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 20),
            cancel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
        ])
    }
}
