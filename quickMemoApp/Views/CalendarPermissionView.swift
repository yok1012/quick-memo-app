import SwiftUI

struct CalendarPermissionView: View {
    @StateObject private var calendarService = CalendarService.shared
    @Environment(\.dismiss) private var dismiss
    @State private var isRequestingPermission = false
    @State private var showDeniedAlert = false
    
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
            .alert("カレンダーにアクセスできません", isPresented: $showDeniedAlert) {
                Button("設定を開く") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("閉じる", role: .cancel) { }
            } message: {
                Text("calendar_permission_description".localized)
            }
        }
    }
    
    private var iconSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 64, weight: .thin))
                .foregroundColor(.blue)
            
            Text("calendar_integration".localized)
                .font(.system(size: 28, weight: .bold))
        }
    }
    
    private var titleSection: some View {
        VStack(spacing: 12) {
            Text("calendar_auto_record".localized)
                .font(.system(size: 20, weight: .semibold))
                .multilineTextAlignment(.center)
            
            Text("calendar_auto_save_description".localized)
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
                title: "calendar_timeline".localized,
                description: "メモを時系列で確認"
            )
            
            BenefitRow(
                icon: "calendar.circle",
                title: "calendar_dedicated".localized,
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
                    Text(isRequestingPermission ? "設定を準備中…" : "続行")
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
        }
        .padding(.bottom, 34)
    }
    
    private func requestPermission() {
        guard !isRequestingPermission else { 
            return 
        }
        
        isRequestingPermission = true
        
        Task { @MainActor in
            do {
                let granted = await calendarService.requestCalendarAccess()
                
                isRequestingPermission = false
                
                if granted {
                    dismiss()
                } else {
                    showDeniedAlert = true
                }
            } catch {
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
