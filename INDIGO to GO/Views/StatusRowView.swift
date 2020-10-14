//
//  StatusRow.swift
//  INDIGO to GO
//
//  Created by Aaron Freimark on 9/30/20.
//

import Foundation
import SwiftUI

struct StatusRowView: View {
    var sr: StatusRow?
    let width: CGFloat = 20
        
    var body: some View {
        if sr != nil && sr!.isSet {
            
            HStack {
                iconView
                    .frame(width: width, alignment: .leading)
                Text(sr!.text)
                Spacer()
                Text(sr!.value)
                    .font(.callout).foregroundColor(.gray)
            }

        } else { EmptyView() }
    }
    
    private var iconView: some View {
        switch sr!.status {
        case .ok:
            return AnyView(Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green))
        case .warn:
            return AnyView(Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.yellow))
        case .alert:
            return AnyView(Image(systemName: "stop.fill")
                            .foregroundColor(.red))
        case .unknown:
            return AnyView(Image(systemName:"questionmark.circle")
                            .foregroundColor(.gray))
        case .blank:
            return AnyView(EmptyView())
        case let .custom(systemImage):
            return AnyView(Image(systemName: systemImage)
                        .foregroundColor(.gray))
        }
    }

}

struct StatusRowView_Previews: PreviewProvider {
    static var previews: some View {
        let sr = StatusRow(text: "Description", value: "Value", status: .ok)
        StatusRowView(sr: sr)
    }
}
