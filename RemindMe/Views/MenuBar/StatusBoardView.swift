import SwiftUI
import AppKit

public struct StatusBoardView: View {
    @ObservedObject var taskStore: TaskStore
    @State private var showCompleted = false
    @State private var isHoveringCompletedHeader = false
    
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
                        VStack(spacing: 6) {
                            ZStack {
                                Circle()
                                    .fill(Color(nsColor: .controlBackgroundColor))
                                    .frame(width: 56, height: 56)
                                    .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 2)
                                
                                Image(systemName: "checkmark")
                                    .font(.system(size: 22, weight: .medium))
                                    .foregroundStyle(Color.green.opacity(0.8))
                            }
                            .padding(.bottom, 8)
                            
                            Text("All clear")
                                .font(.system(.body, design: .rounded).weight(.medium))
                                .foregroundStyle(Color.primary)
                            
                            Text("Take a breath or start something new.")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.secondary)
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
                                
                                Button("Clear") {
                                    withAnimation {
                                        taskStore.clearCompleted()
                                    }
                                }
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(Color.secondary)
                                .buttonStyle(.plain)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color(NSColor.controlBackgroundColor).opacity(isHoveringCompletedHeader ? 0.8 : 0))
                                .cornerRadius(4)
                                .opacity(isHoveringCompletedHeader ? 1 : 0)
                            }
                            .padding(.vertical, 6)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    showCompleted.toggle()
                                }
                            }
                            .onHover { hover in
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    isHoveringCompletedHeader = hover
                                }
                            }
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
        .frame(width: 340, height: activeAndPastDueTasks.isEmpty && taskStore.completedToday == 0 ? 240 : 400, alignment: .top)
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
                if total > 0 {
                    let progress = Double(taskStore.completedToday) / Double(total)
                    ProgressView(value: progress).progressViewStyle(.linear).tint(.green).frame(height: 2).padding(.top, 6)
                } else {
                    Spacer().frame(height: 8)
                }
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
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                    )
                    .padding(.leading, 20)
                    .padding(.top, 2)
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
            
            if task.snoozeCount > 0 {
                HStack(spacing: 6) {
                    Text("Snoozed \(task.snoozeCount)x")
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
            
            if isExpanded {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Created: \(formatTime(task.createdAt))")
                    if task.snoozeCount > 0 {
                        Text("Total extensions: +\(formatMins(task.totalSnoozeDelay))")
                    }
                    if let completedAt = task.completedAt {
                        Text("Completed: \(formatTime(completedAt))")
                    }
                }
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(Color(nsColor: .tertiaryLabelColor))
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                )
                .padding(.leading, 20)
                .padding(.top, 2)
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
    
    private func formatTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.timeStyle = .short
        return f.string(from: date)
    }
}
