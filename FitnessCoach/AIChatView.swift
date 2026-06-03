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

        guard let url = URL(string: "http://localhost:5001/api/chat") else {
            appendAIReply("Unable to create request URL.")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload = ["message": text]
        do {
            request.httpBody = try JSONEncoder().encode(payload)
        } catch {
            appendAIReply("Failed to encode chat message.")
            return
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200..<300).contains(httpResponse.statusCode) else {
                throw URLError(.badServerResponse)
            }

            let apiResponse = try JSONDecoder().decode(ChatAPIResponse.self, from: data)
            appendAIReply(apiResponse.response)
        } catch {
            errorMessage = "Unable to reach AI server."
            appendAIReply("I couldn't reach the AI server. Please try again later.")
        }
    }

    private func appendAIReply(_ text: String) {
        let aiMessage = ChatMessage(content: text, isUser: false)
        messages.append(aiMessage)
    }

    private struct ChatAPIResponse: Decodable {
        let response: String
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
                Button(action: viewModel.sendCurrentMessage) {
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
