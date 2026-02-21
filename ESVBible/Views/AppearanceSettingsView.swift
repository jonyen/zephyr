import SwiftUI

struct AppearanceSettingsView: View {
    @AppStorage("selectedFont") private var selectedFont: String = "Georgia"
    @AppStorage("bionicReadingEnabled") private var bionicReadingEnabled: Bool = false

    var body: some View {
        Form {
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
