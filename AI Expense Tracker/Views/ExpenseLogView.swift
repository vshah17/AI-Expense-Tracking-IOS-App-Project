import SwiftUI

struct ExpenseLogView: View {
    @EnvironmentObject private var viewModel: ExpenseViewModel
    @State private var showingAddExpense = false
    @State private var showingCurrencyPicker = false
    @State private var quickInput = ""
    @State private var editingExpense: Expense?
    @State private var isProcessingQuickInput = false
    @State private var errorMessage: String?
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Total Spending Card
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Monthly Total")
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundColor(.white.opacity(0.9))
                        
                        Text(viewModel.totalExpenses(for: viewModel.selectedCategory), format: .currency(code: viewModel.currencyCode))
                            .font(.system(size: 28, weight: .bold, design: .rounded))
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
                
                // Category Filter Tabs
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        CategoryFilterTab(
                            title: "All",
                            isSelected: viewModel.selectedCategory == nil,
                            action: { viewModel.selectedCategory = nil }
                        )
                        
                        ForEach(Category.allCases, id: \.self) { category in
                            CategoryFilterTab(
                                icon: category.icon,
                                title: category.rawValue,
                                isSelected: viewModel.selectedCategory == category,
                                action: { viewModel.selectedCategory = viewModel.selectedCategory == category ? nil : category }
                            )
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 8)
                .background(colorScheme == .dark ? Color(.systemGray6) : .white)
                
                // Date Range Picker
                DateRangePicker(dateRange: $viewModel.dateRange)
                    .padding()
                
                // Expense List
                List {
                    ForEach(viewModel.filteredExpenses) { expense in
                        ExpenseRow(expense: expense)
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
                            viewModel.deleteExpense(viewModel.filteredExpenses[index])
                        }
                    }
                }
                .listStyle(.plain)
                
                // Quick Input
                VStack(spacing: 0) {
                    HStack(spacing: 12) {
                        HStack(spacing: 8) {
                            Image(systemName: "plus")
                                .font(.system(.body, design: .rounded))
                                .foregroundColor(.secondary)
                            
                            TextField("Quick add expense", text: $quickInput)
                                .font(.system(.body, design: .rounded))
                                .textInputAutocapitalization(.words)
                                .disabled(isProcessingQuickInput)
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(colorScheme == .dark ? Color(.systemGray5) : .white)
                        )
                        
                        Button(action: processQuickInput) {
                            Group {
                                if isProcessingQuickInput {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Image(systemName: "arrow.up.circle.fill")
                                        .font(.system(size: 32, design: .rounded))
                                        .symbolRenderingMode(.hierarchical)
                                }
                            }
                            .frame(width: 44, height: 44)
                        }
                        .disabled(quickInput.isEmpty || isProcessingQuickInput)
                        .foregroundColor(.blue)
                    }
                    
                    if let error = errorMessage {
                        Text(error)
                            .font(.system(.caption, design: .rounded))
                            .foregroundColor(.red)
                            .padding(.top, 8)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .edgesIgnoringSafeArea(.bottom)
                )
            }
            .navigationTitle("Expenses")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showingCurrencyPicker = true }) {
                        Text(currencySymbol)
                            .font(.system(.body, design: .rounded))
                            .foregroundColor(.white)
                            .padding(8)
                            .background(
                                Circle()
                                    .fill(Color.white.opacity(0.2))
                            )
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 12) {
                        NavigationLink(destination: BudgetView()) {
                            Image(systemName: "chart.bar.fill")
                                .font(.system(.body, design: .rounded))
                                .foregroundColor(.white)
                                .padding(8)
                                .background(
                                    Circle()
                                        .fill(Color.white.opacity(0.2))
                                )
                        }
                        
                        NavigationLink(destination: RecurringExpenseListView()) {
                            Image(systemName: "repeat.circle.fill")
                                .font(.system(.body, design: .rounded))
                                .foregroundColor(.white)
                                .padding(8)
                                .background(
                                    Circle()
                                        .fill(Color.white.opacity(0.2))
                                )
                        }
                        
                        Button(action: { showingAddExpense = true }) {
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
            }
            .sheet(isPresented: $showingAddExpense) {
                AddExpenseView()
            }
            .sheet(isPresented: $showingCurrencyPicker) {
                CurrencyPickerView()
            }
            .sheet(item: $editingExpense) { expense in
                EditExpenseView(expense: expense)
            }
        }
    }
    
    private var currencySymbol: String {
        ExpenseViewModel.availableCurrencies
            .first { $0.code == viewModel.currencyCode }?
            .symbol ?? "$"
    }
    
    private func processQuickInput() {
        guard !quickInput.isEmpty else { return }
        
        isProcessingQuickInput = true
        errorMessage = nil
        
        // Split input into components
        let components = quickInput.components(separatedBy: .whitespaces)
        
        // Extract amount - prefer numbers at the end that don't look like dates
        let amountComponent = components.reversed().first { component in
            // Skip components that look like dates (e.g., 3/10)
            guard !component.contains("/") else { return false }
            // Skip if it looks like a day number after a month name
            if let index = components.firstIndex(of: component),
               index > 0 {
                let previousWord = components[index - 1].lowercased()
                let months = ["jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec"]
                if months.contains(where: { previousWord.hasPrefix($0) }) {
                    return false
                }
            }
            return Double(component.filter { "0123456789.".contains($0) }) != nil
        }
        
        guard let amountComponent = amountComponent,
              let amount = Double(amountComponent.filter { "0123456789.".contains($0) }),
              amount > 0 else {
            errorMessage = "Please include an amount (e.g., 'Costco 126')"
            isProcessingQuickInput = false
            return
        }
        
        // Extract date if present
        var date = Date()
        var dateComponents = DateComponents()
        let calendar = Calendar.current
        
        // First try to parse numeric dates (e.g., 3/10)
        if let dateComponent = components.first(where: { $0.contains("/") }) {
            let parts = dateComponent.split(separator: "/")
            if parts.count == 2,
               let month = Int(parts[0]),
               let day = Int(parts[1]),
               month >= 1 && month <= 12,
               day >= 1 && day <= 31 {
                dateComponents.month = month
                dateComponents.day = day
                dateComponents.year = calendar.component(.year, from: Date())
                
                if let parsedDate = calendar.date(from: dateComponents) {
                    date = parsedDate
                }
            }
        } else {
            // Look for month names or abbreviations
            let months = ["jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec"]
            if let monthComponent = components.first(where: { component in
                let lowercased = component.lowercased()
                return months.contains(where: { lowercased.hasPrefix($0) })
            }) {
                let monthStr = monthComponent.lowercased().prefix(3)
                if let monthIndex = months.firstIndex(of: String(monthStr)) {
                    dateComponents.month = monthIndex + 1
                    
                    // Look for day number after month
                    if let monthWordIndex = components.firstIndex(where: { $0.lowercased().hasPrefix(monthStr) }),
                       monthWordIndex + 1 < components.count,
                       let day = Int(components[monthWordIndex + 1]) {
                        dateComponents.day = day
                    } else {
                        // If no day specified, use the first of the month
                        dateComponents.day = 1
                    }
                    
                    // Use current year
                    dateComponents.year = calendar.component(.year, from: Date())
                    
                    if let parsedDate = calendar.date(from: dateComponents) {
                        date = parsedDate
                    }
                }
            }
        }
        
        // Build description from remaining components
        let description = components
            .filter { component in
                // Exclude amount (exact match only)
                if component == amountComponent {
                    return false
                }
                
                // Exclude month names
                let lowercased = component.lowercased()
                let months = ["jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec"]
                if months.contains(where: { lowercased.hasPrefix($0) }) {
                    return false
                }
                
                // Exclude day number if it follows a month
                if let componentIndex = components.firstIndex(of: component),
                   componentIndex > 0,
                   let _ = Int(component),
                   let previousComponent = components[safe: componentIndex - 1]?.lowercased(),
                   months.contains(where: { previousComponent.hasPrefix($0) }) {
                    return false
                }
                
                // Exclude numeric dates
                if component.contains("/") {
                    return false
                }
                
                return true
            }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespaces)
        
        Task {
            do {
                let (_, category) = try await viewModel.analyzeExpenseDescription(description)
                
                await MainActor.run {
                    let expense = Expense(
                        amount: amount,
                        category: category,
                        date: date,
                        description: description
                    )
                    viewModel.addExpense(expense)
                    quickInput = ""
                    isProcessingQuickInput = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isProcessingQuickInput = false
                }
            }
        }
    }
}

struct EditExpenseView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var viewModel: ExpenseViewModel
    let expense: Expense
    
    @State private var description: String
    @State private var amount: String
    @State private var category: Category
    @State private var date: Date
    @State private var errorMessage: String?
    
    init(expense: Expense) {
        self.expense = expense
        _description = State(initialValue: expense.description)
        _amount = State(initialValue: String(format: "%.2f", expense.amount))
        _category = State(initialValue: expense.category)
        _date = State(initialValue: expense.date)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Expense Details") {
                    TextField("Description", text: $description)
                        .textInputAutocapitalization(.words)
                    
                    TextField("Amount", text: $amount)
                        .keyboardType(.decimalPad)
                    
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                    
                    Picker("Category", selection: $category) {
                        ForEach(Category.allCases, id: \.self) { category in
                            Label(category.rawValue, systemImage: category.icon)
                                .tag(category)
                        }
                    }
                }
                
                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Edit Expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveChanges()
                    }
                    .disabled(description.isEmpty || amount.isEmpty)
                }
            }
        }
    }
    
    private func saveChanges() {
        guard let amountValue = Double(amount), amountValue > 0 else {
            errorMessage = "Please enter a valid amount"
            return
        }
        
        let updatedExpense = Expense(
            id: expense.id,
            amount: amountValue,
            category: category,
            date: date,
            description: description
        )
        
        viewModel.updateExpense(updatedExpense)
        dismiss()
    }
}

struct CategoryFilterTab: View {
    let icon: String?
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    init(icon: String? = nil, title: String, isSelected: Bool, action: @escaping () -> Void) {
        self.icon = icon
        self.title = title
        self.isSelected = isSelected
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(.subheadline, design: .rounded))
                }
                Text(title)
                    .font(.system(.subheadline, design: .rounded))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(isSelected ? Color.blue : Color.blue.opacity(0.1))
            )
            .foregroundColor(isSelected ? .white : .blue)
        }
        .buttonStyle(.plain)
    }
}

struct DateRangePicker: View {
    @EnvironmentObject private var viewModel: ExpenseViewModel
    @Binding var dateRange: ClosedRange<Date>?
    @State private var startDate: Date
    @State private var endDate: Date
    
    init(dateRange: Binding<ClosedRange<Date>?>) {
        self._dateRange = dateRange
        self._startDate = State(initialValue: Date())
        self._endDate = State(initialValue: Date())
    }
    
    private var earliestDate: Date {
        viewModel.expenses.min { $0.date < $1.date }?.date ?? Date()
    }
    
    private var latestDate: Date {
        viewModel.expenses.max { $0.date < $1.date }?.date ?? Date()
    }
    
    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 4) {
                Text("Start")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundColor(.secondary)
                Text(startDate.formatted(date: .abbreviated, time: .omitted))
                    .font(.system(.body, design: .rounded))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray6))
            )
            .overlay {
                DatePicker("", selection: $startDate, displayedComponents: .date)
                    .labelsHidden()
                    .blendMode(.destinationOver)
            }
            
            Text("to")
                .font(.system(.subheadline, design: .rounded))
                .foregroundColor(.secondary)
            
            HStack(spacing: 4) {
                Text("End")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundColor(.secondary)
                Text(endDate.formatted(date: .abbreviated, time: .omitted))
                    .font(.system(.body, design: .rounded))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray6))
            )
            .overlay {
                DatePicker("", selection: $endDate, displayedComponents: .date)
                    .labelsHidden()
                    .blendMode(.destinationOver)
            }
        }
        .onChange(of: startDate) { _ in updateRange() }
        .onChange(of: endDate) { _ in updateRange() }
        .onChange(of: viewModel.expenses) { _ in
            let latest = latestDate
            if latest > endDate {
                endDate = latest
                updateRange()
            }
        }
        .onAppear {
            if dateRange == nil {
                startDate = earliestDate
                endDate = latestDate
                updateRange()
            } else if let range = dateRange {
                startDate = range.lowerBound
                endDate = range.upperBound
            }
        }
    }
    
    private func updateRange() {
        if startDate > endDate {
            endDate = startDate
        }
        dateRange = startDate...endDate
    }
}

struct CurrencyPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var viewModel: ExpenseViewModel
    
    var body: some View {
        NavigationView {
            List {
                ForEach(ExpenseViewModel.availableCurrencies, id: \.code) { currency in
                    Button(action: {
                        viewModel.setCurrency(currency.code)
                        dismiss()
                    }) {
                        HStack {
                            Text(currency.symbol)
                                .font(.system(.body, design: .rounded))
                                .foregroundColor(.blue)
                            
                            Text(currency.name)
                            
                            Spacer()
                            
                            if viewModel.currencyCode == currency.code {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Select Currency")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct ExpenseRow: View {
    let expense: Expense
    @EnvironmentObject private var viewModel: ExpenseViewModel
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(expense.description)
                    .font(.system(.body, design: .rounded))
                    .foregroundColor(.primary)
                
                HStack {
                    Label(expense.category.rawValue, systemImage: expense.category.icon)
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundColor(.secondary)
                    
                    Text(expense.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Text(expense.amount, format: .currency(code: viewModel.currencyCode))
                .font(.system(.headline, design: .rounded))
                .foregroundColor(.primary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    ExpenseLogView()
        .environmentObject(ExpenseViewModel())
}

// Add extension for safe array access
extension Array {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
} 