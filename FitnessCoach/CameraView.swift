import SwiftUI
import AVFoundation
import CoreML
import UIKit
import Vision

enum WorkoutState {
    case setup
    case calibrating
    case active
}

struct CameraFeedbackView: View {
    @StateObject private var camera: PoseCameraController
    @StateObject private var historyStore = WorkoutHistoryStore()
    @State private var workoutState: WorkoutState = .setup
    @State private var didSaveCurrentSession = false

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

            cameraStage
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay(alignment: .top) {
                    topBar
                        .padding(.horizontal, 16)
                        .padding(.top, 50)
                }
                .overlay(alignment: .topLeading) {
                    if workoutState == .active {
                        compactRepsHUD
                            .padding(.leading, 16)
                            .padding(.top, 102)
                    }
                }
                .overlay(alignment: .topTrailing) {
                    if workoutState == .active {
                        liveMetricPanel
                            .padding(.trailing, 16)
                            .padding(.top, 102)
                    }
                }
                .overlay(alignment: .center) {
                    if workoutState == .calibrating {
                        VStack(spacing: 18) {
                            Text("Calibration")
                                .font(.system(size: 20, weight: .heavy))
                                .foregroundColor(.white)
                            
                            Text("Stand in frame so all required\njoints are visible.")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                                .multilineTextAlignment(.center)
                            
                            ProgressBar(value: camera.calibrationProgress, height: 8)
                                .frame(width: 180)
                            
                            if camera.calibrationProgress >= 1.0 {
                                Text("Ready!")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.green)
                            }
                        }
                        .padding(24)
                        .background(Color.black.opacity(0.7))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                }
                .overlay(alignment: .bottom) {
                    VStack(spacing: 0) {
                        if workoutState == .active {
                            activeFeedbackBar
                                .padding(.horizontal, 16)
                                .padding(.bottom, 18)
                        } else if workoutState == .setup {
                            bottomPanel
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                                .padding(.bottom, 18)
                        }
                    }
                }
        }
        .animation(.spring(response: 0.34, dampingFraction: 0.86), value: workoutState)
        .onAppear {
            camera.start()
        }
        .onDisappear {
            camera.stop()
        }
        .onChange(of: camera.calibrationProgress) { progress in
            if workoutState == .calibrating && progress >= 1.0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    if workoutState == .calibrating {
                        camera.beginWorkout()
                        didSaveCurrentSession = false
                        withAnimation { workoutState = .active }
                    }
                }
            }
        }
        .onChange(of: camera.repCount) { reps in
            if workoutState == .active && reps >= camera.selectedMove.targetReps {
                finishAndSaveWorkout()
            }
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

            if workoutState != .setup {
                Button(action: {
                    finishAndSaveWorkout()
                }) {
                    Label("Stop", systemImage: "xmark")
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
                CameraPreview(session: camera.session, joints: camera.joints, hasGoodForm: camera.hasGoodForm)
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
            .colorMultiply(.fcAccent)

            HStack(alignment: .center, spacing: 14) {
                VStack(alignment: .leading, spacing: 7) {
                    Text("REPS")
                        .font(.system(size: 12, weight: .heavy))
                        .foregroundColor(.white.opacity(0.7))

                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text("\(camera.repCount)")
                            .font(.system(size: 44, weight: .heavy, design: .rounded))
                            .foregroundColor(.white)
                        Text("/\(camera.selectedMove.targetReps)")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }

                Spacer()

                Label(camera.feedbackMessage,
                      systemImage: camera.hasGoodForm ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(camera.hasGoodForm ? Color.green : Color.orange)
                    .lineLimit(2)
                    .minimumScaleFactor(0.78)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background((camera.hasGoodForm ? Color.green : Color.orange).opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }

            ProgressBar(value: camera.progress, height: 8)

            Button(action: {
                camera.resetCounter()
                didSaveCurrentSession = false
                workoutState = .calibrating
            }) {
                Label("Start Workout", systemImage: "play.fill")
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(LinearGradient(colors: [CameraFeedbackStyle.accent, CameraFeedbackStyle.ink], startPoint: .leading, endPoint: .trailing))
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .shadow(color: CameraFeedbackStyle.accent.opacity(0.4), radius: 14, x: 0, y: 6)
            }
        }
        .padding(20)
        .background(.ultraThinMaterial)
        .environment(\.colorScheme, .dark)
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .shadow(color: .black.opacity(0.25), radius: 24, x: 0, y: 12)
        .padding(.horizontal, 12)
    }

    private var compactRepsHUD: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 5) {
                Text(camera.selectedMove.shortTitle.uppercased())
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundColor(.white.opacity(0.75))

                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text("\(camera.repCount)")
                        .font(.system(size: 46, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)

                    Text("/\(camera.selectedMove.targetReps)")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.72))
                }
            }

            VStack(spacing: 8) {
                Button(action: camera.increaseRepCount) {
                    Image(systemName: "plus")
                        .font(.system(size: 15, weight: .heavy))
                        .foregroundColor(.white)
                        .frame(width: 34, height: 34)
                        .background(Color.white.opacity(0.18))
                        .clipShape(Circle())
                }

                Button(action: camera.decreaseRepCount) {
                    Image(systemName: "minus")
                        .font(.system(size: 15, weight: .heavy))
                        .foregroundColor(.white)
                        .frame(width: 34, height: 34)
                        .background(Color.white.opacity(0.18))
                        .clipShape(Circle())
                }
            }
            
            Divider()
                .background(Color.white.opacity(0.3))
                .frame(height: 40)
            
            VStack(alignment: .leading, spacing: 5) {
                Text("SCORE")
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundColor(.white.opacity(0.75))
                
                Text("\(camera.averageScore)")
                    .font(.system(size: 36, weight: .heavy, design: .rounded))
                    .foregroundColor(scoreColor(camera.averageScore))
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .environment(\.colorScheme, .dark)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.2), radius: 16, x: 0, y: 8)
    }

    private var liveMetricPanel: some View {
        VStack(alignment: .trailing, spacing: 9) {
            DebugPill(title: camera.metricTitle, value: camera.metricValueText)
            DebugPill(title: "Form", value: camera.correctionTip)
        }
        .frame(maxWidth: 178, alignment: .trailing)
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

    private func scoreColor(_ score: Int) -> Color {
        if score >= 90 { return .green }
        if score >= 70 { return .yellow }
        if score > 0 { return .orange }
        return .white
    }

    private func finishAndSaveWorkout() {
        guard !didSaveCurrentSession else {
            workoutState = .setup
            camera.resetCounter()
            return
        }

        if let record = camera.finishWorkout() {
            historyStore.add(record)
        }

        didSaveCurrentSession = true
        workoutState = .setup
        camera.resetCounter()
    }
}

private struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    let joints: [PoseJoint: CGPoint]
    let hasGoodForm: Bool

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
        uiView.updateSkeleton(joints: joints, hasGoodForm: hasGoodForm)
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

    func updateSkeleton(joints: [PoseJoint: CGPoint], hasGoodForm: Bool) {
        skeletonView.previewLayer = previewLayer
        skeletonView.joints = joints
        skeletonView.hasGoodForm = hasGoodForm
    }

    private func commonInit() {
        skeletonView.backgroundColor = .clear
        skeletonView.isUserInteractionEnabled = false
        addSubview(skeletonView)
    }
}

private final class SkeletonOverlayUIView: UIView {
    weak var previewLayer: AVCaptureVideoPreviewLayer?
    var hasGoodForm: Bool = true {
        didSet { setNeedsDisplay() }
    }
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

        let goodColor = UIColor(red: 0.52, green: 1.0, blue: 0.26, alpha: 0.95).cgColor
        let badColor = UIColor(red: 1.0, green: 0.3, blue: 0.26, alpha: 0.95).cgColor
        let color = hasGoodForm ? goodColor : badColor
        context.setStrokeColor(color)
        context.setFillColor(color)

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
                    .fill(LinearGradient(colors: [CameraFeedbackStyle.accent, CameraFeedbackStyle.ink], startPoint: .leading, endPoint: .trailing))
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
    static let ink = Color(red: 0.08, green: 0.15, blue: 0.28)
    static let accent = Color(red: 0.15, green: 0.45, blue: 1.0)
    static let muted = Color(red: 0.45, green: 0.50, blue: 0.58)
    static let line = Color(red: 0.90, green: 0.92, blue: 0.96)
}

enum WorkoutMove: String, CaseIterable, Identifiable, Codable {
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

    var metricTitle: String {
        switch self {
        case .squat:
            return "Knee"
        case .sitUp:
            return "Torso"
        case .pushUp:
            return "Elbow"
        case .jumpingJack:
            return "Spread"
        }
    }
}

extension WorkoutMove {
    fileprivate var requiredJoints: [PoseJoint] {
        switch self {
        case .squat:
            return [.leftHip, .rightHip, .leftKnee, .rightKnee, .leftAnkle, .rightAnkle]
        case .sitUp:
            return [.leftShoulder, .rightShoulder, .leftHip, .rightHip]
        case .pushUp:
            return [.leftShoulder, .rightShoulder, .leftElbow, .rightElbow, .leftWrist, .rightWrist]
        case .jumpingJack:
            return [.leftWrist, .rightWrist, .leftAnkle, .rightAnkle]
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

private enum RepPhase {
    case ready
    case loaded
}

private struct MovementAnalysis {
    let didCountRep: Bool
    let message: String
    let score: Int?
    let metricTitle: String
    let metricValue: Double?
    let metricUnit: String

    var metricText: String {
        guard let metricValue = metricValue else {
            return "--"
        }

        if metricUnit == "deg" {
            return "\(Int(metricValue.rounded())) deg"
        }

        return "\(Int(metricValue.rounded()))\(metricUnit)"
    }
}

private final class PoseCameraController: NSObject, ObservableObject {
    @Published var authorizationStatus: AVAuthorizationStatus
    @Published var joints: [PoseJoint: CGPoint] = [:]
    @Published var hasGoodForm = false
    @Published var repCount = 0
    @Published var fps: Double = 0
    @Published var processingMs: Double = 0
    @Published var poseQuality: Double = 0
    @Published var calibrationProgress: CGFloat = 0
    @Published var averageScore: Int = 0
    @Published var lastScore: Int = 0
    @Published var metricTitle = "Angle"
    @Published var metricValueText = "--"
    @Published var correctionTip = "Find your setup"
    
    private var repScores: [Int] = []
    private var currentRepMetric: CGFloat = 0
    private var workoutStartedAt: Date?
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
    private let bodyPoseRequest = VNDetectHumanBodyPoseRequest()
    private var isConfigured = false
    private var phase: RepPhase = .ready
    private var smoothedJoints: [PoseJoint: CGPoint] = [:]
    private var lastFrameTimestamp: CFAbsoluteTime?

    init(selectedMove: WorkoutMove = .squat) {
        self.selectedMove = selectedMove
        authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
        super.init()
    }

    func resetCounter() {
        repCount = 0
        phase = .ready
        smoothedJoints = [:]
        feedbackMessage = "Adjust your position"
        correctionTip = "Find your setup"
        repScores = []
        averageScore = 0
        lastScore = 0
        calibrationProgress = 0
        currentRepMetric = 0
        metricTitle = selectedMove.metricTitle
        metricValueText = "--"
        workoutStartedAt = nil
    }

    func beginWorkout() {
        workoutStartedAt = Date()
    }

    func finishWorkout() -> WorkoutSessionRecord? {
        guard repCount > 0 else {
            return nil
        }

        let startedAt = workoutStartedAt ?? Date()
        return WorkoutSessionRecord(
            move: selectedMove,
            date: Date(),
            reps: repCount,
            targetReps: selectedMove.targetReps,
            duration: max(Date().timeIntervalSince(startedAt), 1),
            averageScore: averageScore
        )
    }

    func increaseRepCount() {
        repCount += 1
    }

    func decreaseRepCount() {
        repCount = max(0, repCount - 1)
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

    @MainActor
    private func publish(joints: [PoseJoint: CGPoint],
                         hasGoodForm: Bool,
                         didCountRep: Bool,
                         message: String,
                         fps: Double,
                         processingMs: Double,
                         poseQuality: Double,
                         score: Int?,
                         metricTitle: String,
                         metricValueText: String,
                         correctionTip: String) {
        self.joints = joints
        self.hasGoodForm = hasGoodForm
        self.feedbackMessage = message
        self.fps = fps
        self.processingMs = processingMs
        self.poseQuality = poseQuality
        self.metricTitle = metricTitle
        self.metricValueText = metricValueText
        self.correctionTip = correctionTip

        updateCalibration(joints: joints)

        if didCountRep {
            repCount += 1
            if let validScore = score {
                lastScore = validScore
                repScores.append(validScore)
                averageScore = repScores.reduce(0, +) / repScores.count
            }
        }
    }

    private func analyzeMovement(joints: [PoseJoint: CGPoint]) -> MovementAnalysis {
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

    private func analyzeSquat(joints: [PoseJoint: CGPoint]) -> MovementAnalysis {
        guard let kneeAngle = averageAngle(
            joints: joints,
            left: (.leftHip, .leftKnee, .leftAnkle),
            right: (.rightHip, .rightKnee, .rightAnkle)
        ) else {
            return analysis(false, "Show hips, knees, ankles", nil, nil)
        }

        if kneeAngle < 105 {
            if phase == .ready { phase = .loaded; currentRepMetric = kneeAngle }
            currentRepMetric = min(currentRepMetric, kneeAngle)
            return analysis(false, "Depth good - stand tall", nil, kneeAngle)
        }

        if kneeAngle > 155, phase == .loaded {
            phase = .ready
            let score = max(0, min(100, Int(100 - (currentRepMetric - 75) * 1.5)))
            return analysis(true, "Good rep!", score, kneeAngle)
        }

        if phase == .loaded {
            return analysis(false, "Keep standing tall", nil, kneeAngle)
        }

        if kneeAngle < 135 {
            return analysis(false, "Go a little lower", nil, kneeAngle)
        }

        return analysis(false, "Start squat - hips back", nil, kneeAngle)
    }

    private func analyzeSitUp(joints: [PoseJoint: CGPoint]) -> MovementAnalysis {
        guard let shoulders = midpoint(joints[.leftShoulder], joints[.rightShoulder]),
              let hips = midpoint(joints[.leftHip], joints[.rightHip]) else {
            return analysis(false, "Show shoulders and hips", nil, Optional<Double>.none, unit: "%")
        }

        let torsoRise = shoulders.y - hips.y
        let torsoMetric = Double(max(0, torsoRise) * 100)

        if torsoRise < 0.16 {
            if phase == .ready { phase = .loaded; currentRepMetric = torsoRise }
            currentRepMetric = max(currentRepMetric, torsoRise)
            return analysis(false, "Down position - curl up", nil, torsoMetric, unit: "%")
        }

        if torsoRise > 0.34, phase == .loaded {
            phase = .ready
            let score = max(0, min(100, Int(100 - (0.45 - currentRepMetric) * 200)))
            return analysis(true, "Good rep!", score, torsoMetric, unit: "%")
        }

        if phase == .loaded {
            return analysis(false, "Curl higher", nil, torsoMetric, unit: "%")
        }

        if torsoRise > 0.26 {
            return analysis(false, "Control back down", nil, torsoMetric, unit: "%")
        }

        return analysis(false, "Lie back before next rep", nil, torsoMetric, unit: "%")
    }

    private func analyzePushUp(joints: [PoseJoint: CGPoint]) -> MovementAnalysis {
        guard let elbowAngle = averageAngle(
            joints: joints,
            left: (.leftShoulder, .leftElbow, .leftWrist),
            right: (.rightShoulder, .rightElbow, .rightWrist)
        ) else {
            return analysis(false, "Show shoulders, elbows, wrists", nil, nil)
        }

        if elbowAngle < 95 {
            if phase == .ready { phase = .loaded; currentRepMetric = elbowAngle }
            currentRepMetric = min(currentRepMetric, elbowAngle)
            return analysis(false, "Depth good - press up", nil, elbowAngle)
        }

        if elbowAngle > 155, phase == .loaded {
            phase = .ready
            let score = max(0, min(100, Int(100 - (currentRepMetric - 75) * 1.5)))
            return analysis(true, "Good rep!", score, elbowAngle)
        }

        if phase == .loaded {
            return analysis(false, "Press until arms extend", nil, elbowAngle)
        }

        if elbowAngle < 130 {
            return analysis(false, "Lower a little more", nil, elbowAngle)
        }

        return analysis(false, "Start push up", nil, elbowAngle)
    }

    private func analyzeJumpingJack(joints: [PoseJoint: CGPoint]) -> MovementAnalysis {
        guard let leftWrist = joints[.leftWrist],
              let rightWrist = joints[.rightWrist],
              let leftShoulder = joints[.leftShoulder],
              let rightShoulder = joints[.rightShoulder],
              let leftAnkle = joints[.leftAnkle],
              let rightAnkle = joints[.rightAnkle],
              let leftHip = joints[.leftHip],
              let rightHip = joints[.rightHip] else {
            return analysis(false, "Show full body", nil, Optional<Double>.none, unit: "%")
        }

        let shoulderWidth = abs(leftShoulder.x - rightShoulder.x)
        let hipWidth = abs(leftHip.x - rightHip.x)
        let wristWidth = abs(leftWrist.x - rightWrist.x)
        let ankleWidth = abs(leftAnkle.x - rightAnkle.x)
        let armsUp = leftWrist.y > leftShoulder.y && rightWrist.y > rightShoulder.y
        let legsOpen = ankleWidth > max(hipWidth * 1.45, 0.16)
        let openPosition = armsUp && wristWidth > shoulderWidth * 1.35 && legsOpen
        let closedPosition = leftWrist.y < leftShoulder.y && rightWrist.y < rightShoulder.y && ankleWidth < max(hipWidth * 1.25, 0.22)
        let spreadMetric = Double(ankleWidth * 100)

        if openPosition {
            if phase == .ready { phase = .loaded; currentRepMetric = ankleWidth }
            currentRepMetric = max(currentRepMetric, ankleWidth)
            return analysis(false, "Open good - close stance", nil, spreadMetric, unit: "%")
        }

        if closedPosition, phase == .loaded {
            phase = .ready
            let score = max(0, min(100, Int(100 - (0.40 - currentRepMetric) * 250)))
            return analysis(true, "Good rep!", score, spreadMetric, unit: "%")
        }

        if phase == .loaded {
            return analysis(false, "Bring hands and feet in", nil, spreadMetric, unit: "%")
        }

        if !armsUp && !legsOpen {
            return analysis(false, "Open arms and feet", nil, spreadMetric, unit: "%")
        }

        if !armsUp {
            return analysis(false, "Raise both hands higher", nil, spreadMetric, unit: "%")
        }

        if !legsOpen {
            return analysis(false, "Step feet wider", nil, spreadMetric, unit: "%")
        }

        return analysis(false, "Keep full body visible", nil, spreadMetric, unit: "%")
    }

    private func analysis(
        _ didCountRep: Bool,
        _ message: String,
        _ score: Int?,
        _ metricValue: CGFloat?,
        unit: String = "deg"
    ) -> MovementAnalysis {
        MovementAnalysis(
            didCountRep: didCountRep,
            message: message,
            score: score,
            metricTitle: selectedMove.metricTitle,
            metricValue: metricValue.map { Double($0) },
            metricUnit: unit
        )
    }

    private func analysis(
        _ didCountRep: Bool,
        _ message: String,
        _ score: Int?,
        _ metricValue: Double?,
        unit: String
    ) -> MovementAnalysis {
        MovementAnalysis(
            didCountRep: didCountRep,
            message: message,
            score: score,
            metricTitle: selectedMove.metricTitle,
            metricValue: metricValue,
            metricUnit: unit
        )
    }

    private func correctionTip(for message: String) -> String {
        if message.contains("hips, knees, ankles") { return "Show lower body" }
        if message.contains("shoulders, elbows") { return "Show arms" }
        if message.contains("full body") { return "Step back" }
        if message.contains("lower") { return "More depth" }
        if message.contains("stand tall") { return "Extend hips" }
        if message.contains("Curl higher") { return "Lift torso" }
        if message.contains("Raise") { return "Hands higher" }
        if message.contains("wider") { return "Feet wider" }
        if message.contains("Good rep") { return "Clean rep" }
        return "Keep steady"
    }

    private func isPositiveFeedback(_ message: String) -> Bool {
        let negativeWords = ["Adjust", "Show", "Go a little lower", "Curl higher", "Press until", "Lower a little more", "Raise", "Step feet", "Bring hands"]
        for word in negativeWords {
            if message.contains(word) { return false }
        }
        return true
    }

    private func updateCalibration(joints: [PoseJoint: CGPoint]) {
        let required = selectedMove.requiredJoints
        let isVisible = required.allSatisfy { joints[$0] != nil }
        if isVisible {
            calibrationProgress = min(1.0, calibrationProgress + 0.05)
        } else {
            calibrationProgress = max(0.0, calibrationProgress - 0.02)
        }
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
                        poseQuality: 0,
                        score: nil,
                        metricTitle: self.selectedMove.metricTitle,
                        metricValueText: "--",
                        correctionTip: "Find your setup"
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
                    poseQuality: poseQuality,
                    score: movement.score,
                    metricTitle: movement.metricTitle,
                    metricValueText: movement.metricText,
                    correctionTip: self.correctionTip(for: movement.message)
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
                    poseQuality: 0,
                    score: nil,
                    metricTitle: self.selectedMove.metricTitle,
                    metricValueText: "--",
                    correctionTip: "Find your setup"
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
        return try detectJointsWithVisionBodyPose(pixelBuffer: pixelBuffer)
    }

    private func detectJointsWithVisionBodyPose(pixelBuffer: CVPixelBuffer) throws -> [PoseJoint: CGPoint] {
        try sequenceHandler.perform([bodyPoseRequest], on: pixelBuffer, orientation: .leftMirrored)

        guard let observation = bodyPoseRequest.results?.first else {
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
}
