import ActivityKit
import SwiftUI
import WidgetKit

struct LiveActivitiesAppAttributes: ActivityAttributes, Identifiable {
    public typealias LiveDeliveryData = ContentState

    public struct ContentState: Codable, Hashable {}

    var id = UUID()
}

extension LiveActivitiesAppAttributes {
    func prefixedKey(_ key: String) -> String {
        "\(id)_\(key)"
    }
}

private let sharedDefaults = UserDefaults(suiteName: "group.com.guomu.huangguo")!

private struct ActivityData {
    let title: String
    let genre: String
    let episode: Int
    let totalEpisodes: Int
    let progress: Double
    let coverPath: String
    let deepLink: String

    init(context: ActivityViewContext<LiveActivitiesAppAttributes>) {
        title = sharedDefaults.string(forKey: context.attributes.prefixedKey("title")) ?? "果幕短剧"
        genre = sharedDefaults.string(forKey: context.attributes.prefixedKey("genre")) ?? "黄果短剧"
        episode = sharedDefaults.integer(forKey: context.attributes.prefixedKey("episode"))
        totalEpisodes = sharedDefaults.integer(forKey: context.attributes.prefixedKey("totalEpisodes"))
        progress = sharedDefaults.double(forKey: context.attributes.prefixedKey("progress"))
        coverPath = sharedDefaults.string(forKey: context.attributes.prefixedKey("cover")) ?? ""
        deepLink = sharedDefaults.string(forKey: context.attributes.prefixedKey("deepLink")) ?? "guomu://"
    }

    var episodeText: String {
        totalEpisodes > 0 ? "观看至 \(episode)/\(totalEpisodes) 集" : "观看至第 \(episode) 集"
    }
}

private struct CoverView: View {
    let path: String
    var body: some View {
        Group {
            if let image = UIImage(contentsOfFile: path) {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                ZStack {
                    LinearGradient(colors: [.orange.opacity(0.8), .black], startPoint: .topLeading, endPoint: .bottomTrailing)
                    Image(systemName: "play.fill").foregroundStyle(.white)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

@main
struct GuomuWidgetBundle: WidgetBundle {
    var body: some Widget {
        GuomuLiveActivityWidget()
    }
}

@available(iOSApplicationExtension 16.1, *)
struct GuomuLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: LiveActivitiesAppAttributes.self) { context in
            let data = ActivityData(context: context)
            HStack(spacing: 12) {
                CoverView(path: data.coverPath)
                    .frame(width: 48, height: 64)
                VStack(alignment: .leading, spacing: 4) {
                    Text("果幕短剧").font(.caption2).foregroundStyle(.orange)
                    Text(data.title).font(.headline).lineLimit(2)
                    Text("\(data.genre) · \(data.episodeText)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Link(destination: URL(string: data.deepLink)!) {
                    Text("继续播放")
                        .font(.caption).fontWeight(.bold)
                        .foregroundStyle(.black)
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(.orange, in: Capsule())
                }
            }
            .padding(14)
            .activityBackgroundTint(Color.black.opacity(0.94))
            .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            let data = ActivityData(context: context)
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    CoverView(path: data.coverPath).frame(width: 46, height: 62)
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(data.title).font(.headline).lineLimit(2)
                        Text("\(data.genre) · \(data.episodeText)")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Link(destination: URL(string: data.deepLink)!) {
                        Text("继续播放")
                            .font(.caption).fontWeight(.bold)
                            .foregroundStyle(.black)
                            .padding(.horizontal, 10).padding(.vertical, 7)
                            .background(.orange, in: Capsule())
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ProgressView(value: data.progress)
                        .tint(.orange)
                }
            } compactLeading: {
                CoverView(path: data.coverPath).frame(width: 24, height: 30)
            } compactTrailing: {
                ProgressView(value: data.progress)
                    .progressViewStyle(.circular)
                    .tint(.orange)
                    .frame(width: 24, height: 24)
            } minimal: {
                Image(systemName: "play.fill").foregroundStyle(.orange)
            }
            .keylineTint(.orange)
        }
    }
}
