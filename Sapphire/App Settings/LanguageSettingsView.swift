import SwiftUI

struct LanguageSettingsView: View {
    @EnvironmentObject private var settings: SettingsEditingSession

    var body: some View {
        SettingsCard(title: "Language", description: "Choose the language for all Sapphire features, menus and descriptions.") {
            HStack {
                Text("App Language")
                Spacer()
                Picker("App Language", selection: $settings.settings.appLanguage) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.displayName).tag(language.rawValue)
                    }
                }
                .labelsHidden()
                .frame(minWidth: 160)
            }
            .padding()

            Divider().padding(.leading, 20)

            HStack(alignment: .center, spacing: 16) {
                Text("Language changes take effect after restarting Sapphire. Your settings are saved before restarting.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
                Button("Restart Sapphire") {
                    settings.flushPendingSave()
                    HelperManager.relaunchApp()
                }
                .buttonStyle(.bordered)
            }
            .padding()
        }
    }
}
