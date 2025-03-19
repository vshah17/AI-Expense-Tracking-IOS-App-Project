import Foundation

actor OpenAIService {
    private let apiKey: String
    private let endpoint: String
    
    init(apiKey: String, endpoint: String) {
        self.apiKey = apiKey
        self.endpoint = endpoint
    }
    
    func analyzeExpense(_ description: String) async throws -> (amount: Double, category: Category) {
        let prompt = """
        Analyze this expense description and extract the amount and categorize it into one of these categories:
        Food, Groceries, Transportation, Housing, Utilities, Entertainment, Shopping, Healthcare, Education, Other
        
        Description: \(description)
        
        Respond in JSON format with two fields:
        {
            "amount": number,
            "category": "category_name"
        }
        """
        
        let response = try await makeRequest(prompt: prompt)
        return try parseExpenseResponse(response)
    }
    
    func getSpendingInsights(expenses: [Expense], question: String) async throws -> String {
        let totalAmount = expenses.reduce(0.0) { $0 + $1.amount }
        
        let expensesSummary = expenses.map { expense in
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let recurringTag = expense.isRecurring ? " (Recurring)" : ""
            return "\(expense.description): $\(String(format: "%.2f", expense.amount)) (\(expense.category.rawValue))\(recurringTag) on \(dateFormatter.string(from: expense.date))"
        }.joined(separator: "\n")
        
        // First, determine if this is a specific category query
        let categoryQueries = [
            "groceries": "How much do I spend on groceries",
            "food": "How much do I spend on food",
            "transportation": "How much do I spend on transportation",
            "gas": "How much do I spend on gas",
            "housing": "How much do I spend on housing",
            "rent": "How much do I spend on rent"
        ]
        
        let isSpecificQuery = categoryQueries.values.contains { question.lowercased().contains($0.lowercased()) }
        
        let prompt = """
        Based on these expenses:
        \(expensesSummary)
        
        The accurate total amount for all expenses is: $\(String(format: "%.2f", totalAmount))
        
        Please answer this question: \(question)
        
        \(isSpecificQuery ? """
        IMPORTANT: This is a specific expense query. You must:
        1. ONLY show the total for the requested category
        2. List the individual expenses in that category
        3. Show the category total
        4. Use EXACTLY this format:
        ### [Category] Expenses:
        - [Description]: $XX.XX
        - [Description]: $XX.XX
        Total [Category] Expenses: $XX.XX
        
        DO NOT include any other information or monthly report.
        """ : """
        This is a request for a monthly report. Include:
        1. Total spending for the month (sum of all expenses including recurring ones) - MUST use the provided total of $\(String(format: "%.2f", totalAmount))
        2. Spending by category (sorted by amount, include all categories with expenses)
        3. Largest individual expenses (top 3-5 expenses)
        4. Recurring expenses (if any are marked as recurring)
        5. Notable spending patterns or trends
        
        Important notes:
        - Include ALL categories in the breakdown, including housing and others
        - The total MUST match the provided accurate total of $\(String(format: "%.2f", totalAmount))
        - Format all currency values with two decimal places
        - Provide clear, organized sections with proper headings
        """)
        """
        
        return try await makeRequest(prompt: prompt)
    }
    
    private func makeRequest(prompt: String) async throws -> String {
        var request = URLRequest(url: URL(string: endpoint)!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "model": "gpt-3.5-turbo",
            "messages": [
                ["role": "system", "content": "You are a helpful assistant that analyzes expenses and provides financial insights."],
                ["role": "user", "content": prompt]
            ],
            "temperature": 0.7
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw OpenAIError.requestFailed
        }
        
        let result = try JSONDecoder().decode(OpenAIResponse.self, from: data)
        return result.choices.first?.message.content ?? ""
    }
    
    private func parseExpenseResponse(_ response: String) throws -> (amount: Double, category: Category) {
        guard let data = response.data(using: .utf8),
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let amount = json["amount"] as? Double,
              let categoryString = json["category"] as? String,
              let category = Category(rawValue: categoryString) else {
            throw OpenAIError.invalidResponse
        }
        
        return (amount, category)
    }
}

// MARK: - Models

struct OpenAIResponse: Codable {
    let choices: [Choice]
    
    struct Choice: Codable {
        let message: Message
    }
    
    struct Message: Codable {
        let content: String
    }
}

enum OpenAIError: Error {
    case requestFailed
    case invalidResponse
} 
