import SwiftUI

struct ImageViewerView: View {
    let image: UIImage
    @State private var rotation: Double = 0
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .rotationEffect(.degrees(rotation))
                    .scaleEffect(scale)
                    .gesture(
                        MagnificationGesture()
                            .onChanged { value in
                                scale = lastScale * value
                            }
                            .onEnded { _ in
                                lastScale = scale
                            }
                    )
                    .frame(width: geometry.size.width, height: geometry.size.height)
            }
            .navigationTitle("查看图片")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") { dismiss() }
                }
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button(action: { rotation -= 90 }) {
                        Image(systemName: "rotate.left")
                    }
                    Button(action: { rotation += 90 }) {
                        Image(systemName: "rotate.right")
                    }
                    Button(action: {
                        scale = 1.0
                        lastScale = 1.0
                        rotation = 0
                    }) {
                        Image(systemName: "arrow.counterclockwise")
                    }
                }
            }
        }
    }
}
