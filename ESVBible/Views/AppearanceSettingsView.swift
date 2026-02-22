import SwiftUI

struct AppearanceSettingsView: View {
    @AppStorage("selectedFont") private var selectedFont: String = "Georgia"
    @AppStorage("bionicReadingEnabled") private var bionicReadingEnabled: Bool = false
    @AppStorage("readingTheme") private var readingTheme: ReadingTheme = .system

    var body: some View {
        Form {
            Section("Appearance") {
                Picker("Theme", selection: $readingTheme) {
                    ForEach(ReadingTheme.allCases, id: \.self) { theme in
                        Label {
                            Text(theme.displayName)
                        } icon: {
                            Circle()
                                .fill(theme.swatchFill)
                                .overlay(Circle().strokeBorder(theme.swatchBorder, lineWidth: 1))
                                .frame(width: 12, height: 12)
                        }
                        .tag(theme)
                    }
                }
                .labelsHidden()
                .pickerStyle(.radioGroup)
            }

            Section("Font") {
                Picker("Font", selection: $selectedFont) {
                    Text("Georgia")
                        .font(.custom("Georgia", size: 14))
                        .tag("Georgia")
                    Text("Palatino")
                        .font(.custom("Palatino-Roman", size: 14))
                        .tag("Palatino-Roman")
                    Text("Helvetica Neue")
                        .font(.custom("HelveticaNeue", size: 14))
                        .tag("HelveticaNeue")
                }
                .labelsHidden()
                .pickerStyle(.radioGroup)
            }

            Section("Reading") {
                Toggle("Bionic Reading", isOn: $bionicReadingEnabled)
            }
        }
        .formStyle(.grouped)
        .frame(width: 320)
        .padding(.vertical, 8)
    }
}

#Preview {
    AppearanceSettingsView()
}
