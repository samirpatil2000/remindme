import SwiftUI

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
                        
                        DisclosureGroup(isExpanded: $showCompleted) {
                            let doneToday = taskStore.tasks.filter { task in
                                task.state == .done && Calendar.current.isDate(task.createdAt, inSameDayAs: taskStore.now())
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(doneToday) { task in
                                    HStack(spacing: 8) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(Color.green.opacity(0.8))
                                            .font(.system(size: 12))
                                        Text(task.title)
                                            .font(.body)
                                            .foregroundStyle(Color(nsColor: .tertiaryLabelColor))
                                            .strikethrough()
                                    }
                                }
                            }
                            .padding(.top, 8)
                            .padding(.bottom, 4)
                            .padding(.leading, 4)
                        } label: {
                            Text("\(taskStore.completedToday) completed today")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(Color(nsColor: .secondaryLabelColor))
                        }
                        .accentColor(Color(nsColor: .secondaryLabelColor))
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                    }
                }
                .padding(.vertical, 12)
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
            }
            
            Spacer()
            
            HStack(spacing: 14) {
                if #available(macOS 14.0, *) {
                    SettingsLink {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 15))
                            .foregroundStyle(Color(nsColor: .tertiaryLabelColor))
                    }
                    .buttonStyle(.plain)
                    .help("Settings")
                    .simultaneousGesture(TapGesture().onEnded {
                        NotificationCenter.default.post(name: NSNotification.Name("ClosePopoverOnly"), object: nil)
                    })
                } else {
                    Button {
                        NotificationCenter.default.post(name: NSNotification.Name("ShowSettingsWindow"), object: nil)
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 15))
                            .foregroundStyle(Color(nsColor: .tertiaryLabelColor))
                    }
                    .buttonStyle(.plain)
                    .help("Settings")
                }
                
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
}

public struct TaskRowView: View {
    public let task: ReminderTask
    @ObservedObject public var store: TaskStore
    @State private var isHovering = false
    
    public var body: some View {
        TimelineView(.periodic(from: Date(), by: 1.0)) { context in
            HStack(spacing: 12) {
                // Status Dot
                Circle()
                    .fill(task.state == .pastDue ? Color.orange : Color.green)
                    .frame(width: 8, height: 8)
                
                Text(task.title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(Color(nsColor: .labelColor))
                    .lineLimit(1)
                
                Spacer(minLength: 16)
                
                if isHovering {
                    HStack(spacing: 12) {
                        Button {
                            store.markStillRunning(id: task.id, newFiresAt: store.now().addingTimeInterval(600))
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(Color(nsColor: .secondaryLabelColor))
                        .help("Still Running (10m)")
                        
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
            .contentShape(Rectangle()) 
            .onHover { hover in
                withAnimation(.easeInOut(duration: 0.15)) {
                    isHovering = hover
                }
            }
            .contextMenu {
                Button("Delete") {
                    store.delete(id: task.id)
                }
            }
        }
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
