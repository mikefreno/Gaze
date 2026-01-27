//
//  ReminderSizeSection.swift
//  Gaze
//
//  Subtle reminder size picker section.
//

import SwiftUI

struct ReminderSizeSection: View {
    @Binding var selectedSize: ReminderSize

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Subtle Reminder Size")
                .font(.headline)

            Text("Adjust the size of blink and posture reminders")
                .font(.caption)
                .foregroundStyle(.secondary)

            sizeButtonRow
        }
        .padding()
        .glassEffectIfAvailable(GlassStyle.regular, in: .rect(cornerRadius: 12))
    }

    private var sizeButtonRow: some View {
        HStack(spacing: 12) {
            ForEach(ReminderSize.allCases, id: \.self) { size in
                ReminderSizeButton(
                    size: size,
                    isSelected: selectedSize == size,
                    action: { selectedSize = size }
                )
            }
        }
    }
}

private struct ReminderSizeButton: View {
    let size: ReminderSize
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Circle()
                    .fill(isSelected ? Color.accentColor : Color.secondary.opacity(0.3))
                    .frame(width: iconSize, height: iconSize)

                Text(size.displayName)
                    .font(.caption)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundStyle(isSelected ? .primary : .secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 60)
            .padding(.vertical, 12)
        }
        .glassEffectIfAvailable(
            isSelected
                ? GlassStyle.regular.tint(.accentColor.opacity(0.3))
                : GlassStyle.regular,
            in: .rect(cornerRadius: 10)
        )
    }

    private var iconSize: CGFloat {
        switch size {
        case .small: return 20
        case .medium: return 32
        case .large: return 48
        }
    }
}

#Preview {
    ReminderSizeSection(selectedSize: .constant(.medium))
        .padding()
}
