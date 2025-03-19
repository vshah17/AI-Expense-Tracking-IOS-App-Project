import Foundation
import SwiftUI

@MainActor
class ExpenseViewModel: ObservableObject {
    @Published var expenses: [Expense] = []
    @Published var recurringExpenses: [RecurringExpense] = []
    @Published var selectedCategory: Category?
    @Published var dateRange: ClosedRange<Date>?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var excludedCategories: Set<Category> = []
    @Published var categoryBudgets: [Category: Double] = [:] {
        didSet {
            saveCategoryBudgets()
        }
    }
    @Published var currencyCode: String {
        didSet {
            UserDefaults.standard.set(currencyCode, forKey: "selectedCurrency")
        }
    }
    
    private let openAIService: OpenAIService
    
    init() {
        // Load saved currency or default to USD
        self.currencyCode = UserDefaults.standard.string(forKey: "selectedCurrency") ?? "USD"
        
        self.openAIService = OpenAIService(
            apiKey: Config.openAIKey,
            endpoint: Config.openAIEndpoint
        )
        loadExpenses()
        loadRecurringExpenses()
        loadCategoryBudgets()
        processRecurringExpenses()
    }
    
    // MARK: - Expense Management
    
    func addExpense(_ expense: Expense) {
        expenses.append(expense)
        saveExpenses()
    }
    
    func updateExpense(_ updatedExpense: Expense) {
        if let index = expenses.firstIndex(where: { $0.id == updatedExpense.id }) {
            expenses[index] = updatedExpense
            saveExpenses()
        }
    }
    
    func deleteExpense(_ expense: Expense) {
        expenses.removeAll { $0.id == expense.id }
        saveExpenses()
    }
    
    // MARK: - Recurring Expense Management
    
    func addRecurringExpense(_ recurringExpense: RecurringExpense) {
        recurringExpenses.append(recurringExpense)
        saveRecurringExpenses()
        processRecurringExpenses()
    }
    
    func updateRecurringExpense(_ updatedExpense: RecurringExpense) {
        if let index = recurringExpenses.firstIndex(where: { $0.id == updatedExpense.id }) {
            recurringExpenses[index] = updatedExpense
            saveRecurringExpenses()
            processRecurringExpenses()
        }
    }
    
    func deleteRecurringExpense(_ expense: RecurringExpense) {
        recurringExpenses.removeAll { $0.id == expense.id }
        expenses.removeAll { $0.recurringExpenseId == expense.id }
        saveRecurringExpenses()
        saveExpenses()
    }
    
    private func processRecurringExpenses() {
        let calendar = Calendar.current
        let now = Date()
        
        for recurringExpense in recurringExpenses where recurringExpense.isActive {
            var currentDate = recurringExpense.startDate
            
            while currentDate <= now {
                // Check if we already have an expense for this date
                let existingExpense = expenses.first { expense in
                    expense.recurringExpenseId == recurringExpense.id &&
                    calendar.isDate(expense.date, equalTo: currentDate, toGranularity: recurringExpense.frequency.calendarComponent)
                }
                
                if existingExpense == nil {
                    let expense = Expense(
                        amount: recurringExpense.amount,
                        category: recurringExpense.category,
                        date: currentDate,
                        description: recurringExpense.description,
                        isRecurring: true,
                        recurringExpenseId: recurringExpense.id
                    )
                    expenses.append(expense)
                }
                
                // Move to next occurrence using componentValue
                currentDate = calendar.date(byAdding: recurringExpense.frequency.calendarComponent,
                                         value: recurringExpense.frequency.componentValue,
                                         to: currentDate) ?? now
            }
        }
        
        saveExpenses()
    }
    
    // MARK: - Filtering
    
    var filteredExpenses: [Expense] {
        var filtered = expenses
        
        if let category = selectedCategory {
            filtered = filtered.filter { $0.category == category }
        }
        
        if let dateRange = dateRange {
            filtered = filtered.filter { dateRange.contains($0.date) }
        }
        
        return filtered.sorted { $0.date > $1.date }
    }
    
    // MARK: - Analytics
    
    func totalExpenses(for category: Category? = nil, in timeFrame: TimeFrame = .month, for date: Date = Date()) -> Double {
        let filtered = expenses.filter { expense in
            let categoryMatch = category == nil || expense.category == category
            let dateMatch = isExpense(expense, inTimeFrame: timeFrame, for: date)
            return categoryMatch && dateMatch
        }
        return filtered.reduce(0) { $0 + $1.amount }
    }
    
    func expensesByCategory(in timeFrame: TimeFrame = .month, for date: Date = Date()) -> [(Category, Double)] {
        Category.allCases
            .map { category in
                (category, totalExpenses(for: category, in: timeFrame, for: date))
            }
            .filter { $0.1 > 0 } // Only include categories with expenses
            .sorted { $0.1 > $1.1 } // Sort by amount descending
    }
    
    func recurringExpensesByCategory() -> [(Category, Double)] {
        let monthlyTotal = Dictionary(grouping: recurringExpenses.filter(\.isActive)) { $0.category }
            .mapValues { expenses in
                expenses.reduce(0) { total, expense in
                    switch expense.frequency {
                    case .daily: return total + expense.amount * 30
                    case .weekly: return total + expense.amount * 4
                    case .biweekly: return total + expense.amount * 2
                    case .monthly: return total + expense.amount
                    case .quarterly: return total + expense.amount / 3
                    case .yearly: return total + expense.amount / 12
                    }
                }
            }
        
        return Category.allCases
            .compactMap { category in
                guard let total = monthlyTotal[category], total > 0 else { return nil }
                return (category, total)
            }
            .sorted { $0.1 > $1.1 }
    }
    
    func monthlyExpenses(for date: Date) -> Double {
        let calendar = Calendar.current
        return expenses.filter { expense in
            calendar.isDate(expense.date, equalTo: date, toGranularity: .month)
        }.reduce(0) { $0 + $1.amount }
    }
    
    private func isExpense(_ expense: Expense, inTimeFrame timeFrame: TimeFrame, for date: Date) -> Bool {
        let calendar = Calendar.current
        
        switch timeFrame {
        case .week:
            let weekInterval = calendar.dateInterval(of: .weekOfYear, for: date)!
            return expense.date >= weekInterval.start && expense.date < weekInterval.end
            
        case .month:
            let monthInterval = calendar.dateInterval(of: .month, for: date)!
            return expense.date >= monthInterval.start && expense.date < monthInterval.end
            
        case .year:
            let yearInterval = calendar.dateInterval(of: .year, for: date)!
            return expense.date >= yearInterval.start && expense.date < yearInterval.end
        }
    }
    
    // MARK: - Persistence
    
    private func saveExpenses() {
        do {
            let data = try JSONEncoder().encode(expenses)
            let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let fileURL = documentsDirectory.appendingPathComponent("expenses.json")
            try data.write(to: fileURL)
        } catch {
            print("Error saving expenses: \(error)")
        }
    }
    
    private func loadExpenses() {
        do {
            let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let fileURL = documentsDirectory.appendingPathComponent("expenses.json")
            let data = try Data(contentsOf: fileURL)
            expenses = try JSONDecoder().decode([Expense].self, from: data)
        } catch {
            print("Error loading expenses: \(error)")
        }
    }
    
    private func saveRecurringExpenses() {
        do {
            let data = try JSONEncoder().encode(recurringExpenses)
            let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let fileURL = documentsDirectory.appendingPathComponent("recurring_expenses.json")
            try data.write(to: fileURL)
        } catch {
            print("Error saving recurring expenses: \(error)")
        }
    }
    
    private func loadRecurringExpenses() {
        do {
            let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let fileURL = documentsDirectory.appendingPathComponent("recurring_expenses.json")
            let data = try Data(contentsOf: fileURL)
            recurringExpenses = try JSONDecoder().decode([RecurringExpense].self, from: data)
        } catch {
            print("Error loading recurring expenses: \(error)")
        }
    }
    
    // MARK: - AI Integration
    
    func analyzeExpenseDescription(_ description: String) async throws -> (amount: Double, category: Category) {
        isLoading = true
        defer { isLoading = false }
        
        let (_, category) = try await openAIService.analyzeExpense(description)
        return (0.0, category)
    }
    
    func getSpendingInsights(question: String) async throws -> String {
        isLoading = true
        defer { isLoading = false }
        
        // Filter expenses for the current month
        let calendar = Calendar.current
        let now = Date()
        let monthInterval = calendar.dateInterval(of: .month, for: now)!
        let currentMonthExpenses = expenses.filter { expense in
            expense.date >= monthInterval.start && expense.date < monthInterval.end
        }
        
        return try await openAIService.getSpendingInsights(expenses: currentMonthExpenses, question: question)
    }
    
    // Add currency-related methods
    static let availableCurrencies: [(code: String, symbol: String, name: String)] = [
        ("USD", "$", "US Dollar"),
        ("EUR", "€", "Euro"),
        ("GBP", "£", "British Pound"),
        ("JPY", "¥", "Japanese Yen"),
        ("CAD", "$", "Canadian Dollar"),
        ("AUD", "$", "Australian Dollar"),
        ("CNY", "¥", "Chinese Yuan"),
        ("INR", "₹", "Indian Rupee")
    ]
    
    func setCurrency(_ code: String) {
        guard Self.availableCurrencies.contains(where: { $0.code == code }) else { return }
        currencyCode = code
    }
    
    // MARK: - Budget Management
    
    func setBudget(for category: Category, amount: Double) {
        categoryBudgets[category] = amount
    }
    
    func getBudget(for category: Category) -> Double {
        return categoryBudgets[category] ?? 0.0
    }
    
    func getBudgetProgress(for category: Category, in timeFrame: TimeFrame = .month, for date: Date = Date()) -> Double {
        let spent = totalExpenses(for: category, in: timeFrame, for: date)
        let budget = getBudget(for: category)
        return budget > 0 ? spent / budget : 0.0
    }
    
    private func saveCategoryBudgets() {
        do {
            let data = try JSONEncoder().encode(categoryBudgets)
            let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let fileURL = documentsDirectory.appendingPathComponent("category_budgets.json")
            try data.write(to: fileURL)
        } catch {
            print("Error saving category budgets: \(error)")
        }
    }
    
    private func loadCategoryBudgets() {
        do {
            let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let fileURL = documentsDirectory.appendingPathComponent("category_budgets.json")
            let data = try Data(contentsOf: fileURL)
            categoryBudgets = try JSONDecoder().decode([Category: Double].self, from: data)
        } catch {
            print("Error loading category budgets: \(error)")
        }
    }
}

enum TimeFrame: String, CaseIterable {
    case week = "Week"
    case month = "Month"
    case year = "Year"
} 