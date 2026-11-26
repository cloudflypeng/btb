import SwiftUI
import WebKit

struct GeetestCaptchaSheet: View {
    let challenge: SMSCaptchaChallenge
    let onResult: (String, String) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            GeetestWebView(gt: challenge.gt, challenge: challenge.challenge) { validate, seccode in
                onResult(validate, seccode)
                dismiss()
            } onError: { _ in
                dismiss()
            }
            .ignoresSafeArea(edges: .bottom)
            .navigationTitle("安全验证")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("取消") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

private struct GeetestWebView: UIViewRepresentable {
    let gt: String
    let challenge: String
    let onResult: (String, String) -> Void
    let onError: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> WKWebView {
        let controller = WKUserContentController()
        controller.add(context.coordinator, name: "geetestSuccess")
        controller.add(context.coordinator, name: "geetestError")
        let config = WKWebViewConfiguration()
        config.userContentController = controller
        config.websiteDataStore = .nonPersistent()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        webView.loadHTMLString(Self.html(gt: gt, challenge: challenge),
                               baseURL: URL(string: "https://passport.bilibili.com"))
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    private static func html(gt: String, challenge: String) -> String {
        let stamp = Int(Date().timeIntervalSince1970 * 1000)
        let js = """
        var C,S,T,t;
        T=function(){if(C&&S&&!t){t=Geetest(C).onSuccess(function(){R("geetestSuccess",t.getValidate())}).onError(function(o){R("geetestError",o)}).onClose(function(o){R("geetestError",o)});t.onReady(function(){t.verify()})}};
        window.geetest_\(stamp)=function(d){
          if(!d||d.status!="success"){R("geetestError",JSON.stringify(d));return}
          C=Object.assign({gt:"\(gt)",challenge:"\(challenge)",offline:false,new_captcha:true,product:"bind",width:"100%",https:true,protocol:"https://"},d.data);
          T()
        };
        window.G=function(){S=1;T()};
        window.E=function(){document.getElementById("tip").textContent="验证码加载失败，请稍后重试"};
        """
        return """
        <!DOCTYPE html>
        <html>
        <head>
        <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1">
        <style>
          html,body{margin:0;padding:0;background:transparent;font-family:-apple-system,sans-serif}
          #tip{position:fixed;inset:0;display:flex;align-items:center;justify-content:center;color:#909090;font-size:14px}
        </style>
        </head>
        <body>
        <div id="tip">正在加载安全验证…</div>
        <script>
          var R=function(name,payload){try{window.webkit.messageHandlers[name].postMessage(payload)}catch(e){}};
          \(js)
        </script>
        <script src="https://static.geetest.com/static/js/fullpage.0.0.0.js" onload="G()" onerror="E()"></script>
        <script src="https://api.geetest.com/gettype.php?gt=\(gt)&callback=geetest_\(stamp)" onerror="E()"></script>
        </body>
        </html>
        """
    }

    final class Coordinator: NSObject, WKScriptMessageHandler {
        private let parent: GeetestWebView

        init(_ parent: GeetestWebView) {
            self.parent = parent
        }

        func userContentController(_ controller: WKUserContentController,
                                   didReceive message: WKScriptMessage) {
            switch message.name {
            case "geetestSuccess":
                guard let body = message.body as? [String: Any],
                      let validate = body["geetest_validate"] as? String,
                      let seccode = body["geetest_seccode"] as? String,
                      !validate.isEmpty, !seccode.isEmpty else { return }
                parent.onResult(validate, seccode)
            case "geetestError":
                parent.onError("\(message.body)")
            default:
                break
            }
        }
    }
}
