import SwiftUI
import WatchKit

struct WatchMainView: View {
    @EnvironmentObject private var connectivityManager: WatchConnectivityManager
    @StateObject private var dataManager = WatchDataManager.shared
    @State private var showingMemoInput = false
    @State private var showingMemoList = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                statusIndicator
                
                quickActionButton

                memoListButton

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
            .sheet(isPresented: $showingMemoList) {
                WatchMemoListView()
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
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.2))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var memoListButton: some View {
        Button(action: {
            showingMemoList = true
        }) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("メモ一覧")
                        .font(.footnote)
                        .fontWeight(.medium)
                    Text("\(dataManager.memos.count)件")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "list.bullet")
                    .font(.body)
                    .foregroundColor(.secondary)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.2))
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