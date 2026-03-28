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
        VStack(alignment: .leading, spacing: 12) {
            headerView
            
            Divider()
            
            if activeAndPastDueTasks.isEmpty {
                Text("Nothing running")
                    .font(.body)
                    .foregroundStyle(Color(nsColor: .secondaryLabelColor))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            } else {
                ForEach(activeAndPastDueTasks) { task in
                    TaskRowView(task: task, store: taskStore)
                }
            }
            
            if taskStore.completedToday > 0 {
                Divider()
                DisclosureGroup(isExpanded: $showCompleted) {
                    let doneToday = taskStore.tasks.filter { task in
                        task.state == .done && Calendar.current.isDate(task.createdAt, inSameDayAs: taskStore.now())
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(doneToday) { task in
                            Text(task.title)
                                .font(.body)
                                .foregroundStyle(Color(nsColor: .secondaryLabelColor))
                                .strikethrough()
                        }
                    }
                    .padding(.top, 4)
                } label: {
                    Text("\(taskStore.completedToday) completed today")
                        .font(.body)
                        .foregroundStyle(Color(nsColor: .labelColor))
                }
            }
        }
        .padding()
        .frame(width: 320)
    }
    
    private var headerView: some View {
        HStack {
            Group {
                let count = taskStore.activeTasks.count
                if count == 0 {
                    Text("0 running")
                        .font(.headline)
                } else {
                    let nextTask = taskStore.activeTasks.min(by: { $0.reminderFiresAt < $1.reminderFiresAt })!
                    let timeString = formatNextTime(nextTask.reminderFiresAt, now: taskStore.now())
                    Text("⏱ \(count) running — next in \(timeString)")
                        .font(.headline)
                }
            }
            Spacer()
            Button {
                NotificationCenter.default.post(name: NSNotification.Name("ShowSettingsWindow"), object: nil)
            } label: {
                Image(systemName: "gear")
                    .font(.body.weight(.bold))
                    .foregroundStyle(Color(nsColor: .secondaryLabelColor))
            }
            .buttonStyle(.plain)
            .help("Settings")
            
            Button {
                NotificationCenter.default.post(name: NSNotification.Name("ShowCommandWindow"), object: nil)
            } label: {
                Image(systemName: "plus")
                    .font(.body.weight(.bold))
                    .foregroundStyle(Color(nsColor: .secondaryLabelColor))
            }
            .buttonStyle(.plain)
            .help("Add new task")
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
            HStack {
                Text(task.title)
                    .font(.headline)
                    .foregroundStyle(Color(nsColor: .labelColor))
                    .lineLimit(1)
                
                Spacer()
                
                if isHovering {
                    HStack(spacing: 8) {
                        Button("Still Running") {
                            store.markStillRunning(id: task.id, newFiresAt: store.now().addingTimeInterval(600))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(Color(nsColor: .controlAccentColor))
                        
                        Button("Done") {
                            store.markDone(id: task.id)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(Color(nsColor: .controlAccentColor))
                    }
                    .font(.body)
                } else {
                    Text(timeText(for: task, now: context.date))
                        .font(.subheadline)
                        .foregroundStyle(colorForTime(task))
                }
            }
            .contentShape(Rectangle()) 
            .onHover { hover in
                isHovering = hover
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
