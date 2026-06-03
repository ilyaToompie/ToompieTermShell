import SwiftData
import SwiftUI

struct ScopeMoveMenu: View {
    @EnvironmentObject private var loc: LocalizationManager
    @Query(sort: \Project.name) private var projects: [Project]
    let currentProjectID: UUID?
    let onCopy: (UUID?) -> Void
    let onMove: (UUID?) -> Void

    var body: some View {
        Menu {
            Menu(loc("scope.copyTo")) {
                targetButtons(action: onCopy)
            }
            Menu(loc("scope.moveTo")) {
                targetButtons(action: onMove)
            }
        } label: {
            Image(systemName: "arrow.left.arrow.right")
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
    }

    @ViewBuilder
    private func targetButtons(action: @escaping (UUID?) -> Void) -> some View {
        Button {
            action(nil)
        } label: {
            Label(loc("scope.global"), systemImage: "globe")
        }
        .disabled(currentProjectID == nil)

        ForEach(projects) { project in
            Button {
                action(project.id)
            } label: {
                Label("\(project.icon) \(project.name)", systemImage: project.id == currentProjectID ? "checkmark" : "folder")
            }
            .disabled(project.id == currentProjectID)
        }
    }
}
