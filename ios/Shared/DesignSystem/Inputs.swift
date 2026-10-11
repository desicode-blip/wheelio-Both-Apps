import SwiftUI

/// Outlined field with the label sitting on the border (Material-style), helper and error text.
struct WTextField: View {
    let label: String
    @Binding var text: String
    var placeholder: String = ""
    var helper: String? = nil
    var error: String? = nil
    var leadingIcon: WIcon? = nil
    var keyboard: UIKeyboardType = .default
    var capitalization: TextInputAutocapitalization = .never
    var large: Bool = false
    var focusOnAppear: Bool = false
    /// Flip to true to move the cursor here (e.g. after the field above is done).
    var focusTrigger: Bool = false
    var submitLabel: SubmitLabel = .done
    var onSubmit: () -> Void = {}

    @FocusState var focused: Bool

    private var borderColor: Color {
        if error != nil { return WColor.destructive }
        return focused ? WColor.primary : WColor.border
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .topLeading) {
                HStack(spacing: 10) {
                    if let leadingIcon { WIconView(icon: leadingIcon, size: 16, color: WColor.secondary) }
                    TextField("", text: $text, prompt: Text(placeholder).foregroundStyle(WColor.placeholder))
                        .font(WFont.of(.value, size: large ? 24 : 17))
                        .tracking(large ? 1.5 : 0)
                        .foregroundStyle(WColor.heading)
                        .keyboardType(keyboard)
                        .textInputAutocapitalization(capitalization)
                        .autocorrectionDisabled()
                        .focused($focused)
                        .submitLabel(submitLabel)
                        .onSubmit(onSubmit)
                }
                .padding(.horizontal, 16)
                .frame(height: large ? 62 : 52)
                .background(WColor.white, in: RoundedRectangle(cornerRadius: WRadius.field))
                .overlay(RoundedRectangle(cornerRadius: WRadius.field)
                    .strokeBorder(borderColor, lineWidth: (focused || error != nil) ? 2 : 1))
                if !label.isEmpty && (focused || !text.isEmpty || error != nil) {
                    Text(label)
                        .wText(.label, color: error != nil ? WColor.destructive : (focused ? WColor.primaryStrong : WColor.secondary))
                        .padding(.horizontal, 4)
                        .background(WColor.white)
                        .offset(x: 12, y: -8)
                }
            }
            if let error {
                HStack(spacing: 6) {
                    WIconView(icon: .warning, size: 12, color: WColor.destructive)
                    Text(error).wText(.caption, color: WColor.destructive)
                }
            } else if let helper {
                Text(helper).wText(.caption)
            }
        }
        .onAppear { if focusOnAppear { DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { focused = true } } }
        .onChange(of: focusTrigger) { _, on in if on { focused = true } }
    }
}

/// Multi-line note box.
struct WTextArea: View {
    @Binding var text: String
    var placeholder: String = ""
    var height: CGFloat = 112

    var body: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: $text)
                .font(WFont.of(.value, size: 16))
                .foregroundStyle(WColor.heading)
                .scrollContentBackground(.hidden)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
            if text.isEmpty {
                Text(placeholder).wText(.value, color: WColor.placeholder, size: 16)
                    .padding(.horizontal, 15)
                    .padding(.vertical, 16)
                    .allowsHitTesting(false)
            }
        }
        .frame(height: height)
        .background(WColor.white, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(WColor.border))
    }
}

/// OTP boxes backed by one hidden text field.
struct WOtpField: View {
    @Binding var code: String
    var length: Int = 6
    var error: Bool = false
    var boxSize: CGFloat = 48
    var autoFocus: Bool = true

    @FocusState var focused: Bool

    var body: some View {
        ZStack {
            TextField("", text: $code)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .focused($focused)
                .opacity(0.02)
                .frame(width: 1, height: 1)
                .onChange(of: code) { _, new in
                    let digits = String(new.filter(\.isNumber).prefix(length))
                    if digits != new { code = digits }
                }
            HStack(spacing: 10) {
                ForEach(0..<length, id: \.self) { i in
                    let chars = Array(code)
                    let ch = i < chars.count ? String(chars[i]) : ""
                    let isCursor = focused && i == min(chars.count, length - 1) && !error
                    Text(ch)
                        .font(WFont.of(.section, weight: .medium, size: boxSize * 0.46))
                        .foregroundStyle(WColor.heading)
                        .frame(width: boxSize, height: boxSize * 1.15)
                        .background(WColor.white, in: RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(
                            error ? WColor.destructive : (isCursor || !ch.isEmpty ? (isCursor ? WColor.primary : WColor.border) : WColor.border),
                            lineWidth: (error || isCursor) ? 2 : 1))
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { focused = true }
        }
        .onAppear { if autoFocus { DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { focused = true } } }
    }
}

/// Phone field: "+91" box and the number field.
struct WPhoneField: View {
    @Binding var number: String
    var error: String? = nil
    var large: Bool = false
    var focusOnAppear: Bool = true
    var focusTrigger: Bool = false

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text("+91")
                .font(WFont.of(.value, size: large ? 19 : 17))
                .foregroundStyle(WColor.heading)
                .frame(width: large ? 72 : 82, height: large ? 62 : 52)
                .background(WColor.white, in: RoundedRectangle(cornerRadius: WRadius.field))
                .overlay(RoundedRectangle(cornerRadius: WRadius.field).strokeBorder(WColor.border))
            WTextField(label: large ? "" : "Mobile number", text: $number, placeholder: "9876543210", error: error,
                       keyboard: .phonePad, large: large, focusOnAppear: focusOnAppear, focusTrigger: focusTrigger)
                .onChange(of: number) { _, new in
                    // Digits only, no spaces; anything after the first 10 digits is ignored.
                    let d = String(Validators.digitsOnly(new).prefix(10))
                    if d != new { number = d }
                }
        }
    }
}
