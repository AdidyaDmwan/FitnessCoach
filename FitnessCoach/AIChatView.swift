import SwiftUI

struct ChatMessage: Identifiable {
    let id = UUID()
    let content: String
    let isUser: Bool
}

@MainActor
final class AIChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var inputText: String = ""
    @Published var isSending = false
    @Published var errorMessage: String?

    private let remoteClient = RemoteFitnessChatClient()
    private let localCoach = LocalFitnessCoach()

    init() {
        messages = [
            ChatMessage(
                content: "Hi! I'm your FitnessCoach AI. Ask me anything about your workout or nutrition!",
                isUser: false
            )
        ]
    }

    func sendCurrentMessage() {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isSending else { return }
        let userMessage = ChatMessage(content: trimmed, isUser: true)
        messages.append(userMessage)
        inputText = ""
        errorMessage = nil
        Task {
            await submitMessage(trimmed)
        }
    }

    private func submitMessage(_ text: String) async {
        isSending = true
        defer { isSending = false }

        do {
            if let response = try await remoteClient.send(message: text) {
                appendAIReply(response)
            } else {
                appendAIReply(localCoach.reply(to: text))
            }
        } catch {
            errorMessage = "Using offline coach."
            appendAIReply(localCoach.reply(to: text))
        }
    }

    private func appendAIReply(_ text: String) {
        let aiMessage = ChatMessage(content: text, isUser: false)
        messages.append(aiMessage)
    }

}

private struct RemoteFitnessChatClient {
    private var serverURL: URL? {
        let environmentValue = ProcessInfo.processInfo.environment["AI_CHAT_SERVER_URL"]
        let plistValue = Bundle.main.object(forInfoDictionaryKey: "AIChatServerURL") as? String
        let configuredValue = environmentValue ?? plistValue ?? ""
        let trimmedConfiguredValue = configuredValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let rawValue = trimmedConfiguredValue.isEmpty || trimmedConfiguredValue.contains("$(")
            ? defaultServerURLString
            : trimmedConfiguredValue

        return URL(string: rawValue)
    }

    private var defaultServerURLString: String {
        #if targetEnvironment(simulator)
        return "http://localhost:5001"
        #else
        return ""
        #endif
    }

    func send(message: String) async throws -> String? {
        guard let serverURL = serverURL else {
            return nil
        }

        let url = serverURL.appendingPathComponent("api/chat")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(["message": message])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }

        return try JSONDecoder().decode(ChatAPIResponse.self, from: data).response
    }

    private struct ChatAPIResponse: Decodable {
        let response: String
    }
}

private struct LocalFitnessCoach {
    func reply(to message: String) -> String {
        let text = message.lowercased()

        if containsAny(text, ["squat", "jongkok"]) {
            return "For squats: stand with feet shoulder-width apart, push your hips back, keep your chest up, and lower until your knees bend deeply. If the camera says “Go a little lower,” reduce depth slowly and keep your knees tracking over your toes."
        }

        if containsAny(text, ["push", "pushup", "push up"]) {
            return "For push-ups: keep a straight line from shoulders to ankles, lower until elbows bend clearly, then press until arms extend. Use a side camera angle so shoulders, elbows, and wrists are visible."
        }

        if containsAny(text, ["sit up", "situp", "abs", "core"]) {
            return "For sit-ups: start lying back, brace your core, curl shoulders toward hips, then return with control. Put the phone on the side so the camera can see shoulders and hips."
        }

        if containsAny(text, ["jumping", "jump", "cardio"]) {
            return "For jumping jacks: open arms and feet together, then close them together. Keep your full body in frame so the camera can track wrists and ankles."
        }

        if containsAny(text, ["calorie", "kalori", "fat", "weight loss", "turun berat"]) {
            return "For fat loss, combine a small calorie deficit, 2-4 strength sessions per week, daily walking, and enough protein. Avoid extreme deficits because they make workouts harder and recovery worse."
        }

        if containsAny(text, ["protein", "makan", "nutrition", "nutrisi"]) {
            return "A simple nutrition target: include protein in each meal, add vegetables or fruit, drink enough water, and keep portions consistent. For training days, eat carbs before or after workouts for energy."
        }

        if containsAny(text, ["pain", "sakit", "injury", "cedera"]) {
            return "If you feel sharp pain, numbness, dizziness, or joint pain, stop the exercise. I can give general form tips, but for injury or medical concerns you should ask a qualified professional."
        }

        if containsAny(text, ["workout", "latihan", "program", "plan"]) {
            return "A balanced home workout: 3 rounds of squats, push-ups, sit-ups, and jumping jacks. Rest 45-90 seconds between rounds. Start with clean form before increasing reps."
        }

        return "I can help with workout form, reps, nutrition, calories, and training plans. Tell me which exercise you are doing and what feels difficult, then I’ll give specific coaching tips."
    }

    private func containsAny(_ text: String, _ keywords: [String]) -> Bool {
        keywords.contains { text.contains($0) }
    }
}

struct AIChatView: View {
    @StateObject private var viewModel = AIChatViewModel()

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView(showsIndicators: false) {
                VStack(spacing: 12) {
                    ForEach(viewModel.messages) { message in
                        messageRow(message)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 18)
            }
            .background(Color.white)

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
            }

            chatInputBar
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.fcSoft)
        }
        .background(Color.white.edgesIgnoringSafeArea(.all))
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("AI Chat")
                    .font(.system(size: 24, weight: .heavy))
                    .foregroundColor(.fcInk)

                Text("Ask your FitnessCoach AI anything.")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.fcMuted)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 20)
        .background(Color.white)
    }

    private func messageRow(_ message: ChatMessage) -> some View {
        HStack {
            if message.isUser { Spacer() }

            Text(message.content)
                .font(.system(size: 16))
                .foregroundColor(message.isUser ? .white : .black)
                .padding(14)
                .background(message.isUser ? Color.fcInk : Color.fcSoft)
                .cornerRadius(20)
                .frame(maxWidth: 280, alignment: message.isUser ? .trailing : .leading)

            if !message.isUser { Spacer() }
        }
    }

    private var chatInputBar: some View {
        HStack(spacing: 12) {
            TextField("Ask a question...", text: $viewModel.inputText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .submitLabel(.send)
                .onSubmit {
                    viewModel.sendCurrentMessage()
                }

            if viewModel.isSending {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .fcInk))
            } else {
                Button {
                    viewModel.sendCurrentMessage()
                } label: {
                    Image(systemName: "paperplane.fill")
                        .foregroundColor(.white)
                        .padding(12)
                        .background(Color.fcInk)
                        .clipShape(Circle())
                }
                .disabled(viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }
}

struct AIChatView_Previews: PreviewProvider {
    static var previews: some View {
        AIChatView()
    }
}
