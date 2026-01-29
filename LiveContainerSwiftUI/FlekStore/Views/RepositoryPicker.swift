//
//  RepositoryPicker.swift
//  LiveContainer
//
//  Created by Alexander Grigoryev on 29.01.2026.
//


import SwiftUI
import Kingfisher

struct RepositoryPicker: View {
    
    @Binding var repositories: [AppRepository]
    @Binding var showSheet: Bool
    let onSelect: (AppRepository) -> Void
    
    @State private var isExpanded = false
    
    private var selectedRepo: AppRepository? {
        repositories.first(where: { $0.isSelected })
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            
            mainButton
            
            if isExpanded {
                dropdown
            }
        }
    }
}

// MARK: - Main UI

private extension RepositoryPicker {
    
    var mainButton: some View {
        Button {
            withAnimation(.easeInOut) {
                isExpanded.toggle()
            }
        } label: {
            HStack(spacing: 12) {
                
                if let url = URL(string: selectedRepo?.iconUrl ?? "") {
                    KFImage(url)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 22, height: 22)
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                } else {
                    Image(systemName: "square.stack")
                        .foregroundColor(.secondary)
                }
                
                Text(selectedRepo?.name ?? "Select Source")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            .padding(12)
            .background(.ultraThinMaterial)
            .cornerRadius(30)
        }
    }
    
    var dropdown: some View {
        VStack(spacing: 4) {
            ForEach(repositories.indices, id: \.self) { index in
                repoRow(for: repositories[index])
            }
            
            Divider().padding(.vertical, 4)
            
            manageSourcesRow
        }
        .padding(8)
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }
}

// MARK: - Rows

private extension RepositoryPicker {
    
    func repoRow(for repo: AppRepository) -> some View {
        Button {
            select(repo)
        } label: {
            HStack(spacing: 12) {
                
                if let url = URL(string: repo.iconUrl) {
                    KFImage(url)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 22, height: 22)
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                }
                
                Text(repo.name)
                    .foregroundColor(.primary)
                
                Spacer()
                
                if repo.isSelected {
                    Image(systemName: "checkmark")
                        .foregroundColor(.accentColor)
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 6)
        }
        .buttonStyle(.plain)
    }
    
    var manageSourcesRow: some View {
        Button {
            isExpanded = false
            showSheet = true
        } label: {
            HStack {
                Text("Manage Sources")
                    .foregroundColor(.primary)
                    .font(.footnote.bold())
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 5)
            .padding(.horizontal)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Logic

private extension RepositoryPicker {
    
    func select(_ repo: AppRepository) {
        let updated = repositories.map {
            AppRepository(
                name: $0.name,
                iconUrl: $0.iconUrl,
                sourceURL: $0.sourceURL,
                isSelected: $0.id == repo.id
            )
        }

        repositories = updated
        saveRepos(updated)

        onSelect(repo)  

        withAnimation {
            isExpanded = false
        }
    }
    
    private func saveRepos(_ repos: [AppRepository]) {
        if let data = try? JSONEncoder().encode(repos) {
            UserDefaults.standard.set(data, forKey: "savedRepositories")
        }
    }
}

//// MARK: - Preview
//
//#Preview {
//    PreviewWrapper()
//}
//
//private struct PreviewWrapper: View {
//    
//    @State private var repos: [AppRepository] = [
//        AppRepository(
//            name: "FlekSt0re Lib",
//            iconUrl: "https://flekstore.com/pro_app/icons/apple-touch-icon.png",
//            sourceURL: "Default app catalog",
//            isSelected: true
//        ),
//        AppRepository(
//            name: "Nabzclan - App Store",
//            iconUrl: "https://cdn.nabzclan.vip/popupv3/imgs/logo-tras.png",
//            sourceURL: "https://appstore.nabzclan.vip/repos/altstore.php",
//            isSelected: false
//        ),
//        AppRepository(
//            name: "AppTesters IPA Repo",
//            iconUrl: "https://apptesters.org/apptesters-512x512.png",
//            sourceURL: "https://repository.apptesters.org/",
//            isSelected: false
//        ),
//        AppRepository(
//            name: "Quantum Source",
//            iconUrl: "https://quarksources.github.io/assets/ElementQ-Circled.png",
//            sourceURL: "https://quarksources.github.io/dist/quantumsource.min.json",
//            isSelected: false
//        )
//    ]
//    
//    @State private var showManageSheet = false
//    
//    var body: some View {
//        VStack(spacing: 20) {
//            RepositoryPicker(
//                repositories: $repos,
//                showSheet: $showManageSheet
//            )
//            
//            Spacer()
//        }
//        .frame(width:200)
//        .padding()
//        .background(Color(.systemGroupedBackground))
//        .sheet(isPresented: $showManageSheet) {
//            AppRepositoryListView()
//        }
//    }
//}
