import SwiftUI
import AppKit

public struct StatusBoardView: View {
    @ObservedObject var taskStore: TaskStore
    @State private var showCompleted = false
    
    public init(taskStore: TaskStore) {
        self.taskStore = taskStore
    }
    
    var activeAndPastDueTasks: [ReminderTask] {
        return (taskStore.activeTasks + taskStore.pastDueTasks).sorted { $0.reminderFiresAt < $1.reminderFiresAt }
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerView
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            
            Divider()
            
            ScrollView {
                VStack(spacing: 8) {
                    if activeAndPastDueTasks.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "clock.badge.checkmark")
                                .font(.system(size: 32, weight: .light))
                                .foregroundStyle(Color(nsColor: .tertiaryLabelColor))
                            Text("All clear")
                                .font(.body.weight(.medium))
                                .foregroundStyle(Color(nsColor: .secondaryLabelColor))
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 32)
                    } else {
                        ForEach(activeAndPastDueTasks) { task in
                            TaskRowView(task: task, store: taskStore)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 4)
                        }
                    }
                    
                    if taskStore.completedToday > 0 {
                        Divider()
                            .padding(.top, 4)
                        
                        let doneToday = taskStore.tasks.filter { task in
                            task.state == .done && Calendar.current.isDate(task.createdAt, inSameDayAs: taskStore.now())
                        }
                        let totalFocus = doneToday.compactMap { $0.completedAt?.timeIntervalSince($0.createdAt) ?? 0 }.reduce(0, +)
                        let totalSnoozes = doneToday.compactMap { $0.snoozeCount }.reduce(0, +)
                        
                        VStack(alignment: .leading, spacing: 0) {
                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    showCompleted.toggle()
                                }
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 10, weight: .bold))
                                        .rotationEffect(.degrees(showCompleted ? 90 : 0))
                                        .foregroundStyle(Color(nsColor: .tertiaryLabelColor))
                                        .frame(width: 14, height: 14)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("\(taskStore.completedToday) completed today")
                                            .font(.subheadline.weight(.medium))
                                            .foregroundStyle(Color(nsColor: .secondaryLabelColor))
                                        
                                        HStack(spacing: 6) {
                                            Text("Focus time: \(formatAggregateMins(totalFocus))")
                                            if totalSnoozes > 0 { Text("• Snoozes: \(totalSnoozes)") }
                                        }
                                        .font(.system(size: 11))
                                        .foregroundStyle(Color(nsColor: .tertiaryLabelColor))
                                    }
                                    
                                    Spacer()
                                }
                                .padding(.vertical, 6)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 16)
                            .padding(.top, 4)
                            
                            if showCompleted {
                                VStack(alignment: .leading, spacing: 14) {
                                    ForEach(doneToday) { task in
                                        CompletedTaskRowView(task: task)
                                            .transition(.opacity.combined(with: .move(edge: .top)))
                                    }
                                }
                                .padding(.top, 12)
                                .padding(.bottom, 8)
                                .padding(.leading, 38)
                                .padding(.trailing, 16)
                            }
                        }
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: showCompleted)
                    }
                }
                .padding(.vertical, 12)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: taskStore.tasks)
            }
        }
        .frame(width: 340, height: activeAndPastDueTasks.isEmpty && taskStore.completedToday == 0 ? 180 : 400, alignment: .top)
    }
    
    private var headerView: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                let count = taskStore.activeTasks.count
                if count == 0 {
                    Text("RemindMe")
                        .font(.title3.weight(.bold))
                    Text("Ready")
                        .font(.subheadline)
                        .foregroundStyle(Color(nsColor: .secondaryLabelColor))
                } else {
                    Text("\(count) Running")
                        .font(.title3.weight(.bold))
                    
                    let nextTask = taskStore.activeTasks.min(by: { $0.reminderFiresAt < $1.reminderFiresAt })!
                    let timeString = formatNextTime(nextTask.reminderFiresAt, now: taskStore.now())
                    Text("Next in \(timeString)")
                        .font(.subheadline)
                        .foregroundStyle(Color(nsColor: .secondaryLabelColor))
                }
                
                let total = taskStore.tasks.filter { Calendar.current.isDate($0.createdAt, inSameDayAs: taskStore.now()) }.count
                let progress = total > 0 ? Double(taskStore.completedToday) / Double(total) : 0.0
                ProgressView(value: progress).progressViewStyle(.linear).tint(.green).frame(height: 2).padding(.top, 6)
            }
            
            Spacer()
            
            HStack(spacing: 14) {
                SettingsLink {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(Color(nsColor: .tertiaryLabelColor))
                }
                .buttonStyle(.plain)
                .help("Settings")
                .simultaneousGesture(TapGesture().onEnded {
                    NSApp.activate(ignoringOtherApps: true)
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        NotificationCenter.default.post(name: NSNotification.Name("ClosePopoverOnly"), object: nil)
                    }
                })
                
                Button {
                    NotificationCenter.default.post(name: NSNotification.Name("ShowCommandWindow"), object: nil)
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(Color(nsColor: .controlAccentColor))
                }
                .buttonStyle(.plain)
                .help("Add task")
            }
        }
    }
    
    private func formatNextTime(_ date: Date, now: Date) -> String {
        let diff = Int(date.timeIntervalSince(now))
        if diff <= 0 { return "now" }
        if diff < 60 { return "\(diff)s" }
        let mins = diff / 60
        if mins < 60 { return "\(mins)m" }
        return "\(mins / 60)h \(mins % 60)m"
    }
    
    private func formatAggregateMins(_ interval: TimeInterval) -> String {
        let mins = Int(interval) / 60
        return mins < 60 ? "\(mins)m" : "\(mins / 60)h \(mins % 60)m"
    }
}

public struct TaskRowView: View {
    public let task: ReminderTask
    @ObservedObject public var store: TaskStore
    @State private var isHovering = false
    @State private var isExpanded = false
    
    public var body: some View {
        TimelineView(.periodic(from: Date(), by: 1.0)) { context in
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 12) {
                    Circle()
                        .fill(task.state == .pastDue ? Color.orange : Color.green)
                        .frame(width: 8, height: 8)
                    
                    Text(task.title)
                        .font(.system(.body, design: .rounded).weight(.medium))
                        .foregroundStyle(Color(nsColor: .labelColor))
                        .lineLimit(1)
                    
                    Spacer(minLength: 16)
                    
                    if isHovering {
                        HStack(spacing: 12) {
                            Button {
                                store.markStillRunning(id: task.id, newFiresAt: store.now().addingTimeInterval(300))
                            } label: {
                                Image(systemName: "moon.fill")
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.secondary)
                            .help("Snooze 5m")
                            
                            Button {
                                store.markDone(id: task.id)
                            } label: {
                                Image(systemName: "checkmark")
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(Color.green)
                            .help("Done")
                        }
                    } else {
                        Text(timeText(for: task, now: context.date))
                            .font(.system(.subheadline, design: .monospaced))
                            .foregroundStyle(colorForTime(task))
                    }
                }
                
                if task.snoozeCount > 0 || isHovering || isExpanded {
                    HStack(spacing: 8) {
                        Text("Estimated \(formatMins(task.originalDuration))")
                        if task.snoozeCount > 0 {
                            Text("• Snoozed \(task.snoozeCount)x")
                            let added = task.totalSnoozeDelay
                            if added > 0 { Text("• Delay +\(formatMins(added))") }
                        }
                    }
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(Color.secondary)
                    .padding(.leading, 20)
                }
                
                if isExpanded {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Created: \(formatTime(task.createdAt))")
                        if task.snoozeCount > 0 {
                            Text("Total extensions: +\(formatMins(task.totalSnoozeDelay))")
                        }
                        Text("Current target: \(formatTime(task.reminderFiresAt))")
                    }
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Color(nsColor: .tertiaryLabelColor))
                    .padding(.leading, 20)
                    .padding(.top, 4)
                }
            }
            .contentShape(Rectangle()) 
            .onHover { hover in
                withAnimation(.easeInOut(duration: 0.15)) {
                    isHovering = hover
                }
            }
            .onTapGesture {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isExpanded.toggle()
                }
            }
            .contextMenu {
                // Secret debug to advance time or test logic would go here, we just use delete
                Button("Delete") {
                    store.delete(id: task.id)
                }
            }
        }
    }
    
    // Time helpers
    private func formatMins(_ interval: TimeInterval) -> String {
        let mins = max(0, Int(interval) / 60)
        return mins < 60 ? "\(mins)m" : "\(mins / 60)h \(mins % 60)m"
    }
    
    private func formatTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.timeStyle = .short
        return f.string(from: date)
    }
    
    private func timeText(for task: ReminderTask, now: Date) -> String {
        if task.state == .pastDue { return "overdue" }
        let diff = Int(task.reminderFiresAt.timeIntervalSince(now))
        if diff <= 0 { return "0s" }
        if diff < 60 { return "\(diff)s" }
        let mins = diff / 60
        if mins < 60 { return "\(mins)m" }
        return "\(mins / 60)h \(mins % 60)m"
    }
    
    private func colorForTime(_ task: ReminderTask) -> Color {
        if task.state == .pastDue { return .orange }
        return Color(nsColor: .secondaryLabelColor)
    }
}

public struct CompletedTaskRowView: View {
    public let task: ReminderTask
    @State private var isExpanded = false
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color.green.opacity(0.8))
                    .font(.system(size: 12))
                
                Text(task.title)
                    .font(.body)
                    .foregroundStyle(Color(nsColor: .tertiaryLabelColor))
                    .strikethrough()
                
                Spacer()
                
                if let completedAt = task.completedAt {
                    let diff = completedAt.timeIntervalSince(task.createdAt)
                    Text("in \(formatMins(diff))")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(Color.secondary)
                }
            }
            
            if isExpanded || task.snoozeCount > 0 {
                HStack(spacing: 6) {
                    if task.snoozeCount > 0 { Text("Snoozed \(task.snoozeCount)x") }
                    let over = max(0, (task.completedAt ?? task.createdAt).timeIntervalSince(task.createdAt) - task.originalDuration)
                    if over >= 60 {
                        Text("• +\(formatMins(over)) over estimate")
                    } else if over < 60 {
                        Text("• Perfect timing ✓")
                            .foregroundStyle(Color.green.opacity(0.8))
                    }
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.secondary)
                .padding(.leading, 20)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isExpanded.toggle()
            }
        }
    }
    
    private func formatMins(_ interval: TimeInterval) -> String {
        let mins = max(0, Int(interval) / 60)
        return mins < 60 ? "\(mins)m" : "\(mins / 60)h \(mins % 60)m"
    }
}
