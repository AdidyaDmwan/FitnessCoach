import SwiftUI
import AVFoundation
import CoreML
import UIKit
import Vision

struct CameraFeedbackView: View {
    @StateObject private var camera: PoseCameraController
    @State private var isWorkoutActive = false

    init(selectedMove: WorkoutMove = .squat) {
        _camera = StateObject(wrappedValue: PoseCameraController(selectedMove: selectedMove))
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.70, green: 0.75, blue: 0.72),
                    Color(red: 0.47, green: 0.51, blue: 0.47)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .edgesIgnoringSafeArea(.all)

            VStack(spacing: 0) {
                cameraStage
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .overlay(alignment: .top) {
                        topBar
                            .padding(.horizontal, 16)
                            .padding(.top, 50)
                    }
                    .overlay(alignment: .topLeading) {
                        if isWorkoutActive {
                            compactRepsHUD
                                .padding(.leading, 16)
                                .padding(.top, 102)
                        }
                    }
                    .overlay(alignment: .bottom) {
                        if isWorkoutActive {
                            activeFeedbackBar
                                .padding(.horizontal, 16)
                                .padding(.bottom, 18)
                        }
                    }

                if !isWorkoutActive {
                    bottomPanel
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .padding(.bottom, 18)
                }
            }
        }
        .animation(.spring(response: 0.34, dampingFraction: 0.86), value: isWorkoutActive)
        .onAppear {
            camera.start()
        }
        .onDisappear {
            camera.stop()
        }
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 9) {
                Circle()
                    .fill(Color.red)
                    .frame(width: 9, height: 9)

                Text(camera.selectedMove.liveTitle)
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundColor(.white)
                    .lineLimit(1)
            }
            .padding(.horizontal, 14)
            .frame(height: 38)
            .background(Color.black.opacity(0.42))
            .clipShape(Capsule())

            Spacer()

            Button(action: camera.resetCounter) {
                Label("Reset", systemImage: "arrow.counterclockwise")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundColor(.red)
                    .padding(.horizontal, 14)
                    .frame(height: 38)
                    .background(Color.white)
                    .clipShape(Capsule())
            }

            if isWorkoutActive {
                Button(action: {
                    isWorkoutActive = false
                }) {
                    Label("Controls", systemImage: "slider.horizontal.3")
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundColor(CameraFeedbackStyle.ink)
                        .padding(.horizontal, 14)
                        .frame(height: 38)
                        .background(Color.white)
                        .clipShape(Capsule())
                }
            }
        }
    }

    private var cameraStage: some View {
        ZStack {
            #if targetEnvironment(simulator)
            CameraUnavailableView(message: "Camera preview is unavailable in Simulator")
            #else
            switch camera.authorizationStatus {
            case .authorized:
                CameraPreview(session: camera.session, joints: camera.joints)
                    .edgesIgnoringSafeArea(.all)
            case .denied, .restricted:
                CameraUnavailableView(message: "Camera not available")
            case .notDetermined:
                CameraUnavailableView(message: "Requesting camera access...")
            @unknown default:
                CameraUnavailableView(message: "Camera not available")
            }
            #endif
        }
    }

    private var bottomPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Workout", selection: $camera.selectedMove) {
                ForEach(WorkoutMove.allCases) { move in
                    Text(move.shortTitle).tag(move)
                }
            }
            .pickerStyle(.segmented)

            HStack(alignment: .center, spacing: 14) {
                VStack(alignment: .leading, spacing: 7) {
                    Text("REPS")
                        .font(.system(size: 12, weight: .heavy))
                        .foregroundColor(CameraFeedbackStyle.muted)

                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text("\(camera.repCount)")
                            .font(.system(size: 40, weight: .heavy))
                            .foregroundColor(CameraFeedbackStyle.ink)
                        Text("/\(camera.selectedMove.targetReps)")
                            .font(.system(size: 18, weight: .heavy))
                            .foregroundColor(CameraFeedbackStyle.muted)
                    }
                }

                Label(camera.feedbackMessage,
                      systemImage: camera.hasGoodForm ? "checkmark.circle" : "exclamationmark.circle")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(camera.hasGoodForm ? Color.green : Color.orange)
                    .lineLimit(2)
                    .minimumScaleFactor(0.78)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background((camera.hasGoodForm ? Color.green : Color.orange).opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

            ProgressBar(value: camera.progress, height: 6)

            HStack(spacing: 10) {
                DebugPill(title: "FPS", value: String(format: "%.0f", camera.fps))
                DebugPill(title: "Pose", value: String(format: "%.0f%%", camera.poseQuality * 100))
                DebugPill(title: "ms", value: String(format: "%.1f", camera.processingMs))
            }

            Button(action: {
                isWorkoutActive = true
            }) {
                Label("Start Workout", systemImage: "play.fill")
                    .font(.system(size: 16, weight: .heavy))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(CameraFeedbackStyle.ink)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .padding(14)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .padding(.horizontal, 12)
    }

    private var compactRepsHUD: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(camera.selectedMove.shortTitle.uppercased())
                .font(.system(size: 11, weight: .heavy))
                .foregroundColor(.white.opacity(0.75))

            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text("\(camera.repCount)")
                    .font(.system(size: 46, weight: .heavy))
                    .foregroundColor(.white)

                Text("/\(camera.selectedMove.targetReps)")
                    .font(.system(size: 18, weight: .heavy))
                    .foregroundColor(.white.opacity(0.72))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.black.opacity(0.42))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var activeFeedbackBar: some View {
        Label(camera.feedbackMessage,
              systemImage: camera.hasGoodForm ? "checkmark.circle" : "exclamationmark.circle")
            .font(.system(size: 13, weight: .heavy))
            .foregroundColor(camera.hasGoodForm ? .green : .orange)
            .lineLimit(2)
            .minimumScaleFactor(0.8)
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .frame(maxWidth: .infinity)
            .background(Color.black.opacity(0.48))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    let joints: [PoseJoint: CGPoint]

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        view.previewLayer.connection?.videoOrientation = .portrait
        view.previewLayer.connection?.isVideoMirrored = true
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        uiView.previewLayer.session = session
        uiView.previewLayer.connection?.videoOrientation = .portrait
        uiView.previewLayer.connection?.isVideoMirrored = true
        uiView.updateSkeleton(joints: joints)
    }
}

private final class PreviewView: UIView {
    private let skeletonView = SkeletonOverlayUIView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    var previewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        skeletonView.frame = bounds
        skeletonView.previewLayer = previewLayer
    }

    func updateSkeleton(joints: [PoseJoint: CGPoint]) {
        skeletonView.previewLayer = previewLayer
        skeletonView.joints = joints
    }

    private func commonInit() {
        skeletonView.backgroundColor = .clear
        skeletonView.isUserInteractionEnabled = false
        addSubview(skeletonView)
    }
}

private final class SkeletonOverlayUIView: UIView {
    weak var previewLayer: AVCaptureVideoPreviewLayer?
    var joints: [PoseJoint: CGPoint] = [:] {
        didSet {
            setNeedsDisplay()
        }
    }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext(), let previewLayer = previewLayer else {
            return
        }

        context.setLineCap(.round)
        context.setLineJoin(.round)
        context.setLineWidth(4)
        context.setStrokeColor(UIColor(red: 0.52, green: 1.0, blue: 0.26, alpha: 0.95).cgColor)
        context.setFillColor(UIColor(red: 0.52, green: 1.0, blue: 0.26, alpha: 0.95).cgColor)

        for connection in PoseJoint.connections {
            guard let start = joints[connection.0], let end = joints[connection.1] else {
                continue
            }

            context.move(to: layerPoint(for: start, in: previewLayer))
            context.addLine(to: layerPoint(for: end, in: previewLayer))
            context.strokePath()
        }

        for (joint, point) in joints {
            let center = layerPoint(for: point, in: previewLayer)
            let radius: CGFloat = joint.isCoreJoint ? 5 : 4
            context.fillEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
            drawLabel(joint.shortLabel, at: CGPoint(x: center.x + 6, y: center.y - 10))
        }
    }

    private func layerPoint(for visionPoint: CGPoint, in previewLayer: AVCaptureVideoPreviewLayer) -> CGPoint {
        let capturePoint = CGPoint(x: visionPoint.x, y: 1 - visionPoint.y)
        return previewLayer.layerPointConverted(fromCaptureDevicePoint: capturePoint)
    }

    private func drawLabel(_ text: String, at point: CGPoint) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.monospacedSystemFont(ofSize: 9, weight: .bold),
            .foregroundColor: UIColor.white,
            .backgroundColor: UIColor.black.withAlphaComponent(0.45)
        ]
        text.draw(at: point, withAttributes: attributes)
    }
}

private struct CameraUnavailableView: View {
    let message: String

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "camera.fill")
                .font(.system(size: 70, weight: .regular))
                .foregroundColor(.white.opacity(0.86))

            Text(message)
                .font(.system(size: 17, weight: .heavy))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 32)
    }
}

private struct ProgressBar: View {
    let value: CGFloat
    let height: CGFloat

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(CameraFeedbackStyle.line)

                Capsule()
                    .fill(CameraFeedbackStyle.ink)
                    .frame(width: max(0, min(value, 1)) * geometry.size.width)
            }
        }
        .frame(height: height)
    }
}

private struct DebugPill: View {
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 4) {
            Text(title)
                .foregroundColor(CameraFeedbackStyle.muted)
            Text(value)
                .foregroundColor(CameraFeedbackStyle.ink)
        }
        .font(.system(size: 12, weight: .heavy))
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(CameraFeedbackStyle.line.opacity(0.70))
        .clipShape(Capsule())
    }
}

private enum CameraFeedbackStyle {
    static let ink = Color(red: 0.055, green: 0.055, blue: 0.055)
    static let muted = Color(red: 0.43, green: 0.43, blue: 0.43)
    static let line = Color(red: 0.88, green: 0.88, blue: 0.88)
}

enum WorkoutMove: String, CaseIterable, Identifiable {
    case squat
    case sitUp
    case pushUp
    case jumpingJack

    var id: String { rawValue }

    var shortTitle: String {
        switch self {
        case .squat:
            return "Squat"
        case .sitUp:
            return "Sit Up"
        case .pushUp:
            return "Push Up"
        case .jumpingJack:
            return "Jump"
        }
    }

    var liveTitle: String {
        switch self {
        case .squat:
            return "Squat Detection"
        case .sitUp:
            return "Sit Up Detection"
        case .pushUp:
            return "Push Up Detection"
        case .jumpingJack:
            return "Jumping Jack Detection"
        }
    }

    var targetReps: Int {
        switch self {
        case .squat, .sitUp, .pushUp:
            return 15
        case .jumpingJack:
            return 30
        }
    }
}

private struct PoseSkeletonOverlay: View {
    let joints: [PoseJoint: CGPoint]

    var body: some View {
        GeometryReader { proxy in
            Canvas { context, size in
                var path = Path()

                for connection in PoseJoint.connections {
                    guard let start = joints[connection.0], let end = joints[connection.1] else {
                        continue
                    }

                    path.move(to: point(start, in: size))
                    path.addLine(to: point(end, in: size))
                }

                context.stroke(
                    path,
                    with: .color(Color(red: 0.52, green: 1.0, blue: 0.26)),
                    style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round)
                )

                for joint in joints.values {
                    let center = point(joint, in: size)
                    let rect = CGRect(x: center.x - 4, y: center.y - 4, width: 8, height: 8)
                    context.fill(Path(ellipseIn: rect), with: .color(Color(red: 0.52, green: 1.0, blue: 0.26)))
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .allowsHitTesting(false)
    }

    private func point(_ normalizedPoint: CGPoint, in size: CGSize) -> CGPoint {
        CGPoint(
            x: normalizedPoint.x * size.width,
            y: (1.0 - normalizedPoint.y) * size.height
        )
    }
}

private enum PoseJoint: Hashable {
    case leftShoulder
    case rightShoulder
    case leftElbow
    case rightElbow
    case leftWrist
    case rightWrist
    case leftHip
    case rightHip
    case leftKnee
    case rightKnee
    case leftAnkle
    case rightAnkle

    static let connections: [(PoseJoint, PoseJoint)] = [
        (.leftShoulder, .rightShoulder),
        (.leftShoulder, .leftElbow),
        (.leftElbow, .leftWrist),
        (.rightShoulder, .rightElbow),
        (.rightElbow, .rightWrist),
        (.leftShoulder, .leftHip),
        (.rightShoulder, .rightHip),
        (.leftHip, .rightHip),
        (.leftHip, .leftKnee),
        (.leftKnee, .leftAnkle),
        (.rightHip, .rightKnee),
        (.rightKnee, .rightAnkle)
    ]

    var visionName: VNHumanBodyPoseObservation.JointName {
        switch self {
        case .leftShoulder:
            return .leftShoulder
        case .rightShoulder:
            return .rightShoulder
        case .leftElbow:
            return .leftElbow
        case .rightElbow:
            return .rightElbow
        case .leftWrist:
            return .leftWrist
        case .rightWrist:
            return .rightWrist
        case .leftHip:
            return .leftHip
        case .rightHip:
            return .rightHip
        case .leftKnee:
            return .leftKnee
        case .rightKnee:
            return .rightKnee
        case .leftAnkle:
            return .leftAnkle
        case .rightAnkle:
            return .rightAnkle
        }
    }

    var isCoreJoint: Bool {
        switch self {
        case .leftShoulder, .rightShoulder, .leftHip, .rightHip:
            return true
        default:
            return false
        }
    }

    var shortLabel: String {
        switch self {
        case .leftShoulder:
            return "LS"
        case .rightShoulder:
            return "RS"
        case .leftElbow:
            return "LE"
        case .rightElbow:
            return "RE"
        case .leftWrist:
            return "LW"
        case .rightWrist:
            return "RW"
        case .leftHip:
            return "LH"
        case .rightHip:
            return "RH"
        case .leftKnee:
            return "LK"
        case .rightKnee:
            return "RK"
        case .leftAnkle:
            return "LA"
        case .rightAnkle:
            return "RA"
        }
    }
}

private enum PoseNetKeypoint: Int {
    case leftShoulder = 5
    case rightShoulder = 6
    case leftElbow = 7
    case rightElbow = 8
    case leftWrist = 9
    case rightWrist = 10
    case leftHip = 11
    case rightHip = 12
    case leftKnee = 13
    case rightKnee = 14
    case leftAnkle = 15
    case rightAnkle = 16

    var poseJoint: PoseJoint {
        switch self {
        case .leftShoulder:
            return .leftShoulder
        case .rightShoulder:
            return .rightShoulder
        case .leftElbow:
            return .leftElbow
        case .rightElbow:
            return .rightElbow
        case .leftWrist:
            return .leftWrist
        case .rightWrist:
            return .rightWrist
        case .leftHip:
            return .leftHip
        case .rightHip:
            return .rightHip
        case .leftKnee:
            return .leftKnee
        case .rightKnee:
            return .rightKnee
        case .leftAnkle:
            return .leftAnkle
        case .rightAnkle:
            return .rightAnkle
        }
    }
}

private enum RepPhase {
    case ready
    case loaded
}

private final class PoseCameraController: NSObject, ObservableObject {
    @Published var authorizationStatus: AVAuthorizationStatus
    @Published var joints: [PoseJoint: CGPoint] = [:]
    @Published var hasGoodForm = false
    @Published var repCount = 0
    @Published var fps: Double = 0
    @Published var processingMs: Double = 0
    @Published var poseQuality: Double = 0
    @Published var selectedMove: WorkoutMove = .squat {
        didSet {
            resetCounter()
        }
    }
    @Published var feedbackMessage = "Adjust your position"

    let session = AVCaptureSession()
    var progress: CGFloat {
        guard selectedMove.targetReps > 0 else {
            return 0
        }

        return CGFloat(repCount) / CGFloat(selectedMove.targetReps)
    }

    private let sessionQueue = DispatchQueue(label: "com.fitnesscoach.camera.session")
    private let videoQueue = DispatchQueue(label: "com.fitnesscoach.camera.video")
    private let sequenceHandler = VNSequenceRequestHandler()
    private let poseNetModel: VNCoreMLModel?
    private var isConfigured = false
    private var phase: RepPhase = .ready
    private var smoothedJoints: [PoseJoint: CGPoint] = [:]
    private var lastFrameTimestamp: CFAbsoluteTime?

    init(selectedMove: WorkoutMove = .squat) {
        self.selectedMove = selectedMove
        self.poseNetModel = Self.makePoseNetModel()
        authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
        super.init()
    }

    func resetCounter() {
        repCount = 0
        phase = .ready
        smoothedJoints = [:]
        feedbackMessage = "Adjust your position"
    }

    func start() {
        #if targetEnvironment(simulator)
        return
        #else
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            authorizationStatus = .authorized
            configureAndStartSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                Task { @MainActor in
                    self?.authorizationStatus = granted ? .authorized : .denied
                }

                if granted {
                    self?.configureAndStartSession()
                }
            }
        case .denied, .restricted:
            authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
        @unknown default:
            authorizationStatus = .denied
        }
        #endif
    }

    func stop() {
        sessionQueue.async { [weak self] in
            guard let self = self, self.session.isRunning else {
                return
            }

            self.session.stopRunning()
        }
    }

    private func configureAndStartSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else {
                return
            }

            if !self.isConfigured {
                self.configureSession()
            }

            if !self.session.isRunning {
                self.session.startRunning()
            }
        }
    }

    private func configureSession() {
        session.beginConfiguration()
        session.sessionPreset = .high

        defer {
            session.commitConfiguration()
        }

        guard let camera = Self.preferredCamera(),
              let input = try? AVCaptureDeviceInput(device: camera),
              session.canAddInput(input) else {
            Task { @MainActor in
                self.authorizationStatus = .denied
            }
            return
        }

        session.addInput(input)

        let output = AVCaptureVideoDataOutput()
        output.alwaysDiscardsLateVideoFrames = true
        output.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        output.setSampleBufferDelegate(self, queue: videoQueue)

        guard session.canAddOutput(output) else {
            return
        }

        session.addOutput(output)

        if let connection = output.connection(with: .video) {
            connection.videoOrientation = .portrait
            connection.isVideoMirrored = camera.position == .front && connection.isVideoMirroringSupported
        }

        isConfigured = true
    }

    private static func preferredCamera() -> AVCaptureDevice? {
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera],
            mediaType: .video,
            position: .unspecified
        )

        if let frontCamera = discoverySession.devices.first(where: { $0.position == .front }) {
            return frontCamera
        }

        return discoverySession.devices.first(where: { $0.position == .back })
    }

    private static func makePoseNetModel() -> VNCoreMLModel? {
        do {
            let configuration = MLModelConfiguration()
            configuration.computeUnits = .all
            let coreMLModel = try PoseNetMobileNet075S16FP16(configuration: configuration).model
            return try VNCoreMLModel(for: coreMLModel)
        } catch {
            print("PoseNet model failed to load: \(error.localizedDescription)")
            return nil
        }
    }

    @MainActor
    private func publish(joints: [PoseJoint: CGPoint],
                         hasGoodForm: Bool,
                         didCountRep: Bool,
                         message: String,
                         fps: Double,
                         processingMs: Double,
                         poseQuality: Double) {
        self.joints = joints
        self.hasGoodForm = hasGoodForm
        self.feedbackMessage = message
        self.fps = fps
        self.processingMs = processingMs
        self.poseQuality = poseQuality

        if didCountRep {
            repCount += 1
        }
    }

    private func analyzeMovement(joints: [PoseJoint: CGPoint]) -> (didCountRep: Bool, message: String) {
        switch selectedMove {
        case .squat:
            return analyzeSquat(joints: joints)
        case .sitUp:
            return analyzeSitUp(joints: joints)
        case .pushUp:
            return analyzePushUp(joints: joints)
        case .jumpingJack:
            return analyzeJumpingJack(joints: joints)
        }
    }

    private func analyzeSquat(joints: [PoseJoint: CGPoint]) -> (Bool, String) {
        guard let kneeAngle = averageAngle(
            joints: joints,
            left: (.leftHip, .leftKnee, .leftAnkle),
            right: (.rightHip, .rightKnee, .rightAnkle)
        ) else {
            return (false, "Show hips, knees, ankles")
        }

        if kneeAngle < 105 {
            phase = .loaded
            return (false, "Depth good - stand tall")
        }

        if kneeAngle > 155, phase == .loaded {
            phase = .ready
            return (true, "Good rep!")
        }

        if phase == .loaded {
            return (false, "Keep standing tall")
        }

        if kneeAngle < 135 {
            return (false, "Go a little lower")
        }

        return (false, "Start squat - hips back")
    }

    private func analyzeSitUp(joints: [PoseJoint: CGPoint]) -> (Bool, String) {
        guard let shoulders = midpoint(joints[.leftShoulder], joints[.rightShoulder]),
              let hips = midpoint(joints[.leftHip], joints[.rightHip]) else {
            return (false, "Show shoulders and hips")
        }

        let torsoRise = shoulders.y - hips.y

        if torsoRise < 0.16 {
            phase = .loaded
            return (false, "Down position - curl up")
        }

        if torsoRise > 0.34, phase == .loaded {
            phase = .ready
            return (true, "Good rep!")
        }

        if phase == .loaded {
            return (false, "Curl higher")
        }

        if torsoRise > 0.26 {
            return (false, "Control back down")
        }

        return (false, "Lie back before next rep")
    }

    private func analyzePushUp(joints: [PoseJoint: CGPoint]) -> (Bool, String) {
        guard let elbowAngle = averageAngle(
            joints: joints,
            left: (.leftShoulder, .leftElbow, .leftWrist),
            right: (.rightShoulder, .rightElbow, .rightWrist)
        ) else {
            return (false, "Show shoulders, elbows, wrists")
        }

        if elbowAngle < 95 {
            phase = .loaded
            return (false, "Depth good - press up")
        }

        if elbowAngle > 155, phase == .loaded {
            phase = .ready
            return (true, "Good rep!")
        }

        if phase == .loaded {
            return (false, "Press until arms extend")
        }

        if elbowAngle < 130 {
            return (false, "Lower a little more")
        }

        return (false, "Start push up")
    }

    private func analyzeJumpingJack(joints: [PoseJoint: CGPoint]) -> (Bool, String) {
        guard let leftWrist = joints[.leftWrist],
              let rightWrist = joints[.rightWrist],
              let leftShoulder = joints[.leftShoulder],
              let rightShoulder = joints[.rightShoulder],
              let leftAnkle = joints[.leftAnkle],
              let rightAnkle = joints[.rightAnkle],
              let leftHip = joints[.leftHip],
              let rightHip = joints[.rightHip] else {
            return (false, "Show full body")
        }

        let shoulderWidth = abs(leftShoulder.x - rightShoulder.x)
        let hipWidth = abs(leftHip.x - rightHip.x)
        let wristWidth = abs(leftWrist.x - rightWrist.x)
        let ankleWidth = abs(leftAnkle.x - rightAnkle.x)
        let armsUp = leftWrist.y > leftShoulder.y && rightWrist.y > rightShoulder.y
        let legsOpen = ankleWidth > max(hipWidth * 1.45, 0.16)
        let openPosition = armsUp && wristWidth > shoulderWidth * 1.35 && legsOpen
        let closedPosition = leftWrist.y < leftShoulder.y && rightWrist.y < rightShoulder.y && ankleWidth < max(hipWidth * 1.25, 0.22)

        if openPosition {
            phase = .loaded
            return (false, "Open good - close stance")
        }

        if closedPosition, phase == .loaded {
            phase = .ready
            return (true, "Good rep!")
        }

        if phase == .loaded {
            return (false, "Bring hands and feet in")
        }

        if !armsUp && !legsOpen {
            return (false, "Open arms and feet")
        }

        if !armsUp {
            return (false, "Raise both hands higher")
        }

        if !legsOpen {
            return (false, "Step feet wider")
        }

        return (false, "Keep full body visible")
    }

    private func isPositiveFeedback(_ message: String) -> Bool {
        message == "Good rep!"
            || message.hasPrefix("Depth good")
            || message.hasPrefix("Open good")
    }

    private func smooth(joints: [PoseJoint: CGPoint]) -> [PoseJoint: CGPoint] {
        let alpha: CGFloat = 0.36
        var result: [PoseJoint: CGPoint] = [:]

        for (joint, point) in joints {
            if let previous = smoothedJoints[joint] {
                result[joint] = CGPoint(
                    x: previous.x + (point.x - previous.x) * alpha,
                    y: previous.y + (point.y - previous.y) * alpha
                )
            } else {
                result[joint] = point
            }
        }

        smoothedJoints = result
        return result
    }

    private func averageAngle(
        joints: [PoseJoint: CGPoint],
        left: (PoseJoint, PoseJoint, PoseJoint),
        right: (PoseJoint, PoseJoint, PoseJoint)
    ) -> CGFloat? {
        let angles = [
            angle(joints[left.0], joints[left.1], joints[left.2]),
            angle(joints[right.0], joints[right.1], joints[right.2])
        ].compactMap { $0 }

        guard !angles.isEmpty else {
            return nil
        }

        return angles.reduce(0, +) / CGFloat(angles.count)
    }

    private func angle(_ first: CGPoint?, _ center: CGPoint?, _ third: CGPoint?) -> CGFloat? {
        guard let first = first, let center = center, let third = third else {
            return nil
        }

        let vectorA = CGVector(dx: first.x - center.x, dy: first.y - center.y)
        let vectorB = CGVector(dx: third.x - center.x, dy: third.y - center.y)
        let dotProduct = vectorA.dx * vectorB.dx + vectorA.dy * vectorB.dy
        let magnitudeA = sqrt(vectorA.dx * vectorA.dx + vectorA.dy * vectorA.dy)
        let magnitudeB = sqrt(vectorB.dx * vectorB.dx + vectorB.dy * vectorB.dy)

        guard magnitudeA > 0, magnitudeB > 0 else {
            return nil
        }

        let cosine = max(CGFloat(-1), min(CGFloat(1), dotProduct / (magnitudeA * magnitudeB)))
        return CGFloat(acos(Double(cosine)) * 180 / Double.pi)
    }

    private func midpoint(_ first: CGPoint?, _ second: CGPoint?) -> CGPoint? {
        guard let first = first, let second = second else {
            return nil
        }

        return CGPoint(x: (first.x + second.x) / 2, y: (first.y + second.y) / 2)
    }
}

extension PoseCameraController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }

        let startTime = CFAbsoluteTimeGetCurrent()
        let fps = currentFPS(at: startTime)

        do {
            let detectedJoints = try detectJoints(in: pixelBuffer)
            let processingMs = (CFAbsoluteTimeGetCurrent() - startTime) * 1000

            guard !detectedJoints.isEmpty else {
                Task { @MainActor in
                    self.publish(
                        joints: [:],
                        hasGoodForm: false,
                        didCountRep: false,
                        message: "Adjust your position",
                        fps: fps,
                        processingMs: processingMs,
                        poseQuality: 0
                    )
                }
                return
            }

            let publishedJoints = self.smooth(joints: detectedJoints)
            let movement = self.analyzeMovement(joints: publishedJoints)
            let hasGoodForm = self.isPositiveFeedback(movement.message)
            let poseQuality = min(Double(publishedJoints.count) / 12.0, 1)

            Task { @MainActor in
                self.publish(
                    joints: publishedJoints,
                    hasGoodForm: hasGoodForm,
                    didCountRep: movement.didCountRep,
                    message: movement.message,
                    fps: fps,
                    processingMs: processingMs,
                    poseQuality: poseQuality
                )
            }
        } catch {
            let processingMs = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
            Task { @MainActor in
                self.publish(
                    joints: [:],
                    hasGoodForm: false,
                    didCountRep: false,
                    message: "Adjust your position",
                    fps: fps,
                    processingMs: processingMs,
                    poseQuality: 0
                )
            }
        }
    }

    private func currentFPS(at timestamp: CFAbsoluteTime) -> Double {
        defer {
            lastFrameTimestamp = timestamp
        }

        guard let lastFrameTimestamp = lastFrameTimestamp else {
            return fps
        }

        let delta = timestamp - lastFrameTimestamp
        guard delta > 0 else {
            return fps
        }

        return 1 / delta
    }

    private func detectJoints(in pixelBuffer: CVPixelBuffer) throws -> [PoseJoint: CGPoint] {
        if let poseNetModel = poseNetModel,
           let joints = try detectJointsWithPoseNet(pixelBuffer: pixelBuffer),
           !joints.isEmpty {
            return joints
        }

        return try detectJointsWithVisionBodyPose(pixelBuffer: pixelBuffer)
    }

    private func detectJointsWithPoseNet(pixelBuffer: CVPixelBuffer) throws -> [PoseJoint: CGPoint]? {
        guard let poseNetModel = poseNetModel else {
            return nil
        }

        let request = VNCoreMLRequest(model: poseNetModel)
        request.imageCropAndScaleOption = .scaleFill

        try sequenceHandler.perform([request], on: pixelBuffer, orientation: .leftMirrored)

        guard let observations = request.results as? [VNCoreMLFeatureValueObservation],
              let heatmap = observations.first(where: { $0.featureName == "heatmap" })?.featureValue.multiArrayValue,
              let offsets = observations.first(where: { $0.featureName == "offsets" })?.featureValue.multiArrayValue else {
            return nil
        }

        return decodePoseNetJoints(heatmap: heatmap, offsets: offsets)
    }

    private func detectJointsWithVisionBodyPose(pixelBuffer: CVPixelBuffer) throws -> [PoseJoint: CGPoint] {
        let request = VNDetectHumanBodyPoseRequest()
        try sequenceHandler.perform([request], on: pixelBuffer, orientation: .leftMirrored)

        guard let observation = request.results?.first else {
            return [:]
        }

        let recognizedPoints = try observation.recognizedPoints(.all)
        var detectedJoints: [PoseJoint: CGPoint] = [:]

        for joint in PoseJoint.connections.flatMap({ [$0.0, $0.1] }) {
            guard let point = recognizedPoints[joint.visionName], point.confidence > 0.25 else {
                continue
            }

            detectedJoints[joint] = CGPoint(x: point.location.x, y: point.location.y)
        }

        return detectedJoints
    }

    private func decodePoseNetJoints(heatmap: MLMultiArray, offsets: MLMultiArray) -> [PoseJoint: CGPoint] {
        let keypoints: [PoseNetKeypoint] = [
            .leftShoulder, .rightShoulder,
            .leftElbow, .rightElbow,
            .leftWrist, .rightWrist,
            .leftHip, .rightHip,
            .leftKnee, .rightKnee,
            .leftAnkle, .rightAnkle
        ]

        var detectedJoints: [PoseJoint: CGPoint] = [:]
        let heatmapHeight = heatmap.shape[1].intValue
        let heatmapWidth = heatmap.shape[2].intValue
        let outputStride: CGFloat = 16
        let inputSize: CGFloat = 513

        for keypoint in keypoints {
            let keypointIndex = keypoint.rawValue
            var bestScore = -Double.greatestFiniteMagnitude
            var bestY = 0
            var bestX = 0

            for y in 0..<heatmapHeight {
                for x in 0..<heatmapWidth {
                    let score = heatmapValue(heatmap, keypoint: keypointIndex, y: y, x: x)
                    if score > bestScore {
                        bestScore = score
                        bestY = y
                        bestX = x
                    }
                }
            }

            let confidence = sigmoid(bestScore)
            guard confidence > 0.25 else {
                continue
            }

            let offsetY = multiArrayValue(offsets, channel: keypointIndex, y: bestY, x: bestX)
            let offsetX = multiArrayValue(offsets, channel: keypointIndex + 17, y: bestY, x: bestX)
            let imageX = (CGFloat(bestX) * outputStride + CGFloat(offsetX)) / inputSize
            let imageY = (CGFloat(bestY) * outputStride + CGFloat(offsetY)) / inputSize

            detectedJoints[keypoint.poseJoint] = CGPoint(
                x: max(0, min(1, imageX)),
                y: max(0, min(1, 1 - imageY))
            )
        }

        return detectedJoints
    }

    private func heatmapValue(_ heatmap: MLMultiArray, keypoint: Int, y: Int, x: Int) -> Double {
        multiArrayValue(heatmap, channel: keypoint, y: y, x: x)
    }

    private func multiArrayValue(_ array: MLMultiArray, channel: Int, y: Int, x: Int) -> Double {
        let offset = channel * array.strides[0].intValue
            + y * array.strides[1].intValue
            + x * array.strides[2].intValue
        return array.dataPointer
            .advanced(by: offset * MemoryLayout<Double>.stride)
            .assumingMemoryBound(to: Double.self)
            .pointee
    }

    private func sigmoid(_ value: Double) -> Double {
        1 / (1 + exp(-value))
    }
}
