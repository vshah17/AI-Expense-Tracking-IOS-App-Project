import SwiftUI
import Charts

struct AnalyticsView: View {
    @EnvironmentObject private var viewModel: ExpenseViewModel
    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedTimeFrame: TimeFrame = .month
    @State private var selectedDate = Date()
    
    private let gradientColors = [Color.blue.opacity(0.8), Color.purple.opacity(0.8)]
    
    var filteredTotal: Double {
        let allExpenses = viewModel.totalExpenses(for: nil, in: selectedTimeFrame, for: selectedDate)
        let excludedAmount = viewModel.expensesByCategory(in: selectedTimeFrame, for: selectedDate)
            .filter { viewModel.excludedCategories.contains($0.0) }
            .reduce(0.0) { $0 + $1.1 }
        return allExpenses - excludedAmount
    }
    
    var filteredCategories: [(Category, Double)] {
        viewModel.expensesByCategory(in: selectedTimeFrame, for: selectedDate)
            .filter { !viewModel.excludedCategories.contains($0.0) }
    }
    
    var filteredRecurringExpenses: [(Category, Double)] {
        viewModel.recurringExpensesByCategory()
            .filter { !viewModel.excludedCategories.contains($0.0) }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Time Frame and Date Navigation - Fixed at top
                VStack(spacing: 16) {
                    // Time Frame Picker
                    Picker("Time Frame", selection: $selectedTimeFrame) {
                        ForEach(TimeFrame.allCases, id: \.self) { timeFrame in
                            Text(timeFrame.rawValue).tag(timeFrame)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: selectedTimeFrame) { _ in
                        selectedDate = Date()
                    }
                    
                    // Date Navigation
                    HStack {
                        Button(action: previousPeriod) {
                            Image(systemName: "chevron.left.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.blue)
                        }
                        
                        Spacer()
                        
                        Text(periodTitle)
                            .font(.system(.headline, design: .rounded))
                        
                        Spacer()
                        
                        Button(action: nextPeriod) {
                            Image(systemName: "chevron.right.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.blue)
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
                .padding(.top)
                .padding(.bottom, 10)
            // Background Gradient
            .background(
                LinearGradient(
                    gradient: Gradient(colors: gradientColors),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
                
                // Scrollable Content
                ScrollView {
                    VStack(spacing: 24) {
                        // Category Breakdown
                        CategoryBreakdownView(
                            expenses: viewModel.expensesByCategory(in: selectedTimeFrame, for: selectedDate),
                            filteredExpenses: filteredCategories,
                            total: filteredTotal
                        )
                        .padding(.horizontal)
                        
                        // Recurring Expenses
                        RecurringExpensesView(expenses: filteredRecurringExpenses)
                            .padding(.horizontal)
                        
                        // Spending Trend
                        SpendingTrendView(
                            expenses: viewModel.expenses,
                            timeFrame: selectedTimeFrame,
                            selectedDate: selectedDate,
                            excludedCategories: viewModel.excludedCategories
                        )
                        .padding(.horizontal)
                        .padding(.bottom)
                    }
                    .padding(.top)
                }
            }
            .navigationTitle("Analytics")
            .background(Color(.systemGroupedBackground))
        }
    }
    
    private var periodTitle: String {
        let formatter = DateFormatter()
        switch selectedTimeFrame {
        case .week:
            let calendar = Calendar.current
            let weekInterval = calendar.dateInterval(of: .weekOfYear, for: selectedDate)!
            formatter.dateFormat = "MMM d"
            return "\(formatter.string(from: weekInterval.start)) - \(formatter.string(from: weekInterval.end.addingTimeInterval(-1)))"
        case .month:
            formatter.dateFormat = "MMMM yyyy"
            return formatter.string(from: selectedDate)
        case .year:
            formatter.dateFormat = "yyyy"
            return formatter.string(from: selectedDate)
        }
    }
    
    private func previousPeriod() {
        let calendar = Calendar.current
        switch selectedTimeFrame {
        case .week:
            selectedDate = calendar.date(byAdding: .weekOfYear, value: -1, to: selectedDate)!
        case .month:
            selectedDate = calendar.date(byAdding: .month, value: -1, to: selectedDate)!
        case .year:
            selectedDate = calendar.date(byAdding: .year, value: -1, to: selectedDate)!
        }
    }
    
    private func nextPeriod() {
        let calendar = Calendar.current
        let now = Date()
        var nextDate: Date
        
        switch selectedTimeFrame {
        case .week:
            nextDate = calendar.date(byAdding: .weekOfYear, value: 1, to: selectedDate)!
        case .month:
            nextDate = calendar.date(byAdding: .month, value: 1, to: selectedDate)!
        case .year:
            nextDate = calendar.date(byAdding: .year, value: 1, to: selectedDate)!
        }
        
        if nextDate <= now {
            selectedDate = nextDate
        }
    }
}

struct TotalSpendingCard: View {
    @EnvironmentObject private var viewModel: ExpenseViewModel
    @Environment(\.colorScheme) private var colorScheme
    let total: Double
    
    var body: some View {
        VStack(spacing: 8) {
            Text("Total Spending")
                .font(.system(.headline, design: .rounded))
                .foregroundColor(.white.opacity(0.9))
            
            Text(total, format: .currency(code: viewModel.currencyCode))
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            LinearGradient(
                gradient: Gradient(colors: [Color.blue.opacity(0.8), Color.purple.opacity(0.8)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .blue.opacity(0.3), radius: 8, y: 4)
    }
}

struct CategoryBreakdownView: View {
    @EnvironmentObject private var viewModel: ExpenseViewModel
    @Environment(\.colorScheme) private var colorScheme
    let expenses: [(Category, Double)]
    let filteredExpenses: [(Category, Double)]
    let total: Double
    
    private let colors: [Color] = [
        .blue, .green, .orange, .purple, .red,
        .yellow, .pink, .mint, .indigo, .cyan
    ]
    
    private func colorIndex(for category: Category) -> Int {
        if let index = expenses.firstIndex(where: { $0.0 == category }) {
            return index % colors.count
        }
        return 0
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Category Breakdown")
                .font(.system(.title3, design: .rounded))
                .fontWeight(.medium)
            
            if expenses.isEmpty {
                Text("No expenses in this time frame")
                    .font(.system(.body, design: .rounded))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                VStack(spacing: 24) {
                    // Pie Chart
                    ZStack {
                        Chart(filteredExpenses, id: \.0) { category, amount in
                            SectorMark(
                                angle: .value("Amount", amount),
                                innerRadius: .ratio(0.618),
                                angularInset: 1.5
                            )
                            .foregroundStyle(colors[colorIndex(for: category)])
                            .opacity(0.8)
                        }
                        
                        VStack(spacing: 4) {
                            Text("Total")
                                .font(.system(.title3, design: .rounded))
                                .foregroundColor(.primary)
                            Text(total, format: .currency(code: viewModel.currencyCode))
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)
                                .contentTransition(.numericText())
                                .multilineTextAlignment(.center)
                        }
                        .padding(.horizontal)
                    }
                    .frame(height: 250)
                    
                    // Category List
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(expenses.enumerated()), id: \.element.0) { index, expense in
                            Button(action: {
                                if viewModel.excludedCategories.contains(expense.0) {
                                    viewModel.excludedCategories.remove(expense.0)
                                } else {
                                    viewModel.excludedCategories.insert(expense.0)
                                }
                            }) {
                                HStack(spacing: 12) {
                                    // Category Icon and Color
                                    ZStack {
                                        Circle()
                                            .fill(colors[index % colors.count])
                                            .frame(width: 36, height: 36)
                                            .opacity(viewModel.excludedCategories.contains(expense.0) ? 0.3 : 0.8)
                                        
                                        Image(systemName: expense.0.icon)
                                            .font(.system(.body, design: .rounded))
                                            .foregroundColor(.white)
                                    }
                                    
                                    // Category Details
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(expense.0.rawValue)
                                            .font(.system(.body, design: .rounded))
                                        
                                        let budget = viewModel.getBudget(for: expense.0)
                                        if budget > 0 {
                                            let progress = viewModel.getBudgetProgress(for: expense.0)
                                            ProgressView(value: min(progress, 1.0))
                                                .tint(progress > 1.0 ? .red : colors[index % colors.count])
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    // Amount and Budget
                                    VStack(alignment: .trailing, spacing: 4) {
                                        Text(expense.1, format: .currency(code: viewModel.currencyCode))
                                            .font(.system(.body, design: .rounded))
                                            .contentTransition(.numericText())
                                        
                                        let budget = viewModel.getBudget(for: expense.0)
                                        if budget > 0 {
                                            Text(budget, format: .currency(code: viewModel.currencyCode))
                                                .font(.system(.caption, design: .rounded))
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    
                                    Image(systemName: viewModel.excludedCategories.contains(expense.0) ? "eye.slash" : "eye.fill")
                                        .foregroundColor(.secondary)
                                        .font(.system(.subheadline, design: .rounded))
                                }
                                .foregroundColor(viewModel.excludedCategories.contains(expense.0) ? .secondary : .primary)
                                .padding(.vertical, 4)
                            }
                            
                            if index < expenses.count - 1 {
                                Divider()
                                    .opacity(0.5)
                            }
                        }
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
    }
}

struct RecurringExpensesView: View {
    @EnvironmentObject private var viewModel: ExpenseViewModel
    let expenses: [(Category, Double)]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Monthly Recurring Expenses")
                .font(.headline)
            
            if expenses.isEmpty {
                Text("No recurring expenses")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                VStack(spacing: 12) {
                    ForEach(expenses, id: \.0) { category, amount in
                        HStack {
                            Image(systemName: category.icon)
                                .foregroundColor(.blue)
                                .frame(width: 24)
                            Text(category.rawValue)
                            Spacer()
                            Text(amount, format: .currency(code: viewModel.currencyCode))
                                .bold()
                        }
                        .padding(.vertical, 4)
                    }
                    
                    Divider()
                    
                    HStack {
                        Text("Total Monthly")
                            .font(.headline)
                        Spacer()
                        Text(expenses.reduce(0) { $0 + $1.1 }, format: .currency(code: viewModel.currencyCode))
                            .font(.headline)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

struct RecurringExpenseListView: View {
    @EnvironmentObject private var viewModel: ExpenseViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showingAddSheet = false
    @State private var editingExpense: RecurringExpense?
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(spacing: 0) {
            // Header Card
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Monthly Total")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundColor(.white.opacity(0.9))
                    
                    let monthlyTotal = viewModel.recurringExpensesByCategory()
                        .reduce(0.0) { $0 + $1.1 }
                    Text(monthlyTotal, format: .currency(code: viewModel.currencyCode))
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                Spacer()
            }
            .padding(.vertical, 12)
            .padding(.horizontal)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [Color.blue.opacity(0.8), Color.purple.opacity(0.8)]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            
            List {
                ForEach(viewModel.recurringExpenses) { expense in
                    RecurringExpenseRow(expense: expense)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            editingExpense = expense
                        }
                        .listRowBackground(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(colorScheme == .dark ? Color(.systemGray6) : .white)
                                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                                .padding(.vertical, 4)
                        )
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        viewModel.deleteRecurringExpense(viewModel.recurringExpenses[index])
                    }
                }
            }
            .listStyle(.plain)
        }
        .navigationTitle("Recurring Expenses")
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { dismiss() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(.body, design: .rounded))
                        Text("Expenses")
                            .font(.system(.body, design: .rounded))
                    }
                    .foregroundColor(.white)
                    .padding(8)
                    .background(Color.white.opacity(0.2))
                    .clipShape(Capsule())
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showingAddSheet = true }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(.body, design: .rounded))
                        .foregroundColor(.white)
                        .padding(8)
                        .background(
                            Circle()
                                .fill(Color.white.opacity(0.2))
                        )
                }
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            RecurringExpenseFormView(mode: .add)
        }
        .sheet(item: $editingExpense) { expense in
            RecurringExpenseFormView(mode: .edit(expense))
        }
    }
}

struct RecurringExpenseRow: View {
    @EnvironmentObject private var viewModel: ExpenseViewModel
    let expense: RecurringExpense
    
    var body: some View {
        HStack(spacing: 12) {
            // Category Icon
            Image(systemName: expense.category.icon)
                .font(.system(.title2, design: .rounded))
                .foregroundColor(.blue)
                .frame(width: 32, height: 32)
                .padding(8)
                .background(
                    Circle()
                        .fill(Color.blue.opacity(0.1))
                )
            
            // Description and Details
            VStack(alignment: .leading, spacing: 4) {
                Text(expense.description)
                    .font(.system(.body, design: .rounded))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    HStack(spacing: 4) {
                        Image(systemName: expense.category.icon)
                            .font(.system(.subheadline, design: .rounded))
                        Text(expense.category.rawValue)
                            .font(.system(.subheadline, design: .rounded))
                            .lineLimit(1)
                    }
                    .foregroundColor(.secondary)
                    
                    Text("•")
                        .foregroundColor(.secondary)
                    
                    Text(expense.frequency.rawValue)
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            Spacer()
            
            // Amount and Status
            VStack(alignment: .trailing, spacing: 4) {
                Text(expense.amount, format: .currency(code: viewModel.currencyCode))
                    .font(.system(.headline, design: .rounded))
                    .foregroundColor(.primary)
                
                if !expense.isActive {
                    Text("Paused")
                        .font(.system(.caption, design: .rounded))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(Color.secondary.opacity(0.1))
                        )
                }
            }
        }
        .padding(.vertical, 8)
    }
}

enum RecurringExpenseFormMode {
    case add
    case edit(RecurringExpense)
}

struct RecurringExpenseFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var viewModel: ExpenseViewModel
    
    let mode: RecurringExpenseFormMode
    
    @State private var description = ""
    @State private var amount = ""
    @State private var category: Category? = nil
    @State private var frequency = RecurringFrequency.monthly
    @State private var startDate = Date()
    @State private var isActive = true
    @State private var isAnalyzing = false
    @State private var errorMessage: String?
    
    private let gradientColors = [Color.blue.opacity(0.8), Color.purple.opacity(0.8)]
    
    init(mode: RecurringExpenseFormMode) {
        self.mode = mode
        if case .edit(let expense) = mode {
            _description = State(initialValue: expense.description)
            _amount = State(initialValue: String(format: "%.2f", expense.amount))
            _category = State(initialValue: expense.category)
            _frequency = State(initialValue: expense.frequency)
            _startDate = State(initialValue: expense.startDate)
            _isActive = State(initialValue: expense.isActive)
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                ScrollView {
                    VStack(spacing: 24) {
                        // Amount Input Card
                        VStack(spacing: 8) {
                            Text("Amount")
                                .font(.system(.subheadline, design: .rounded))
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            HStack(alignment: .center) {
                                Text(viewModel.currencyCode)
                                    .font(.system(.title3, design: .rounded))
                                    .foregroundColor(.secondary)
                                
                                TextField("0.00", text: $amount)
                                    .font(.system(size: 34, weight: .bold, design: .rounded))
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.leading)
                                    .minimumScaleFactor(0.5)
                            }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(colorScheme == .dark ? Color(.systemGray6) : .white)
                                .shadow(color: .black.opacity(0.05), radius: 8)
                        )
                        .padding(.horizontal)
                        
                        // Details Card
                        VStack(spacing: 20) {
                            // Description
                            VStack(spacing: 8) {
                                Text("Description")
                                    .font(.system(.subheadline, design: .rounded))
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                
                                TextField("What is this recurring expense for?", text: $description)
                                    .font(.system(.body, design: .rounded))
                                    .textFieldStyle(PlainTextFieldStyle())
                                    .padding()
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(colorScheme == .dark ? Color(.systemGray5) : Color(.systemGray6))
                                    )
                                    .textInputAutocapitalization(.words)
                            }
                            
                            // Category
                            VStack(spacing: 8) {
                                Text("Category")
                                    .font(.system(.subheadline, design: .rounded))
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 12) {
                                        ForEach(Category.allCases, id: \.self) { cat in
                                            CategoryButton(
                                                title: cat.rawValue,
                                                icon: cat.icon,
                                                isSelected: category == cat,
                                                action: { category = cat }
                                            )
                                        }
                                    }
                                    .padding(.horizontal, 4)
                                }
                            }
                            
                            // Frequency
                            VStack(spacing: 8) {
                                Text("Frequency")
                                    .font(.system(.subheadline, design: .rounded))
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(RecurringFrequency.allCases, id: \.self) { freq in
                                            Button(action: { frequency = freq }) {
                                                Text(freq.rawValue)
                                                    .font(.system(.subheadline, design: .rounded))
                                                    .padding(.horizontal, 12)
                                                    .padding(.vertical, 8)
                                                    .background(
                                                        Capsule()
                                                            .fill(frequency == freq ? Color.blue : Color.blue.opacity(0.1))
                                                    )
                                                    .foregroundColor(frequency == freq ? .white : .blue)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                    .padding(.horizontal, 4)
                                }
                            }
                            
                            // Start Date
                            VStack(spacing: 8) {
                                Text("Start Date")
                                    .font(.system(.subheadline, design: .rounded))
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                
                                DatePicker("", selection: $startDate, displayedComponents: .date)
                                    .datePickerStyle(.graphical)
                                    .padding()
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(colorScheme == .dark ? Color(.systemGray5) : Color(.systemGray6))
                                    )
                            }
                            
                            // Active Toggle
                            Toggle(isOn: $isActive) {
                                HStack {
                                    Image(systemName: isActive ? "checkmark.circle.fill" : "circle")
                                        .foregroundColor(isActive ? .blue : .secondary)
                                    Text("Active")
                                        .font(.system(.body, design: .rounded))
                                }
                            }
                            .tint(.blue)
                            .padding(.vertical, 8)
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(colorScheme == .dark ? Color(.systemGray6) : .white)
                                .shadow(color: .black.opacity(0.05), radius: 8)
                        )
                        .padding(.horizontal)
                    }
                    .padding(.vertical)
                }
                .safeAreaInset(edge: .bottom) {
                    VStack {
                        Button(action: save) {
                            HStack {
                                if isAnalyzing {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Text(mode.isAdd ? "Add Recurring" : "Save Changes")
                                        .font(.system(.headline, design: .rounded))
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                LinearGradient(colors: description.isEmpty || amount.isEmpty || category == nil ? [.gray] : gradientColors,
                                             startPoint: .leading,
                                             endPoint: .trailing)
                            )
                            .foregroundColor(.white)
                            .cornerRadius(16)
                            .shadow(color: .blue.opacity(0.3), radius: 8, y: 4)
                        }
                        .disabled(description.isEmpty || amount.isEmpty || category == nil)
                        .padding()
                    }
                    .background(.ultraThinMaterial)
                }
            }
            .navigationTitle(mode.isAdd ? "Add Recurring" : "Edit Recurring")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") {
                    errorMessage = nil
                }
            } message: {
                if let error = errorMessage {
                    Text(error)
                }
            }
            .background(Color(.systemGroupedBackground))
        }
    }
    
    private func save() {
        guard let amountValue = Double(amount), amountValue > 0 else {
            errorMessage = "Please enter a valid amount"
            return
        }
        
        guard let selectedCategory = category else {
            errorMessage = "Please select a category"
            return
        }
        
        let expense = RecurringExpense(
            id: mode.isEdit ? mode.editingExpense.id : UUID(),
            amount: amountValue,
            category: selectedCategory,
            description: description,
            frequency: frequency,
            startDate: startDate,
            isActive: isActive
        )
        
        if mode.isAdd {
            viewModel.addRecurringExpense(expense)
        } else {
            viewModel.updateRecurringExpense(expense)
        }
        
        dismiss()
    }
}

extension RecurringExpenseFormMode {
    var isAdd: Bool {
        if case .add = self { return true }
        return false
    }
    
    var isEdit: Bool {
        if case .edit = self { return true }
        return false
    }
    
    var editingExpense: RecurringExpense {
        if case .edit(let expense) = self { return expense }
        fatalError("Not in edit mode")
    }
}

struct SpendingTrendView: View {
    let expenses: [Expense]
    let timeFrame: TimeFrame
    let selectedDate: Date
    let excludedCategories: Set<Category>
    
    var filteredExpenses: [Expense] {
        expenses.filter { !excludedCategories.contains($0.category) }
    }
    
    var trendData: [(Date, Double)] {
        let calendar = Calendar.current
        
        switch timeFrame {
        case .week:
            // Get start of the selected week
            let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: selectedDate))!
            
            // Create array of last 5 weeks
            let weekStarts = (0..<5).map { weeks in
                calendar.date(byAdding: .weekOfYear, value: -weeks, to: weekStart)!
            }.reversed()
            
            return weekStarts.map { date in
                let weekEnd = calendar.date(byAdding: .weekOfYear, value: 1, to: date)!
                let weekExpenses = filteredExpenses.filter { expense in
                    expense.date >= date && expense.date < weekEnd
                }
                return (date, weekExpenses.reduce(0) { $0 + $1.amount })
            }
            
        case .month:
            // Get start of the selected month
            let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: selectedDate))!
            
            // Create array of last 5 months
            let monthStarts = (0..<5).map { months in
                calendar.date(byAdding: .month, value: -months, to: monthStart)!
            }.reversed()
            
            return monthStarts.map { date in
                let monthEnd = calendar.date(byAdding: .month, value: 1, to: date)!
                let monthExpenses = filteredExpenses.filter { expense in
                    expense.date >= date && expense.date < monthEnd
                }
                return (date, monthExpenses.reduce(0) { $0 + $1.amount })
            }
            
        case .year:
            // Get start of the selected year
            let yearStart = calendar.date(from: calendar.dateComponents([.year], from: selectedDate))!
            
            // Create array of last 5 years
            let yearStarts = (0..<5).map { years in
                calendar.date(byAdding: .year, value: -years, to: yearStart)!
            }.reversed()
            
            return yearStarts.map { date in
                let yearEnd = calendar.date(byAdding: .year, value: 1, to: date)!
                let yearExpenses = filteredExpenses.filter { expense in
                    expense.date >= date && expense.date < yearEnd
                }
                return (date, yearExpenses.reduce(0) { $0 + $1.amount })
            }
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Spending Trend")
                .font(.headline)
            
            if trendData.isEmpty {
                Text("No expenses in this time frame")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                Chart(trendData, id: \.0) { item in
                    LineMark(
                        x: .value("Date", formattedDate(item.0)),
                        y: .value("Amount", item.1)
                    )
                    .foregroundStyle(Color.blue)
                    
                    PointMark(
                        x: .value("Date", formattedDate(item.0)),
                        y: .value("Amount", item.1)
                    )
                    .foregroundStyle(Color.blue)
                }
                .chartXAxis {
                    AxisMarks(values: .automatic) { value in
                        AxisValueLabel {
                            if let date = value.as(String.self) {
                                Text(date)
                                    .font(.caption)
                                    .rotationEffect(.degrees(-45))
                            }
                        }
                    }
                }
                .frame(height: 200)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        switch timeFrame {
        case .week:
            formatter.dateFormat = "MMM d"
        case .month:
            formatter.dateFormat = "MMM"
        case .year:
            formatter.dateFormat = "yyyy"
        }
        return formatter.string(from: date)
    }
}

#Preview {
    let viewModel = ExpenseViewModel()
    
    // Add sample data for preview
    let sampleExpenses = [
        Expense(amount: 50.0, category: .groceries, description: "Groceries"),
        Expense(amount: 30.0, category: .entertainment, description: "Movies"),
        Expense(amount: 25.0, category: .transportation, description: "Gas")
    ]
    
    for expense in sampleExpenses {
        viewModel.addExpense(expense)
    }
    
    return AnalyticsView()
        .environmentObject(viewModel)
} 