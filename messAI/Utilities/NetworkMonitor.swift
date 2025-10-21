//
//  NetworkMonitor.swift
//  messAI
//
//  Created by Isaac Jaramillo on October 20, 2025.
//  Purpose: Monitor network connectivity for offline/online detection
//

import Network
import Combine
import Foundation

class NetworkMonitor: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = NetworkMonitor()
    
    // MARK: - Properties
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    @Published var isConnected: Bool = true
    @Published var connectionType: NWInterface.InterfaceType?
    
    // MARK: - Initialization
    
    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                let wasConnected = self?.isConnected ?? true
                self?.isConnected = path.status == .satisfied
                
                // Log connection changes
                if wasConnected != self?.isConnected {
                    if self?.isConnected == true {
                        print("🟢 Network: Online")
                    } else {
                        print("🔴 Network: Offline")
                    }
                }
                
                // Determine connection type
                if path.usesInterfaceType(.wifi) {
                    self?.connectionType = .wifi
                    print("📶 Connection: WiFi")
                } else if path.usesInterfaceType(.cellular) {
                    self?.connectionType = .cellular
                    print("📱 Connection: Cellular")
                } else if path.usesInterfaceType(.wiredEthernet) {
                    self?.connectionType = .wiredEthernet
                    print("🔌 Connection: Ethernet")
                } else {
                    self?.connectionType = nil
                }
            }
        }
        
        monitor.start(queue: queue)
    }
    
    deinit {
        monitor.cancel()
    }
    
    // MARK: - Manual Check
    
    /// Force a connection check (monitor updates automatically)
    func checkConnection() {
        print("🔍 Checking network connection...")
    }
}

