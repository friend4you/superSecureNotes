import SwiftUI

public struct ShareNoteView: View {
    @Bindable private var viewModel: DefaultShareNoteViewModel

    public init(viewModel: DefaultShareNoteViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        NavigationStack {
            Form {
                if viewModel.isSharing {
                    Section {
                        HStack {
                            Spacer()
                            ProgressView(ShareNoteUILocalization.localized("share.loading"))
                            Spacer()
                        }
                    }
                }

                if let errorMessage = viewModel.errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }

                Section {
                    TextField(
                        ShareNoteUILocalization.localized("share.emailField"),
                        text: $viewModel.recipientEmail
                    )
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    #endif
                    .autocorrectionDisabled()
                }

                Section {
                    Button(ShareNoteUILocalization.localized("share.button")) {
                        Task {
                            await viewModel.share()
                        }
                    }
                    .disabled(viewModel.isSharing)
                }
            }
            .navigationTitle(ShareNoteUILocalization.localized("share.title"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(ShareNoteUILocalization.localized("share.cancel")) {
                        viewModel.dismiss()
                    }
                    .disabled(viewModel.isSharing)
                }
            }
        }
    }
}
