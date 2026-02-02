//
//  PremiumRequiredView.swift
//  LiveContainerSwiftUI
//
//  Created by Alexander Grigoryev on 30.01.2026.
//

import SwiftUI

struct PremiumRequiredView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack {
            Image("premiumLogo")
                .resizable()
                .frame(width: 100, height: 100)
                .cornerRadius(20)
                .shadow(radius: 10)
            
            
            Text("Premium Access is required to download applications from external sources.")
                .font(Font.title3.bold())
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .padding(.vertical)
            
            Text("Open the FlekSt0re app -> Device -> in the Services section, click the Premium Access button")
                .font(Font.caption)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
            
            Image("premiumSuggestion")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: 250)
                .shadow(radius: 10)
                .padding()
            
            Button {
                dismiss()
            } label: {
                Text("Got it")
                    .font(.title3.bold())
                    .frame(maxWidth: .infinity, maxHeight: 40)
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)
            .padding()
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                }
            }
        }
    }
}

#Preview {
    PremiumRequiredView()
}
