import Foundation

struct Expense: Identifiable, Codable, Equatable {
    let id: UUID
    var amount: Double
    var category: Category
    var date: Date
    var description: String
    var isRecurring: Bool
    var recurringExpenseId: UUID?
    
    init(id: UUID = UUID(), amount: Double, category: Category, date: Date = Date(), description: String, isRecurring: Bool = false, recurringExpenseId: UUID? = nil) {
        self.id = id
        self.amount = amount
        self.category = category
        self.date = date
        self.description = description
        self.isRecurring = isRecurring
        self.recurringExpenseId = recurringExpenseId
    }
    
    static func == (lhs: Expense, rhs: Expense) -> Bool {
        lhs.id == rhs.id &&
        lhs.amount == rhs.amount &&
        lhs.category == rhs.category &&
        lhs.date == rhs.date &&
        lhs.description == rhs.description &&
        lhs.isRecurring == rhs.isRecurring &&
        lhs.recurringExpenseId == rhs.recurringExpenseId
    }
}

struct RecurringExpense: Identifiable, Codable {
    let id: UUID
    var amount: Double
    var category: Category
    var description: String
    var frequency: RecurringFrequency
    var startDate: Date
    var isActive: Bool
    
    init(id: UUID = UUID(), amount: Double, category: Category, description: String, frequency: RecurringFrequency, startDate: Date = Date(), isActive: Bool = true) {
        self.id = id
        self.amount = amount
        self.category = category
        self.description = description
        self.frequency = frequency
        self.startDate = startDate
        self.isActive = isActive
    }
}

enum RecurringFrequency: String, Codable, CaseIterable {
    case daily = "Daily"
    case weekly = "Weekly"
    case biweekly = "Biweekly"
    case monthly = "Monthly"
    case quarterly = "Quarterly"
    case yearly = "Yearly"
    
    var calendarComponent: Calendar.Component {
        switch self {
        case .daily: return .day
        case .weekly: return .weekOfYear
        case .biweekly: return .weekOfYear
        case .monthly: return .month
        case .quarterly: return .month
        case .yearly: return .year
        }
    }
    
    var componentValue: Int {
        switch self {
        case .daily: return 1
        case .weekly: return 1
        case .biweekly: return 2
        case .monthly: return 1
        case .quarterly: return 3
        case .yearly: return 1
        }
    }
}

enum Category: String, Codable, CaseIterable, Identifiable {
    case food = "Food"
    case groceries = "Groceries"
    case transportation = "Transportation"
    case housing = "Housing"
    case utilities = "Utilities"
    case entertainment = "Entertainment"
    case shopping = "Shopping"
    case healthcare = "Healthcare"
    case education = "Education"
    case subscriptions = "Subscriptions"
    case other = "Other"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .food: return "fork.knife"
        case .groceries: return "cart.fill"
        case .transportation: return "car.fill"
        case .housing: return "house.fill"
        case .utilities: return "bolt.fill"
        case .entertainment: return "tv.fill"
        case .shopping: return "bag.fill"
        case .healthcare: return "heart.fill"
        case .education: return "book.fill"
        case .subscriptions: return "repeat"
        case .other: return "square.fill"
        }
    }
} 