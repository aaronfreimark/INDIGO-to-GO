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
        
    var body: some View {
        if sr != nil && sr!.isSet {
            
            HStack {
                Label(
                    title: { Text(sr!.text) },
                    icon: { iconView }
                )
                Spacer()
                Text(sr!.value)
                    .foregroundColor(.gray)
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
        let sr = StatusRowText(text: "Description", value: "Value", status: .ok)
        StatusRowView(sr: sr)
            .previewLayout(PreviewLayout.sizeThatFits)
            .padding()

        let sr2 = StatusRowText(text: "Description", value: "Alert", status: .alert)
        StatusRowView(sr: sr2)
            .previewLayout(PreviewLayout.sizeThatFits)
            .padding()
            .background(Color(.systemBackground))
            .environment(\.colorScheme, .dark)

        let sr3 = StatusRowTime(text: "Description", status: .custom("star.fill"), date: Date())
        StatusRowView(sr: sr3)
            .previewLayout(PreviewLayout.sizeThatFits)
            .padding()
    }
}
