//
//  FlekstoreAppsListView.swift
//  LiveContainer
//
//  Created by Alexander Grigoryev on 30.09.2025.
//

import SwiftUI

// MARK: - View
// FlekstoreAppsListView.swift
import SwiftUI
import Kingfisher

struct FlekstoreAppsListView: View {
    @StateObject private var viewModel = FlekstoreAppsListViewModel()
    @Binding var selectedTab: Int
    
    @State private var showRepositorySheet = false
    @State private var showPremiumRequiredSheet = false
    @State private var repos: [AppRepository] = []
    @State private var udid = Bundle.main.object(forInfoDictionaryKey: "UDID") as? String
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                
                RepositoryPicker(
                    repositories: $repos,
                    showSheet: $showRepositorySheet,
                    onSelect: { repo in
                        switchRepository(repo)
                    }
                )
                .padding(.vertical , 2)
                .padding(.horizontal)
                
                if (viewModel.repository == .flekstore)
                {
                    // Categories
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: 8) {
                            CategoryButton(
                                title: "Updates",
                                isSelected: viewModel.selectedCategoryID == nil
                            ) {
                                viewModel.selectCategory(nil)
                            }
                            
                            CategoryButton(
                                title: "Top",
                                isSelected: viewModel.selectedCategoryID == "downloads"
                            ) {
                                viewModel.selectCategory("downloads")
                            }
                            
                            ForEach(viewModel.categories) { cat in
                                CategoryButton(
                                    title: cat.name,
                                    isSelected: viewModel.selectedCategoryID == cat.id
                                ) {
                                    viewModel.selectCategory(cat.id)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    .frame(height: 44)
                }
                // Content
                Group {
                    if viewModel.apps.isEmpty && viewModel.isLoading {
                        ProgressView("Loading apps…")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if let error = viewModel.errorMessage {
                        VStack(spacing: 12) {
                            Text(error)
                                .foregroundColor(.red)
                            
                            Button("Retry") {
                                Task { await viewModel.resetAndFetchApps() }
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        List {
                            ForEach(viewModel.visibleApps) { app in
                                AppRow(
                                    app: app,
                                    selectedTab: $selectedTab,
                                    isCustomRepository: (viewModel.repository != .flekstore),
                                    hasSubscription: viewModel.hasSubscription,
                                    onPremiumRequired: {
                                        showPremiumRequiredSheet = true
                                    }
                                )
                                .onAppear {
                                    if app == viewModel.apps.last {
                                        Task { await viewModel.fetchApps() }
                                    }
                                }
                            }
                            
                            if viewModel.isLoading {
                                HStack {
                                    Spacer()
                                    ProgressView()
                                    Spacer()
                                }
                            }
                        }
                        .listStyle(.plain)
                        .refreshable {
                            Task { await viewModel.resetAndFetchApps() }
                        }
                    }
                }
            }
            .searchable(
                text: $viewModel.searchQuery,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Search by app name"
            )
            .onChange(of: viewModel.searchQuery) { _ in
                if viewModel.repository == .flekstore {
                    Task { await viewModel.resetAndFetchApps() }
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if viewModel.repository != .flekstore && !viewModel.hasSubscription {
                        Text("Premium required")
                            .font(.caption.bold())
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.orange.opacity(0.15))
                            .foregroundColor(.orange)
                            .clipShape(Capsule())
                    }
                }
            }
            .sheet(isPresented: $showRepositorySheet) {
                AppRepositoryListView(
                    repos: $repos,
                    onSelect: { repo in
                        switchRepository(repo)
                    }
                )
            }
            .sheet(isPresented: $showPremiumRequiredSheet) {
                PremiumRequiredView()
            }
        }
        .onChange(of: viewModel.hasSubscription) {
            print("HAS SUB:", $0)
        }
        .onAppear {
            Task {
                if let repo = await loadRepos() {
                    switchRepository(repo)
                } else {
                    await viewModel.fetchApps()
                }
            }
            Task {
                await viewModel.refreshSubscriptionStatus()
            }
        }
        .alert(item: $viewModel.deviceDateErrorMessage) { message in
            Alert(
                title: Text("Device Date Error"),
                message: Text(message),
                dismissButton: .default(Text("OK")) {
                    viewModel.deviceDateErrorMessage = nil
                }
            )
        }
        
    }
    
    // MARK: - Repos
    
    private func switchRepository(_ repo: AppRepository) {
        //make search field empty so search is not automatically applied when user switches repos
        viewModel.searchQuery = ""
        
        if repo.sourceURL == "Default app catalog" {
            viewModel.repository = .flekstore
        } else {
            viewModel.repository = .custom(url: repo.sourceURL)
        }
        
        Task {
            await viewModel.resetAndFetchApps()
        }
    }
    
    private func loadRepos() async -> AppRepository? {
        if let data = UserDefaults.standard.data(forKey: "savedRepositories"),
           let savedRepos = try? JSONDecoder().decode([AppRepository].self, from: data) {
            
            await MainActor.run {
                self.repos = savedRepos
            }
            
            // Return only the repo that is selected
            return savedRepos.first(where: { $0.isSelected })
        }
        
        return nil
    }
    
}

fileprivate struct CategoryButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .lineLimit(1)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Group {
                        if isSelected {
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.blue)
                        } else {
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.gray.opacity(0.16))
                        }
                    }
                )
                .foregroundColor(isSelected ? .white : .primary)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(isSelected ? Color.blue.opacity(0.8) : Color.clear, lineWidth: 0)
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Row
struct AppRow: View {
    let app: FSAppModel
    @Binding var selectedTab: Int
    @EnvironmentObject private var flekstoreSharedModel: FlekstoreSharedModel
    
    let isCustomRepository: Bool
    let hasSubscription: Bool
    
    let onPremiumRequired: () -> Void
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            KFImage(URL(string: app.app_icon))
                .placeholder { Color.gray.opacity(0.2) }
                .resizable()
                .scaledToFit()
                .frame(width: 60, height: 60)
                .cornerRadius(12)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(app.app_name)
                    .font(.headline)
                    .lineLimit(1)
                
                Text("Version \(app.app_version)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text(app.app_short_description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
            VStack {
                Spacer()
                Button(action: {
                    // Check your condition here
                    if isCustomRepository && !hasSubscription {
                        print("Subscription required")
                        onPremiumRequired()
                    } else {
                        selectedTab = 0
                        flekstoreSharedModel.appInstallURL = app.install_url
                    }
                }) {
                    Text("GET")
                        .font(.subheadline.bold())
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(14)
                }
                Spacer()
            }
        }
        .padding(.vertical, 6)
    }
}

#Preview {
    FlekstoreAppsListView(
        selectedTab: .constant(0)
    )
    .environmentObject(FlekstoreSharedModel())
}
