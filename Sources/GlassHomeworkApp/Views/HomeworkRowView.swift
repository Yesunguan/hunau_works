import GlassHomeworkCore
import SwiftUI

struct HomeworkRowView: View {
    @Bindable var store: HomeworkStore
    let itemId: UUID
    let fallbackItem: HomeworkItem
    let now: Date
    let isCompact: Bool
    let isSelected: Bool
    let onToggleComplete: () -> Void
    let onSelect: () -> Void
    let onPostponeOneDay: () -> Void
    let onDelete: () -> Void

    @State private var isHovering = false

    private var item: HomeworkItem {
        store.item(for: itemId) ?? fallbackItem
    }

    private var course: Course? {
        store.course(for: item.courseId)
    }

    private var urgency: UrgencyLevel {
        UrgencyCalculator.urgency(for: item, now: now)
    }

    private var urgencyColor: Color {
        GlassPalette.urgencyColor(urgency)
    }

    private var courseColor: Color {
        course.map { Color(hex: $0.colorHex) } ?? Color(hex: "#60A5FA")
    }

    var body: some View {
        HStack(spacing: isCompact ? 8 : 11) {
            // Left urgency energy indicator bar
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(urgencyColor.opacity(item.isCompleted ? 0.45 : 0.92))
                .frame(width: 3.5)
                .padding(.vertical, 3)

            // Completion checkbox
            Button(action: onToggleComplete) {
                ZStack {
                    Circle()
                        .strokeBorder(
                            item.isCompleted ? urgencyColor : urgencyColor.opacity(0.75),
                            lineWidth: 1.8
                        )
                        .background(
                            Circle()
                                .fill(item.isCompleted ? urgencyColor.opacity(0.9) : Color.clear)
                        )
                        .frame(width: isCompact ? 18 : 20, height: isCompact ? 18 : 20)

                    if item.isCompleted {
                        Image(systemName: "checkmark")
                            .font(.system(size: isCompact ? 9 : 10, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .help(item.isCompleted ? "撤销完成" : "标记为已完成")

            // Main content
            VStack(alignment: .leading, spacing: isCompact ? 3 : 5) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(item.title)
                        .font(.system(size: isCompact ? 12.5 : 13.5, weight: .semibold))
                        .foregroundStyle(item.isCompleted ? .secondary : .primary)
                        .strikethrough(item.isCompleted, color: .secondary)
                        .lineLimit(isCompact ? 1 : 2)

                    Spacer(minLength: 4)

                    // Countdown badge
                    Text(UrgencyCalculator.countdownText(for: item, now: now))
                        .font(.system(size: isCompact ? 10.5 : 11, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(item.isCompleted ? .secondary : urgencyColor)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2.5)
                        .background(
                            Capsule(style: .continuous)
                                .fill(urgencyColor.opacity(item.isCompleted ? 0.1 : 0.16))
                        )
                        .fixedSize()
                }

                if !isCompact {
                    HStack(spacing: 8) {
                        if let course {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(courseColor)
                                    .frame(width: 6, height: 6)
                                Text(course.name)
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(courseColor.opacity(0.14))
                            )
                        }

                        Label(
                            UrgencyCalculator.dueDateFormatted(item.dueDate, now: now),
                            systemImage: "clock"
                        )
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .labelStyle(.titleOnly)

                        if item.priority == .high && !item.isCompleted {
                            HStack(spacing: 2) {
                                Image(systemName: "flame.fill")
                                    .font(.system(size: 9))
                                Text("高优")
                                    .font(.system(size: 10.5, weight: .semibold))
                            }
                            .foregroundStyle(GlassPalette.priorityColor(.high))
                        }

                        if !item.subtasks.isEmpty {
                            HStack(spacing: 3) {
                                Image(systemName: "checklist")
                                    .font(.system(size: 10))
                                Text("\(item.completedSubtasksCount)/\(item.subtasks.count)")
                                    .font(.system(size: 10.5, design: .rounded))
                                    .monospacedDigit()
                            }
                            .foregroundStyle(.secondary)
                        }

                        if !item.attachments.isEmpty {
                            Image(systemName: "paperclip")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }

                        Spacer(minLength: 0)
                    }
                } else {
                    // Compact secondary line
                    HStack(spacing: 6) {
                        if let course {
                            HStack(spacing: 3) {
                                Circle()
                                    .fill(courseColor)
                                    .frame(width: 5, height: 5)
                                Text(course.name)
                                    .font(.system(size: 10.5))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        if !item.subtasks.isEmpty {
                            Text("· \(item.completedSubtasksCount)/\(item.subtasks.count) 子任务")
                                .font(.system(size: 10.5))
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                    }
                }
            }
        }
        .padding(.horizontal, isCompact ? 9 : 11)
        .padding(.vertical, isCompact ? 8 : 10)
        .glassContentCard(
            cornerRadius: isCompact ? 12 : 14,
            isSelected: isSelected || isHovering,
            accent: isSelected ? urgencyColor : nil
        )
        .contentShape(RoundedRectangle(cornerRadius: isCompact ? 12 : 14, style: .continuous))
        .onTapGesture(perform: onSelect)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.14)) {
                isHovering = hovering
            }
        }
        .contextMenu {
            Button(item.isCompleted ? "撤销完成" : "标记已完成", action: onToggleComplete)
            if !item.isCompleted {
                Button("截止时间延后 1 天", action: onPostponeOneDay)
            }
            Button("查看 / 编辑详情", action: onSelect)
            Divider()
            Button("删除作业", role: .destructive, action: onDelete)
        }
    }
}
