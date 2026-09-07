import SwiftUI
import MushKit

/// Every creature state on one screen.
///
/// Exists so the character system can be reviewed in a single CI screenshot rather than
/// inferred from five separate runs. Reachable only with `-MushScreen gallery`, so it
/// never ships in a normal launch.
struct StageGalleryView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                Text("STAGES")
                    .font(.mushLabel())
                    .tracking(2)
                    .foregroundStyle(Token.Color.inkDim)
                    .frame(maxWidth: .infinity, alignment: .leading)

                ForEach(BrainStage.allCases.reversed(), id: \.self) { stage in
                    Viewport {
                        HStack(spacing: 0) {
                            BlobView(stage: stage, isStatic: true)
                                .frame(width: 140, height: 130)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(stage.title)
                                    .font(.mushDisplay(30))
                                    .foregroundStyle(Token.Color.inkOnViewport)
                                Text(stage.mood)
                                    .font(.system(size: 13))
                                    .foregroundStyle(Token.Color.inkOnViewport.opacity(0.6))
                                Text("\(Int(stage.lowerBound))+")
                                    .font(.mushData(12))
                                    .foregroundStyle(Token.Color.inkOnViewport.opacity(0.45))
                                    .padding(.top, 2)
                            }
                            Spacer()
                        }
                    }
                }
            }
            .padding(20)
        }
        .background(Token.Color.ground)
    }
}
