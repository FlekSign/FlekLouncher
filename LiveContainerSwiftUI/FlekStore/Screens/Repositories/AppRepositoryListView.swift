//
//  AppRepositoryListView.swift
//  LiveContainer
//
//  Created by Alexander Grigoryev on 27.01.2026.
//

import SwiftUI
import Foundation
import Kingfisher

struct AppRepositoryListView: View {
    @State private var apps: [AppRepository] = []
    @State private var newRepoURL: String = ""
    private let userDefaultsKey = "savedRepositories"
    
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isLoading = false
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                VStack {
                    // MARK: - Input HStack
                    HStack {
                        TextField("Source URL", text: $newRepoURL)
                            .padding(8)
                            .background(Color(.systemGray6))
                            .cornerRadius(30)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                        
                        Button(action: addRepository) {
                            HStack(spacing: 4) {
                                Image(systemName: "plus.circle.fill")
                                Text("Add").fontWeight(.semibold)
                            }
                            .padding(.vertical, 6)
                            .padding(.horizontal, 12)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(30)
                        }
                        .disabled(newRepoURL.isEmpty || isLoading)
                    }
                    .padding(.horizontal)
                    .padding(.top)
                    
                    // MARK: - App list
                    List {
                        ForEach(apps.indices, id: \.self) { index in
                            AppRepositoryRow(app: apps[index])
                                .contentShape(Rectangle())
                                .onTapGesture { select(at: index) }
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    if apps[index].name != "FlekSt0re Lib" {
                                        Button(role: .destructive) {
                                            apps.remove(at: index)
                                            saveApps()
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                                }
                        }
                    }
                }
                .blur(radius: isLoading ? 3 : 0)
                
                // MARK: - Loading overlay
                if isLoading {
                    VStack(spacing: 12) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                            .scaleEffect(1.5)
                        Text("Adding repository...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(radius: 10)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        //dismiss()
                    } label: {
                        Text("Edit")
                            .frame(width: 50)
                    }
                    
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                }
            }
            .onAppear { loadApps() }
            .alert("Repository Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    private func select(at index: Int) {
        for i in apps.indices {
            apps[i].isSelected = (i == index)
        }
    }
    // MARK: - Add repository
    private func addRepository() {
        let trimmedURL = newRepoURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedURL.isEmpty, let url = URL(string: trimmedURL) else { return }
        
        isLoading = true
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            defer { DispatchQueue.main.async { isLoading = false } }
            
            if let error = error {
                showErrorOnMain("Failed to fetch repository: \(error.localizedDescription)")
                return
            }
            
            guard let data = data else {
                showErrorOnMain("No data returned from repository.")
                return
            }
            
            do {
                guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                      json["sourceURL"] != nil || json["name"] != nil else {
                    showErrorOnMain("Invalid repository format. Only AltStore-style repositories are supported.")
                    return
                }
                
                let name = json["name"] as? String ?? trimmedURL.components(separatedBy: "/").last ?? "New Repo"
                let sourceURL = json["sourceURL"] as? String ?? trimmedURL
                let iconUrl = json["iconURL"] as? String ?? (json["META"] as? [String: Any])?["repoIcon"] as? String ?? "https://via.placeholder.com/40"
                
                let newRepo = AppRepository(
                    name: name,
                    iconUrl: iconUrl,
                    sourceURL: sourceURL,
                    isSelected: false
                )
                
                DispatchQueue.main.async {
                    apps.append(newRepo)
                    saveApps()
                    newRepoURL = ""
                }
                
            } catch {
                showErrorOnMain("Failed to parse repository JSON. Only AltStore-style repositories are supported.")
            }
        }.resume()
    }
    
    private func showErrorOnMain(_ message: String) {
        DispatchQueue.main.async {
            self.errorMessage = message
            self.showError = true
        }
    }
    
    // MARK: - User defaults
    
    private func loadApps() {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let savedApps = try? JSONDecoder().decode([AppRepository].self, from: data) {
            self.apps = savedApps
        } else {
            // First launch – load default data
            self.apps = [
                AppRepository(
                    name: "FlekSt0re Lib",
                    iconUrl: "https://flekstore.com/pro_app/icons/apple-touch-icon.png",
                    sourceURL: "Default app catalog",
                    isSelected: true
                ),
                AppRepository(
                    name: "Nabzclan - App Store",
                    iconUrl: "https://cdn.nabzclan.vip/popupv3/imgs/logo-tras.png",
                    sourceURL: "https://appstore.nabzclan.vip/repos/altstore.php",
                    isSelected: false
                ),
                AppRepository(
                    name: "AppTesters IPA Repo",
                    iconUrl: "https://apptesters.org/apptesters-512x512.png",
                    sourceURL: "https://repository.apptesters.org/",
                    isSelected: false
                ),
                AppRepository(
                    name: "Quantum Source",
                    iconUrl: "https://quarksources.github.io/assets/ElementQ-Circled.png",
                    sourceURL: "https://quarksources.github.io/dist/quantumsource.min.json",
                    isSelected: false
                )
            ]
            saveApps()
        }
    }
    
    private func saveApps() {
        if let data = try? JSONEncoder().encode(apps) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        }
    }
    
    private func delete(at offsets: IndexSet) {
        // Filter out Flekstore
        let filteredOffsets = offsets.filter { apps[$0].name != "FlekSt0re Lib" }
        apps.remove(atOffsets: IndexSet(filteredOffsets))
        saveApps()
    }
}

struct AppRepositoryRow: View {
    let app: AppRepository
    
    var body: some View {
        HStack(spacing: 12) {
            KFImage(URL(string: app.iconUrl))
                .resizable()
                .placeholder {
                    Color.gray.opacity(0.3)
                }
                .scaledToFit()
                .frame(width: 40, height: 40)
                .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(app.name)
                    .font(.headline)
                
                Text(app.sourceURL)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if app.isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.blue)
            }
        }
        .padding(.vertical, 6)
    }
}
#Preview {
    AppRepositoryListView()
}
