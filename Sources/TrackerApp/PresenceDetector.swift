import AVFoundation
import Vision
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
    private static let minFaceWidth: CGFloat = 0.15

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

        let request = VNDetectFaceRectanglesRequest()
        let handler = VNImageRequestHandler(cvPixelBuffer: buffer, options: [:])
        try? handler.perform([request])

        let largestWidth = request.results?.map { $0.boundingBox.width }.max() ?? 0
        if largestWidth >= Self.minFaceWidth {
            return .present
        }

        // Fallback: human-body detection catches rotated-chair / face-away cases
        // where the face detector misses at full profile.
        let bodyRequest = VNDetectHumanRectanglesRequest()
        try? handler.perform([bodyRequest])
        let hasBody = (bodyRequest.results?.isEmpty == false)
        return hasBody ? .present : .absent
    }
}
