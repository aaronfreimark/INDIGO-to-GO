//
//  WebView.swift
//  Todos
//
//  Created by Bradley Hilton on 6/5/19.
//  Copyright © 2019 Brad Hilton. All rights reserved.
//  https://developer.apple.com/forums/thread/117348

import SwiftUI
import WebKit

struct WebViewView: View {
    @Environment(\.presentationMode)
    var presentationMode: Binding<PresentationMode>
    
    var request: URLRequest
    
    init(url: String?) {
        var thisURL: String?
        if url != "" { thisURL = url }
        self.request = URLRequest(url: URL(string: thisURL ?? "http://www.cloudmakers.eu")!)
    }

    var body: some View {
        NavigationView {
            WebView(request: request)
                .navigationBarTitle("Preview")
                .navigationBarItems(trailing: Button("Close", action: {
                    self.presentationMode.wrappedValue.dismiss()
                }))
        }
    }
}


struct WebView : UIViewRepresentable {
    
    let request: URLRequest

    func makeUIView(context: Context) -> WKWebView  {
        return WKWebView()
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        uiView.load(request)
    }
    
}

#if DEBUG
struct WebView_Previews : PreviewProvider {
    static var previews: some View {
        WebViewView(url: "https://www.apple.com")

    }
}
#endif
