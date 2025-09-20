import SwiftUI

struct ProFeatureLockView: View {
    let featureName: String
    let description: String
    let icon: String
    @State private var showingPurchase = false
    
    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 40))
                    .foregroundColor(.orange)
                
                Text(featureName)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            
            Button(action: {
                showingPurchase = true
            }) {
                HStack {
                    Image(systemName: "star.fill")
                    Text("Pro版にアップグレード")
                }
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.orange)
                .cornerRadius(8)
            }
        }
        .padding()
        .sheet(isPresented: $showingPurchase) {
            PurchaseView()
        }
    }
}

struct ProBadge: View {
    let text: String
    
    var body: some View {
        Text(text)
            .font(.caption2)
            .fontWeight(.bold)
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                LinearGradient(
                    colors: [.orange, .red],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(4)
    }
}

struct ProFeatureRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let isLocked: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isLocked ? Color.orange.opacity(0.2) : Color.blue.opacity(0.2))
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: isLocked ? "lock.fill" : icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(isLocked ? .orange : .blue)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(title)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        
                        if isLocked {
                            ProBadge(text: "PRO")
                        }
                    }
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    VStack(spacing: 20) {
        ProFeatureLockView(
            featureName: "高度なタグ管理",
            description: "メモをより詳細に分類・整理できる高度なタグ機能です",
            icon: "tag.fill"
        )
        
        ProFeatureRow(
            icon: "calendar.badge.plus",
            title: "カレンダー詳細連携",
            subtitle: "メモをカレンダーに自動記録",
            isLocked: true
        ) {
            // Action
        }
        
        ProFeatureRow(
            icon: "link",
            title: "Deep Link機能",
            subtitle: "他のアプリから直接メモ作成",
            isLocked: false
        ) {
            // Action
        }
    }
    .padding()
}