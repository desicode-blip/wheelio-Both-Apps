import SwiftUI

// MARK: Support ladder: 1) quick check by the app → 2) sort it out with the owner → 3) Wheelio team
// There is no "call us" button up front. Only safety emergencies call directly.

enum CaptainHelpTopic: String, CaseIterable, Hashable {
    case money, job, rating, app

    var icon: WIcon {
        switch self {
        case .money: return .rupee
        case .job: return .car
        case .rating: return .star
        case .app: return .phone
        }
    }

    @MainActor func title(_ s: CaptainStore) -> String {
        switch self {
        case .money: return s.t("Money or payout", "पैसे या पेमेंट", "డబ్బు లేదా చెల్లింపు")
        case .job: return s.t("Problem at a job", "काम पर समस्या", "పనిలో సమస్య")
        case .rating: return s.t("Rating or photo check", "रेटिंग या फ़ोटो जाँच", "రేటింగ్ లేదా ఫోటో తనిఖీ")
        case .app: return s.t("App not working", "ऐप नहीं चल रहा", "యాప్ పనిచేయట్లేదు")
        }
    }

    /// App problems skip the owner step.
    var usesOwner: Bool { self != .app }
}

/// Three small steps, shown on Help and inside each problem.
struct HelpLadder: View {
    @Environment(CaptainStore.self) var store
    /// 0 = just showing the steps; 1...3 = current step.
    let current: Int
    var skipOwner = false

    var body: some View {
        HStack(spacing: 6) {
            step(1, .sparkle, store.t("Quick check", "जल्दी जाँच", "త్వరిత తనిఖీ"))
            line(1)
            step(2, .user, store.t("Owner", "मालिक", "యజమాని"), skipped: skipOwner)
            line(2)
            step(3, .chat, store.t("Our team", "हमारी टीम", "మా బృందం"))
        }
        .padding(12)
        .background(WColor.canvas, in: RoundedRectangle(cornerRadius: 14))
    }

    func step(_ n: Int, _ icon: WIcon, _ label: String, skipped: Bool = false) -> some View {
        let done = current > n, now = current == n
        return VStack(spacing: 6) {
            WIconView(icon: done ? .check : icon, size: 15, color: done ? WColor.onSuccess : (now ? .white : WColor.primaryStrong))
                .frame(width: 34, height: 34)
                .background(done ? WColor.success : (now ? WColor.primary : WColor.primaryTint), in: Circle())
                .opacity(skipped ? 0.4 : 1)
            Text(label).wText(.small, color: now ? WColor.heading : WColor.secondary, weight: now ? .semibold : .regular)
                .lineLimit(1).minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
    }

    func line(_ after: Int) -> some View {
        Rectangle().fill(current > after ? WColor.success : WColor.border).frame(height: 2).frame(maxWidth: 30)
            .padding(.bottom, 18)
    }
}

struct HelpFlowScreen: View {
    @Environment(CaptainStore.self) var store
    @Environment(WRouter.self) var router
    let topic: CaptainHelpTopic

    @State private var level = 1
    @State private var checking = true
    @State private var jobIssue: Int? = nil
    @State private var sentMessage: String? = nil
    @State private var calledOwner = false
    @State private var callbackRequested = false
    @State private var solved = false

    var body: some View {
        WScreen(gutter: WSpace.gutterCaptain) {
            WHeader(title: topic.title(store), help: false)
        } content: {
            HelpLadder(current: solved ? 4 : level, skipOwner: !topic.usesOwner).padding(.top, 10).padding(.bottom, 20)
            if solved {
                solvedView
            } else {
                switch level {
                case 1: quickCheck
                case 2: ownerStep
                default: teamStep
                }
            }
        } footer: {
            if !solved {
                WFooter {
                    VStack(spacing: 6) {
                        if level < 3 {
                            WButton(store.t("Solved", "हल हो गया", "పరిష్కారమైంది"), icon: .check, size: .captain, enabled: !(level == 1 && checking)) {
                                withAnimation { solved = true }
                            }
                            WButton(store.t("Still a problem", "अभी भी समस्या है", "ఇంకా సమస్య ఉంది"), kind: .text) {
                                withAnimation { level = (level == 1 && !topic.usesOwner) ? 3 : level + 1 }
                            }
                            .disabled(level == 1 && checking)
                        } else if !callbackRequested {
                            WButton(store.t("Ask our team to call me", "हमारी टीम से कॉल मँगवाएं", "మా బృందం కాల్ చేయమనండి"), icon: .phone, size: .captain) {
                                withAnimation { callbackRequested = true }
                            }
                        } else {
                            WButton(store.t("Back to home", "होम पर वापस", "హోమ్‌కి తిరిగి"), size: .captain) { router.home() }
                        }
                    }
                }
            }
        }
        .task {
            // Step 1: the app checks first (photos, payouts, job status).
            try? await Task.sleep(nanoseconds: 1_800_000_000)
            withAnimation { checking = false }
        }
    }

    // MARK: Step 1: quick check by the app

    @ViewBuilder var quickCheck: some View {
        Text(store.t("Step 1 · We’re checking", "कदम 1 · हम जाँच रहे हैं", "దశ 1 · మేము తనిఖీ చేస్తున్నాం")).wText(.label, color: WColor.secondary)
        if checking {
            VStack(spacing: 14) {
                WStateCircle(icon: .sparkle, size: 92, spinning: true)
                Text(store.t("Checking photos and job details…", "फ़ोटो और काम की जानकारी देख रहे हैं…", "ఫోటోలు, పని వివరాలు చూస్తున్నాం…")).wBodyBig()
            }
            .frame(maxWidth: .infinity).padding(.top, 30)
        } else {
            switch topic {
            case .money:
                result(.lock, .wait,
                       store.t("₹116 is on hold", "₹116 रोके गए हैं", "₹116 నిలిపివేయబడింది"),
                       store.t("Owner said the bonnet had water streaks. Your after-photos look clean, so we asked the owner to check again. Other jobs are paid as normal.",
                               "मालिक ने कहा बोनट पर पानी के निशान थे। आपकी बाद की फ़ोटो साफ़ हैं, इसलिए हमने मालिक से फिर देखने को कहा। बाकी कामों के पैसे सामान्य रूप से मिलेंगे।",
                               "బానెట్‌పై నీటి గీతలు ఉన్నాయని యజమాని చెప్పారు. మీ తర్వాతి ఫోటోలు శుభ్రంగా ఉన్నాయి, అందుకే మళ్ళీ చూడమని యజమానిని అడిగాము. మిగతా పనుల డబ్బు మామూలుగానే వస్తుంది."))
                photoCompare
            case .rating:
                result(.checkCircle, .ok,
                       store.t("Your photos look good", "आपकी फ़ोटो ठीक हैं", "మీ ఫోటోలు బాగున్నాయి"),
                       store.t("We compared before and after photos. If they show a good wash, a low rating won’t count against you.",
                               "हमने पहले और बाद की फ़ोटो मिलाईं। अगर धुलाई अच्छी दिखी, तो कम रेटिंग आपके ख़िलाफ़ नहीं गिनी जाएगी।",
                               "ముందు, తర్వాతి ఫోటోలు పోల్చాము. వాష్ బాగుంటే, తక్కువ రేటింగ్ మీకు వ్యతిరేకంగా లెక్కించబడదు."))
                photoCompare
            case .app:
                result(.refresh, .info,
                       store.t("Try these", "ये करके देखें", "ఇవి ప్రయత్నించండి"),
                       store.t("1. Turn internet off and on.  2. Close the app and open again.  3. Keep battery above 15%. Your photos are saved on the phone.",
                               "1. इंटरनेट बंद करके चालू करें।  2. ऐप बंद करके फिर खोलें।  3. बैटरी 15% से ऊपर रखें। आपकी फ़ोटो फ़ोन में सेव हैं।",
                               "1. ఇంటర్నెట్ ఆఫ్ చేసి ఆన్ చేయండి.  2. యాప్ మూసి మళ్ళీ తెరవండి.  3. బ్యాటరీ 15% పైన ఉంచండి. మీ ఫోటోలు ఫోన్‌లో సేవ్ అయ్యాయి."))
            case .job:
                Text(store.t("What happened?", "क्या हुआ?", "ఏమైంది?")).wText(.section, weight: .semibold).padding(.top, 10).padding(.bottom, 10)
                let issues: [(WIcon, String, String)] = [
                    (.door, store.t("Can’t get in", "अंदर नहीं जा पा रहे", "లోపలికి వెళ్ళలేకపోతున్నాను"),
                     store.t("Show the owner’s gate pass to the guard. It’s on the Go to vehicle screen.", "गार्ड को मालिक का गेट पास दिखाएं। यह ‘गाड़ी तक जाएं’ स्क्रीन पर है।", "గార్డ్‌కి యజమాని గేట్ పాస్ చూపించండి. ఇది ‘వాహనం దగ్గరికి వెళ్ళండి’ స్క్రీన్‌లో ఉంది.")),
                    (.search, store.t("Can’t find vehicle", "गाड़ी नहीं मिल रही", "వాహనం కనబడట్లేదు"),
                     store.t("Check the owner’s vehicle photos and slot number. The plate on the vehicle must match.", "मालिक की गाड़ी की फ़ोटो और स्लॉट नंबर देखें। गाड़ी की प्लेट मिलनी चाहिए।", "యజమాని వాహనం ఫోటోలు, స్లాట్ నంబర్ చూడండి. ప్లేట్ సరిపోలాలి.")),
                    (.warning, store.t("Vehicle already damaged", "गाड़ी पहले से खराब है", "వాహనం ముందే దెబ్బతింది"),
                     store.t("Take a clear before-photo of the damage. Our photo check marks it as old damage, so you’re safe.", "नुकसान की साफ़ ‘पहले’ फ़ोटो लें। फ़ोटो जाँच इसे पुराना नुकसान मानेगी, आप सुरक्षित हैं।", "దెబ్బను స్పష్టంగా ‘ముందు’ ఫోటో తీయండి. ఫోటో తనిఖీ దాన్ని పాత దెబ్బగా గుర్తిస్తుంది.")),
                    (.drop, store.t("No water available", "पानी नहीं है", "నీళ్ళు లేవు"),
                     store.t("Use the society tap near the lift or ask the guard. For a water wash, 1 bucket is enough.", "लिफ़्ट के पास का नल इस्तेमाल करें या गार्ड से पूछें। पानी वाली धुलाई के लिए 1 बाल्टी काफ़ी है।", "లిఫ్ట్ దగ్గర కుళాయి వాడండి లేదా గార్డ్‌ని అడగండి. 1 బకెట్ చాలు.")),
                ]
                VStack(spacing: 10) {
                    ForEach(Array(issues.enumerated()), id: \.offset) { i, it in
                        WSelectionTile(icon: it.0, title: it.1, selected: jobIssue == i, radio: true) { withAnimation { jobIssue = i } }
                    }
                }
                if let i = jobIssue {
                    result(.sparkle, .info, store.t("Try this", "ये करें", "ఇది చేయండి"), issues[i].2).padding(.top, 6)
                }
            }
        }
    }

    func result(_ icon: WIcon, _ tone: WTone, _ title: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            WIconView(icon: icon, size: 20, color: tone == .ok ? WColor.onSuccess : tone.bannerText)
            VStack(alignment: .leading, spacing: 6) {
                Text(title).wText(.title, size: 18)
                Text(text).wText(.body, size: 15.5).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(tone.background, in: RoundedRectangle(cornerRadius: 16))
        .padding(.top, 12)
        .transition(.opacity)
    }

    var photoCompare: some View {
        HStack(spacing: 8) {
            WPhotoPlaceholder(icon: .car, tag: store.t("Before", "पहले", "ముందు")).frame(height: 92)
            WPhotoPlaceholder(icon: .sparkle, tag: store.t("After", "बाद", "తర్వాత"), tagTone: .ok).frame(height: 92)
        }
        .padding(.top, 12)
    }

    // MARK: Step 2: sort it out with the owner

    @ViewBuilder var ownerStep: some View {
        let j = store.current
        Text(store.t("Step 2 · Talk to the owner", "कदम 2 · मालिक से बात करें", "దశ 2 · యజమానితో మాట్లాడండి")).wText(.label, color: WColor.secondary)
        HStack(spacing: 12) {
            WAvatar(initials: String(j.owner.prefix(1)), size: 52)
            VStack(alignment: .leading, spacing: 4) {
                Text(j.owner).wText(.title, size: 18)
                Text("\(j.society) · \(j.plate)").wText(.caption)
            }
            Spacer()
        }
        .wCard(padding: 16)
        .padding(.top, 10)
        Text(store.t("Send a quick message", "जल्दी संदेश भेजें", "త్వరగా సందేశం పంపండి")).wText(.label).padding(.top, 18).padding(.bottom, 8)
        let msgs = [
            store.t("I’m at the gate. Please allow entry.", "मैं गेट पर हूँ। कृपया अंदर आने दें।", "నేను గేట్ దగ్గర ఉన్నాను. లోపలికి అనుమతించండి."),
            store.t("I can’t find the vehicle. Is it in the slot?", "गाड़ी नहीं मिल रही। क्या स्लॉट में है?", "వాహనం కనబడట్లేదు. స్లాట్‌లో ఉందా?"),
            store.t("Please check the photos in the app.", "कृपया ऐप में फ़ोटो देखें।", "దయచేసి యాప్‌లో ఫోటోలు చూడండి."),
        ]
        VStack(spacing: 8) {
            ForEach(msgs, id: \.self) { m in
                Button { withAnimation { sentMessage = m } } label: {
                    HStack(spacing: 10) {
                        WIconView(icon: sentMessage == m ? .checkCircle : .chat, size: 16, color: sentMessage == m ? WColor.success : WColor.primaryStrong)
                        Text(m).wText(.body, size: 15.5).multilineTextAlignment(.leading)
                        Spacer(minLength: 0)
                    }
                    .padding(14)
                    .background(sentMessage == m ? WColor.successTint : .white, in: RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(WColor.border))
                }
                .buttonStyle(.plain)
            }
        }
        if sentMessage != nil {
            Text(store.t("Sent. The owner gets it on WhatsApp.", "भेज दिया। मालिक को WhatsApp पर मिलेगा।", "పంపాము. యజమానికి WhatsApp లో వస్తుంది."))
                .wText(.caption, color: WColor.onSuccess).padding(.top, 8)
        }
        Button { calledOwner = true; Support.call() } label: {
            HStack(spacing: 10) {
                WIconView(icon: .phone, size: 16, color: WColor.primaryStrong)
                Text(store.t("Call owner (number stays hidden)", "मालिक को कॉल करें (नंबर छिपा रहेगा)", "యజమానికి కాల్ (నంబర్ దాచి ఉంటుంది)")).wText(.title, color: WColor.primaryStrong, size: 16)
                Spacer()
            }
            .padding(14)
            .background(WColor.primaryTint, in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .padding(.top, 12)
    }

    // MARK: Step 3: Wheelio team (callback, not a direct line)

    @ViewBuilder var teamStep: some View {
        Text(store.t("Step 3 · Our team", "कदम 3 · हमारी टीम", "దశ 3 · మా బృందం")).wText(.label, color: WColor.secondary)
        if callbackRequested {
            VStack(spacing: 12) {
                WStateCircle(icon: .phone, tone: .ok, size: 96)
                Text(store.t("We’ll call you soon", "हम जल्दी कॉल करेंगे", "మేము త్వరలో కాల్ చేస్తాము")).wText(.section, weight: .semibold, size: 22)
                Text(store.t("Within 30 minutes on \(Fmt.phone(store.phone)). Keep your phone close.",
                             "30 मिनट में \(Fmt.phone(store.phone)) पर। फ़ोन पास रखें।",
                             "30 నిమిషాల్లో \(Fmt.phone(store.phone)) కి. ఫోన్ దగ్గర ఉంచుకోండి."))
                    .wBodyBig().multilineTextAlignment(.center)
                Text(store.t("Ticket", "टिकट", "టికెట్") + " #WH-2814").wText(.caption)
            }
            .frame(maxWidth: .infinity).padding(.top, 24)
        } else {
            Text(store.t("Sorry this didn’t get fixed. Our team will look at your photos and job, then call you.",
                         "माफ़ करें, यह ठीक नहीं हुआ। हमारी टीम आपकी फ़ोटो और काम देखकर आपको कॉल करेगी।",
                         "క్షమించండి, ఇది తీరలేదు. మా బృందం మీ ఫోటోలు, పని చూసి మీకు కాల్ చేస్తుంది."))
                .wBodyBig().padding(.top, 8)
            HStack(spacing: 10) {
                WIconView(icon: .clock, size: 16, color: WColor.secondary)
                Text("7 AM – 9 PM · Hindi, Telugu, English").wText(.caption)
            }
            .padding(.top, 14)
            WButton(store.t("Explain by voice (optional)", "आवाज़ में बताएं (ज़रूरी नहीं)", "వాయిస్‌తో చెప్పండి (ఐచ్ఛికం)"), icon: .mic, kind: .outline, size: .captain) {}
                .padding(.top, 18)
        }
    }

    var solvedView: some View {
        VStack(spacing: 12) {
            WStateCircle(icon: .check, tone: .ok, size: 96)
            Text(store.t("Glad it’s sorted", "अच्छा हुआ, हल हो गया", "తీరింది, సంతోషం")).wText(.section, weight: .semibold, size: 22)
            Text(store.t("You can come back to Help any time.", "आप कभी भी मदद पर वापस आ सकते हैं।", "ఎప్పుడైనా సహాయానికి రావచ్చు.")).wBodyBig()
            WButton(store.t("Back to home", "होम पर वापस", "హోమ్‌కి తిరిగి"), size: .captain) { router.home() }.padding(.top, 10)
        }
        .frame(maxWidth: .infinity).padding(.top, 24)
    }
}
