import SwiftUI

struct AIAssistantView: View {
    @EnvironmentObject private var viewModel: ExpenseViewModel
    @Environment(\.colorScheme) private var colorScheme
    @State private var question = ""
    @State private var insights: [String] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    let sampleQuestions = [
        (icon: "chart.pie.fill", question: "Generate a monthly spending report"),
        (icon: "chart.line.uptrend.xyaxis", question: "Give me insights on my spending habits"),
        (icon: "arrow.left.arrow.right", question: "How does my spending compare to last month?"),
        (icon: "fuelpump.fill", question: "How much do I spend on gas?"),
        (icon: "cart.fill", question: "How much do I spend on groceries?"),
        (icon: "repeat", question: "Do I have any recurring expenses/subscriptions?")
    ]
    
    private let gradientColors = [Color.blue.opacity(0.8), Color.purple.opacity(0.8)]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header Card
                VStack(spacing: 12) {
                    // Title Section
                    Text("Get insights about your spending")
                        .font(.system(.body, design: .rounded))
                        .foregroundColor(.white.opacity(0.8))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, -16)
                    
                    // Question Input Section
                    HStack(spacing: 12) {
                        ZStack(alignment: .leading) {
                            if question.isEmpty {
                                Text("Type your question...")
                                    .font(.system(.body, design: .rounded))
                                    .foregroundColor(.white.opacity(0.7))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                            }
                            
                            TextField("", text: $question)
                                .font(.system(.body, design: .rounded))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .foregroundColor(.white)
                        }
                        .background(Color.white.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .disabled(isLoading)
                        .tint(.white)
                    
                        Button(action: askQuestion) {
                            if isLoading {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: "arrow.up.circle.fill")
                                    .font(.system(size: 32, design: .rounded))
                                    .symbolRenderingMode(.hierarchical)
                                    .foregroundStyle(.white)
                            }
                        }
                        .disabled(question.isEmpty || isLoading)
                    }
                }
                .padding()
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: gradientColors),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            
            ScrollView {
                VStack(spacing: 24) {
                    // Suggested Questions
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Suggested Questions")
                            .font(.system(.title3, design: .rounded))
                            .fontWeight(.medium)
                        
                        LazyVGrid(columns: [
                            GridItem(.flexible(), spacing: 12),
                            GridItem(.flexible(), spacing: 12)
                        ], spacing: 12) {
                            ForEach(sampleQuestions, id: \.question) { item in
                                Button(action: { question = item.question }) {
                                    HStack {
                                        Image(systemName: item.icon)
                                            .font(.system(size: 16, weight: .medium, design: .rounded))
                                            .foregroundColor(.blue)
                                            .frame(width: 24)
                                        
                                        Text(item.question)
                                            .font(.system(.subheadline, design: .rounded))
                                            .foregroundColor(.primary)
                                            .lineLimit(2)
                                            .multilineTextAlignment(.leading)
                                        
                                        Spacer(minLength: 8)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(colorScheme == .dark ? Color(.systemGray6) : .white)
                                            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                                    )
                                }
                            }
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(colorScheme == .dark ? Color(.systemGray6) : .white)
                            .shadow(color: .black.opacity(0.05), radius: 8)
                    )
                    .padding(.horizontal)
                    
                    // Previous Insights
                    if !insights.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Previous Insights")
                                .font(.system(.title3, design: .rounded))
                                .fontWeight(.medium)
                            
                            LazyVStack(spacing: 12) {
                                ForEach(insights, id: \.self) { insight in
                                    InsightCard(text: insight)
                                }
                            }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(colorScheme == .dark ? Color(.systemGray6) : .white)
                                .shadow(color: .black.opacity(0.05), radius: 8)
                        )
                        .padding(.horizontal)
                    }
                    
                    if let error = errorMessage {
                        Text(error)
                            .font(.system(.callout, design: .rounded))
                            .foregroundColor(.red)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.red.opacity(0.1))
                            )
                            .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("AI Assistant")
            .background(Color(.systemGroupedBackground))
            }
        }
    }
    
    private func askQuestion() {
        guard !question.isEmpty else { return }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let insight = try await viewModel.getSpendingInsights(question: question)
                await MainActor.run {
                    insights.insert(insight, at: 0)
                    question = ""
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }
}

struct InsightCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let text: String
    
    private var insightType: (title: String, icon: String) {
        if text.contains("Monthly Spending Report") {
            return ("Monthly Report", "chart.pie.fill")
        } else if text.contains("Gas Expenses:") {
            return ("Gas", "fuelpump.fill")
        } else if text.contains("Groceries Expenses:") {
            return ("Groceries", "cart.fill")
        } else if text.contains("Food Expenses:") {
            return ("Food", "fork.knife")
        } else if text.contains("Housing Expenses:") {
            return ("Housing", "house.fill")
        } else if text.contains("Transportation Expenses:") {
            return ("Transportation", "car.fill")
        } else {
            return ("Spending Insight", "chart.line.uptrend.xyaxis")
        }
    }
    
    private var formattedText: String {
        // Remove ### prefix and asterisks
        var formatted = text
            .replacingOccurrences(of: "### ", with: "")
            .replacingOccurrences(of: "**", with: "")
        
        // If it's a specific expense query, format it nicely
        if formatted.contains("Expenses:") {
            let components = formatted.components(separatedBy: "\n")
            return components.enumerated().map { index, line -> String in
                if line.hasPrefix("-") {
                    // Format expense lines
                    return line
                        .replacingOccurrences(of: "- ", with: "")
                        .trimmingCharacters(in: .whitespaces)
                } else if line.lowercased().contains("total") {
                    // Format total line
                    return "\n" + line.trimmingCharacters(in: .whitespaces)
                } else {
                    // Remove category label if it matches the header
                    return line.contains("Expenses:") ? "" : line
                }
            }.filter { !$0.isEmpty }.joined(separator: "\n")
        }
        
        // For monthly reports, format sections nicely
        if formatted.contains("Monthly Spending Report") {
            let components = formatted.components(separatedBy: "\n")
            return components.enumerated().map { index, line -> String in
                if line.contains("Monthly Spending Report") {
                    return line
                } else if line.contains("Spending by Category:") {
                    return "\nSpending by Category"
                } else if line.contains("Notable Spending Patterns") {
                    return "\nNotable Patterns & Insights"
                } else if line.hasPrefix("-") {
                    return line.replacingOccurrences(of: "- ", with: "• ")
                } else {
                    return line.trimmingCharacters(in: .whitespaces)
                }
            }.filter { !$0.isEmpty }.joined(separator: "\n")
        }
        
        return formatted
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack(spacing: 12) {
                // Icon Circle
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.1))
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: insightType.icon)
                        .font(.system(size: 18, weight: .medium, design: .rounded))
                        .foregroundStyle(.blue)
                }
                
                Text(insightType.title)
                    .font(.system(.headline, design: .rounded))
                    .foregroundColor(.primary)
            }
            
            // Content
            VStack(alignment: .leading, spacing: 8) {
                if formattedText.contains("Monthly Spending Report") {
                    let sections = formattedText.components(separatedBy: "\n\n")
                    ForEach(sections.indices, id: \.self) { index in
                        let lines = sections[index].components(separatedBy: "\n")
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(lines.indices, id: \.self) { lineIndex in
                                if lines[lineIndex].contains("Monthly Spending Report") {
                                    Text(lines[lineIndex])
                                        .font(.system(.title3, design: .rounded))
                                        .foregroundColor(.primary)
                                } else if lines[lineIndex].contains("Category") || lines[lineIndex].contains("Patterns & Insights") {
                                    Text(lines[lineIndex])
                                        .font(.system(.headline, design: .rounded))
                                        .foregroundColor(.primary)
                                        .padding(.top, 4)
                                } else if lines[lineIndex].hasPrefix("•") {
                                    Text(lines[lineIndex])
                                        .font(.system(.subheadline, design: .rounded))
                                        .foregroundColor(.secondary)
                                } else {
                                    Text(lines[lineIndex])
                                        .font(.system(.body, design: .rounded))
                                        .foregroundColor(.primary)
                                }
                            }
                        }
                        if index < sections.count - 1 {
                            Divider()
                                .padding(.vertical, 8)
                        }
                    }
                } else {
                    // Expense query formatting
                    let lines = formattedText.components(separatedBy: "\n")
                    ForEach(lines.indices, id: \.self) { index in
                        if lines[index].contains("Total") {
                            // Total amount
                            Text(lines[index])
                                .font(.system(.headline, design: .rounded))
                                .foregroundColor(.primary)
                                .padding(.top, 4)
                        } else {
                            // Individual expenses
                            Text(lines[index])
                                .font(.system(.body, design: .rounded))
                                .foregroundColor(.primary)
                        }
                    }
                }
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(colorScheme == .dark ? Color(.systemGray5) : Color(.secondarySystemBackground))
                .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
        )
    }
}

#Preview {
    NavigationView {
        AIAssistantView()
            .environmentObject(ExpenseViewModel())
    }
}

extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content) -> some View {
        
        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
} 
