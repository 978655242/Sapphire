//
//  NotchViewSupport.swift
//  Sapphire
//
//  Created by Shariq Charolia on 2026-09-02

import SwiftUI
import AppKit

struct IdealSizeReader: Layout {
    final class Cache {
        var ideal: CGSize = .zero
        var reported: CGSize?
    }

    let epsilon: CGFloat
    let sizeIsProposalIndependent: Bool
    let onChange: (CGSize) -> Void

    func makeCache(subviews: Subviews) -> Cache {
        let cache = Cache()
        cache.ideal = Self.idealSize(of: subviews)
        return cache
    }

    func updateCache(_ cache: inout Cache, subviews: Subviews) {
        cache.ideal = Self.idealSize(of: subviews)
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) -> CGSize {
        report(cache.ideal, cache: cache)
        if sizeIsProposalIndependent { return cache.ideal }
        guard let subview = subviews.first else { return .zero }
        return subview.sizeThatFits(proposal)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) {
        guard let subview = subviews.first else { return }
        subview.place(at: CGPoint(x: bounds.minX, y: bounds.minY), anchor: .topLeading, proposal: proposal)
    }

    private static func idealSize(of subviews: Subviews) -> CGSize {
        subviews.first?.sizeThatFits(.unspecified) ?? .zero
    }

    private func report(_ size: CGSize, cache: Cache) {
        if let reported = cache.reported,
           abs(reported.width - size.width) <= epsilon,
           abs(reported.height - size.height) <= epsilon {
            return
        }
        cache.reported = size
        let onChange = self.onChange
        DispatchQueue.main.async { onChange(size) }
    }
}

extension View {
    func measureIdealSize(
        into binding: Binding<CGSize>,
        epsilon: CGFloat = 0.5,
        sizeIsProposalIndependent: Bool = false
    ) -> some View {
        let reader = IdealSizeReader(
            epsilon: epsilon,
            sizeIsProposalIndependent: sizeIsProposalIndependent
        ) { newValue in
            guard abs(newValue.width - binding.wrappedValue.width) > epsilon
                || abs(newValue.height - binding.wrappedValue.height) > epsilon else { return }
            binding.wrappedValue = newValue
        }
        return reader { self }
    }

    func measureIdealWidth(into binding: Binding<CGFloat>, epsilon: CGFloat = 0.5) -> some View {
        let reader = IdealSizeReader(
            epsilon: epsilon,
            sizeIsProposalIndependent: false
        ) { newValue in
            guard abs(newValue.width - binding.wrappedValue) > epsilon else { return }
            binding.wrappedValue = newValue.width
        }
        return reader { self }
    }
}

struct SubtleIconButton: View {
    let systemName: String
    let action: () -> Void
    let horizontalPadding: CGFloat
    let verticalPadding: CGFloat

    @State private var isHovering = false

    init(systemName: String, action: @escaping () -> Void, horizontalPadding: CGFloat = 8, verticalPadding: CGFloat = 6) {
        self.systemName = systemName
        self.action = action
        self.horizontalPadding = horizontalPadding
        self.verticalPadding = verticalPadding
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(isHovering ? 1.0 : 0.7))
                .padding(.horizontal, horizontalPadding)
                .padding(.vertical, verticalPadding)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) { isHovering = hovering }
        }
        .scaleEffect(isHovering ? 1.1 : 1.0)
        .animation(.spring(response: 0.4, dampingFraction: 0.6), value: isHovering)
    }
}
