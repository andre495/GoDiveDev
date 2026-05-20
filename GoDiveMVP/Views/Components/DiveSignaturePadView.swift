import SwiftUI
#if canImport(PencilKit)
import PencilKit
#endif

/// Finger/stylus signature capture; persists **`PKDrawing`** bytes on **`DiveActivity.diveSignatureData`**.
struct DiveSignaturePadView: View {
    @Binding var signatureData: Data?

    private let canvasHeight: CGFloat = 128

    var body: some View {
        #if canImport(PencilKit)
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            DiveSignaturePadRepresentable(signatureData: $signatureData)
                .frame(height: canvasHeight)
                .background(AppTheme.Colors.surfaceMuted.opacity(0.35))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(AppTheme.Colors.tabUnselected.opacity(0.22), lineWidth: 1)
                }

            if signatureData != nil {
                Button("Clear signature", role: .destructive) {
                    signatureData = nil
                }
                .font(.footnote.weight(.semibold))
            } else {
                Text("Sign with your finger or Apple Pencil.")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.Colors.tabUnselected)
            }
        }
        #else
        Text("Signatures require PencilKit (iOS).")
            .font(.footnote)
            .foregroundStyle(AppTheme.Colors.tabUnselected)
        #endif
    }
}

#if canImport(PencilKit)
private struct DiveSignaturePadRepresentable: UIViewRepresentable {
    @Binding var signatureData: Data?

    func makeCoordinator() -> Coordinator {
        Coordinator(signatureData: $signatureData)
    }

    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        canvas.drawingPolicy = .anyInput
        canvas.tool = PKInkingTool(.pen, color: .label, width: 2)
        canvas.delegate = context.coordinator
        if let data = signatureData, let drawing = try? PKDrawing(data: data) {
            canvas.drawing = drawing
        }
        return canvas
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        if let data = signatureData, let drawing = try? PKDrawing(data: data) {
            if uiView.drawing.dataRepresentation() != data {
                uiView.drawing = drawing
            }
        } else if !uiView.drawing.bounds.isEmpty {
            uiView.drawing = PKDrawing()
        }
    }

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        var signatureData: Binding<Data?>

        init(signatureData: Binding<Data?>) {
            self.signatureData = signatureData
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            let drawing = canvasView.drawing
            if drawing.bounds.isEmpty {
                signatureData.wrappedValue = nil
            } else {
                signatureData.wrappedValue = drawing.dataRepresentation()
            }
        }
    }
}
#endif
