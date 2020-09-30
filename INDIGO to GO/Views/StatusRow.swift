//
//  StatusRow.swift
//  INDIGO to GO
//
//  Created by Aaron Freimark on 9/30/20.
//

import Foundation
import SwiftUI

struct StatusRow: View {
    var description: String
    var subtext: String?
    var status: String?
    let width: CGFloat = 20
    
    private var iconView: some View {
        switch status {
        case "ok":
            return AnyView(Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green).frame(width: width, alignment: .leading))
        case "warn":
            return AnyView(Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.yellow).frame(width: width, alignment: .leading))
        case "alert":
            return AnyView(Image(systemName: "stop.fill")
                .foregroundColor(.red).frame(width: width, alignment: .leading))
        case "unknown":
            return AnyView(Image(systemName:"questionmark.circle")
                .foregroundColor(.gray).frame(width: width, alignment: .leading))
        case "", nil:
            return AnyView(EmptyView().frame(width: width))
        default: return
            AnyView(Image(systemName:status!)
            .foregroundColor(.gray).frame(width: width, height: nil, alignment: .leading))
        }
    }
    
    private var subtextView: some View {
        if subtext != nil {
            return Text(subtext!).font(.callout).foregroundColor(.gray)
        }
        return Text("")
    }
    
    var body: some View {
        HStack {
            iconView
            Text(description)
            Spacer()
            subtextView
        }
    }
}
