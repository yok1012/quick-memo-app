import SwiftUI
import WatchKit

struct WatchMainView: View {
    @EnvironmentObject private var connectivityManager: WatchConnectivityManager
    @State private var showingMemoInput = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                statusIndicator
                
                quickActionButton
                
                if !connectivityManager.pendingMemos.isEmpty {
                    pendingMemosIndicator
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Quick Memo")
            .sheet(isPresented: $showingMemoInput) {
                WatchFastInputView()
            }
        }
    }
    
    private var statusIndicator: some View {
        HStack {
            Circle()
                .fill(connectivityManager.isReachable ? Color.green : Color.red)
                .frame(width: 8, height: 8)
            
            Text(connectivityManager.isReachable ? "iPhone接続中" : "オフライン")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
    
    private var quickActionButton: some View {
        Button(action: {
            showingMemoInput = true
        }) {
            VStack(spacing: 8) {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
                
                Text("新しいメモ")
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray6))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var pendingMemosIndicator: some View {
        HStack {
            Image(systemName: "clock")
                .foregroundColor(.orange)
                .font(.caption)
            
            Text("\(connectivityManager.pendingMemos.count)件の同期待ち")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.orange.opacity(0.1))
        )
    }
}

struct WatchComplicationView: View {
    var body: some View {
        VStack {
            Image(systemName: "note.text")
                .font(.title3)
                .foregroundColor(.blue)
            
            Text("Memo")
                .font(.caption2)
                .fontWeight(.medium)
        }
    }
}

#Preview {
    WatchMainView()
        .environmentObject(WatchConnectivityManager.shared)
}