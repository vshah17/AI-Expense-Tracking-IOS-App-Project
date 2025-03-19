import SwiftUI

struct BudgetView: View {
    @EnvironmentObject private var viewModel: ExpenseViewModel
    @Environment(\.colorScheme) private var colorScheme
    @State private var editingCategory: Category?
    @State private var editingAmount: String = ""
    
    private let gradientColors = [Color.blue.opacity(0.8), Color.purple.opacity(0.8)]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Total Budget Card
                let totalBudget = Category.allCases.reduce(0.0) { $0 + viewModel.getBudget(for: $1) }
                let totalSpent = Category.allCases.reduce(0.0) { $0 + viewModel.totalExpenses(for: $1) }
                
                VStack(spacing: 12) {
                    VStack(spacing: 8) {
                        Text("Total Budget")
                            .font(.system(.headline, design: .rounded))
                            .foregroundColor(.white.opacity(0.9))
                        
                        Text(totalBudget, format: .currency(code: viewModel.currencyCode))
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                    
                    VStack(spacing: 8) {
                        HStack {
                            Text("Spent")
                                .font(.system(.subheadline, design: .rounded))
                                .foregroundColor(.white.opacity(0.9))
                            Spacer()
                            Text(totalSpent, format: .currency(code: viewModel.currencyCode))
                                .font(.system(.subheadline, design: .rounded))
                                .foregroundColor(.white)
                        }
                        
                        ProgressView(value: totalBudget > 0 ? min(totalSpent / totalBudget, 1.0) : 0)
                            .tint(.white)
                    }
                }
                .padding()
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: gradientColors),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .blue.opacity(0.3), radius: 8, y: 4)
                
                // Category Budgets
                VStack(alignment: .leading, spacing: 20) {
                    Text("Category Budgets")
                        .font(.system(.headline, design: .rounded))
                    
                    ForEach(Category.allCases, id: \.self) { category in
                        BudgetRow(
                            category: category,
                            onEditBudget: { category in
                                editingAmount = String(format: "%.2f", viewModel.getBudget(for: category))
                                editingCategory = category
                            }
                        )
                        
                        if category != Category.allCases.last {
                            Divider()
                                .opacity(0.5)
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
            .padding()
        }
        .navigationTitle("Budgets")
        .sheet(item: $editingCategory) { category in
            NavigationView {
                VStack(spacing: 24) {
                    // Category Header
                    VStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(Color.blue.opacity(0.1))
                                .frame(width: 80, height: 80)
                            
                            Image(systemName: category.icon)
                                .font(.system(size: 32))
                                .foregroundColor(.blue)
                        }
                        
                        Text(category.rawValue)
                            .font(.system(.title2, design: .rounded))
                    }
                    .padding(.top)
                    
                    // Budget Input
                    VStack(spacing: 8) {
                        Text("Monthly Budget")
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        HStack(alignment: .center) {
                            Text(viewModel.currencyCode)
                                .font(.system(.title3, design: .rounded))
                                .foregroundColor(.secondary)
                            
                            TextField("0.00", text: $editingAmount)
                                .font(.system(size: 34, weight: .bold, design: .rounded))
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.leading)
                                .minimumScaleFactor(0.5)
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(colorScheme == .dark ? Color(.systemGray5) : Color(.systemGray6))
                        )
                    }
                    .padding(.horizontal)
                    
                    if let amount = Double(editingAmount), amount > 0 {
                        // Budget Statistics
                        VStack(spacing: 16) {
                            let spent = viewModel.totalExpenses(for: category)
                            let remaining = amount - spent
                            let progress = spent / amount
                            
                            VStack(spacing: 8) {
                                HStack {
                                    Text("Monthly Progress")
                                        .font(.system(.subheadline, design: .rounded))
                                    Spacer()
                                    Text(progress, format: .percent)
                                        .font(.system(.subheadline, design: .rounded))
                                }
                                
                                ProgressView(value: min(progress, 1.0))
                                    .tint(progress > 1.0 ? .red : .blue)
                            }
                            
                            HStack {
                                StatisticView(
                                    title: "Spent",
                                    value: spent,
                                    color: .blue
                                )
                                
                                StatisticView(
                                    title: "Remaining",
                                    value: remaining,
                                    color: remaining >= 0 ? .green : .red
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
                    
                    Spacer()
                }
                .navigationTitle("Set Budget")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            editingCategory = nil
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            if let amount = Double(editingAmount), amount > 0 {
                                viewModel.setBudget(for: category, amount: amount)
                            }
                            editingCategory = nil
                        }
                        .disabled(Double(editingAmount) ?? 0 <= 0)
                    }
                }
            }
        }
    }
}

struct BudgetRow: View {
    @EnvironmentObject private var viewModel: ExpenseViewModel
    let category: Category
    let onEditBudget: (Category) -> Void
    
    var body: some View {
        let budget = viewModel.getBudget(for: category)
        let spent = viewModel.totalExpenses(for: category)
        let progress = viewModel.getBudgetProgress(for: category)
        
        Button(action: { onEditBudget(category) }) {
            VStack(spacing: 12) {
                HStack {
                    // Category Icon
                    ZStack {
                        Circle()
                            .fill(Color.blue.opacity(0.1))
                            .frame(width: 40, height: 40)
                        
                        Image(systemName: category.icon)
                            .font(.system(.body, design: .rounded))
                            .foregroundColor(.blue)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(category.rawValue)
                            .font(.system(.body, design: .rounded))
                        
                        if budget > 0 {
                            Text(budget, format: .currency(code: viewModel.currencyCode))
                                .font(.system(.subheadline, design: .rounded))
                                .foregroundColor(.secondary)
                        } else {
                            Text("Set budget")
                                .font(.system(.subheadline, design: .rounded))
                                .foregroundColor(.blue)
                        }
                    }
                    
                    Spacer()
                    
                    if budget > 0 {
                        // Budget Progress
                        VStack(alignment: .trailing, spacing: 4) {
                            Text(spent, format: .currency(code: viewModel.currencyCode))
                                .font(.system(.body, design: .rounded))
                            
                            Text(progress, format: .percent)
                                .font(.system(.caption, design: .rounded))
                                .foregroundColor(progress > 1.0 ? .red : .secondary)
                        }
                    }
                }
                
                if budget > 0 {
                    ProgressView(value: min(progress, 1.0))
                        .tint(progress > 1.0 ? .red : .blue)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

struct StatisticView: View {
    @EnvironmentObject private var viewModel: ExpenseViewModel
    let title: String
    let value: Double
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.system(.subheadline, design: .rounded))
                .foregroundColor(.secondary)
            
            Text(value, format: .currency(code: viewModel.currencyCode))
                .font(.system(.headline, design: .rounded))
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    NavigationView {
        BudgetView()
            .environmentObject(ExpenseViewModel())
    }
}

extension View {
    func findParentView<T: View>(ofType type: T.Type) -> T? {
        var currentView: UIView? = UIView.getParentViewController()?.view
        while let view = currentView {
            if let targetView = view.findSwiftUIView(ofType: type) {
                return targetView
            }
            currentView = view.superview
        }
        return nil
    }
}

extension UIView {
    static func getParentViewController() -> UIViewController? {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootViewController = window.rootViewController else {
            return nil
        }
        return rootViewController
    }
    
    func findSwiftUIView<T: View>(ofType type: T.Type) -> T? {
        for subview in subviews {
            if let hostingView = subview as? UIHostingController<T> {
                return hostingView.rootView
            }
            if let found = subview.findSwiftUIView(ofType: type) {
                return found
            }
        }
        return nil
    }
} 