//
//  ContentView.swift
//  AI Expense Tracker
//
//  Created by Vansh Shah on 3/5/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = ExpenseViewModel()
    
    var body: some View {
        TabView {
            ExpenseLogView()
                .tabItem {
                    Label("Expenses", systemImage: "list.bullet")
                }
            
            AnalyticsView()
                .tabItem {
                    Label("Analytics", systemImage: "chart.pie")
                }
            
            AIAssistantView()
                .tabItem {
                    Label("AI Assistant", systemImage: "brain")
                }
        }
        .environmentObject(viewModel)
    }
}

#Preview {
    ContentView()
}
