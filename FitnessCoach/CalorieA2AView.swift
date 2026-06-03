import SwiftUI

struct CalorieA2AView: View {
    @State private var response: A2AResponse?
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 20) {
            Text("AppleHealthAgent")
                .font(.title2)
                .fontWeight(.bold)

            Text("Data via A2A Protocol")
                .font(.caption)
                .foregroundColor(.secondary)

            if let response = response {
                let calories = response.result.artifact.calories

                HStack {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)

                    Text("Status: \(response.result.status)")
                        .font(.caption)
                        .foregroundColor(.green)
                }

                Text(response.result.artifact.date)
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                VStack(spacing: 12) {
                    CalorieRow(label: "Active Calories", value: "\(calories.active) \(calories.unit)")
                    CalorieRow(label: "Resting Calories", value: "\(calories.resting) \(calories.unit)")
                    CalorieRow(label: "Total Calories", value: "\(calories.total) \(calories.unit)", isHighlighted: true)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)

                Text("Agent: \(response.result.agent)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            } else if let errorMessage = errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.caption)
            } else {
                ProgressView("Loading A2A data...")
            }
        }
        .padding()
        .onAppear(perform: loadA2AData)
    }

    private func loadA2AData() {
        guard let url = Bundle.main.url(forResource: "mock_a2a_response", withExtension: "json") else {
            errorMessage = "File mock_a2a_response.json tidak ditemukan di bundle app."
            return
        }

        do {
            let data = try Data(contentsOf: url)
            response = try JSONDecoder().decode(A2AResponse.self, from: data)
        } catch {
            errorMessage = "Gagal parse JSON: \(error.localizedDescription)"
        }
    }
}

struct CalorieRow: View {
    let label: String
    let value: String
    var isHighlighted: Bool = false

    var body: some View {
        HStack {
            Text(label)
                .font(isHighlighted ? .headline : .subheadline)

            Spacer()

            Text(value)
                .font(isHighlighted ? .headline : .subheadline)
                .fontWeight(isHighlighted ? .bold : .regular)
                .foregroundColor(isHighlighted ? .orange : .primary)
        }
    }
}

struct CalorieA2AView_Previews: PreviewProvider {
    static var previews: some View {
        CalorieA2AView()
    }
}
