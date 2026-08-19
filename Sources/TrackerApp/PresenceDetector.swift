import AVFoundation
import Vision
import CoreImage
import AppKit
import TrackerCore

final class FrameGrabber: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    let semaphore = DispatchSemaphore(value: 0)
    private(set) var pixelBuffer: CVPixelBuffer?

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard pixelBuffer == nil else { return }
        if let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
            pixelBuffer = buffer
            semaphore.signal()
        }
    }
}

final class PresenceDetector: PresenceDetecting {
    var onFrameCaptured: ((NSImage) -> Void)?
    private let ciContext = CIContext()

    func detectPresence() -> PresenceResult {
        let session = AVCaptureSession()
        session.sessionPreset = .low

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
                ?? AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input)
        else { return .cameraUnavailable }
        session.addInput(input)

        let output = AVCaptureVideoDataOutput()
        output.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)
        ]
        output.alwaysDiscardsLateVideoFrames = true
        guard session.canAddOutput(output) else { return .cameraUnavailable }
        session.addOutput(output)

        let grabber = FrameGrabber()
        let queue = DispatchQueue(label: "com.presencetracker.capture")
        output.setSampleBufferDelegate(grabber, queue: queue)

        session.startRunning()
        let gotFrame = grabber.semaphore.wait(timeout: .now() + 3) == .success
        session.stopRunning()
        output.setSampleBufferDelegate(nil, queue: nil)

        guard gotFrame, let buffer = grabber.pixelBuffer else {
            return .cameraUnavailable
        }

        let ciImage = CIImage(cvPixelBuffer: buffer)
        if let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) {
            let image = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
            onFrameCaptured?(image)
        }

        let faceThreshold = UserDefaults.standard.object(forKey: Settings.faceSizeThresholdKey) as? Double
            ?? Settings.defaultFaceSizeThreshold
        let request = VNDetectFaceRectanglesRequest()
        let handler = VNImageRequestHandler(cvPixelBuffer: buffer, options: [:])
        try? handler.perform([request])

        let largestWidth = request.results?.map { $0.boundingBox.width }.max() ?? 0
        if CGFloat(largestWidth) >= CGFloat(faceThreshold) {
            return .present
        }

        // Fallback: human-body detection catches rotated-chair / face-away cases
        // where the face detector misses at full profile. Require a large enough
        // body box so a person standing 3m away is NOT counted as working.
        let bodyThreshold = UserDefaults.standard.object(forKey: Settings.bodySizeThresholdKey) as? Double
            ?? Settings.defaultBodySizeThreshold
        let bodyRequest = VNDetectHumanRectanglesRequest()
        try? handler.perform([bodyRequest])
        let largestBodyArea = bodyRequest.results?
            .map { $0.boundingBox.width * $0.boundingBox.height }
            .max() ?? 0
        return CGFloat(largestBodyArea) >= CGFloat(bodyThreshold) ? .present : .absent
    }
}
