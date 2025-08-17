import SwiftUI

struct CalendarPermissionView: View {
    @StateObject private var calendarService = CalendarService.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showingSettings = false
    @State private var isRequestingPermission = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()
                
                iconSection
                
                titleSection
                
                benefitsSection
                
                Spacer()
                
                actionButtons
            }
            .padding(.horizontal, 24)
            .toolbar(.hidden, for: .navigationBar)
        }
    }
    
    private var iconSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 64, weight: .thin))
                .foregroundColor(.blue)
            
            Text("カレンダー連携")
                .font(.system(size: 28, weight: .bold))
        }
    }
    
    private var titleSection: some View {
        VStack(spacing: 12) {
            Text("メモを自動でカレンダーに記録")
                .font(.system(size: 20, weight: .semibold))
                .multilineTextAlignment(.center)
            
            Text("作成したメモが自動的にカレンダーイベントとして保存され、時系列で確認できます")
                .font(.system(size: 16))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
        }
    }
    
    private var benefitsSection: some View {
        VStack(spacing: 16) {
            BenefitRow(
                icon: "clock",
                title: "タイムライン表示",
                description: "メモを時系列で確認"
            )
            
            BenefitRow(
                icon: "calendar.circle",
                title: "専用カレンダー",
                description: "「Quick Memo」カレンダーを自動作成"
            )
            
            BenefitRow(
                icon: "tag",
                title: "詳細情報",
                description: "カテゴリやタグも一緒に記録"
            )
        }
    }
    
    private var actionButtons: some View {
        VStack(spacing: 16) {
            Button(action: {
                if !isRequestingPermission {
                    requestPermission()
                }
            }) {
                HStack {
                    if isRequestingPermission {
                        ProgressView()
                            .scaleEffect(0.8)
                            .tint(.white)
                    } else {
                        Image(systemName: "calendar.badge.checkmark")
                            .font(.system(size: 18, weight: .medium))
                    }
                    
                    Text(isRequestingPermission ? "設定中..." : "カレンダーアクセスを許可")
                        .font(.system(size: 18, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isRequestingPermission ? Color.gray : Color.blue)
                )
            }
            .disabled(isRequestingPermission)
            
            Button(action: {
                dismiss()
            }) {
                Text("後で設定")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.bottom, 34)
    }
    
    private func requestPermission() {
        guard !isRequestingPermission else { 
            print("Permission request already in progress")
            return 
        }
        
        print("Starting permission request...")
        isRequestingPermission = true
        
        Task { @MainActor in
            do {
                print("Calling requestCalendarAccess...")
                let granted = await calendarService.requestCalendarAccess()
                print("Permission result: \(granted)")
                
                isRequestingPermission = false
                
                if granted {
                    print("Permission granted, dismissing view")
                    dismiss()
                } else {
                    print("Permission denied, showing settings alert")
                    showingSettings = true
                }
            } catch {
                print("Error requesting permission: \(error)")
                isRequestingPermission = false
            }
        }
    }
}

struct BenefitRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .medium))
                .foregroundColor(.blue)
                .frame(width: 32, height: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                
                Text(description)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

#Preview {
    CalendarPermissionView()
}