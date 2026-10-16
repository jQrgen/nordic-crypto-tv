import SwiftUI

/// Publisher contact details. The section title is the localized "Contact us"
/// (Play's News and magazines policy: a clearly labeled contact section).
struct ContactView: View {
    /// When set, the screen can be closed (Apple TV overlay, not a tab).
    var onClose: (() -> Void)? = nil

    @Environment(\.openURL) private var openURL
    @FocusState private var focus: Field?

    private enum Field: Hashable { case email, website, page, close }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: NLMetrics.gutter) {
                Text("Contact us")
                    .font(NLFont.display)
                    .foregroundStyle(NL.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("contact-screen")

                publisher

                link(.email, title: "Email", value: APIConfig.contactEmail, url: APIConfig.contactMailto)
                link(.website, title: "Website", value: APIConfig.website.absoluteString, url: APIConfig.website)
                link(.page, title: "Contact page", value: APIConfig.contactPage.absoluteString, url: APIConfig.contactPage)

                if let onClose {
                    Button(action: onClose) {
                        Text("Done")
                            .font(NLFont.row)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                    #if os(tvOS)
                    .buttonStyle(.bordered)
                    #endif
                    .focused($focus, equals: .close)
                    .accessibilityIdentifier("contact-done")
                }
            }
            .padding(NLMetrics.margin)
            .frame(maxWidth: 720, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .background(NLBackground())
        .navigationTitle("Contact us")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onAppear { focus = .email }
        #if os(tvOS)
        .onExitCommand { onClose?() }
        #endif
    }

    private var publisher: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Publisher")
                .font(NLFont.kicker)
                .foregroundStyle(NL.textSecondary)
            Text(verbatim: APIConfig.publisherName)
                .font(NLFont.title)
                .foregroundStyle(NL.textPrimary)
            Text(verbatim: APIConfig.publisherCompany)
                .font(NLFont.row)
                .foregroundStyle(NL.textPrimary)
                .accessibilityIdentifier("publisher-company")
            VStack(alignment: .leading, spacing: 2) {
                Text("Organization number")
                    .font(NLFont.caption)
                    .foregroundStyle(NL.textTertiary)
                Text(verbatim: APIConfig.publisherOrgNo)
                    .font(NLFont.body)
                    .foregroundStyle(NL.textPrimary)
                    .accessibilityIdentifier("publisher-org")
            }
            Text("Oslo, Norway")
                .font(NLFont.body)
                .foregroundStyle(NL.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(NLMetrics.cardPadding)
        .nlGlass(cornerRadius: NLMetrics.rowRadius)
    }

    private func link(_ field: Field, title: LocalizedStringKey, value: String, url: URL) -> some View {
        Button {
            openURL(url)
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(NLFont.kicker)
                    .foregroundStyle(NL.accent)
                Text(verbatim: value)
                    .font(NLFont.body)
                    .foregroundStyle(NL.textPrimary)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(NLMetrics.cardPadding)
            #if !os(tvOS)
            .nlGlass(cornerRadius: NLMetrics.rowRadius)
            #endif
        }
        #if os(tvOS)
        .buttonStyle(.card)
        #else
        .buttonStyle(.plain)
        #endif
        .focused($focus, equals: field)
        .accessibilityIdentifier(identifier(field))
        .accessibilityValue(Text(verbatim: value))
    }

    private func identifier(_ field: Field) -> String {
        switch field {
        case .email: "contact-email"
        case .website: "contact-website"
        case .page: "contact-page"
        case .close: "contact-done"
        }
    }
}
