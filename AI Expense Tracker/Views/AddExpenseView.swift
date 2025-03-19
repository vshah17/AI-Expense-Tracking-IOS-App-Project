import SwiftUI

struct AddExpenseView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var viewModel: ExpenseViewModel
    
    @State private var description = ""
    @State private var amount = ""
    @State private var category: Category? = nil
    @State private var date = Date()
    @State private var isAnalyzing = false
    @State private var errorMessage: String?
    @State private var isKeyboardVisible = false
    
    private let gradientColors = [Color.blue.opacity(0.8), Color.purple.opacity(0.8)]
    
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
                        
                        // Description and Category Card
                        VStack(spacing: 20) {
                            VStack(spacing: 8) {
                                Text("Description")
                                    .font(.system(.subheadline, design: .rounded))
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                
                                TextField("What did you spend on?", text: $description)
                                    .font(.system(.body, design: .rounded))
                                    .textFieldStyle(PlainTextFieldStyle())
                                    .padding()
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(colorScheme == .dark ? Color(.systemGray5) : Color(.systemGray6))
                                    )
                                    .textInputAutocapitalization(.words)
                            }
                            
                            VStack(spacing: 8) {
                                Text("Category")
                                    .font(.system(.subheadline, design: .rounded))
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 12) {
                                        CategoryButton(
                                            title: "Auto",
                                            icon: "wand.and.stars",
                                            isSelected: category == nil,
                                            action: { category = nil }
                                        )
                                        
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
                            
                            VStack(spacing: 8) {
                                Text("Date")
                                    .font(.system(.subheadline, design: .rounded))
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                
                                DatePicker("", selection: $date, displayedComponents: .date)
                                    .datePickerStyle(.graphical)
                                    .padding()
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(colorScheme == .dark ? Color(.systemGray5) : Color(.systemGray6))
                                    )
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
                    .padding(.vertical)
                }
                .safeAreaInset(edge: .bottom) {
                    VStack {
                        Button(action: saveExpense) {
                            HStack {
                                if isAnalyzing {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Text("Save Expense")
                                        .font(.system(.headline, design: .rounded))
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                LinearGradient(colors: description.isEmpty || amount.isEmpty ? [.gray] : gradientColors,
                                             startPoint: .leading,
                                             endPoint: .trailing)
                            )
                            .foregroundColor(.white)
                            .cornerRadius(16)
                            .shadow(color: .blue.opacity(0.3), radius: 8, y: 4)
                        }
                        .disabled(description.isEmpty || amount.isEmpty)
                        .padding()
                    }
                    .background(.ultraThinMaterial)
                }
            }
            .navigationTitle("Add Expense")
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
        }
    }
    
    private func saveExpense() {
        guard let amountValue = Double(amount), amountValue > 0 else {
            errorMessage = "Please enter a valid amount"
            return
        }
        
        isAnalyzing = true
        
        Task {
            do {
                let finalCategory: Category
                if let selectedCategory = category {
                    finalCategory = selectedCategory
                } else {
                    let (_, analyzedCategory) = try await viewModel.analyzeExpenseDescription(description)
                    finalCategory = analyzedCategory
                }
                
                let expense = Expense(
                    amount: amountValue,
                    category: finalCategory,
                    date: date,
                    description: description
                )
                
                await MainActor.run {
                    viewModel.addExpense(expense)
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isAnalyzing = false
                }
            }
        }
    }
}

struct CategoryButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(.title3, design: .rounded))
                Text(title)
                    .font(.system(.subheadline, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(width: 90)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.blue : Color.blue.opacity(0.1))
            )
            .foregroundColor(isSelected ? .white : .blue)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    AddExpenseView()
        .environmentObject(ExpenseViewModel())
} 