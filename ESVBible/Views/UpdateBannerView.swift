import SwiftUI

struct UpdateBannerView: View {
    let updateService: UpdateService

    var body: some View {
        switch updateService.state {
        case .idle, .checking:
            EmptyView()

        case let .updateAvailable(version, notes, downloadURL):
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "arrow.down.circle.fill")
                        .foregroundStyle(.blue)
                    Text("Zephyr v\(version) is available")
                        .font(.headline)
                    Spacer()
                    Button {
                        updateService.dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }

                if !notes.isEmpty {
                    Text(notes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }

                HStack {
                    Spacer()
                    Button("Later") {
                        updateService.dismiss()
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)

                    Button("Update") {
                        Task {
                            await updateService.downloadUpdate(from: downloadURL)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }
            .padding(12)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(.separator, lineWidth: 0.5)
            }
            .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
            .padding(.horizontal, 48)
            .padding(.top, 12)
            .transition(.move(edge: .top).combined(with: .opacity))

        case let .downloading(progress):
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "arrow.down.circle")
                        .foregroundStyle(.blue)
                    Text("Downloading update...")
                        .font(.headline)
                    Spacer()
                }
                ProgressView(value: progress)
                    .progressViewStyle(.linear)
            }
            .padding(12)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(.separator, lineWidth: 0.5)
            }
            .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
            .padding(.horizontal, 48)
            .padding(.top, 12)

        case let .readyToInstall(localURL):
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Update ready to install")
                        .font(.headline)
                    Spacer()
                }
                HStack {
                    Spacer()
                    Button("Install & Relaunch") {
                        updateService.installAndRelaunch(from: localURL)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }
            .padding(12)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(.separator, lineWidth: 0.5)
            }
            .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
            .padding(.horizontal, 48)
            .padding(.top, 12)

        case let .error(message):
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text(message)
                    .font(.caption)
                Spacer()
                Button("Retry") {
                    Task {
                        await updateService.checkForUpdate()
                    }
                }
                .buttonStyle(.plain)
                .foregroundStyle(.blue)

                Button {
                    updateService.dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(12)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(.separator, lineWidth: 0.5)
            }
            .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
            .padding(.horizontal, 48)
            .padding(.top, 12)
        }
    }
}
